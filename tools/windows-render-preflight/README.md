# Owned Windows screen preflight

Source-only preparation against Civ13/Civ13 master
`3f3dd47f614f4659031a793dc590346f5e4de3e6`, verified 2026-10-25.
No workflow, branch, pull request or Windows process has been started by preparing
this source. Review before activation. This is NOT DreamSeeker gameplay or a
BYOND installation test.

## Exact question

Can an unmodified standard `windows-2022` GitHub-hosted runner display one owned
native window and return its changing client pixels from the actual screen?
The WinForms window is 320 x 160 with an owned, unique title. It initially paints
red/blue panels, then their RGB inverse cyan/yellow panels. The only capture API
is `Graphics.CopyFromScreen`, constrained to the verified owned client rectangle.
Every pixel of both frames must match its exact phase before an image is saved.
No whole-desktop image, offscreen-render fallback or unexpected image is retained.

## Activation and single-attempt boundary

Publish exactly one reviewed source commit whose sole parent is the base above,
on branch `ci/windows-render-preflight-20261025`, with exactly this commit message:

`ci: one-shot owned Windows screen preflight (2026-10-25)`

The push must be initial branch publication (old ref is base or all zeroes),
change this workflow or its dedicated tool directory, and be run attempt 1.
There is no pull-request, scheduled or manual-dispatch trigger. Later patch
commits and Actions reruns cannot enter the probe. This is an intentionally
one-time branch experiment, not a durable global one-use ledger: deliberately
deleting/recreating the branch at the same commit could generate another run.
Do not do that, automatically retry, or expand the trigger after a failure.
Any subsequent experiment needs a separately reviewed activation plan.

Normal repository all-branch CI subscriptions remain unchanged and may run
alongside this experiment. Its own workflow cannot suppress their side effects.
Do not modify unrelated workflows, the frozen PR #3236 fixture, game source,
branch protections or account/security settings to make this experiment pass.

## Scope and outputs

- Existing pinned checkout and upload-artifact actions; read-only contents token,
  checkout credential persistence disabled, no secrets or new permissions.
- Existing Windows PowerShell/.NET Framework assemblies/compiler only. No package
  install, executable download, BYOND, browser/WebView2 launch, credential, login,
  local server, network probe, RDP, autologon, registry write or driver changes.
- Read-only current session ID, window-station name/visibility, thread/input
  desktop, primary/virtual geometry. Input desktop opens with READOBJECTS only.
  Access denial is terminal; there is no desktop switch, escalation or retry.
- Read-only 32-bit-view WebView2 registration and bounded PE-header inspection of
  six named SysWOW64 VC runtime DLLs. Registration is not an x86 WebView2 loader
  test; DLL presence is not proven dependency closure or runtime compatibility.
- The HWND is bound to this process, its unique title, client geometry, current
  input desktop, visibility/foreground state and nine client hit-test points.
  Ownership/geometry/foreground are rechecked after each real screen copy.
  No input is injected. Only this owned form is shown/activated/closed/disposed.
- All-pixel validation prevents unexpected/occluded/blank/stale image persistence.
  Desktop observations are snapshots, not protection against adversarial races;
  this probe is only for the disposable isolated hosted runner, never a user's PC.
- C# cooperative work budget is 30 seconds; the complete script step is capped at
  two minutes and the job at four. A blocked OS call cannot be preempted by the
  cooperative budget; the Actions timeout is the outer bound. Normal cleanup
  closes/disposes only the retained owned form and closes its input handle, then
  restores this thread's prior DPI context. Process exit also destroys its form.
- At most four files: receipt.json (32 KiB text bound), probe.log, red-blue.png and
  cyan-yellow.png; each must be a regular, non-reparse file at most 64 KiB. Only
  the allowlisted directory becomes upload-eligible; retention is seven days.
  Workflow/script/C# hashes, exact commit/run identity and image hashes are in
  the receipt. No usernames, credentials, process inventory or other window text
  are collected. A capability failure normally retains only JSON and one log.

## Outcomes, without overclaiming

`passed_owned_screen_capture` and exit 0: both real screen frames exactly match,
repaint happened, geometry/ownership remained valid, cleanup confirmed, PNG pair
exists with distinct hashes. This establishes only the native diagnostic window.

`capability_unavailable` and exit 2: input desktop denied/inaccessible,
noninteractive station, foreground/geometry/paint/pixel failure, budget expiry,
or unconfirmed cleanup. This is NOT a passing or skipped capture. No privileged
fallback, settings change, capture retry or dependency installer is attempted.

`probe_error` and nonzero: evidence writing or final image-pair checks failed.
Compilation, self-test, script or timeout failure is also nonzero. If the script
cannot validate its output directory, the upload step does not run; ordinary
Actions logs remain. Absence of an artifact never means the probe passed.

Even a pass does not establish DreamSeeker 516.1688 acquisition, 32-bit dependency
loading, WebView2 compatibility, guest/authenticated admission, Bakery observer
rendering, real game screenshots, performance or a finished trailer. PR #3236's
516.1681 vendor-403 and historical failed attempts remain separate evidence.

## Tests and review status

`python tools/windows-render-preflight/check_source.py` runs seven source-contract
checks without Windows APIs. It does not compile C# or execute PowerShell.
On Windows, `Run.ps1 -SelfTestOnly` compiles against installed assemblies and runs
seven synthetic all-pixel validator controls (blank, single color, expected first
phase, stale first phase, one corrupted pixel, inverse phase and wrong size),
without probing any desktop. The native workflow runs these same controls first.
Synthetic control images are never saved or substituted for screen evidence.

Prepared in Linux: seven source contracts passed; YAML parsed with trigger,
permissions, runner and step-count assertions. Windows PowerShell parsing/C#
compilation, the seven native validator controls, Actions evaluation and actual
screen capture have NOT been run. No Windows/.NET compiler is available here.
Independent source review and an authorized first hosted execution are pending.

## Sources

- Current base: https://github.com/Civ13/Civ13/commit/3f3dd47f614f4659031a793dc590346f5e4de3e6
- Existing runner/action pattern: https://github.com/Civ13/Civ13/blob/3f3dd47f614f4659031a793dc590346f5e4de3e6/.github/workflows/native-launcher.yml
- Frozen native experiment: https://github.com/Civ13/Civ13/pull/3236
- Hosted runner model: https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- Input desktop: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-openinputdesktop
- Object visibility/input metadata: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getuserobjectinformationw
- Actual screen copying: https://learn.microsoft.com/en-us/dotnet/api/system.drawing.graphics.copyfromscreen
- Thread-local DPI context: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setthreaddpiawarenesscontext
- WebView2 registry detection: https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution
