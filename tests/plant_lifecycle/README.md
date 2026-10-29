# Plant lifecycle regression

Run `./tests/plant_lifecycle/run.ps1 -ByondBin <516.1681-bin>`.
Use `-Revision e48afe3a84485de779b2076b80841c1119288930 -Baseline` to reproduce the previous dead-crop recurring entry.

The fixture extracts production growth, stage, water, soil and death procs. Only the one-minute wait is shortened to two ticks and growth entries counted. Location adapters and a minimal map/area replace game startup. It checks drought death, terminal pending waits, static plants, living cadence, overripe transition, deletion and replacement by nonploughed terrain. Temporary artifacts and owned processes are removed in finally; no production state or external-effect hooks run.

Measured baseline: one recurring entry after drought; patched: zero. This is callback evidence, not full-game CPU/memory or speed evidence. Seed/harvest and persistence code are unchanged; gameplay and save/load acceptance for future cultivation adapters remain separate. Static state changed after a wait is queued drains that wait without further work. A plant becoming dead through age gets its dead appearance before the terminal growth entry returns.

No DF13 or Pocket Stronghold code/assets are copied. Explicit lifecycle stopping is an independently implemented idea, informed by source review of public DF13's processing lifecycle.

The current source extracts the shared `advance_stage_if_allowed` boundary too;
historical `-Revision` baselines without it retain their original proc list.
Offline parity coverage is documented in `../crop_stage_step/README.md`. It does
not replace native compilation or this fixture's actual lifecycle acceptance.
