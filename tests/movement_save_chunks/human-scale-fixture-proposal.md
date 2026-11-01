# Synthetic human scale comparison: source-only proposal

This adapter is not approved for native execution by its presence in the tree.
It measures one paired synthetic case; it is not a full Gaia, connected-client,
availability, save-consistency or production-enablement acceptance test.
The production 1,200-tick geometry-validation deadline and all other production
guards remain unchanged. Refusal, timeout, missing evidence or insufficient
resources is a failed or inconclusive measurement, never a pass.

The staged disabled and enabled fixture DME files differ only by the single
experimental feature definition. Both use the same exact committed source,
isolated startup, synthetic probe, staged timestamp instrumentation and fixed
order: disabled writer/reader then enabled writer/reader. A fresh process reads
each writer's copied generation.
The fixture fixes 700 x 500 x 1 turfs (350,000), 32 stationary unlinked humans
with nonzero positions and two inventory items each, and 5,000 identified
nondense ground items. It checks that 350,000 saved grid slots contain positive
integer references; it does not independently prove that those references are
unique, have turf type or describe the complete saved graph. The world turf
count is a dimension product, not a separate count of restored turfs. It also
checks the generation, exact body positions and inventory, and every restored
ground identity/location.
It does not use a real save or demonstrate moving client input. If the engine
cannot represent the fixed dimensions or any count differs, it fails rather
than silently reducing the workload.

The proposed manual job has a hard 90-minute job timeout, an 18-minute
bootstrap and a 68-minute fixture step. The bootstrap installs the pinned
516.1688 Linux toolchain and performs one game compile (the existing bootstrap
uses a 300-second compiler timeout). The fixture performs two compiles with
120-second deadlines and four sequential daemons with 900-second deadlines.
Those deadlines are checked at polling boundaries; monitoring and blocking I/O
can overshoot them. Its 3,600-second native-sequence watchdog starts after
staging; the outer step and job limits also cover staging and cleanup, with up
to 10 seconds of group cleanup per child. The single order and single sample
are vulnerable to cache, host-load and scheduler noise. No release budget or
comparative threshold is selected here; agree on thresholds before interpreting
the measurements for release.

Each of the six owned fixture children inherits a 2 GiB address-space limit
and a 2 GiB per-file limit; these are not aggregate process-group memory limits.
RSS is sampled for the leader using the existing helper's
nominal 50 ms polling interval plus monitoring overhead, with a bounded 100 ms
exit reconciliation; this is a change from the earlier 20 ms proposal. The
bootstrap compiler and package installer are outside these child limits. Each
runtime directory has sampled 3 GiB, 4,096-entry and depth-16 limits; logs are
sampled at 8 MiB and the existing diagnostic scanner has a stricter 4 MiB
limit. Staged source is bounded to 2 GiB. Sampling can overshoot and none of
these is a hard aggregate disk quota. Four retained runtime directories can
approach 12 GiB, plus staged source, bootstrap, compiled artifacts and logs.
Free space must be at least 16 GiB before bootstrap and again before staging,
and at least 2 GiB during monitored execution and bounded file copies.

The runner records observed process-start-to-entry sampling, setup, whole-save,
the level traversal through `Flush` interval, the enabled-only human candidate
checks, whole-load and separate inspection timing, tick-heartbeat gaps, sampled
peak RSS, sizes, hashes, owner/group cleanup events and failures. Test-only
clock reads bracket those explicit saver anchors without changing guards or
yield behavior; both variants compile the same instrumentation. Capture,
other candidate validation, file-write-only and maximum-work-slice boundaries
remain unknown. The heartbeat maximum covers post-initialization setup, save
or load, and inspection together; it is not a save-only pause. It also includes
host scheduling and measurement overhead. Each child retains up to 20,000 raw
available leader-memory observations, including missing fields and over-limit
observations. Successful directory scans attach sampled file counts, byte
totals and available disk; an interrupted or refused scan may lack a total.
Exhausting the observation budget fails the run. A completed comparison records
`product_acceptance: not_evaluated`, never a release verdict.

The wrapper checks the exact reviewed commit and adapter scope before any
bootstrap, disables persisted checkout credentials and uses a read-only token.
It obtains pinned packages over the network; no OS egress sandbox is provided.
The daemons use loopback and disable the web client, but may briefly listen
before the fixture closes the port. Each child is launched through the existing
owned-process-group helper, which records signaling and waits but cannot prove
that all escaped descendants are absent. No Gaia process, credentials, real
save, firewall, ACL or account setting is touched.

CI retains bounded JSON receipts, logs and bootstrap diagnostics even on
failure. It intentionally excludes large synthetic `.sav` data from the
uploaded artifact, so independent reviewers can inspect recorded hashes but
cannot rehash those raw save bytes from the retained artifact. The temporary
runner filesystem is disposable. This plan requires separate source/scope
review and execution authorization; no native process ran during preparation.
