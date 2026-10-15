# Wood ash and plant nitrary gameplay

Ovens, bloomeries, kilns and fuel-burning factories retain the provenance of paid wood and plant fuel. Burning each whole unit of that fuel leaves one existing wood-ash item on the structure's turf. Loading fuel alone produces nothing. Fractional consumption carries forward; coal, charcoal, dung and unattributed legacy fuel receive no wood credit. Existing campfires and wood stoves have four units of construction wood. Existing loose-log burning is unchanged. Ash collection requires room for a whole unit in a glass container.

An empty existing compost bin has a **Use as plant nitrary** verb. Conversion dedicates that bin permanently; ordinary compost bins continue making fertilizer. Building and dismantling bins retain their existing map, material and research requirements.

The game's nitrary accepts leaves or the listed raw crop stacks (flax, hemp, poppy, tobacco or coca), plus water. Examine the bin for paid input totals, stage and remaining running-server time. It requires a full batch and active-server aging before accepting ash for another timed stage. An empty held small pot draws one finite batch of dilute leachate; the existing lit-stove small-pot callback converts that paid extract into the same legacy potassium and nitrogen reagent IDs used by saltpeter ore extraction. This is a compressed gameplay abstraction, not real-world chemistry or production guidance. Ash supports processing; it does not independently supply nitrogen.

Balance constants in `wood_ash_compost.dm`: eight crop-equivalent units (a leaf counts one quarter), ten water, thirty running-server minutes, one ash, one minute of leaching, ten leachate yielding one each of the existing mineral IDs. Food, seeds, wood, urine and fertilizer do not earn plant credit. Production-religion crafting discounts do not reduce feedstock payment. Stages and paid inputs survive native saves; the runtime clock does not, so offline time earns no progress. A processing gap credits at most one minute per call.

Existing mined saltpeter, fertilizer composting, chemistry recipes, sprites and structures remain available. No third-party assets are copied.

## Verification

`tests/wood_ash_compost/run.py --byond-bin <516.1681-bin> --output <empty-directory>` compiles production code with maps and normal startup disabled. It closes the network port and uses temporary native saves. The fixture exercises production refueling, ignition, ash pickup, paid nitrary stages, real stove callbacks and disk round trips. Aging advances controlled clock deltas through the actual process method; it is not a thirty-minute gameplay observation.

Six generated-source negative controls omit wood consumption, misclassify coal, skip plant payment, remove aging, permit batch replay or serialize the runtime clock. `--source-check` validates their unique targets without launching BYOND. CI selects the new suite for this PR; subsequent runs remain opt-in. Full-map acquisition and production deployment are separate evidence.
