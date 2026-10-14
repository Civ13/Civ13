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
current atomic export coverage or a speed measurement. Ten-decisecond wall
clock resolution permits zero short phase intervals. Engine monotonic flush
timings provide separate attribution; yield includes those flushes, so the two
measurements must not be added together. A matching accepted smoke enables the
owner's next full Gaia profile; only a completed stopped full-world generation
can enable its fresh-process recovery check.
