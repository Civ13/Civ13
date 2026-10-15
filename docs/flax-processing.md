# Flax processing

Draft implementation: the source is included and the comb is registered for
eight softwood planks under Resource Processing. Native acceptance is pending.

## Proposed player route

1. Hold at least two raw flax portions and use **Tie Flax Bundle**. The two
   portions are bound with their own fibres; existing twine is not required.
2. Use the bundle on adjacent, non-irradiated fresh water. Three ten-second
   attended soaking stages produce two portions of rotted flax. Interruption
   retains completed stages. Click a submerged bundle to resume; drag it into
   a hand to recover it.
3. Load up to ten rotted flax portions into a flax comb. Each attended
   ten-second use advances one stage: straw, tow, then textile lint. Each
   portion yields one of each product. Drag the comb onto yourself to remove
   its unfinished batch. That batch can resume in another empty comb.
4. Use two tow in hand to spin one coil of twine in five seconds. It uses the
   existing rope item and its consumers. Existing weak grass twine is unchanged.
5. Use two textile lint in hand to prepare one retted fabric, already accepted
   by the existing loom. Textile lint is a separate item from magical pocket lint.

Thus two paid raw flax produce two straw, one rope and one retted fabric.
Legacy raw-flax rope recipes and hemp/flax trough recipes remain available.
The new route adds a staged alternative; it does not replace those recipes.

The [A Tale in the Desert Flax Comb reference](https://atitd.org/wiki/tale4/Flax_Comb)
describes three stages, one straw/tow/lint per rotted flax and a ten-portion
batch cap. These are design inspiration. Civ13 costs, times, self-binding,
water restrictions and secondary conversion ratios are independent tuning.

## State and acceptance

Bundles retain completed soaking stages. Combs contain an actual unfinished
batch with its paid portion count and completed stage, rather than retained
actor references. Removing or destroying a comb releases its unfinished batch.
Action locks are explicitly excluded from native persistence, including import.
No per-item timer or recurring processing list is added.

The implementation reuses actual flax, rope, retted fabric and drying-rack
DMI states. The comb currently uses the existing rack sprite. Static sprite
inspection is not a gameplay capture.

Required acceptance includes paid construction and registration, native
production-path processing, cancellation and overlap, water replacement and
salt rejection, output conservation, recovery after destruction, and disk
round trips of partly soaked bundles and partly combed batches. Mutation
controls must detect free inputs, replayed outputs and persisted locks.
The versioned fixture is `tests/flax_processing/run.py`. Its source check
validates unique mutation targets without invoking native tools:

```text
<verified-python> tests/flax_processing/run.py --source-check
```

Native runs require pinned BYOND 516.1681 and an empty evidence directory:

```text
<verified-python> tests/flax_processing/run.py --byond-bin <516.1681-bin> --output <evidence>
```

Run each of `--negative-control payment`, `replay` and `persistence` with
separate evidence directories. Remote CI selects this new suite for its PR;
local native runs require the exclusive runtime lease. No runtime, CI,
graphical or live-server acceptance is claimed yet.
