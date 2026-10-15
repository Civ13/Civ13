# Continuous persistence rounds

`run.py --byond-bin <516.1681-bin>` compiles the complete production sources
without maps or normal world startup, then exercises the actual vote, ticker and
rotation procedures in temporary offline storage. No player accounts or server
saves are used. The fixture rejects connections and closes the port.

Checks include automatic/admin vote creation, stale pending votes and results
before callbacks, finish-flag recovery, automatic rotation, initial lobby map
selection and ordinary-round controls. `--negative-control vote` removes the
creation guard; `--negative-control ticker` removes the ticker guard. Each must
fail its intended assertion without engine diagnostics. The `deferred` control
removes both delayed guards. The positive test also runs the real 50-tick end
delay and restart sleep, enabling persistence during each. Only round-end hooks
and the reboot side effect are replaced with counters, so tests cannot reboot.

This is a production-procedure integration test, not a full public-server test
or a save/reboot proof. The administrative save/restart transaction is unchanged.
