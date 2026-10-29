# Cactus water

Use an open reagent container in the active hand on an adjacent ordinary wild
cactus with a non-harm intent. This immediately collects water reagent. The
provisional tuning is 20 units per cactus and at most 5 units per click: 5 is
the normal small reagent-container transfer, and 20 is less than the 30-unit
capacity of a vial. These are gameplay defaults for later tuning, not
claims about real cactus water. Peyote crops and cactus artwork are unchanged.

The cactus does not regenerate water. A full or closed container consumes no
stock. The amount is bounded by the container's free space and reserved before
holder callbacks. The holder reports the actual amount accepted and any unused
reservation is refunded. The immediate action has no waiting/cancellation period. It
rejects persistence operations, and the wild-object save allowlist includes
the remaining amount even at zero. Old saves without the field use the default.
Destroying the cactus discards any remaining stock.

Offline check: run `-B -m unittest discover -s tests/cactus_water -v` with a
working Python 3 executable. This checks source contracts and a small accounting
projection, not DM execution.

Native acceptance remains separate and requires an authorized isolated fixture
or game on the reviewed exact commit and CI's BYOND version (516.1688):

1. Collect repeatedly into an open held container; verify 5, a partial draw
   into near-full capacity, zero on full, and total yield of 20 across vessels.
2. Check closed and dropped containers, movement/range, deletion, harm intent,
   and two players rapidly interacting. Verify no double credit or lost stock
   on a rejected interaction and normal chopping still works.
3. Save and restore a partially drained and a fully depleted cactus alongside
   its containers. Verify the restored amounts and that a legacy save without
   the new field starts at 20. Attempt collection while save/load is active.
4. Exercise a vessel with reactions and change callbacks, including a reentrant
   attempt, and verify the amount accepted before reactions matches the debit.

Run the project's full compiler/CI checks as appropriate. These steps are a
test plan, not evidence that native behavior has already passed.
