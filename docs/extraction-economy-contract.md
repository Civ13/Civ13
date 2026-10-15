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
