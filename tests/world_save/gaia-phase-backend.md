The legacy Gaia backend smoke is a separate contract from the current atomic
save fixtures. `build-gaia-phase-backend.py` freezes the original f519 saver,
afe5 helpers and 3da tick definitions, and takes its loading, offline adapters,
predefines and genuine floor resource from commit cbf0ebb0. It rejects changed
original hashes before creating the output directory. The generated saver and
diagnostic helpers match the existing legacy Gaia phase packet.

The runtime owner compiles `backend.dme` with the selected exact OpenDream
compiler/runtime, then runs SAVE followed by a separate VERIFY process with
`verify=1`, sharing only temporary storage. Record engine commit, compiler and
runtime hashes, original logs, exit status, guard results and generated manifest.
An engine error, incomplete generation, failed assertion or missing terminal
receipt invalidates the result. Neither this generator nor its source-only
validation launches an engine.

SAVE checks real timeofday advancement, actual multi-level typed save files,
completion marker, nested object/datum/list data, traversal/call counters, scoped
yield advancement and an exclusive phase partition. An explicit fixture legacy
`before_save()` hook requests real stoplag to exercise pending engine flushes.
Production tick limits and saver hooks remain unchanged. VERIFY checks the saved
graph and second-level turf/item in a fresh process. It must only run after the
SAVE process has stopped successfully and the complete generation is retained.

This is a small actual backend smoke, not full Gaia recovery, crash recovery,
current atomic export coverage or a speed measurement. One-decisecond wall
clock resolution permits zero short phase intervals. Engine monotonic flush
timings provide separate attribution; yield includes those flushes, so the two
measurements must not be added together. A matching accepted smoke enables the
owner's next full Gaia profile; only a completed stopped full-world generation
can enable its fresh-process recovery check.

The first actual 644 backend run compiled without warnings, then rejected equal
timeofday samples across the startup `sleep(2)`; no SAVE generation or VERIFY
was accepted. Its shutdown runtime errors remain a separate engine investigation.
The successor moves sampling after eight normal ticks, then observes four normal
ticks and records both game time and timeofday. This follows pinned 644 native
sleep's tick deadlines and its af2a7d04 Robust game loop's five queued tick limit:
startup catch-up can advance game ticks inside one 0.1-second clock interval.
This is a source-supported timing hypothesis, not a proven cause or getter fix.
The clock advancement assertion remains mandatory; game-time advancement is
also required. No polling, fake clock, production threshold change or assertion
waiver is introduced. Preserve the original failed packet and logs.

The third fixture packet changes only the declared isolated stop route: after
writing its terminal JSON and TXT receipts the fixture returns, leaving the
world idle. The owner waits for both bounded disk results, sends the pinned
Robust console `shutdown` command through its owned input pipe and verifies a
clean exit with no runtime diagnostics before starting fresh VERIFY. A failed
or malformed result still requires shutdown but cannot accept the phase. This
does not fix or exercise `del(world)`; the original shutdown failure remains
separate. Clock, save, payload, phase and fresh-process assertions are unchanged.

The actual v3 SAVE passed, but fresh VERIFY rejected matrix construction. The
stopped save contains `/matrix` entries referenced by item transform fields.
Legacy `Load_Entry` calls `new type(starting_loc)` even for non-atom datums;
OpenDream's matrix constructor rejects that explicit null argument rather than
using its no-argument identity constructor. `--datum-constructor-mode no-location`
changes only the generated loader's construction branch: atoms retain the
location argument and non-atom datums receive no arguments. The manifest binds
both original and generated loader hashes, and the original loader is retained.
This is an explicit source change to the legacy closure, not original-source
backend acceptance or a production patch.

The strengthened fixture saves standalone and transform matrices with six
non-default coefficients and requires exact restoration of every coefficient.
Generate the same fixture with `--datum-constructor-mode original` for the
constructor negative control. It must fail the fresh load at the original matrix
constructor error; a null/default fallback, matrix exclusion or missing receipt
cannot pass. The positive must pass SAVE and fresh VERIFY without runtime errors,
with stopped generation hashes unchanged by VERIFY. Native BYOND compatibility
and production adoption remain separate work for the runtime owner.
