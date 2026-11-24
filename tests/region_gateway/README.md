# Gateway region

A `GATEWAY` region (`code/modules/persistence/region_gateway.dm`,
[scripts/shard-group/README.md](../../scripts/shard-group/README.md#gateway-world))
stays on the front door's port and sends ordinary connections on to their land.
The Persistence front door also accepts an explicit `character_lobby=1`
connection hint from the bed picker. The roster is private, derives the active
character from the signed-in client and cannot claim, create, embody or switch
a character on the gateway. Choosing another slot takes the client to the
active character's land first for the usual switching checks.

```sh
python3 tests/region_gateway/run.py --byond-bin <pinned bin> --evidence-dir <fresh dir>
```

`run.py` compiles the full DME without maps through the existing
`isolated_startup` adapter and runs `probe.dm` with a hand-made group and a stub
transfer agent: the group config accepts the kind; an account's home, the start
region for a new one and a guest are each sent on; pending, travelling, silent,
unknown-home and home-in-the-gateway answers wait with a reason; a laid-up land is
summoned; Join is refused; the hub text sums active regions, names the battle map for a TDM group, distinguishes confirmed
zero from partial counts, omits the line when no region reported, and ignores stale or invalid samples; seen
from a land, the gateway has no Join link, no trail and refuses admin sends. No
client joins: the login forward, the relay route and the link are not driven.
The optional chooser exercises an exact extra-slot owner lookup with no claim,
confirmed new-slot destination, stale and travelling refusals, and a parked
verdict that returns no direct route or wake from the lookup itself.

Run the offline route and owner-source contracts separately with
`python3 -B -m unittest discover -s tests/region_gateway -p 'test_*.py'`.
Host-side behaviour (never sleeps, restarts instead of a standby handover,
`add-gateway`, `set-gate` waiting for it) is in `tests/gaia_host/test_gateway.py`.
