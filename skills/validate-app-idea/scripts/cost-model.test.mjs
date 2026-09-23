import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  workloadCost,
  costPerUserWeek,
  sharedCostWeek,
  totalWeekly,
  breakEvenSubscribers,
  burstMinutes,
  summarize,
  WEEKS_PER_MONTH,
  EXAMPLE,
} from './cost-model.mjs';

const pricing = { inputPerMTok: 3, cachedInputPerMTok: 0.3, outputPerMTok: 15 };
const close = (a, b, eps = 1e-9) => assert.ok(Math.abs(a - b) < eps, `${a} != ${b}`);

test('workloadCost prices input, cached input and output separately', () => {
  // 1M in @ $3 + 1M out @ $15 = $18 per call
  close(workloadCost({ calls: 1, inputTokens: 1e6, outputTokens: 1e6 }, pricing), 18);
  // half the input cached: 0.5*3 + 0.5*0.3 = 1.65
  close(workloadCost({ calls: 2, inputTokens: 1e6, cachedInputTokens: 5e5, outputTokens: 0 }, pricing), 3.3);
});

test('cached rate falls back to the input rate', () => {
  close(workloadCost({ calls: 1, inputTokens: 1e6, cachedInputTokens: 1e6, outputTokens: 0 }, { inputPerMTok: 3, outputPerMTok: 15 }), 3);
});

test('cachedInputTokens above inputTokens is an assumption error', () => {
  assert.throws(() => workloadCost({ name: 'x', calls: 1, inputTokens: 1, cachedInputTokens: 2, outputTokens: 0 }, pricing), RangeError);
});

test('shared work is paid once, not per user', () => {
  const shared = [{ calls: 100, inputTokens: 1000, outputTokens: 0 }];
  const perUser = [{ calls: 1, inputTokens: 1000, outputTokens: 0 }];
  const one = totalWeekly(1, { perUser, shared, pricing });
  const thousand = totalWeekly(1000, { perUser, shared, pricing });
  close(thousand - one, 999 * costPerUserWeek(perUser, pricing));
  close(sharedCostWeek(shared, pricing), 0.3);
});

test('break-even covers fixed + shared costs out of per-subscriber margin', () => {
  // margin = 10*0.85 - 0.5 = 8; (500 + 100) / 8 = 75
  assert.equal(breakEvenSubscribers({ fixedMonthly: 500, sharedMonthly: 100, priceMonthly: 10, storeCut: 0.15, variablePerUserMonthly: 0.5 }), 75);
  // rounds up: 1 dollar over needs one more subscriber
  assert.equal(breakEvenSubscribers({ fixedMonthly: 601, priceMonthly: 8 }), 76);
});

test('break-even is Infinity when each subscriber loses money', () => {
  assert.equal(breakEvenSubscribers({ fixedMonthly: 1, priceMonthly: 1, storeCut: 0.3, variablePerUserMonthly: 0.7 }), Infinity);
});

test('burst time is bound by requests/min when unbatched', () => {
  const r = burstMinutes({ users: 10000, tokensPerCall: 1000, rpm: 1000, tps: 100000 });
  assert.equal(r.bottleneck, 'requests/min');
  close(r.minutes, 10); // 10k requests / 1k rpm
  close(r.byTokens, 10e6 / 6e6);
});

test('batching flips the bottleneck from requests/min to tokens/sec', () => {
  const base = { users: 10000, tokensPerCall: 1000, overheadTokensPerRequest: 500, rpm: 1000, tps: 40000 };
  const unbatched = burstMinutes(base);
  const batched = burstMinutes({ ...base, batchSize: 50 });
  assert.equal(unbatched.bottleneck, 'requests/min');
  assert.equal(batched.bottleneck, 'tokens/sec');
  assert.equal(batched.requests, 200);
  assert.equal(batched.tokens, 10000 * 1000 + 200 * 500);
  assert.ok(batched.minutes < unbatched.minutes);
  // tokens now bind: batching further cannot beat the token floor
  const floor = (10000 * 1000) / (40000 * 60);
  assert.ok(burstMinutes({ ...base, batchSize: 10000 }).minutes >= floor);
});

test('batchSize below 1 is rejected', () => {
  assert.throws(() => burstMinutes({ users: 1, tokensPerCall: 1, batchSize: 0, rpm: 1, tps: 1 }), RangeError);
});

test('summarize agrees with the parts for the EXAMPLE', () => {
  const s = summarize({ users: 1000, ...EXAMPLE });
  close(s.totalWeek, totalWeekly(1000, EXAMPLE));
  close(s.totalMonth, s.totalWeek * WEEKS_PER_MONTH);
  assert.ok(Number.isInteger(s.breakEven) && s.breakEven > 0);
});
