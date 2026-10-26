# Unexpected owned-Job member diagnostic: source/offline only

Invocation 2 observed a successful PID-list query with assigned/count 2/2,
returned length 24, PIDs 579400 and 641196, and accounting total/active/terminated
2/2/0. The retained primary handle was nonsignaled before and after the query.
The strict one-member rejection stopped compilation and Job cleanup drained to
zero. The second member's image, creation identity and parentage were not captured.
That historical PID must not be opened now; it may have been reused.

## New diagnostic scope

`WindowsJob.unexpected_member` is called only for unexpected IDs in a successful,
complete and structurally valid census bounded by the existing two-entry buffer.
Malformed/truncated lists do not authorize identity reads. The active-process
limit remains one: a valid two-entry census still fails the original guard.

The diagnostic requests only `PROCESS_QUERY_LIMITED_INFORMATION` (`0x1000`),
with inheritance off. It enables no privilege, requests no terminate/VM/write
rights and never terminates a member by PID. After obtaining a read-only handle,
it checks `IsProcessInJob(handle, exact_owned_job)` before reading the image,
checks again before reading creation time, and checks afterward. Only a fully
verified image/creation pair is published. A recycled foreign PID fails membership
before identity is read. The returned image string is recorded without resolving
or opening that image path. The query handle closes immediately, without a retry;
close failures are explicit diagnostics. Cleanup-start state refuses any later open.
Owned-Job termination and existing cleanup remain the sole termination mechanism.

These rights are sufficient for both
[IsProcessInJob](https://learn.microsoft.com/en-us/windows/win32/api/jobapi/nf-jobapi-isprocessinjob)
and [GetProcessTimes](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getprocesstimes).
Invocation 3 recorded PID 629456 as `C:\WINDOWS\System32\conhost.exe`, creation
FILETIME 134371900026432798, with all three membership checks true and its query
handle closed. The unchanged guard rejected the two-member census; cleanup
reported zero active Job members. This records identity, not harmlessness or
parentage. A subsequent read-only inspection found that recorded PID absent.
Its tests inject
read-only handles, access denial, PID reuse, membership loss, close failure and
after-cleanup refusal; they do not identify historical PID 641196.

## Facts from executable inspection and primary sources

Static byte inspection, without loading or executing the files, found:

| Installed file | Bytes | PE machine / optional header | Subsystem |
| --- | ---: | --- | --- |
| dm.exe | 46,080 | I386 / PE32 | Windows CUI (3) |
| dd.exe | 38,400 | I386 / PE32 | Windows CUI (3) |
| dreammaker.exe | 2,143,232 | I386 / PE32 | Windows GUI (2) |
| dreamdaemon.exe | 268,800 | I386 / PE32 | Windows GUI (2) |

Interpretation follows Microsoft's [PE format](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format).
The inspected dm.exe/dd.exe hashes match the pinned 516.1681 allowlist. dm.exe
imports byondcore.dll and compiler-related symbols. This is static import evidence,
not proof of which code paths ran or whether a DLL/dynamic call created a helper.

[BYOND's 516 notes](https://www.byond.com/docs/notes/516.html) identify dm.exe as
the Windows command-line Dream Maker. The
[engine author's CLI discussion](https://www.byond.com/forum/post/2785103)
describes its shared Linux compiler implementation and the separate Windows CLI
daemon. Neither establishes that PID 641196 was dreammaker.exe, or that an extra
member is expected or harmless. No such identity claim is made.

## Why accounting can exceed the configured active limit

Microsoft documents that exceeding
[ActiveProcessLimit](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-jobobject_basic_limit_information)
causes termination and failed association, but the incremented active count is
decremented only after termination and closure of all process handles. Its
[accounting contract](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-jobobject_basic_accounting_information)
also includes failed over-limit associations in total count and temporarily in
active count. Therefore an active limit of one is not a guarantee that every
sampled accounting snapshot reports at most one.

That documented transition is a plausible explanation for total/active 2, not
proof of invocation 2's exact sequence. The two PID entries and terminated=0
snapshot do not establish whether the second process ran, was pending rejection,
or which component created it. Parentage is outside this limited diagnostic.
Application/DLL helpers and Windows compatibility/crash components remain
unverified hypotheses. No candidate is treated as harmless; the rejection stays.

No native retry, cap/process-count relaxation, security change, accounts, clients,
or production interaction is authorized by this source addition.
