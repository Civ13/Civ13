# Roof without an upper plane

Run `python3 -B -m unittest discover -s tests/roof_construction -v` (Windows:
use a verified full Python path). This runs no compiler, daemon or game systems.

The test projects the production roof preflight and constructor's straight-line
and conditional statements into Python, with engine effects replaced by counted
boundaries. It checks refused and allowed allocation, existing planes, null
fallback, obstruction/support/save/busy restrictions, post-allocation rechecks,
material properties and linking. The caller is also projected to count single
roofing-item retirement only after construction succeeds and reset on failure.
Generated controls restore the old allocation abort or remove the null guard;
they must expose the missing roof or attempted null-location floor respectively.

Budget tests project the shared production arithmetic with float32 division,
checking below, exactly at and one cell above 1,400,000 tiles, repeated requests,
lower host budgets, whole-target reservations and the existing plane policy.
Two additional controls remove the cap or incorrectly make it exclusive.

This establishes offline source control flow, not native DM semantics, object
constructors, garbage collection, client rendering or full-game interaction.
Native fixtures and connected-client gameplay remain separate acceptance.
