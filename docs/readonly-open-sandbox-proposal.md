# Read-only native-open sandbox proposal

This is an unimplemented, source-only execution proposal for the Windows
compatibility probe at `ac7472a4b43f5fc23d3886963583e649f2b1eccd`.
It grants no execution permission and establishes no network containment.

## Availability evidence

The exact known path `C:/Windows/System32/WindowsSandbox.exe` exists on the
current host. A read-only query of `Containers-DisposableClientVM` with
`Get-WindowsOptionalFeature -Online` returned "requires elevation" in both
the ordinary and approved elevated-tool invocation. Feature state therefore
remains unknown. No feature was enabled, installed or started. Do not infer
availability from the executable alone, retry unchanged, or discover executables
recursively.

## Proposed configuration

[Microsoft's configuration reference](https://learn.microsoft.com/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-configure-using-wsb-file)
documents disabled networking and read-only mapped folders. The following is a
non-launchable template: placeholders must be resolved to validated, dedicated
task directories before a reviewed wrapper could use it.

```xml
<Configuration>
  <Networking>Disable</Networking>
  <vGPU>Disable</vGPU>
  <AudioInput>Disable</AudioInput>
  <VideoInput>Disable</VideoInput>
  <PrinterRedirection>Disable</PrinterRedirection>
  <ClipboardRedirection>Disable</ClipboardRedirection>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>DEDICATED_FROZEN_INPUT</HostFolder>
      <SandboxFolder>C:\ProbeInput</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
    <MappedFolder>
      <HostFolder>DEDICATED_EVIDENCE_OUTPUT</HostFolder>
      <SandboxFolder>C:\ProbeEvidence</SandboxFolder>
      <ReadOnly>false</ReadOnly>
    </MappedFolder>
  </MappedFolders>
</Configuration>
```

Input would contain only the frozen standalone scripts and required pinned
BYOND/Python dependency files. There is no repository, production save, credential
or general host-directory mapping. Package staging and hashing need a separate
resource turn; neither has occurred. Native temporary sources, binaries and
`selected.sav` must be created inside the guest local filesystem. Running against
a host read-only mapping would invalidate the writable omission control.
Both host mappings must resolve beneath their explicitly approved task roots;
reject reparse points, junctions and path escapes. Dependency inputs must be
complete before launch and must never download replacements from the guest.

Before any engine launch, guest preflight would record the configuration digest,
guest OS/build, exact tool identities, active adapters and routes. Unexpected
non-loopback connectivity, unknown measurements or configuration mismatch reject
launch. Adapter/route observation is supplemental evidence, not a substitute for
verified platform containment. BYOND `-close`, `-safe` and the source OpenPort
override alone do not establish network isolation.

## Wrapper contract and unresolved lifecycle

The wrapper must first prove the optional feature is already enabled and identify
all pre-existing Sandbox instances read-only. It must reject an existing instance,
unknown inventory, or an API that might reuse a pre-existing instance. Starting a
GUI executable and retaining its PID alone does not prove ownership of the guest
VM, its service processes or its eventual teardown.

A selected, independently reviewed platform API must return a unique owned
Sandbox identity, expose its lifecycle and permit teardown of that exact instance.
No such API has been verified for this host. Consequently the present proposal
must fail closed before startup. Do not stop processes by name, stop all Sandbox
instances, alter global firewall settings, enable features, create accounts or
terminate shared virtualization services.

The proposed wrapper state machine is:

1. Verify feature state, zero pre-existing instances, paths and resource grant.
2. Establish an absolute monotonic deadline of at most 600 seconds and reserve
   cleanup time before startup. Register an independent watchdog bound to the
   exact owned instance before permitting guest work.
3. Start only through the verified ownership API. Record the instance identity,
   host owner/watchdog PIDs and observed start evidence.
4. Run guest containment preflight, then the three sequential controls. Each
   launch requires enough remaining time for its work and reserved cleanup.
5. Stream bounded receipts to the dedicated output directory. No bulk export or
   hashing may consume the cleanup reserve.
6. On success, failure or timeout, terminate only the owned guest and verify its
   disappearance. Record cleanup errors and surviving owned processes. Any
   unknown ownership, incomplete receipt or failed cleanup rejects acceptance.

Retain bounded generated sources and role logs/results for unsupported and failed
cases too. The host may accept transferred evidence only after verified owned
teardown and closed writers, with a frozen artifact manifest. Guest receipts are
not independent host OS attestation. Missing evidence is failure, including when
startup or timeout prevents export.

The existing runner's 324-second sum of process waits and cleanup allowances for
three cases is not a whole-run deadline. Startup, preflight, filesystem I/O,
evidence transfer and teardown must fit the 600-second envelope. A deadline check
around blocking calls cannot guarantee a hard deadline. Acceptance requires a
reviewed independent watchdog and bounded ownership/teardown operations; if the
platform cannot provide them, this execution route is unavailable. Do not present
best-effort polling as a hard wall-time bound.

## Review and execution boundary

Freeze the actual wrapper, configuration and ownership API evidence for
independent source review before requesting an execution grant. Unavailable
feature state or lifecycle proof remains a technical blocker. No sandbox launch,
runtime staging, compilation, native test, ACL change or deployment is authorized
by this document. PR18 retains execution priority.
