# Gateway region

A `GATEWAY` region (`code/modules/persistence/region_gateway.dm`,
[scripts/shard-group/README.md](../../scripts/shard-group/README.md#gateway-world))
stays on the front door's port and sends every player on to their land.

```sh
python3 tests/region_gateway/run.py --byond-bin <pinned bin> --evidence-dir <fresh dir>
```

`run.py` compiles the full DME without maps through the existing
`isolated_startup` adapter and runs `probe.dm` with a hand-made group and a stub
transfer agent: the group config accepts the kind; an account's home, the start
region for a new one and a guest are each sent on; pending, travelling, silent,
unknown-home and home-in-the-gateway answers wait with a reason; a laid-up land is
summoned; Join is refused; the hub text counts players across the lands; and seen
from a land, the gateway has no Join link, no trail and refuses admin sends. No
client joins: the login forward, the relay route and the link are not driven.
Host-side behaviour (never sleeps, restarts instead of a standby handover,
`add-gateway`, `set-gate` waiting for it) is in `tests/gaia_host/test_gateway.py`.
