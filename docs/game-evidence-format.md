# Evidence manifest contract (version 1)

The checker creates a deterministic JSON inventory from existing files. Run it
against a dedicated evidence directory. Artifact paths are relative to the
manifest, remain inside that directory, and must be nonempty files. It hashes
local artifacts, optionally checks supplied `sha256` values, and leaves HTTPS
URLs explicitly unverified. It does not alter sources or upload anything.
Use completed captures and copies of closed logs; do not hash files that a game
or recorder is still writing.

Record metadata from the actual run, including the tested commit and dirty diff.
`--expected-commit` should come from the intended test target, independently of
the manifest. A hash comparison cannot prove that a log or capture came from
that executable: record build/run commands and inspect provenance separately.

This is a synthetic example with a missing runtime check, not completed evidence:

```json
{
  "schema_version": 1,
  "game": "Civ13",
  "commit": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "runtime": {"name": "BYOND", "version": "record-actual-version", "platform": "record-actual-OS"},
  "map": {"name": "fixture", "source": "tests/example.dme", "dimensions": [2, 2, 1]},
  "scenario": "other",
  "run": {
    "scope": "synthetic", "dirty": false,
    "started_utc": "2026-10-11T00:00:00Z", "finished_utc": "2026-10-11T00:01:00Z"
  },
  "steps": ["Record the exact setup, commands, inputs, interaction, and cleanup used."],
  "media": {"screenshot_required": false, "video_required": false, "reason": "Helper fixture only."},
  "checks": [
    {"id": "runtime", "description": "Changed interaction behaves correctly", "result": "not-run", "evidence": [], "notes": "BYOND was not run."}
  ],
  "artifacts": [],
  "limitations": ["No real game, graphical acceptance, or production behavior was verified."]
}
```

Use `scenario`: `season-memory`, `save-roundtrip`, `gameplay`, or `other`.
Use `run.scope`: `synthetic`, `isolated-fixture`, `isolated-game`, or
`production-observation`. Scope records evidence; it does not grant authorization.
UTC timestamps, three positive map dimensions, steps, and explicit limitations
are required. A dirty run needs a `patch` artifact containing the full tested
diff plus provenance of relevant untracked files.

The checker also supports other games: record their actual engine under
`runtime.name`, such as `Godot`, with version and platform. For a scene with no
tile grid, a non-Civ13 manifest may set `map.dimensions` to `null` and include an
explicit `map.dimensions_reason`. Never invent dimensions for such a scene.

Each check has a unique `id`, observable `description`, `result` (`passed`,
`failed`, or `not-run`), artifact IDs in `evidence`, and observed results or skip
reasons in `notes`. Executed checks require evidence; the helper does not judge
whether the contents prove the result.

Each artifact has a unique `id`, `kind`, and exactly one `path` or `url`.
Kinds: `log`, `build-log`, `screenshot`, `video`, `metrics`, `save`, `patch`,
`other`. Example: `{"id":"runtime-log","kind":"log","path":"runtime.log"}`.
An optional `sha256` pins an existing local artifact. Use actual captures for
media and inspect them manually. A present file alone is not proof of gameplay.

Gameplay requires `screenshot_required: true`; set `video_required: true` when
timing or movement needs it. If required media is unavailable, include a check
whose ID is exactly `screenshot` or `video`, with `result: "not-run"`, an empty
evidence list, and the reason. The report preserves `missing_required_media`;
structural validation success never waives that acceptance gap. Other skipped
checks cannot stand in for the missing capture. Keep internal captures local.

## Season-memory observations

Required check IDs are `repeated-seasons` and `memory-samples`. Mark unavailable
checks `not-run`. A passed `memory-samples` check needs a local `metrics` CSV and:

```json
"memory": {
  "artifact": "memory-csv",
  "metric": "private_bytes",
  "process_identity": "PID and process start time from the same bounded run",
  "settling_rule": "Record the actual wait/cleanup rule and sample cadence"
}
```

CSV columns are exactly `elapsed_seconds,cycle,phase,bytes`. Each cycle, numbered
contiguously from 1, has baseline, peak, and settled phases in that order. Multiple
samples per phase are allowed; timestamps strictly increase. At least two
complete cycles are needed to summarize repetition. Use more cycles and a
representative duration to support the investigation's actual acceptance claim.

Choose one metric: `private_bytes`, `rss_bytes`, or `working_set_bytes`. Do not mix
metrics/processes or convert datum counts into memory bytes. The report records
each cycle's first baseline, maximum sampled value, last settled value and delta,
plus the first-to-last settled delta. It does not claim to observe the true peak
between samples or determine leaks/OOMs. Keep raw logs, workload, timings,
environment limits, and baseline/control comparisons with the bundle.

## Save round trips

Required check IDs are `roundtrip`, `nested-values`, `edge-turfs`,
`missing-turf-rejected`, and `world-unchanged-after-rejection`. They can be
explicitly `not-run`; never fabricate a pass from compilation. Add further checks
for aliases/cycles, multi-level maps, malformed imports, large maps, performance,
or client interaction when those are part of the changed contract. Record the
pre/post world invariants and fixture size in notes and logs. Sanitized temporary
fixture saves may be included; production saves are not needed.
