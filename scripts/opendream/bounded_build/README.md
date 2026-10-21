# Source-only bounded Windows build guard

This is reusable preparation, not a build lease. There is intentionally no CLI
and no default SDK, source revision, patch, command, or environment. Importing
the Windows adapter does not bind APIs or launch a process. A reviewed caller
may later instantiate `Windows` and call `guard.run` only under an explicit lease.
The small client guard is neither modified nor used.

The caller supplies immutable provenance bytes, exact trusted executable argv,
an explicit environment, and a filesystem-only `stage(root)` callback. Staging
must authenticate the SDK binary, exact engine commit, recursively pinned
gitlinks, reviewed patch bytes and clean source. The guard hashes and preserves
that caller receipt; its hash does **not** establish the receipt's truth. Staging
places all source under `root/source`, without reused bin/obj. Build commands and
file logger paths must direct all outputs inside the unique root. Environment
cache/temp paths are placed there. The caller must reject flags or source targets
that write elsewhere, and exclude concurrent workspace writers using ACLs.

Each root is created suspended, assigned to a new unnamed kill-on-close Job,
membership checked, then resumed. Neither job nor creation flags permit
breakaway; nested inherited jobs can make assignment fail, in which case the
new suspended root is terminated through its retained handle. No process is
attached by discovery or terminated by PID. Commands are serialized until all
owned descendants exit. Job completion notifications retain child handles and
check membership; missed ownership, unavailable handles, limits, and unknown
notifications fail closed. All retained exits are checked before closing.
Cumulative Job process accounting must equal the retained handle count whenever
the Job becomes empty, detecting children that exit between inventory samples.

The Job commit cap is 2 GiB minus a 128 MiB watcher reserve. The watcher is sampled
and must fit that reserve; aggregate private bytes must remain <=2 GiB and host
free physical memory >=6 GiB. Work stops at 870 seconds, reserving 30 seconds
for cleanup within the overall 900-second budget. Termination/inventory/wait or
handle-close failures mark the receipt unsuccessful. Kill-on-close remains the
fallback. An empty active inventory alone never substitutes for retained exits.
Completed guard results include command exits, all observed owned exits, memory
samples' peak/minimum, frozen receipt hash, failures and elapsed time.

Limitations before a lease: native interop has not been exercised. Adapter tests
prove control flow, not Windows containment or a completed compiler build.
Windows completion events are not guaranteed for every condition; short-lived
children whose handles cannot be acquired fail the run. Resource sampling does
not continuously establish host free memory or watcher use between polls. Path
checks reject reparse points but need exclusive ACLs to exclude replacement
races. The guard does not sandbox arbitrary executable/source filesystem writes,
network access, or malicious targets. Native calls and the staging callback are
synchronous; a hung OS call/callback can exceed the deadline, which is reported
as failure rather than represented as a hard real-time guarantee. Use bounded
filesystem staging and reviewed commands. Standard output is not captured by
this adapter; reviewed compiler file logging must stay inside the root.

Pure tests, using a verified interpreter: `python.exe -m unittest discover -s
scripts/opendream/bounded_build -p "test_*.py"`. The production Windows methods
are exercised through fake injected kernel/PSAPI functions, with a WinDLL tripwire.
No native calls, inert process
tests, SDK queries, dotnet, compiler or server execution are part of these tests.
