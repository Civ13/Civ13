# Active training regression

Run `./tests/active_training/run.ps1 -ByondBin <516.1681-bin>`.
The isolated full-source fixture checks finite manual repetitions, native stat
gains, competing actors/reentry, movement/death/interruption/cancel guards,
actual course corner positions, era/caps/fatigue, human/equipment deletion and
disk-backed native gains/fatigue restoration without runtime session references.
Wait/clock adapters accelerate actions and inject failures. These assertions
do not exercise a human client, real elapsed waits, combat, or a live server.
Repeat with `-NegativeControl` to prove omitted post-wait movement and
consciousness guards fail the generated source copy; production is untouched.

## Click feedback source preparation

Offline preparation/oracle checks (no native processes):

```powershell
py -3 -B -m unittest discover -s tests/active_training -p 'test_click*.py' -v
py -3 -B tests/active_training/prepare_click.py --output C:/evidence/training-click-candidate
py -3 -B tests/active_training/prepare_click.py --original-silence --output C:/evidence/training-click-original
```

Use separate empty directories outside the checkout. These commands prepare
five overlay files and source hashes; they never compile or launch a daemon.
The pinned control uses the original production training source at
`cc03b199128f8afed58713912c551ad7556e6bc4`, with the same chat observation adapter.
It must fail the empty-hand/start/rejection/interruption feedback assertions
while retaining the finite native reward assertion. Do not accept an unrelated
runtime, incomplete result, timeout or abnormal exit as detection of silence.

After review, the sole authorized native executor can use the existing runner
from a disposable source checkout under its owned-process guard:

```powershell
./tests/active_training/run.ps1 -ByondBin <516.1681-bin> -ClickFeedback -EvidenceDirectory C:/evidence/training-click-candidate
./tests/active_training/run.ps1 -ByondBin <516.1681-bin> -ClickFeedback -OriginalSilence -EvidenceDirectory C:/evidence/training-click-original
```

Each evidence directory must be fresh and outside the checkout. This mode
consumes the exact prepared overlay, verifies every input/generated hash before
materialization, and refuses preexisting generated source/binary names. Shared
ClickOn, do_after, progressbar and time sources stay unchanged. It compiles with
BYOND 516.1681 and zero errors/warnings under a 180-second bound, then runs under
a 100-second wall bound. The fixture's 900-tick deadline is supplemental. Exit,
timeout and unrounded elapsed receipts are mandatory for both phases. Logs,
metadata and results survive failure; configs and binaries are not copied to the
evidence directory. The source-only preparation interface still launches nothing.

`verify_click.py` requires the exact 21 ordered checks and 11 cases. Candidate
must pass all checks; original-silence must fail exactly the 11 feedback checks
while all 10 other checks, including the native reward, pass. Matching canonical
PASS/FAIL log labels are required. Missing receipts, warnings, unrelated runtime
diagnostics, abnormal exits and timeouts cannot satisfy the causal oracle.

The compiler evidence contract requires one exact 516.1681 banner followed by
one complete `.active_training_click.dmb - 0 errors, 0 warnings` result line
(with optional native timestamp). Its version 1 diagnostic pattern and compiler
validator are copied unchanged from the accepted `contained-bb89a0b8-v7` helper
`oracle/z_budget_evidence.py` (SHA256
`133c130845ab28cfb6f0bfb8b2c63b595d3694afc44a3af398cb1fdf3de584db`),
identical to the `client-native-v10-composited-capture/helpers` copy. Additional
fixture-specific diagnostics remain rejected. Compiler logs retain the helper's
1 MiB bound. All ten required metadata/result/status/log files have a combined
16 MiB bound checked before reading, with bounded reads guarding subsequent
file growth. Every compiler/runtime stream rejects diagnostics and unrelated
FAIL markers; repeated intended original-silence markers in console copies are
allowed while the canonical log must still match the exact 21-check receipt.

The existing active_training CI step selects offline checks, the two original
accelerated positive/post-wait modes and both ClickFeedback modes under the
existing introduced-tests/extensive guard. Its 20-minute step bound also limits
the retained original flow. A pinned upload step retains only selected logs,
metadata/status/result/verification JSON for seven days after the step starts,
including failure. Connected client input is separate. This document describes
the executable seam; preparation/offline success does not mean native execution
has occurred or passed.

`click_game.dm` reuses the existing minimal world/human setup, routes clicks
through actual ClickOn, checks item versus empty-hand dispatch, and calls parent
exercise_wait for three real 150-tick waits and a hand-switch interruption.
No fake wait/clock is inserted. Ownership guard states and inventory fields are
seeded; only exercise-source chat calls are observed and forwarded to native chat.
The no-client fixture uses the same turf to avoid client-only facing code. It
does not establish a connected player's adjacent click or actual chat rendering.
Those require a separately approved isolated client check, including progress
bars disabled, empty active/occupied inactive hand, real timed repetition,
interruption and cap/fatigue explanations. Never target a public world.
