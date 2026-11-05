# Mount gunfire regression

`run.py --byond-bin <pinned-bin>` compiles the production sources without maps
or normal startup into an 8x8 plating world and runs `probe.dm` once:

- 7.62x39 rounds fired at a horse each do damage and kill it within five hits
  (horses had 1800 health, about 20 rifle rounds).
- A rider's shot handled on the mount's own tile passes the mount untouched
  instead of being absorbed by it.

`--negative-control health` restores the 1800 health and `--negative-control rider`
removes the mount skip in a generated copy; each must fail its named check.
Evidence goes to a fresh temporary directory. No client, save or live server.
