# Continuous persistence rounds

`run.py --byond-bin <516.1681-bin>` compiles the complete production sources
without maps or normal world startup, then exercises the actual vote, ticker and
rotation procedures in temporary offline storage. No player accounts or server
saves are used. The fixture rejects connections and closes the port.

The default retains historical 516.1681 behavior, including Windows tools.
Ordinary CI explicitly adds `--byond-archive "$PWD/BYOND/pinned.zip"` for the
current Linux 516.1688 toolchain. That mode verifies the exact pinned archive
and installed members before compilation and again before the daemon, and
requires one exact compiler banner with zero errors and warnings. It is
Linux-only; the historical default and the same six cases/deadlines remain.

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

## Persistent lobby countdown

`python3 -m unittest discover -s tests/persistence_round -p test_pregame.py`
checks the boot/countdown, immediate mode-toggle cancellation, delayed vote and
setup-admission guards, unchanged ordinary timer, manual Start Now override,
and restore/save/startup guard ordering. It mechanically projects the two small
production cancellation helpers into Python; scheduler/callback ordering is
checked as source contracts, not exercised in a native event loop.

Automatic start cancellation is latched for this lobby: switching persistence
off does not resurrect an old timer. Start Now remains available. No native
compile, live startup, graphical lobby, save/load or callback acceptance is
implied by these offline checks.
