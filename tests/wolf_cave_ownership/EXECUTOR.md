# Dedicated cave executor: source/offline review only

This executor is dedicated to the existing seven cave cases. It imports no
floor-decal, OpenDream, benchmark, grant or lease code. Three separately reviewed
native invocations stopped in the first fixed compile at the strict member guard;
no daemon ran. See README.md for the fixture error and pending revised build.
All executor tests use fake processes and injected DLL functions;
a WinDLL tripwire makes accidental native binding fail the tests.

`executor.py` has an **offline preparation CLI only**. `run_packet` is a library
entry requiring an explicitly supplied backend. Parent review is still required
before constructing the real `windows_job.WindowsJob` backend and invoking it.
There is no run-on-import, native CLI option, scheduler, automatic retry, login,
client launcher, public port parameter or arbitrary case selector.

## Containment implemented in source

- Each compile/runtime phase gets a fresh unnamed Windows Job, with kill-on-close,
  one active process, and both per-process and aggregate Job memory limits of
  **256 MiB**. Both breakaway flags are absent. Limits are queried after setting,
  after assignment, before resume, and at each monitor sample. A denied child
  process or assignment is a failure; there is no privilege or fallback path.
- `CreateProcessW` creates the exact hashed executable **suspended**, hidden and
  without breakaway. Before resume, assignment and membership are checked, the
  image and creation FILETIME are retained, and all packet/tool/input hashes are
  rechecked. No named shared Job or PID-based termination is used. The optional
  unexpected-member diagnostic opens limited-query handles only while the exact
  owned Job remains open; it grants no additional execution allowance.
- An explicit inherited-handle list contains only newly created stdout/stderr
  files and NUL stdin. Child environment paths point into the phase's fresh
  storage. The environment omits account credentials and normal user configuration.
- Monotonic deadlines are **60 seconds compile / 20 seconds runtime**, including
  creation from the controller's timer start. A separate watchdog owns a duplicate
  Job handle and requests termination at the remaining deadline. This duplicate
  prevents cleanup races from targeting a recycled handle. The existing fixture
  additionally has its **150-decisecond** watchdog. OS/API calls and controller
  scheduling can delay observation; this is not a hard real-time guarantee.
- Every path after successful creation stops the watchdog and cleans the owned
  Job. Cleanup requests termination, checks Job accounting drains to zero, closes
  the Job as kill-on-close fallback, waits on the retained child handle, and closes
  thread/process handles. Its deadline is five seconds. Unconfirmed exit, Job drain,
  close, or watchdog retirement fails the receipt; it never becomes a pass.
  Early creation/assignment/identity failures have their own retained-handle cleanup.
- Host admission reads available physical/commit memory, current process CPU
  affinity and system CPU counters. It requires at least **1 GiB** available
  physical and commit memory and at least one allowed CPU. Raw counters are retained;
  they are not a claim about future CPU availability or a reserved host allocation.
- Raw stdout, stderr, runtime logs, compiled artifacts and receipts remain in a
  fresh packet-local `execution` directory, including on failure. Observed total
  output above **16 MiB** stops the phase without truncating existing diagnostics.
  This sampled check is not a hard filesystem quota. No filesystem cleanup runs.

The three native receipts report rejection and cleanup to zero active Job members,
with no cave runtime acceptance. Injected API tests establish call order, layout
and failure-path behavior only; they do not replace native evidence. Python 64-bit
Windows is the intended executor environment. Any further invocation needs review.

The unexpected-member addition is described in
[MEMBER_DIAGNOSTIC.md](MEMBER_DIAGNOSTIC.md). It rechecks exact Job membership
before each image/creation-time read and afterward, closes the query handle
immediately, refuses opens after cleanup starts, and retains all existing rejection
rules. A diagnostic or handle-close failure is retained and cannot turn an
unexpected member into an accepted run.

## Immutable inputs

Offline `freeze` checks the existing source-manifest hashes, copies exactly four
files for each of seven cases, and records the exact source head. It pins the
already-identified official 516.1681 `dm.exe`, `dd.exe` and `byondcore.dll` hashes;
all other installed DLL hashes and the interpreter/runner/backend hashes are also
recorded. The original fixed 144-cell `probe.dm` hash is enforced in every case.

`verify_packet` requires the externally supplied packet SHA-256, exact case/oracle
and limit sets, unchanged code/interpreter/tool DLL set, matching source manifest,
and unchanged frozen inputs. It rejects linked files/ancestors. Each phase checks
again before child creation and while still suspended; staged sources and compiled
artifacts are checked before/after use. As with ordinary file hashes, this does not
provide a hostile-filesystem locking guarantee between checks and OS loading.

Offline tests supply the host interpreter's strictly resolved canonical path as
fixture input, so Ubuntu's symlinked `python3` does not fail simulated packets.
This test-only substitution neither starts another interpreter nor establishes
Windows native provenance. Resolution errors still fail; production freeze and
verification retain their exact interpreter path/hash and linked-ancestor checks.
Use the actual canonical, nonlinked Python executable for a real freeze/invocation.
Resolver/link tests use injected filesystem results; they require no Windows
symlink privilege. Changed paths (even with identical bytes), changed bytes and
linked interpreter files/ancestors must reject before any fake child is created.

The output path is restricted to the fresh `execution` sibling of the packet.
An existing output is an error: the executor never retries a consumed run directory.
There is no new lease/grant mechanism and no authority inferred from packet metadata.

## Socket contract and its limits

The installed official **516.1681** reference (`help/ref/info.html`, startup options)
documents `-close` as making the child DreamDaemon exit after its world shuts down.
It does **not** make a network-isolated world. See the
[BYOND startup reference](https://www.byond.com/docs/ref/#/proc/startup).

The fixed command has `-close -invisible -trusted`, no requested public port,
and no client/login action. The unchanged fixture closes with `OpenPort("none")`,
checks `world.port == 0`, rejects reopen requests and rejects clients. There is
no socket opened by the executor, connectivity probe, listener reservation or
firewall/security modification.

Read-only OS TCP/UDP tables for IPv4/IPv6 are sampled for the owned PID with
retained-handle liveness checks before/after enumeration. **Any observed owned
socket fails** and triggers cleanup. Failed, oversized or truncated census data
fails closed without retry. Empty samples establish only that no owned socket
was observed at those instants. They cannot exclude a short startup bind or
connection between observations and do not prove continuous zero sockets.
If continuous prevention is a mandatory admission condition, this executor is
insufficient: stop before launching and use a separately approved suitable
environment. The socket policy does not silently relax that condition.

## Exact oracles and retained collateral

Compiler acceptance requires exit 0, exactly one `DM compiler version 516.1681`
banner, a single zero-error/zero-warning result, an actual DMB and no diagnostics.
Native acceptance requires exit 0, all six ordered batch completion receipts and
no engine/runtime diagnostics. Fixed additionally requires exactly one PASS and
no FAIL. Controls require no PASS, the final failure receipt and these exact
assertions:

| Case | Required `FAIL wolf cave:` assertion |
| --- | --- |
| world-scan | `one initial service count=3 full=0` |
| duplicate-start | `one chain count=1 full=0` |
| missing-stop | `Destroy stops sleeper` |
| saved-flag | `timer excluded from custom save` |
| missing-recount | `population recount` |
| baseline | `one chain count=1 full=0` |

The existing fixture accumulates failures, so each receipt retains the entire
failure list, first actual failure and collateral. Requiring the named assertion
does not claim single-target mutation isolation or assume it was the first failure.
Missing named assertions, incomplete runs, unknown FAIL/PASS lines, diagnostics
and a false PASS are rejected. A failure stops the packet; nothing is retried.

## Offline review commands

```text
<verified-python> -B -m unittest discover -s tests/wolf_cave_ownership -p test_*.py -v
<verified-python> -B tests/wolf_cave_ownership/executor.py --prepared <existing-packet> --byond-bin <official-bin> --output <fresh-freeze-directory>
```

Neither command launches BYOND. There is intentionally no native invocation
command here before parent source review. Native pass/fail, observed socket
behavior, 256 MiB OS enforcement and cleanup results remain **UNRUN**.
