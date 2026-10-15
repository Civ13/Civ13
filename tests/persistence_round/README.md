# Continuous persistence rounds

`run.py --byond-bin <516.1681-bin>` compiles the complete production sources
without maps or normal world startup, then exercises the actual vote, ticker and
rotation procedures in temporary offline storage. No player accounts or server
saves are used. The fixture rejects connections and closes the port.

Checks include automatic/admin vote creation, stale pending votes and results
before callbacks, finish-flag recovery, automatic rotation, initial lobby map
selection and ordinary-round controls. `--negative-control vote` removes the
creation guard; `--negative-control ticker` removes the ticker guard. Each must
fail its intended assertion without engine diagnostics.

This is a production-procedure integration test, not a full public-server test
or a save/reboot proof. The administrative save/restart transaction is unchanged.
