# Runtime isolation review: 516.1688

Status: proposal only for Windows. No daemon retry and no socket-guard change
have occurred after the rejected attempt. No native resource window is active.

## Preserved rejection

At predecessor `eed6d7299`, the owned Job launched installed
`C:\Program Files (x86)\BYOND\bin\dd.exe`, SHA-256
`abb21de26047724bf64411e17da5e17cacc74221817c3e049a79626156b44866`,
PE file/product version 5.0.516.1688. The command used the isolated DMB,
`-invisible -close -ip 127.0.0.1 -nowebclient -trusted`, tested-commit params,
and a relative runtime log; no explicit positional port or `-port` was supplied.
The sampled TCP listener was `127.0.0.1:52440`, state listen, remote 0.0.0.0:0.
No external socket was observed. This is a sample, not continuous proof.

The unchanged Session rejected that first socket sample. It retained the child
identity (PID 78920, creation FILETIME 134375288157433341), terminated its Job,
and confirmed its retained exit with no unexpected members or cleanup errors.
No fixture completion receipt was produced. The run remains failed.

Maintainer-local evidence under task-15:

- `evidence-candidate-2/supervisor/containment.json`, SHA-256
  `a1173599c565a8f10b7ef0483d03042b5056643c86caa6bb32fe8db2951dc8fa`.
- `evidence-candidate-2/runtime/runtime.log`, SHA-256
  `6032fe45770ebc5d8220cc18cd54e6b3ff46aadf6f0770bd08f03191e8bd4a48`.

## Why it opens

The installed official reference documents that startup port 0 chooses any
available port; `-port P` or a positional port selects it. `-ip` selects the
hosting interface. `-close` exits the daemon after the world shuts down;
`-nowebclient` disables the web client. Neither is a no-network flag.
See [startup options](https://www.byond.com/docs/ref/#/proc/startup).

The selected command leaves the port at its automatic default. The native
startup log identifies the bound loopback address and selected port. The full
fixture closes the port at the first line of `/world/New`, but native engine
startup, global initializers and map constructors precede that entry. This
explains the observed pre-entry listener; it is not an inference that source
`OpenPort("none")` reopened it. The proprietary engine parser was not executed
or modified to test speculative options.

The reference documents `OpenPort("none")` for closing a running world's port,
and `-ports` as a numeric list/range restriction. It does not document a
socket-free CLI mode, an empty range, or `-port none`. No supported option that
guarantees absence of the startup socket has been established. Do not guess an
option or treat `OpenPort(0)` as closure. See
[OpenPort](https://www.byond.com/docs/ref/#/world/proc/OpenPort).

## Gaia approach

`tests/world_save/playable_reconnect/test_port.py`, `control.dm` and its README
already distinguish the initial native port from closed fixture entry. They
extract production entry/port guards, close with `OpenPort("none")`, refuse
subsequent random/fixed opens, deny clients, and obtain a later OS zero-listener
census. Historical Gaia records explicitly acknowledge a startup listener before
world/New. They also retain failed full-world diagnostics.

That design can supply application closure and later OS checks. It cannot meet
the present Windows Session rule rejecting any sampled socket including startup.
Copying its weaker initial-listener policy into this Session without approval
would be a policy change, not a socket-free fix. Its 1681 launch code must not be
executed or called 1688 evidence. The entry/closure checks can be reused in a
reviewed current-version profile after the exact policy decision below.

## Proposed single Windows session requiring approval

Bind approval to a newly frozen source head, generated-DMB hash, runner/helper
hashes and fresh evidence directory. This proposal does not grant itself approval.

1. Serialize with the JIT owner and root. One current-engine compile phase, then
   exactly one diagonal/default daemon phase; no connected client, mining second
   daemon or automatic retry. Keep the standard 120s compile, 90s daemon and 360s
   aggregate cleanup bounds; retain the existing one-process Job, cumulative
   accounting, memory/CPU/free-memory/output budgets and retained exit checks.
2. Recheck the above dd.exe hash immediately before creation; compiler dm.exe
   hash remains `f29b3041c46df453b3f999583bef0bb0ff79fe2b53ee1b8686bb46ce18c7df77`.
   The compiler banner and runtime receipt must both be exactly 516.1688.
3. Use explicit positional port `59474`, `-ports 59474`, `-ip 127.0.0.1`,
   `-nowebclient -invisible -close -trusted`, no public hub, no normal startup,
   no external-effect hooks, no DLL/JIT changes and no client/Topic admission.
   Refuse a pre-existing owner on that port rather than evicting it or choosing
   a different port. No firewall, host security, credential or deployed-file change.
4. For at most five seconds from owned process creation and only until the exact
   closed-entry marker is seen, allow at most one sampled TCP listener, exactly
   127.0.0.1:59474, remote address/port 0.0.0.0:0. Reject all UDP, all connected or
   connecting TCP rows, every other address/port, and any external bind/connect.
   Reject on a missing/late/malformed marker. After closure, reject every sampled
   socket for the remainder of the phase; no reopen or grace-window renewal.
5. Record native initial port, closed-entry port 0, refused random/fixed reopen,
   OS samples, exact assertion counts, complete logs and final owned exit. Any
   deviation kills only the owned Job and retains the failed evidence. Success
   does not approve another run, defect controls, client capture or deployment.

The existing 100ms OS sampler cannot prove continuous absence of short-lived
outbound attempts. The log also says the pager is offline before guest startup;
its exact native connection behavior is not established by game source. Thus
"no external bind/connect" above is an execution constraint and a fail condition
for every observation, not a proved prevention boundary. If prevention rather
than sampled detection is required, an already approved network-isolated host
or VM is needed; no firewall exception or security weakening is proposed.

## Hosted CI scope

Root separately requested correction of the existing hosted Linux lane. It uses
the repository's existing bounded process-group/deadline/loopback application
closure policy with target 516.1688 and genuine new runtime tests/controls.
That lane never claims the Windows no-socket envelope or DreamSeeker acceptance.
Historical run 40416416003 remains failed: its primitive compiler oracle expected
1681 and rejected the actual 1688 banner after all offline checks passed.
