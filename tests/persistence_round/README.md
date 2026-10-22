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

The positive test also calls the production ticker while a persistent round is
being saved. It must return without clearing the finish flag or changing round
state. `--negative-control save` removes only the save guard and must fail that
interaction check before any vote or delayed round-end assertions.

The transaction startup hold is checked separately with the save flag cleared,
so the save guard cannot hide a missing startup guard. The ticker must preserve
the finish flag and PLAYING state. `--negative-control startup` removes only
that production guard and must fail this exact assertion.

This is a production-procedure integration test, not a full public-server test
or a save/reboot proof. The separate restart-transaction suite checks the
administrative save/restart contract with isolated external-effect adapters.

The vote adapter acquires real generation-bound handles before simulating stale
pending routes. It checks terminal cancellation, cleared callback ownership,
repeat-resolution rejection and the production direct-application guard. A
callback that enables persistence must prevent the resolved route from ending
the round. Generic questions also cannot hide map/epoch transition callbacks.
`python -m unittest discover -s tests/persistence_round -p 'test_*.py'` checks
source integration contracts only; it is not native compiler or runtime proof.
