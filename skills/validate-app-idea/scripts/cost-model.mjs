// Cost + rate-limit model for /validate-app-idea. Zero dependencies.
// Copy this file and cost-model.test.mjs next to each other, replace the
// EXAMPLE workloads with the idea's own, and run `node --test`.
//
// Units: prices in $ per million tokens, rate limits in requests/min (rpm)
// and tokens/sec (tps), money per week unless a name says otherwise.

export const WEEKS_PER_MONTH = 52 / 12;

// One LLM call pattern. `calls` is per user per week for a per-user workload,
// or per week in total for a shared one (computed once, fanned out in code).
// cachedInputTokens is the share of inputTokens billed at the cache-read rate.
export function workloadCost(w, pricing) {
  const cached = w.cachedInputTokens ?? 0;
  if (cached > w.inputTokens) throw new RangeError(`${w.name}: cachedInputTokens > inputTokens`);
  const perCall =
    ((w.inputTokens - cached) * pricing.inputPerMTok +
      cached * (pricing.cachedInputPerMTok ?? pricing.inputPerMTok) +
      w.outputTokens * pricing.outputPerMTok) /
    1e6;
  return w.calls * perCall;
}

export function sumCost(workloads, pricing) {
  return workloads.reduce((sum, w) => sum + workloadCost(w, pricing), 0);
}

export const costPerUserWeek = (perUser, pricing) => sumCost(perUser, pricing);
export const sharedCostWeek = (shared, pricing) => sumCost(shared, pricing);

export function totalWeekly(users, { perUser = [], shared = [], pricing }) {
  return users * costPerUserWeek(perUser, pricing) + sharedCostWeek(shared, pricing);
}

// Paying subscribers needed to cover fixed monthly costs (data feed, hosting)
// plus shared LLM work. Each subscriber nets price after the store cut, minus
// their own variable LLM cost. Returns Infinity when a subscriber loses money.
export function breakEvenSubscribers({
  fixedMonthly = 0,
  sharedMonthly = 0,
  priceMonthly,
  storeCut = 0,
  variablePerUserMonthly = 0,
}) {
  const margin = priceMonthly * (1 - storeCut) - variablePerUserMonthly;
  if (margin <= 0) return Infinity;
  return Math.ceil((fixedMonthly + sharedMonthly) / margin);
}

// Minutes to serve `users` after a breaking event, bounded by BOTH limits.
// batchSize folds several users' items into one request, which cuts requests
// but not tokens; overheadTokensPerRequest is the prompt repeated per request.
// Returns the binding limit, so you can see when batching flips it.
export function burstMinutes({
  users,
  callsPerUser = 1,
  tokensPerCall,
  overheadTokensPerRequest = 0,
  batchSize = 1,
  rpm,
  tps,
}) {
  if (batchSize < 1) throw new RangeError('batchSize must be >= 1');
  const items = users * callsPerUser;
  const requests = Math.ceil(items / batchSize);
  const tokens = items * tokensPerCall + requests * overheadTokensPerRequest;
  const byRequests = requests / rpm;
  const byTokens = tokens / (tps * 60);
  return {
    minutes: Math.max(byRequests, byTokens),
    bottleneck: byRequests >= byTokens ? 'requests/min' : 'tokens/sec',
    byRequests,
    byTokens,
    requests,
    tokens,
  };
}

export function summarize({ users, perUser, shared, pricing, fixedMonthly, priceMonthly, storeCut }) {
  const perUserWeek = costPerUserWeek(perUser, pricing);
  const sharedWeek = sharedCostWeek(shared, pricing);
  return {
    perUserWeek,
    sharedWeek,
    totalWeek: users * perUserWeek + sharedWeek,
    totalMonth: (users * perUserWeek + sharedWeek) * WEEKS_PER_MONTH,
    breakEven: breakEvenSubscribers({
      fixedMonthly,
      sharedMonthly: sharedWeek * WEEKS_PER_MONTH,
      priceMonthly,
      storeCut,
      variablePerUserMonthly: perUserWeek * WEEKS_PER_MONTH,
    }),
  };
}

// EXAMPLE only: replace with the idea's features, sourced prices and limits.
export const EXAMPLE = {
  pricing: { inputPerMTok: 3, cachedInputPerMTok: 0.3, outputPerMTok: 15 },
  perUser: [
    { name: 'daily digest', calls: 7, inputTokens: 4000, cachedInputTokens: 3000, outputTokens: 500 },
    { name: 'ad-hoc question', calls: 10, inputTokens: 2000, outputTokens: 400 },
  ],
  shared: [{ name: 'classify each event once', calls: 5000, inputTokens: 800, outputTokens: 100 }],
  fixedMonthly: 500,
  priceMonthly: 9.99,
  storeCut: 0.15,
};

if (import.meta.url === `file://${process.argv[1]}`) {
  const users = Number(process.argv[2] ?? 1000);
  console.log(JSON.stringify({ users, ...summarize({ users, ...EXAMPLE }) }, null, 2));
}
