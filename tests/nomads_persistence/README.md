# Synthetic Nomads persistence regressions

See [the profile contract and limits](../../docs/nomads-persistence.md).

With pinned BYOND 516.1688, run `python run.py --byond-bin <bin>` for all 26
metadata profiles, corruption, calendar and callback tests. Run separately with
`--negative-control profile`, `--negative-control timer-restore`, and `--spatial`.
The spatial mode starts 26 sequential fresh disposable worlds and runs the real
saver/importer, nested graph and bed-return paths for every audited type.
Save/import occurs in the same daemon, so this is not cold-start acceptance.
`--events` checks owned nuke/radiation tails, lava propagation/drying and failed
Mountain/Ice Age transitions. Blast bodies use a yielding adapter; lava delays
are accelerated by 100 with production callbacks. Run the `nuke-tail`,
`calendar-failure` and `lava-tail` negative controls separately to confirm that
removing the respective barriers fails their named assertions.
The runner records complete source hashes, dirty diff, runtime file hashes,
compiler/runtime diagnostics and each case result in its printed temporary path.
It does not use production saves. Normal startup is disabled; GC registration
is explicit. Ports are closed/refused after startup, with no claim of OS network
isolation or absent initial loopback/pager effects.

`python -m unittest discover -s tests/nomads_persistence -v` from the repository
root checks authored DMM/metadata/catalog completeness and injected build/cache
behavior without running Git, compilers or a daemon. The CI registry admits only
that explicit offline test file; native runs have their own workflow.
