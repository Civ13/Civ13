# Sleep while resting: offline contracts

Run `py -3 -B -m unittest discover -s tests/sleep_resting -p "test_*.py" -v`.

Sleep alone selects `(INCAPACITATION_DEFAULT & ~INCAPACITATION_DISABLED) |
INCAPACITATION_DISABLED_NO_REST`. This adds a positive checked-state subset at
bit 64: stat, paralysis, stun, weakness, actual sleeping and fake death are checked;
resting is not. The full disabled flag still checks resting. DEFAULT remains 13.
Even all-bits masks retain resting checks; no existing mask is globally relaxed.
Restraints and full buckling remain selected; an ordinary unrestrained bed buckle
is partial and retains its existing allowance. Lying appearance is not resting.

The do_after implementation and defaults are unchanged. Needhand remains FALSE,
movement remains disallowed, repeat ownership remains enabled and delay remains
two minutes. Tile changes or either physical step offset cancel. Changing held
items alone does not cancel this wait. A second attempt fails without releasing
or cancelling the first; Sleep is not a toggle. Current client identity is still
checked after the wait: disconnect/replacement/detachment rejects completion,
without a claim that do_after itself immediately detects network loss.

Tests project the complete actual incapacitated procedure, the complete do_after
body in both bridge modes with null contexts, and the selected actual Sleep prefix
through its wait call. All active instructions are translated. Local lexical
mappings supply null initial values, a fake progressbar constructor, type-path
sentinels, a Python while colon and explicit DM implicit-result return. The shared
projector is unchanged. Engine clocks, object null/deletion, client ownership,
progressbars, typed turf/clothing iteration and dialogs are fake boundaries.
One isolated fake status bit represents FAKEDEATH's on/off predicate; its production
definition is unchanged. These are source/model checks, not native two-minute,
movement, deletion, networking or graphical acceptance.

Frozen legacy capacity and Sleep-prefix fixtures come from f0cc213d4. No test
fetches Git history. All 64 preexisting named-mask combinations across 768 state
combinations retain exact results. A further 130 masks (including all-bit masks)
across those states never permit a previously refused state. The new Sleep mask
matches the original predicate with only resting removed. Tests cover ordinary
standing/resting success, all other actual incapacities, bed buckling, physical
movement, deletion, hand changes, repeated attempts, client loss and unchanged
disease/flea/hygiene/bed/sleeping early refusals.

Persistence completion is outside this patch. The body/lobby/storage owner should
carry the same explicit wait-mask argument forward when changing Sleep's success
path. Tests intentionally exclude that completion/storage code; its existing
client-ownership guard is checked separately. No body removal, lobby return,
save format, rejoin or live operation is implemented here. New native runs and
publication remain subject to the requested source review and bounded route.
