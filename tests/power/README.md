# Cable power regression probes

Run from the repository root with BYOND 516.1681 (the CI version):

```powershell
./scripts/test-power.ps1 -ByondBin 'C:/path/to/byond/bin'
```

CI compiles the whole game, then runs this probe using its Linux BYOND installation.
The probe creates an isolated 8 x 8 x 1 empty world, compiles the actual cable
network procedures, engine output/deletion procedures, object deletion procedure,
and lamp/radio power checks with minimal fixture types. It starts one headless
process, shuts it down, verifies exit, and removes temporary compiler/runtime
state. It does not load the game map, production saves, bots, or server settings.
The fixture is runtime contract coverage, not full-game graphical acceptance.

## Confirmed original defects

Original source: `0d38999d5` (master when this investigation began).
Use the retained original-source reproduction mode to obtain failing assertions:

```powershell
./scripts/test-power.ps1 -ByondBin 'C:/path/to/byond/bin' -SourceRef 0d38999d5
```

1. Connect a 10-unit source to three cables A--B--C. After waiting 30 deciseconds,
   call A.power_on(10), as an external engine does during running(). Repeat four
   times at 30-decisecond intervals. The root reports 50 and the remote end 350
   instead of 10. External engines actually call power_on every 10 deciseconds;
   the longer interval makes the original propagation throttle deterministic.
2. Disconnect the middle cable B. The original disconnected end retains 350
   capacity, despite having no generator or storage attached.
3. In one tick, request loads of 4 at A and 6 at B. The original remote demand
   is 4 instead of 10. Release those requests in the same tick; remote demand
   remains 4 instead of decreasing to 6 then 0.

The pinned Windows 516.1681 runtime reproduced all six failing assertions in
these three cases. These are confirmed capacity/accounting defects; this does
not establish that any specific historical player report used these steps.

## Accounting and regression coverage

`maxpower`, `powerflow`, `powerneeded`, and `currentflow` are instantaneous power
capacity/demand in the existing gameplay scale. They are not stored energy.
Running, unbroken, connected engines contribute positive maxpower once each.
Capacity is replaced on rebuild, never integrated over ticks. Consumer demand is
reserved once per consumer; releases are idempotent and immediate. A consumer
may reuse its existing reservation when checking a fully occupied network.
Engine demand is shared proportionally between contributing sources, preserving
the existing 10-percent idle load and maximum-load clamp. No batteries,
charge/discharge rules, storage state, or new physical unit conversion are added.

Checks cover single and multiple sources, repeated generation and same-tick
updates, capacity exhaustion, real lamp/radio checks, demand release and deletion,
loops, merge/split, broken/stopped/deleted engines, cable movement/deletion,
six-way fanout, and ten disconnect/reconnect cycles. Numeric engine shares use a
0.0001 tolerance for BYOND floating-point arithmetic. No nonfinite input exploit
was established by this investigation.

## Full-game evidence still required

On the exact PR head, in an isolated full-game world, build an anchored steam
engine with its legitimate lit heat source. Attach a cable chain and normal
consumers, verify capacity remains bounded through repeated running ticks, cut
the middle cable, and verify the isolated consumers stop. Reconnect and verify
power returns; join two legitimate sources and verify stopping one preserves the
other's capacity. Capture actual screenshots and sequence video showing these
steps, the tested map, and commit. This gameplay sequence remains to be verified;
probe results must not be presented as completed gameplay capture.
