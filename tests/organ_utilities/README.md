# Intestine casing source checks

Run `python3 tests/organ_utilities/test_casings.py` or the registered offline
`intestine_casings` suite. Seven source-contract checks cover input admission,
paid output ordering, individual omitted-guard mutations, duplicate output,
accidental waits, existing inheritance/art and Atlas metadata consistency.
These are not a DM interpreter or a native gameplay test.

The production interaction is immediate, with no introduced wait or saved state.
Real-client knife/grab dispatch, inventory cleanup, queued deletion, stack merging,
sausage stuffing, save/load and map reachability still need native acceptance.
Existing stomach recipes and the existing sausage-stuffing implementation are not
changed or validated by these tests. No claim of complete organ-plan delivery.

## Specimens, organ spoiling and catgut (issue 5126 phases 2-4)

`python3 tests/organ_utilities/test_organ_uses.py` (same `intestine_casings`
suite) checks `code/modules/organs/organ_uses.dm` and its hooks: specimen
preservation re-checks both hands, the organ and the fluid after the wait and
pays both inputs before one output; no human brain or limb becomes a specimen;
finds stay finite, are re-checked after the wait and share one kind across
animal and human organs; cold storage and the sealed box only slow spoiling,
and an unpowered fridge helps less; loose organs resume spoiling after a load;
the transplant end step refuses a filled slot; catgut is a surgical tool.
These are source checks. Real-client dispatch, save/load round trips, fridge
power loss and two surgeons racing still need native acceptance.
