# Material weapon parry durability

Run `run.py --byond-bin <BYOND-516.1681-bin>` with a verified Python interpreter.
The isolated native fixture compiles the actual sword/twohanded parry procedures
and inherited health check. Mock actors supply stable skill/hand state; audio,
disarm movement and shattering use injected no-op/counting adapters.

Thirty-two scenarios cover exactly zero, negative and surviving health after
successful parries against sledgehammer, melee, hatchet and ordinary attacks,
plus rejected parries that must not wear or break the item. Native random parry
rolls are retried up to 300 times; no production probability is changed.
`--negative-control sword` and `--negative-control twohanded` independently
restore the missing health check and must detect eight failed boundaries each.

This establishes wear and dispatch to the existing shatter procedure; it does
not establish graphical debris, inventory disarm movement or server behavior.
