# Reserved-cell lumcount acceptance

The retained production corner graph supplies `get_lumcount()` for a turf whose
overlay is intentionally omitted by the reservation predicate. This path requires
completed startup and all four corners. Ordinary no-overlay cells, disabled
reservation policy, startup in progress, unsuccessful startup and incomplete
corners retain the existing `0.5` fallback. Both reservation defaults remain off;
no map opts in.

The omitted path refreshes the turf's dirty window coefficient, which its absent
overlay cannot refresh. It then uses the existing corner RGB, current time of day,
min/max scaling and clamping formula. The ordinary overlay path is unchanged.
This corrects a gameplay query; it does not prove appearance clearance, enable a
region, establish an unreachable-region invariant or measure net resource gains.

The production fixture retains the original six states and 1,350 overlay rows.
A separate `lumcounts` field calls the actual production `get_lumcount()` with
default bounds and with `(0.2, 0.8)` on all 256 cells in each state, giving 1,536
coordinate rows. Fixed cells `(9,6)`, `(10,6)`, `(10,7)`, `(11,6)`, `(11,7)` and
`(11,8)` must still be omitted in the candidate, including the final state. Their
36 rows are compared without requiring or reconstructing an overlay. Their dirty
window coefficients are deliberately invalidated in both variants: the baseline
uses its real overlay update, while the candidate must refresh during the query.

Additional native assertions exercise pre-startup, in-progress startup,
incomplete-corner, disabled-gate and ordinary no-overlay fallbacks. The existing
four causal controls are retained. A fifth `lumcount-guard` control restores the
old unconditional fallback and must reach a `Native lumcount mismatch`, rather
than merely failing to prepare or compile. Its fixed six-cell queries also retain
the dirty-cache sentinel, so stale coefficient behavior cannot be hidden by a
manually refreshed candidate cache.

Offline comparator tests reject either lumcount channel changing to the old
fallback at each of the six cells in every state (72 mutations), as well as missing,
duplicate, out-of-world, malformed and nonfinite semantic rows, including matching
corruption in both receipts. Preparation tests check the generated causal mutation
changes only its intended production source. Synthetic receipt tests establish
checker behavior, not production DM behavior.

The revised DM fixture and production correction require compilation and native
execution on the final published head through ordinary CI. Local work for this
change is source/offline only; no compiler, game, client or private save is used.
The held Windows runner, measurement/preflight tooling and existing README are
unchanged. Native state parity still does not establish rendered clearance,
performance, production availability or deployment.
