# Grinder transaction regression

From the repository root, with a verified Python installation:

```powershell
py -3 tests/grinder/test_transaction.py
```

This offline runner does not compile or launch BYOND. Its small interpreter
executes the scalar assignments, branches and delayed callback bodies of the
production grinder procedures. It rejects unsupported statements. Adapters
stand in for cable supply/reservations, inventory, stack debit/deletion,
constructors, UI and sounds. The real base-stack split/merge, oven dispatch and
paid-fuel credit procedure bodies are projected for conservation; the oven's
existing residue-account getter is an adapter. Material callbacks and native atom
movement are not executed. Fingerprint randomness is disabled in that projection.

Acquisition checks execute selected production menu, ordinary admission, scaled
wait, use/payment and constructor windows, plus the real exact-key research
resolver and base-stack debit. These omit unrelated recipe special cases and
native terrain checks. Map node completion, waits, occupancy, constructors and
the non-grinder exercise/telecom/generator gates are adapters. Circuit skill
checks project the existing >= 2.2 predicate; nominal copper/iron requirements
are source contracts. No native crafting/inventory or complete map progression
is established. Existing one-per-turf admission is before the wait: this change
does not fix concurrent construction, post-wait research or inventory-location
admission in the shared generic builder.

Checks cover:

- Every integer count from 0 through 51, fractional/invalid quantities and
  unsupported stacks; whole-batch debits, retained remainders and sized output.
- Power loss observed after either wait, missing cable, power restoration,
  cancellation, restart and stale callbacks that must not stop a newer cycle.
- Duplicate starts/completions, changed input identity/location/type/material,
  split/merged input counts, deletion flags, fire and woodworking ownership.
- Machine location/anchoring, replaced/deleted supply, save/load admission and
  its epoch, runtime-field exclusions, destruction/ejection and refused debit.
- Distinct nonmaterial chip batches, neighboring stacks, the ten-batch cap, split/merge
  conservation and no constructor auto-merge before output sizing.
- Equal raw-log/chip fuel and residue credit, retained leftovers, real oven
  dispatch, repeated/refused debit, malformed counts and held/adjacent admission.
- Refusal as ordinary wood or bark, no material/matter/crafting alias and no
  reverse-to-wood route. Five logs make one abstract batch, not a physical yield.
- Exact global-only constructed recipe and Electricity mapping; maximum era,
  locked-node/menu controls, 20-unit admission with normal 20/Production 18
  payment, scaled base duration, interruption and depleted stock after waiting.
- Constructed-type zero-salvage dispatch and inherited transaction checks;
  mapped base grinder flags remain unchanged. No new grinder skill threshold.

Five generated-source mutations remove ownership, input identity, quantity,
final power validation or debit. Each must expose an unsafe output that the
normal safety assertions would reject. Production source stays untouched.
Three additional fuel mutations expose amplified fuel, amplified residue credit
or fuel credited without the chip debit. They must violate the paid-input oracle.
Acquisition controls remove/misregister the exact node binding, admit the generic
wood-salvage guard, remove payment or over-discount the debit. Generated source
only is mutated. The subtype overrides no processing/lifecycle procedure.
`historical-grinder.dm` is the immutable grinder excerpt from baseline
`7f0a709df48bc8f8cf064ea2b679a68bdf937b25`; tests use this fixture rather than
requiring Git history. It records the old fractional conversion and lacks the
transaction contract. It is neither compiled nor claimed as a native reproducer.

Native compilation, the engine's callback/deletion ordering, real cable-network
transients, native stack/inventory behavior, current-format save/load and gameplay
are outside this offline runner's coverage. The projection checks procedure
logic, not these engine contracts.
The bounded offline registry in `scripts/ci_baseline.py` explicitly registers
only `test_transaction.py`. Changes under `tests/grinder/` select it along with
the mandatory baseline. Shared chemistry, stack, chip-definition, oven and paid-
residue, structure, research, menu and acquisition-catalog source changes and unknown impact
keep the existing conservative all-suite fallback, now including this suite.
Normal CI records its command, test counts and log in the baseline artifact;
nonzero exit, failed/empty/skipped execution or a missing receipt cannot pass
the existing required aggregate. No workflow/native admission is expanded.
