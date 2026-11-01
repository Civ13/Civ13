# Animal harvest regression

Busy-action admission is checked offline with:

```powershell
& '<verified-python-executable>' -B tests/animal_harvest/test_action_admission.py
```

This checks the production early-return expressions before messages, claims or
cooldown changes across tall/floor grass, branch clearing, stick sharpening,
ants, axe binding, flint gathering and the flint/bench repair handlers. Each
omitted guard and a guard moved after the grass announcement are negative
controls. It does not execute DM, waits, UI or native callbacks.

The prepared `action_admission_probe.dm` additionally holds the real stick
sharpening wait while clicking both tall-grass variants, another stick, axe
parts and repair targets. It asserts no second grass wait/start/cooldown, no
resource/durability changes, the original wait remains owned and completes,
and idle grass cutting still announces and yields normally. The existing
tall-grass matrix also checks busy entry. These added native assertions
were compiled at `011931e0a`, where runtime preflight rejected the copied-name
file count. At `8cc5ddd1d` the input correction passed preflight, both compiles
passed, and one daemon ran, but startup runtime errors caused the runner to
reject the attempt. Later tanning PASS markers are partial progress only.
See [startup diagnosis and local proposal](startup-isolation.md).

Normal CI registers this exact offline file as the bounded baseline's
`action_admission` suite. Its stdlib-only imports never launch a native runner;
shared game and fixture inputs preserve the existing all-suite fallback.

CI selection proposal: an ordinary PR against master introducing the new probe
and offline test also selects the registered `tests/animal_harvest` native suite
in CI, including its existing pinned 516.1688 limited fixture runner after
compilation. Leave `extensive_regressions` off. The new competing-click fixture
is included and invoked by that runner; it is not a separate manual case.
If publication
of a new native test is not yet admitted, retain this branch locally. No workflow
dispatch is needed or authorized by preparing the source. Connected-client
message delivery, smooth movement and live Gaia behavior remain separate.

Run only under the admitted native plan, with a verified Python interpreter and
explicit BYOND 516.1688 bin path:

```powershell
& '<verified-python-executable>' tests/animal_harvest/run.py --byond-bin '<516.1688-bin>'
```

The runner compiles the production DME without its map or normal world startup,
then launches a small offline world in unique temporary storage under ignored
`data/animal-harvest-tests`. The prepared correction stages the exact 146 pinned
eager name inputs and the existing minimal config under `runtime/`, with separate
input/output accounting. See [input-accounting.md](input-accounting.md) for the
source proof, old/new bounds, zero-launch controls and native review proposal.
The baseline registers `test_input_accounting.py` as the offline `harvest_inputs`
suite. Unique owned
generated files, prelaunch input snapshots and runtime logs are retained on
success, failure, timeout and interruption. No runner path deletes them.
Linux CI uses the downloaded pinned BYOND bin directory and `/usr/bin/python3`.
Linux also requires `--byond-archive <reviewed-pinned.zip>`; the manifest version,
one exact clean compiler banner, archive and four installed members are checked.
This source reconciliation does not establish new native compatibility.

Linux reuses the reviewed flax bounded capture/manifest helper instead of the
bare subprocess fallback. The existing CI call explicitly selects
`--acceptance-scope limited`; legacy callers default to that scope. It retains
the pinned compile, fixture result, diagnostic and no-port checks and preserves
all generated inputs/logs. A passing limited run records
`limited_fixture_pass_cleanup_unverified`, prints a LIMITED notice and never
claims verified Linux descendants/sockets or complete acceptance.

The stricter lane requires explicit `--acceptance-scope full` together with
`--external-cleanup-receipt <observer-produced.json>` (up to five seconds to
arrive, adjustable downward with `--cleanup-receipt-wait`). The external observer
must bind `head_sha`, the generated manifest's `run_id`, absolute
`evidence_directory`, sorted compile/runtime `phase_pids`, `descendants_exited`
and `sockets_closed` TRUE, a named `external_verifier`, and an owned relative
`os_evidence_path` with matching `os_evidence_sha256`. It must actually verify
owned descendants and sockets; the runner never generates that assertion.
The receipt and OS evidence still require independent review. A JSON assertion
is not authorization or independently proven containment. Missing/mismatched
evidence fails closed in full scope while preserving the fixture's actual
results and files. Full selection without a receipt path, or a receipt argument
without explicit full selection, is rejected before launch. Full scope is
prepared for Linux only; the existing Windows owned Session checks remain.
`full_acceptance_complete` stays FALSE because complete #3322 acceptance also
needs independent OS/capture review and the connected scene.

No reviewed Linux external cleanup observer/producer is available in the shared
helper or this fixture. CI therefore selects only limited checks; extensive
selection does not promote them to full scope. The full lane is not wired into
CI and remains gated on an admitted external observer and its actual evidence.
No workflow was launched and no OS attestation was synthesized here.

The reused #3322 rack matrix keeps production human left/right pickup and checks
HUD item state on admission/cleanup. It retains its legacy-result, floor-merge,
bag, denial and redirect controls. Its constructor initializes the existing HUD
dependencies without replacing inventory handlers. See the source-only
[human entry plan](../flax_processing/human-entry-plan.md) for the separate
admission and evidence limits. No native run was performed in that preparation.

The fixture executes production yield construction, harvesting claims, post-wait
validation, sinew conversion, axe assembly and the actual map-storage object
save/load implementation. Wait adapters inject cancellation, revival, movement,
tool loss, corpse deletion, disconnected actors and recursive competing attempts.
Two cases additionally execute production `do_after` for successful completion
and movement cancellation. Network clients, normal AI/startup, medical experience
and inventory UI are excluded. Results do not establish full-server RAM usage,
production season behavior or graphical gameplay acceptance.

Tall grass uses the existing grass-cuttings material: cut either tall-grass
object with a sharp tool, then activate two held cuttings to make one crude
twine. The twine already gives a flint axe one quarter of normal durability.
Harvesting removes the plant without changing its floor; ordinary uprooting and
burning remain available. The agent's existing guarded `gather` action admits
both tall-grass types with its existing sharpened flint requirement.

The prepared tall-grass cases call each variant's production `attackby`, checking
two cuttings, one existing twine, plant retirement, unchanged floor, competing
and repeated claims, knife versus raw flint, cancellation, tool loss/blunting,
plant or actor movement, deletion, disconnection and unconsciousness. The lock
is explicitly excluded from persistence. Entry and completion also reject
stunned actors, changed hands, tools left in inventory or nested in a bag, and
movement to another adjacent tile. Production `do_after` cases additionally
inject movement, stun and hand switching during a real wait. The substantive
cases and adapters live in `tall_grass_probe.dm`, included and called by the
existing fixture; its new executable path selects this registered suite on PRs
without changing the CI workflow. Client, inventory setup and wait adapters
remain fixture-only. They were included in the compiled `8cc5ddd1d` fixture,
whose daemon attempt failed its runtime guard; there is no clean native pass.

Startup diagnostics and DM exceptions remain failures, recorded by the runner;
the local startup proposal does not change that guard or establish a clean
full-game startup. The bounded output assertion measures item count, not heap
usage.

With Pillow, `preview.py --output <file.png>` validates each new item's effective
existing DMI state (including rotten variants), rejects blank/missing sprites and
renders a PR-review sheet. It never modifies game art. Upload the sheet to the PR,
verify its rendered attachment, then remove the generated local PNG.
