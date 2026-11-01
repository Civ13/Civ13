# Lighting restore interleaving: source prepared, native execution held

The candidate uses the existing full-source staging and owned-process helpers.
Preparation requires an exact committed base and an independently reviewed
hash of the explicit fixture/loader/driver overlay. Preparation alone does not
compile or execute BYOND. The included runner and fixture have not been
compiled or executed; source-only tests cannot establish native behavior.

Proposed single attempt for separate approval: one pinned 516.1688 fixture
compile followed by two sequential fresh daemon processes: one synthetic writer
and one reader. The reader performs ten small-world restores, with fixture-only
recovery-hold reset between deliberately failed owned operations. Each phase
has a 120-second deadline; the complete native sequence has a 360-second
deadline. Group cleanup may take up to 10 seconds after a deadline. The fixture
uses 1 GiB per-process inherited address-space limit and sampled leader RSS
limit, a 256 MiB per-file limit, a sampled 256 MiB runtime-directory limit,
4 MiB diagnostic-file bound and 8 MiB monitored log bound. Limits are checked
with the existing owned-process helper; periodic samples are not hard aggregate
disk or process-tree RSS quotas. Source staging is separately bounded to 2 GiB.
The existing hosted runner requires at least 16 GiB initially free and an
isolated direct child of RUNNER_TEMP. It rechecks the pinned archive and runtime;
the runner itself does not download anything.

Only newly generated synthetic saves are used; the reader gets a verified copy
of the writer's seed. Daemons bind loopback and close their port at startup, but
there is no OS-level outbound-network sandbox. No credentials, Gaia operations,
real/copied saves, configuration changes, production activation or deployment.
The group signal and leader wait are recorded; they do not independently prove
every possible descendant exited. Stop on the first failure, retain evidence,
and do not retry automatically.

The fixture instruments only the two callback sites, retains the production
guards except for a named guard-omission negative control, schedules its
mutation in a separate spawn during an actual sleep, and asserts the observed
before/mutation/after order. Cases cover successful ordered passes, retained
qdel and a separate hard deletion that must leave a null pending list slot,
each retirement marker on an atom and a turf, omission
detection, and list/level replacement while the original operation remains
owned. It asserts no callback or light resurrection on retired entries, live
light-source/owner restoration, the held recovery gate and bookkeeping cleanup on
owned failures, and seed/marker identity. The omitted-guard case deliberately
exercises the bad callback to demonstrate the assertion can detect it. The
positive assertion does not drain the lighting queue or establish rendered
lighting parity.

The case loop's resetting of the recovery flag is strictly synthetic test
setup between independent cases and must never be used as a production
recovery procedure. No case creates a successor after foreign ownership loss:
the current unconditional cleanup has not been shown safe in that corrupted
situation. The deterministic forced sleep validates interleaving logic, not
whether conditional TICK_CHECK prevents the 350,000-tile engine warning. The
large-world comparison and connected-player acceptance remain separate.
