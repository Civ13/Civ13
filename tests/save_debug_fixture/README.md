# Debug-lossy save fixture - source for review, not executed

This is a synthetic-only writer/fresh-reader fixture for the narrow prototype.
It stages exact reviewed Git source plus an explicit hashed overlay, substitutes
only isolated startup and one deterministic test-only movement immediately after
the real mob child is encoded, and keeps the real child-consistency guard. It
does not test Gaia, connected clients, general lossy recovery or full-world scale.
The explicitly scoped text inputs are hashed and staged after CRLF-to-LF
normalization; lone carriage returns are rejected. The Git base is bound by
its immutable commit and the archive manifest records the original file hashes.

The writer seeds a completed world, copies its exact four-file seed, deliberately
fails a regular save, then requests a debug save whose first attempt reaches the
same actual failure and whose second may omit the same live animal. It requires
the live animal and an unrelated nested item to remain intact and the old backup
to remain byte-identical. The fresh reader must import the completed generation,
observe the retained box and item, find no saved target or dangling fixture field,
and report an audit exactly matching the writer and completion marker. It also
tests missing or nonempty child, an associated-key omission refusal, a bound owner
and simulated lost-owner refusal. The named controls exercise specific direct
policy paths; they are not a complete inventory of all possible failures.
The expanded fixture also requires nested positional and associated-value
references to the target to restore as null while a neighboring value, an alias,
and a self-cycle survive. Its audit names the saved level, list ID, index and
side for each omitted occurrence. This expanded behavior is not yet natively
validated; the earlier successful fixture tested the narrower policy.

## Proposed execution envelope

No native action has been performed. After source and envelope review, the
proposed single Linux hosted run uses one 516.1688 compile and two sequential
short-lived daemons, each limited to 120 seconds with a 360-second total native
deadline; each process-group cleanup waits up to ten more seconds. The launcher
uses an unmodified, SHA-256-verified pinned Linux archive and the matching
installed binaries. The existing passive verifier checks DreamMaker, DreamDaemon,
libbyond.so and libext.so byte-for-byte against the pinned archive immediately
before each launch, recording the identity; each child gets the existing
fixture's minimal environment with its own work directory as HOME/TMPDIR and
that bin directory as its library search path. Caller variables and credentials
are not passed through. System loader and
other system libraries are outside that identity. A filesystem replacement race
after the last check is not eliminated. Compilation must report the exact pin
and zero warnings.
Its Linux RLIMIT_AS is 1 GiB per process and RLIMIT_FSIZE 256 MiB per file;
core files are disabled. Logs are sampled at 8 MiB each and the runtime tree at
256 MiB, 4096 entries and depth 16. These are sampled aggregate limits, not a
filesystem quota. The separately staged source/build tree has the existing
stager's 2 GiB/8000-file input bounds, but no hard aggregate output-disk quota.
Native daemon logs use fixed basenames in the isolated runtime directory;
DreamDaemon refuses an absolute log path outside its DMB directory.
No RSS, CPU or total descendant-memory guarantee is claimed. Processes have a
retained, unreaped Linux group leader during inspection and group cleanup is
reported; this is not a system-wide process census. Artifact and receipt reads
are explicitly bounded. Writer failure stops before the reader; all failures
and cleanup receipts are retained.

The game runs `-trusted` with a synthetic world, loopback listener binding and
application-level port closure and client rejection. A brief initial loopback
listener may exist before `/world/New`; this does not block outbound traffic.
There is no OS-level egress sandbox. No real or copied saves, credentials,
Gaia processes or live endpoints are inputs. Normal hosted provisioning may
install packages and download the pinned archive and must be separately included
in execution scope. Toolchain/version identity and staged source must be checked
against an externally reviewed exact head and scope before execution.

This fixture currently has no CI job. A new test-only branch workflow/explicit
manual selector needs review before dispatch. A PR containing the candidate's
`saving.dm` or `functions.dm` also matches the existing `moving-save-chunks`
pull-request path filter, causing its existing correctness/memory native matrix
and ordinary game compilation. Do not infer that this fixture ran from that
matrix. These publication side effects and hosted provisioning must be stated
before publication; the current source work itself launches none of them.

## Beyond the first animal slice

The following are not implemented or validated: a missing/deleted object,
player-associated entities, animals with contents or clients, other movable
types, repeated faults beyond two selected handles, associated keys with
non-null values, durable world graph roots and dangling
cross-level links. The current identity/structural backup check is not a full
byte or restore validation. The audit member changes the strict round envelope;
rollback to older binaries needs a separately retained compatible generation.
The actual Gaia failure does not identify the child and may fall outside this
slice.

A broader candidate still needs a bounded, operation-owned occurrence ledger that
names each encoded owner, field or list ID/index/key/value, candidate-level
identity, and replacement; this slice adds list-slot locations for its one
supported target, but a graph pass must prove no surviving entry or
cross-level/durable link points to an omitted entry. Nested-list alias,
cycle and value behavior in this slice awaits native validation; omitted
associated keys with non-null values remain refused. Contained entities require
an explicit recursive-subtree policy and a complete loss count. All replacements
must be applied to a new candidate rather than mutating the live world, with
strict mode retained. Each class needs fresh-writer/reader positive and refusal
controls, immutable old-backup evidence and a generation-bound audit before it
can be claimed as supported. Publishing a marker without proven loadability is
not a successful recovery. This is a design direction, not a general fix.
