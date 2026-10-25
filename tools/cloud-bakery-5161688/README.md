# Genuine Civ13 bakery cloud stills: first execution review

This is SOURCE ONLY until main review. No package, compiler, server or client has
been executed to prepare it. The previous successful Windows screen preflight is
native diagnostic evidence, not Civ13 gameplay. Wine's denied AF_UNIX prerequisite
was not bypassed. Frozen PR #3236 and prior desktop attempts remain unchanged.

## Concrete approved acquisition

Official Windows URL returned 403 once for each distinct EXE and ZIP request in
this cloud shell. There were no retries, header tricks or TLS/proxy exceptions.
The CMSS13 public mirror inventory then supplied these data-only observations:

- 516.1688_byond.exe: 7,264,990 bytes, SHA-256
  d1c8d916d684d5163f88b6ceb6312d1cba2128ea64d0b94c1d4e6db35ea46e21.
  This exactly matches the earlier official HTTPS download pin in version.json.
- 516.1688_byond.zip: 8,602,470 bytes, SHA-256
  9079f29b0747719233715dfeff223641e6fb69bd16b8ba9676d5cd42cfcd0148.
  All 45 regular files match the prior desktop's exact 516.1688 toolchain seals.
- Source: https://cmss13-devs.github.io/byond-build-mirror/download/build/516/
  This remains a community mirror, not an independently vendor-signed checksum.

The user approved using this verified package on a disposable Windows cloud
runner for an isolated Civ13 scene. Prefer ZIP extraction into the task directory
rather than running its NSIS installer. No Windows package mirror is published,
no system installation is attempted, and no credentials are involved. Normal
proxy/TLS policy is preserved; download is single-attempt and byte/hash bounded.
The prepared source retains complete ZIP notices and validates every file.
The first run stopped in offline controls before any BYOND download or launch.
An actual synthetic Git experiment confirmed core.autocrlf=true also converts
git archive bytes. This revision replaces both archive materialization paths
with ls-tree and one retained cat-file --batch process, validating exact blob
identity, type, size, framing and canonical SHA-1 before exclusive fresh writes.
It preserves both original LF and original CRLF bytes; no pins are normalized.
The bootstrap Python source may be read from the normal Windows checkout, but
all materialized tooling and scene data come only from raw committed Git blobs.

Static PE imports establish x86 mfc140u.dll, vcruntime140.dll, msvcp140.dll and
d3dx9_43.dll requirements for the client. They do NOT import mfc120u.dll or
vcruntime140_1.dll. Their absence in the earlier screen diagnostic is therefore
not a demonstrated 1688 blocker. VC/MFC are not bundled: if required runtime
files are missing from the actual hosted runner, STOP instead of installing.

The ZIP's Microsoft Jun2010_d3dx9_43_x86.cab can be extracted as data into owned
bin if the installed DLL is absent. Installed libarchive read its payload here:
x86 d3dx9_43.dll is 1,998,168 bytes, SHA-256
0b28546be22c71834501f7d7185ede5d79742457331c7ee09efc14490dd64f5f.
Only that exact file may be used. Do not run DirectX setup. WebView2 registration
is not loader compatibility; this first scene uses a map-only native skin, not a
browser control. Delayed Steam/FMOD and dynamic dependencies remain unproven.

V4 passed offline gates, exact source/package materialization and dependencies,
then the actual 516.1688 compiler failed before any daemon/client. The isolated
error_handler.dm stub retained an opening #ifdef from a removed production
handler. This revision removes that unused opening/macro, preserves both global
runtime counters and the fixture's own stop-on-error handler, and checks all
modified DM/DME conditionals for balance. The original failed evidence remains.
This static repair is not a native compile or rendering pass.

V5 compiled the exact isolated bakery with BYOND 516.1688, zero errors/warnings.
The daemon then stopped with "startup failed: bad index" after both parameter
checks passed, before a client or screenshot. That receipt does not identify the
failing initializer. V6 added diagnostics only: last startup phase/type and
bounded original exception name/file/line/description go to the existing stop
receipt. All startup calls, checks and stop behavior stay in place. No arbitrary list-access workaround is applied. BYOND documents that caught exceptions may lack desc;
absence is marked explicitly rather than synthesized. Reference:
https://www.byond.com/docs/ref/#/exception

V7 additionally supplies one source-proven prerequisite: the isolated global
controller explicitly initializes its sticker_registry member to an empty list.
The native registry initializer requires that list; the prior isolation stub
omitted its generated initializer. A new pre-call assertion checks the controller
and empty list. All native initialization calls remain intact. Broad Initialize()
is not invoked, and no production initializer or error is skipped. This corrects
a directly verified omission, not proof of the original failure's exact line.

V7 compiled but the explicit registry prerequisite stopped startup. The original
Master constructor creates global_vars without assigning its result; the original
global_vars constructor publishes itself through GLOB = src. The isolated stub
had omitted that publication. V8 restores exactly the original single-instance
guard and GLOB assignment before the explicit registry/events initialization,
without broad Initialize(). Staging checks that caller/publication contract on
hash-verified original source before overlaying the fixture. Separate assertions
identify missing GLOB, non-list registry or unexpectedly nonempty registry.

## Real scene, exact source

The scene is the existing V4 15 x 13 Johnson's Bakery crop from authored Little
Creek at 58404f5bd16e3fed80f1d9844c5db3edd144942c. Its 3,673 allowlisted committed
source/assets are exported from that exact Git checkout and checked as Git blobs.
Public config/names lists only; no production configs, accounts, saves or live
world are copied into runtime. Seventeen reviewed changed-source files implement
the same isolated startup and a small cloud derivative. The original V4 stays held
and untouched. The cloud derivative explicitly has its source hold released, so
publication/execution of this packet requires main review, not a runtime override.

The derivative changes only the camera entry/skin and fixed sequence, not bakery
mechanics. The engine must provide exactly one actual Guest key, loopback address
and client build 516.1688. This is a real BYOND guest, never the user's account,
synthetic session or invented ckey. A login prompt, extra window, wrong client
build, unexpected child or non-loopback owned endpoint stops the run. No account
login automation or persistent access is included.

The map-only 480 x 480 viewport excludes production login and browser UI. One
stationary guest observes two scripted native humans. Production item pickup,
flour recipe, oven ignition/cooking and table exchange handlers stay unchanged.
The fixed sequence prepares paid dough, waits for a first real screenshot, then
runs the real oven timer and item exchange, and takes the second screenshot.
No timer shortening, direct cooked-bread creation, fake client, actor teleport,
canvas reconstruction or user-facing screenshot label is substituted for rendering.

This is staged native Civ13, not an ordinary-player input/multiplayer test or a
full round. Reduced controller initialization, translated crop lighting, guest
admission and real scene behavior are not yet natively verified. Compilation or
runtime errors remain failures. Do not switch to the production world to hide them.

## Containment and evidence

Only one console dm.exe, console dd.exe and visible dreamseeker.exe are launched.
Each receives a separate retained Windows Job before resume: kill-on-close,
one-process limit, 512 MiB process cap and 60-second hard process CPU allocation.
The caller samples its own 128 MiB preflight reserve and requires 2 GiB free RAM
before each launch. Process image/PID/birth are captured while suspended. Cleanup
acts through retained handles, not name/PID adoption, and handles partial launch.

Daemon uses -trusted because the reviewed fixture needs trusted local files; it
also uses -ip 127.0.0.1, -invisible and -nowebclient. Production shell/export sites
are replaced by the existing throwing V4 stubs. Guest connects only to the owned
loopback port. This is not an OS network sandbox. To observe actual endpoint
behavior, the adapter reads GLOBAL Windows TCP/UDP tables, filters owned PID rows
immediately in memory, and rechecks its retained handle. Other-process rows are
never persisted. This is expressly a disposable hosted-runner query, not a
process-scoped API, desktop inventory workaround or proof against between-sample
network activity. Main must review this boundary before launch.

The native work budget is 165 seconds shared across compiler, daemon and client,
plus at most 15 seconds total cleanup. Native step timeout is four minutes and
whole job ten minutes, including source checkout/acquisition. Blocking OS calls
are not preempted by cooperative Python checks; Actions timeout is the outer
boundary. Failure retains the native/log/cleanup evidence and never becomes a pass.

Capture uses actual screen pixels from only the verified retained client's
480 x 480 rectangle. Input-desktop denial is terminal. Foreground, desktop,
geometry, ownership and sampled occlusion checks surround capture. No generated
image, PrintWindow or offscreen fallback is used. Nonblank/diversity checks are
heuristics, not semantic proof; main must inspect both images and native receipts.

Artifacts are two PNGs plus bounded receipts/logs (including acquisition/dependency failures), never package bytes, runtime
profile/cache directory, whole desktop or raw socket tables. Seven-day retention,
allowlisted regular files, 1 MiB each and 5 MiB aggregate. Before/after pixel hashes
must differ, and all owned processes must confirm cleanup before PASS. A partial
image can still be useful failure evidence but is never completed bakery proof.

## Exact next action after complete source review

Map cloud-bakery-5161688.yml to .github/workflows/cloud-bakery-5161688.yml; map the
other proposed source files to tools/cloud-bakery-5161688/ (not __pycache__). Make
one source commit on pinned base 3f3dd47f614f4659031a793dc590346f5e4de3e6, branch
ci/cloud-bakery-5161688-glob-20261025, exact commit message:

ci: one-shot published-globals Civ13 bakery cloud render (2026-10-25)

The initial publication admits attempt 1 only; no scheduled/PR/manual trigger or
retry. Normal all-branch CI remains enabled and may also run. One-time selectors
are not a durable ledger against deliberate branch deletion/recreation.

Review the complete capture/acquisition/controller code and bakery-v4-cloud-delta
before publication. Then read the exact run's receipts, inspect real PNG pixels,
and report only the demonstrated result. Stop at a concrete missing dependency,
compile failure, guest rejection, runtime fault, capture refusal or cleanup error;
repair source only within the authorized scene and review the changed operation
before any new attempt. No Gaia, desktop, account, security or publication detour.
