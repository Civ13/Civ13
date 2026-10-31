# Extraction economy service contract

This is the staged implementation contract, not a claim that these services
are complete or accepted. The existing service implements quoted buyback and
fixed-price escrow. Specialized traders, listing fees, auctions and the admin
ledger below still require implementation and regression acceptance.

Stage one source now provides `extraction_trade_policy` and `trader_offer`.
The initial exact-type catalog matches the existing buyback types. Armorer
accepts weapons/ammunition/armor; quartermaster accepts armor/tools/materials;
salvager accepts salvage/tools/materials. Initial minimum condition is 50% for
armorer/quartermaster and 25% for salvager. Fence accepts their category union
at 20% of condition-scaled value. These are unaccepted tuning defaults. The
legacy adapter still uses its original root valuation; specialist offers are
not exposed yet. Specialist graphs reject any uncatalogued nested node, including
containers not yet assigned a legitimate category. Native assertions are authored
but remain unrun during the quiet window.

## Ownership and service boundary

The game owns category policy, valuation, quotes, equipment custody, balances,
fees, deadlines, settlement and audit recovery. Native safehouse interactions
must expose every player action. The bot owner implements projections and
confirmation UI against the same versioned service; it must never edit saves,
recompute authoritative prices or settle deadlines. Agree the action schemas
with that owner through the coordinator before extending either adapter.

## Trader policy

Use an explicit exact-type catalog with category, base integer value, supported
quantity and authoritative condition fields. No arbitrary subtype fallback.
Specialists accept overlapping declared categories with declared minimum
condition. Fence accepts the union of legitimate supported categories with a
lower policy multiplier. Private, admin, quest, secure, insured and unsupported
graphs are rejected. Validate every nested node, not just the root. Transfer
unchanged graphs preserving IDs, condition, FIR and insurance metadata.

Insured trading is currently unavailable: `ipc_economy.eligible()` rejects any
nested insurance token. This is a safety restriction, not permission to strip
tokens. Enabling it requires an explicit claim-ownership policy and an atomic
transaction updating the original insurer's claim/recovered-token records,
escrow and recipient ownership. The initial policy must be agreed through the
coordinator before implementation. Until then, deny the sale with an explicit
reason and retain the original item and all metadata unchanged. Test prior-owner
insurance recovery after sale, nested tokens, cancellation and crash replay.

Quotes bind policy version, trader, graph digest, account revisions, condition,
quantity, price and expiry. Confirmation repeats eligibility and rejects stale
condition, duplicate IDs, changed policy and busy or deployed accounts.

## Real-world currency valuation for future traders

Extraction game modes must use actual real-world foreign-exchange (FX) rates
when future traders value supported real-world currencies. Pounds, euros and
other supported currencies must not be interchangeable skins for equal-value
credits or use invented exchange rates. This means currency exchange rates,
not stock/security prices. This is a future implementation requirement: the
current prototype game-credit economy does not perform FX conversion.

### Currency and denomination identity

Use an explicit allowlist mapping each supported money item type and its existing
sprite to an ISO 4217 currency code and face denomination. Stack count multiplies
that denomination; stacked icon variants do not multiply it again. The existing
[money definitions](../code/game/objects/items/stacks/money.dm) and
[item sprites](../icons/obj/items.dmi) include these verified starting points:

| Item types under `/obj/item/stack/money/european/` | Currency | Face denominations per item | Initial icon states |
| --- | --- | --- | --- |
| `britpound`, `britpound5`, `britpound10`, `britpound20`, `britpound50` | GBP | 1, 5, 10, 20, 50 pounds respectively | `britpound`, `5britpound`, `10britpound`, `20britpound`, `50britpound` |
| `euro`, `euro2`, `euro5`, `euro10`, `euro20`, `euro50`, `euro100`, `euro200`, `euro500` | EUR | 1, 2, 5, 10, 20, 50, 100, 200, 500 euros respectively | `euro`, `2euro`, `5euro`, `10euro`, `20euro`, `50euro`, `100euro`, `200euro`, `500euro` |

Audit other currencies before admitting them; this table is not an exhaustive
currency catalog. Do not infer currency identity or face value from the legacy
`value` field alone: `/money/dollar` changes identity/denomination by map and era,
and `/money/rubles` describes Soviet rubles, not modern RUB. Historical,
fictional, ambiguous and unsupported money must remain outside contemporary FX
conversion unless a separate explicit policy is reviewed. Reuse existing sprites;
this requirement does not authorize adding art or changing legacy mode prices.

### Rate source and deterministic settlement

- Select and document a trusted, free public FX source at implementation time,
  verifying currency coverage, quotation direction, publication cadence and
  permitted use. Record provider identity, source effective time, fetch time,
  base currency and snapshot/version ID. No provider or current numeric rate is
  selected here; published reference rates must not be presented as guaranteed
  live executable prices. No paid service, credential or client-side request is
  required or authorized by this design note.
- Normalize all supported currencies to one explicit real-world base currency.
  Define `r_C` as base-currency units per one unit of currency C (`r_base = 1`).
  Then `base_value = stack_count * face_denomination * r_C`; conversion from C
  to D is `amount_C * r_C / r_D`. Invert provider quotes where required rather
  than accidentally reversing buy/sell conversion. The base selection and any
  mapping from base units to game credits are separately versioned design
  decisions, not an assumption that one game credit equals one real-world unit.
- Fetch and validate rates server-side on a bounded schedule, outside the trade
  transaction. Cache last-known-good snapshots with explicit freshness and
  maximum-stale limits that account for the provider's publication calendar.
  Reject malformed, missing, non-positive or non-finite required rates. On a
  fetch failure, use only an explicitly labeled cached snapshot within the
  reviewed stale limit; otherwise refuse new FX-dependent trades. Never silently
  substitute 1:1, fabricated rates or zero value. Show source date and stale state.
- Pin one immutable accepted snapshot for the round's economy and bind its ID to
  every quote, settlement receipt and recovery record. A refresh is for a later
  round, not repricing a pending trade. Once the pinned snapshot exceeds the
  maximum-stale limit, refuse new FX quotes rather than silently refreshing it;
  honor already accepted durable settlements using their recorded terms.
  Recovery/replay must use the original snapshot and amounts, never today's rate.
- Keep quotes and settlement server-authoritative across native and bot adapters.
  Specify bounded fixed-point/rational arithmetic and rounding once at the
  settlement boundary; buying and selling must not create profit from rounding
  or split-stack conversion. Retain existing custody, account-revision,
  conservation, bounds and idempotency checks.
- Keep trader buy/sell spreads, fees, condition, scarcity and game-balance
  multipliers explicit and separate from the recorded FX rate. Display face
  amount/currency, FX conversion, each adjustment and final payable amount.
  Balancing must not silently replace the real-world relative currency values.

Before activation, cover GBP/EUR denominations and stacks, both quote directions,
cross-currency conversion, unsupported/historical money, missing/stale/malformed
rates, provider outages, round snapshot pinning, quote expiry, rounding and
split-stack arbitrage, bounds, concurrent confirmation and crash/replay. These
are future acceptance requirements, not claims of implemented or tested FX.

## Fixed-price listings and fees

Listing creation atomically moves the actual graph to escrow and transfers the
quoted fee to a dedicated fee account through the conservation journal.
Keep the existing one-million-credit account bound. Asking prices and all fee
inputs must be bounded positive integers. Use configurable integer basis points:
`fee = max(minimum_fee, ceil(price * rate_bps / 10000))`. Enforce a bounded rate
and overflow-safe arithmetic before multiplication. The initial rate and minimum
are tuning choices, not human-approved balance values.

Quote the exact fee and resulting balance before confirmation. Reject insufficient
funds. Store the fee paid on the listing. Raising the price charges only
`max(0, fee(new_price) - fee_paid)` atomically with the revision; lowering it
does not refund fees. Cancellation, expiry and an unsold return retain the paid
fee. A rejected or rolled-back creation charges nothing. Replayed requests
return the original receipt without another transfer or fee.

Buy, cancel, reprice and expire compare the current listing revision and graph
digest. Only one can settle. Expired items return through durable escrow recovery;
blocked recipients remain pending without issuing copies or deleting custody.

## Auctions

Use a separate auction action family and safehouse menu. Creation fixes the
minimum bid, positive integer increment, absolute server deadline and fee quote.
The first bid meets the minimum; subsequent bids meet the previous bid plus
increment. Accept bids only before the deadline. Do not silently extend it.
Reserve actual bidder credits in escrow and atomically refund the previous
bidder when replacing a bid. Reject seller bids and stale revisions.

At the deadline, one idempotent settlement transfers the unchanged item graph
to the winning account and reserved funds to the seller. No bids returns the
item. Cancellation is allowed only before a bid. Full or busy accounts and
ambiguous disk state leave custody pending for recovery, never mint refunds.
Bound active records and process deadlines in bounded batches without world scans.

## Durable admin transaction ledger

Include an immutable audit event in the durable settlement intent before any
account projection. Recovery must materialize that event once under its stable
transaction/event ID before considering the settlement complete. A crash between
transfer and ledger acknowledgement must block access until reconciliation.
The bounded settlement receipt history is not the durable economic ledger.

Record timestamp, actor/counterparty account IDs, action/outcome, idempotency ID,
item ID/type/category/quantity/condition, trader/listing/auction ID, asking and
settlement prices, fee and currency deltas, policy version and game/bot origin.
Reversal and recovery events link the original transaction; never rewrite it.
Exclude secrets, IP addresses and private chats. Rate-limit and bound rejected
abuse-attempt events separately from completed transfers.

Shard and rotate disk records with bounded in-memory indexes and pagination.
Archive closed shards explicitly; do not silently erase records to meet a cap.
Manifest hashes support integrity checks, not a tamper-proof claim. Storage
exhaustion must reject new transfers before applying projections. Restricted
admin filters, paginated exports and aggregates read committed events only;
bot access is limited to separately authorized read-only views.

## Acceptance sequence

1. Exact-type category/condition valuation and duplicate selection guards.
2. Price-scaled fee quotes, atomic escrow, repricing, cancellation and expiry.
3. Auction bid reservation, replacement refunds and deadline settlement.
4. Ledger reconciliation and restricted game/admin/bot projections.

Each stage needs meaningful native negative controls for omitted guards,
temporary disk crash/replay/concurrency tests and exact-head CI. Exercise rounding,
minimum and price bounds, fee rollback, stale condition, nested identity,
double sale, late bids, unsold returns, recovery, ledger pagination/access and
bounded storage growth. Native tests resume only after explicit quiet-window
release. Connected acceptance and activation remain separate gates.
