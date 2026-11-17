# Train step cost

Runner: `tests/train_step_bench/run.py` (probe `bench.dm`). It builds trains
with the real train code on a bare map, steps each one 20 tiles after a
two-tile warm-up, and reports the cost of one step in milliseconds
(`world.tick_usage`). The clearance column is `train_consist_obstacle()` on
its own. Every train is led by a heavy steam locomotive (4 sections), except
the one-tile rows.

```bash
python3 tests/train_step_bench/run.py --byond-bin <pinned bin> --evidence-dir <fresh dir>
```

The runner sets no time limit, since timings depend on the machine. It fails
when a scenario does not run in full or when cost does not grow with length.

## Baseline

BYOND 516.1688 on Linux, a 2.1 GHz cloud Xeon, 2026-11-17, before any of the
train scale-up work. Sections are rail tiles of train; parts are the deck,
wall, window and door objects; carried is furniture and people on the decks.

| Train | Sections | Parts | Carried | Mean ms | Worst ms | Clearance ms |
| --- | --- | --- | --- | --- | --- | --- |
| flatbed x1 | 8 | 20 | 0 | 0.97 | 1.97 | 0.07 |
| flatbed x3 | 16 | 44 | 0 | 1.53 | 2.21 | 0.15 |
| flatbed x6 | 28 | 80 | 0 | 2.48 | 3.49 | 0.20 |
| flatbed x12 | 52 | 152 | 0 | 4.59 | 5.92 | 0.50 |
| flatbed x24 | 100 | 296 | 0 | 8.27 | 10.59 | 0.71 |
| flatbed x29 | 120 | 356 | 0 | 10.38 | 13.59 | 1.07 |
| coach x1 | 8 | 30 | 6 | 1.12 | 1.62 | 0.06 |
| coach x3 | 16 | 74 | 18 | 2.04 | 2.60 | 0.13 |
| coach x6 | 28 | 140 | 36 | 3.72 | 8.10 | 0.20 |
| coach x12 | 52 | 272 | 72 | 7.38 | 11.40 | 0.38 |
| coach x24 | 100 | 536 | 144 | 15.34 | 31.49 | 0.76 |
| coach x29 | 120 | 646 | 174 | 15.86 | 25.02 | 0.94 |
| coach x6 with 8 riders a car | 28 | 140 | 84 | 5.67 | 7.70 | 0.28 |
| coach x12 with 8 riders a car | 52 | 272 | 168 | 10.42 | 13.04 | 0.36 |
| coach x24 with 8 riders a car | 100 | 536 | 336 | 19.71 | 29.90 | 0.75 |
| storage x12 | 52 | 416 | 72 | 8.87 | 15.45 | 0.39 |
| sleeper x12 | 52 | 416 | 72 | 9.56 | 10.98 | 0.49 |
| coach x12 backward | 52 | 272 | 72 | 7.97 | 10.54 | 0.00 |
| one-tile wagons x12 | 13 | 0 | 0 | 1.17 | 6.35 | 0.05 |
| one-tile wagons x48 | 49 | 0 | 0 | 2.93 | 7.40 | 0.12 |
| coach x6 round a curve | 28 | 140 | 36 | 4.27 | 5.82 | 0.21 |

## Reading it

- Cost is close to linear in train length: about 0.09 ms a section for an
  empty flatbed, 0.14 for a furnished coach, 0.18 for a storage or sleeper car
  and 0.20 for a coach full of people.
- The clearance check and the walk along the train are about 6% of a step.
  The rest is moving objects: for a coach, 5 parts and 1.4 carried objects per
  section on top of the section itself.
- Running backward and rounding a curve cost about the same as a straight
  forward step.
- A step is one burst of work in a 40 ms server tick. At 8 ms a step, the
  figure used for built ship hulls, today's code carries about 52 sections of
  furnished coaches (a heavy engine and 12 cars) or about 95 sections of empty
  flatbeds.
- A steam train takes 5 steps a second at full speed and a diesel about 8, so
  a 120-section coach train costs about 80 ms of every second behind steam and
  about 130 ms behind a diesel.

## Targets for the scale-up

A 120-section train of furnished cars has to fit in 8 ms a step, which needs
the cost of a section about halved, to 0.07 ms. The measurements say where:
fewer objects per section (deck floors as overlays, walls only where they
block) and cheaper moves, not a faster clearance check. Until then, train
length stays bounded by locomotive pull as it is now. Rerun this benchmark
with each change to the movement code and add the new table below the
baseline.
