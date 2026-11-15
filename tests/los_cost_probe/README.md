# Line-of-sight cost probe

Manual native probe for issue #3582: what geometric line of sight costs the
server with one and with several connected clients, on a small map and on
Gaia, against the same scenes with `CIV13_GEOMETRIC_LOS_CORE` off. CI never
compiles or runs it. Results are in
[docs/los-cost-measurement.md](../../docs/los-cost-measurement.md).

It needs real Dream Seeker clients, so it runs on a Windows PC with BYOND
installed, never on a live server. Dream Daemon runs `-trusted` on a loopback
port from a scratch folder with the repository's example `config/`.

```
py -3 tests\los_cost_probe\run.py --map small --los on  --out D:\scratch\los-small-on
py -3 tests\los_cost_probe\run.py --map small --los off --out D:\scratch\los-small-off
py -3 tests\los_cost_probe\run.py --map gaia  --los on  --out D:\scratch\los-gaia-on
py -3 tests\los_cost_probe\run.py --map gaia  --los off --out D:\scratch\los-gaia-off
```

`run.py` compiles a copy of `civ13.dme` with `probe.dm` appended (and the two
feature macros set to 0 for `--los off`), starts Dream Daemon, and opens eight
guest Dream Seeker windows (`--clients`) through a loopback relay that counts
the bytes sent each way. It stops only the processes it started. One run takes
about twelve minutes; do not use the PC for anything heavy meanwhile.

The probe starts the round, picks an open field and a forest, builds a small
wooden hut with a door in the field, gives every client a human body, then
runs 12 second phases with 1, 2, 4 and 8 clients active (the others are
parked in a corner with line of sight switched off):

| Phase | What happens |
| --- | --- |
| `stand` | Everyone stands still: only the once-a-second audit runs. |
| `walk-one` | One client walks east and west; the rest watch. |
| `walk-all` | Every active client walks east and west. |
| `pan` | Every active client looks into the distance and back every 2 s. |
| `door` | The hut door opens or closes every 2 s in everyone's view. |
| `forest/...` | `stand` and `walk-all` again among trees. |
| `apart/...` | Every client alone in its own field, more than 70 tiles apart. |
| `memory/...` | Contexts held, released with `set_geometric_los(FALSE)`, held again, then every client disconnected. |

`result.json` holds one row per phase:

- `count` and `ms`: calls and total milliseconds of `reconcile_geometric_los()`,
  `capture()`, `los_presenter.refresh()`, `refresh_targets()`,
  `root_tree_presenter.refresh()` and the audit scan, timed with
  `world.tick_usage` around the real procs.
- `profile`: BYOND profiler rows for every line-of-sight proc, which is where
  `decision_snapshot()` is counted.
- `image_adds`, `image_removes`, `max_los_masks`, `max_client_images`: mask
  image churn and the most images held at once.
- `avg_cpu`: `world.cpu` averaged over the phase.
- `host`: Dream Daemon CPU and private memory, Dream Seeker CPU and the
  kilobytes per second relayed to the clients, sampled once a second.
- The memory rows count live `los_context`, `los_presenter`,
  `root_tree_presenter` and `los_snapshot` datums.

The wrappers add a little time of their own, so treat the numbers as slightly
high. Client frame rate is not measured here; `tests/animal_fps_probe` does that.
