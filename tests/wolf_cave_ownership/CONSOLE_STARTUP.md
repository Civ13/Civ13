# Proposed detached console startup: offline evidence only

Invocation 3 identified an unexpected owned `conhost.exe` alongside the compiler.
The strict census rejected it; cleanup drained the Job. Its packet, failed logs
and creation identities remain unchanged. This proposal neither accepts that
member nor reopens its historical PID.

## Creation contract

Replace the old creation mask `0x08080404` with `0x0008040c`:

| Bit | Contract |
| --- | --- |
| `0x00000004` | CREATE_SUSPENDED, assign and verify the owned Job before resume |
| `0x00000008` | DETACHED_PROCESS, start without console attachment |
| `0x00000400` | CREATE_UNICODE_ENVIRONMENT |
| `0x00080000` | EXTENDED_STARTUPINFO_PRESENT, explicit inherited-handle list |

Microsoft documents [DETACHED_PROCESS and CREATE_NO_WINDOW](https://learn.microsoft.com/en-us/windows/win32/procthread/process-creation-flags)
as different startup contracts; CREATE_NO_WINDOW is ignored when combined with
DETACHED_PROCESS, so remove it rather than combining them. There is no
CREATE_NEW_CONSOLE or breakaway bit. No parent console is detached or modified.

The explicit stdout/stderr file handles and NUL stdin remain unchanged, with
STARTF_USESTDHANDLES and the three-handle inheritance list. Microsoft's
[standard-handle contract](https://learn.microsoft.com/en-us/windows/console/getstdhandle)
supports redirected handles independently of a console. STARTF_USESHOWWINDOW and
SW_HIDE remain unchanged; hiding a window alone is not the console-ownership rule.

## Expected effect and limits

This targets startup console allocation as the cause of the observed extra member.
Requesting no console attachment is expected to avoid a console host created for
that startup path. It is a source-supported hypothesis, not a demonstrated fix of
invocation 3: that receipt did not trace who requested the console. A detached
application can still explicitly [call AllocConsole](https://learn.microsoft.com/en-us/windows/console/creation-of-a-console),
or require console APIs and fail. No claim is made that BYOND's pinned binaries
will avoid either behavior. The new seven-case packet is proposed and unexecuted.

Offline injected tests check the actual CreateProcessW flag argument, unchanged
redirected handles, and rejection plus cleanup of a second member even when its
reported identity is conhost.exe. They do not create a Windows process or prove
console absence. The historical windowless mask must fail the new flag oracle.

All one-member rejection/accounting rules, 256 MiB process/Job caps, 60-second
compile and 20-second runtime limits, 15-second fixture watchdog, socket policy,
ownership checks and cleanup stay unchanged. Any future native invocation needs
parent review of the exact packet and fresh resource/input checks. No retry,
allowlist, security change, CI dispatch or live action is authorized here.
