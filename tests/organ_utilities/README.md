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
