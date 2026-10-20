# Offline source generator checks

Run `test_progress_sources.py` with a verified Python interpreter. It uses the
checkout's saver, persistence functions and tick definition as immutable inputs,
and writes generated copies only in temporary storage. `--source-root <checkout>`
can select another explicitly reviewed source checkout without changing it.

The checks cover phase wrapper generation, exact source and output hashes,
unchanged functions/input bytes, missing and duplicate insertion anchors, and
legacy backend rejection before Git dependency reads or output creation.

The generic progress generator accepts sources whose hashes and required anchors
match. That lexical acceptance is separate from the backend builder's fixed legacy
source closure. Neither establishes that all current save phases are measured,
that generated DM compiles, or that current save/recovery behavior works. Native
clock, phase attribution, overhead and gameplay acceptance remain separate work.
