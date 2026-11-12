# Biofuel output capacity

Issue #4865: an almost-full output barrel must not consume a full input batch
when it can accept only part of the product. Ethanol keeps its 1:1 yield;
biodiesel and the legacy fallback keep their 0.7 yield and ten-unit input cap.
The remainder stays in the refinery for later cycles or a replacement barrel.

Run `python -m unittest discover -s tests/biofuel_capacity -p "test_*.py" -v`
or the registered `biofuel_capacity` offline suite.

The tests execute the complete production `biofuel/refine()` control flow through
the shared source adapter. Reagents and timer scheduling are fake boundaries;
this is not native BYOND execution or save/load acceptance. Near-full and
fractional capacity, small and full batches, both outputs, the legacy fallback,
power/active/missing-barrel guards, and old-loss mutation controls are covered.

Manual mixed-feed overfill (#4864), petroleum refining, unknown reagent
registration, native chemistry callbacks and graphical gameplay are separate.

Batches below MINIMUM_CHEMICAL_VOLUME are retained rather than debited because
the reagent holder removes new traces below that threshold. This conservative
guard also retains trace batches when an existing product could accumulate them.
