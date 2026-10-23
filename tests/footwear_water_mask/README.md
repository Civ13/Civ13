# Footwear water mask regression

The worn footwear path is `update_inv_shoes` in
`code/game/mob/living/carbon/human/update_icons.dm`. It constructs a boot image
at `human.layer + 0.01`, using `icon_override` or `body_build.shoes_icon`, then
adds the species blood mask's `shoeblood` image with `shoes.blood_color`.
Neither image specifies a separate plane, so both inherit the wearer's plane.
The item/inventory `blood_overlay` is a different appearance; it is not copied
into the worn boot. Bare-foot blood uses `shoeblood` directly in the same slot.

Mud movement in `mob_movement.dm` sets `blood_color = "#70543E"` and initializes
`blood_DNA`; blood decal crossing sets the same fields with its blood color.
Both therefore reach the same worn stain. `dirtyness` drives clothing examine
text, not a separate worn dirt sprite. The supplied examine text alone does not
identify which stain pixels are visible. Library resolved the two supplied PNGs
(`libfile_5e78891fc0348191895c22535dca8fd4`, 5541 bytes, and
`libfile_e064364b0f9c8191902d5f7d3f6a5cf0`, 2472 bytes), but the supported helper
failed both byte transfers, including the permitted retry. No bytes or pixels
were inspected and no visual reproduction is claimed.

`handle_drowning` sets drowning/wading state for uncovered beach water,
flooded trenches and flooded sub decks, with the existing ice/cover/boat rules.
It calls `update_fire` from the living-human Life path. The mask selection is
unchanged: ordinary wading uses `seashallow_over2`, drowning uses
`seashallow_over3`, and sub-deck depths >0, >=30 and >=100 use over1/2/3.
Zero depth returns no mask. This patch retains the existing environmental
refresh cadence and eligibility rules.

Before the fix, `update_fire` filtered the human and each top-level cached
image. A filter on the boot alone does not clip its nested stain. BYOND's
[appearance flag](https://www.byond.com/docs/ref/#/atom/var/appearance_flags)
and [filter](https://www.byond.com/docs/ref/#/atom/var/filters) contracts specify
that KEEP_TOGETHER applies filters after composing children. This patch groups
only the footwear image while masked, then removes grouping on dry refresh.
It does not group the whole mob or change planes, visibility, lighting, layers,
direction, transforms, durable stains, cleaning or footprint accounting.

`update_inv_shoes` also applies the current mask before publishing a replacement
image, including when its `update_icons` flag is false. `update_fire` refreshes
that grouping for depth/entry/exit updates. `update_icons` still publishes the
cached images and applies the existing standing/prone/lying transform. Suit
hiding, clean equipment and bare-foot branches retain their original behavior.
Other nested clothing overlays may have the same general filtering limitation;
this footwear fix deliberately does not change those compositions.

## Checks and recorded evidence

Run offline with a verified Python executable (no BYOND, network or game):

```powershell
& '<verified-python>' -B -m unittest discover -s tests/footwear_water_mask -v
```

The source contracts retain comparison of unchanged production shoe construction
and mask selection with deployed `77c14940584bedfa6241ecf1e0642a53ca6df0c7`.
They reject the ungrouped path and five source omission controls. The new pure
result-parser tests require the exact intended control failure, complete check
counts and control admission; collateral failures, absent controls and partial
results are rejected. These tests do not execute DM or establish rendered pixels.

At original patch head `86bbbb2cb8da8bcd12dfc1300e08d71c205480c6`, full-game
BYOND 516.1681 CI compiled with zero errors/warnings in run `40004369529`.
Two later reviewed headless packets completed 6,090 checks but FAILED 505 raw
color-text comparisons. Preserve both failed verdicts. The diagnostic packet
captured all 505 unique scene IDs with no dropped/truncated rows: native cached
child and detached direct/copy controls returned text `#a10808` (252 rows) and
`#70543e` (253), while the source fields retained `#A10808` and `#70543E`.
These measured getter representations justify a fixture-only comparison change,
not a production color change or graphical acceptance.

Retained evidence hashes:

- Both failed result files: `c61e59ed6a560eff77bc7d605425d891bf87aced3280717f06d1f44bf614db49`.
- First reviewed receipt: `70d9531ad3b0fff72140b412146a0e3eff0e0fde64987e7d7d3530029c6f1181`.
- Diagnostic receipt: `0ee1123384c7f3300187fd83cd1f0c6f2e751040113a2759c9079a0ba9085db5`.
- Complete diagnostics: `51ad55273ea7cf0a0d6c027d1f03ac2411879c5c9a9599954158a0d23cd7fcf4`.

The corrected comparator accepts only text of length seven matching
`^#[0-9A-Fa-f]{6}$`, then compares lowercase text. It rejects named/arbitrary
colors, whitespace, alpha suffixes, nulls, numbers and matrices. The authored
32-case JSON corpus exercises both operands and a changed RGB channel; it is
used by both offline policy checks and the proposed native fixture.

## Native packet preparation, no implicit execution

```powershell
& '<verified-python>' -B tests/footwear_water_mask/prepare.py --output '<fresh-absolute-directory>' --control fixed
```

Other preparation-only variants are `wrong-rgb` and `missing-stain`. All copy
exact production procs and real DMI resources, recording hashes, HEAD and dirty
diff in an adapted 3x3x1 packet. Preparation never starts a compiler or daemon.

The test-only entry closes native startup port 59474 and verifies closure and
refused reopening. Every client is rejected. Native execution requires review of
the complete frozen packet and a fresh, time-bounded, single-use exact-packet
grant. `run-contained.py` is a domain adapter of the existing floor-decal runner;
its Windows/socket/Job helpers are staged byte-identically from that suite.
Never use the rejected zero-socket supervisor or reuse a consumed grant.

The proposed final run is three serial cases, each one compiler followed by one
daemon under retained-handle, kill-on-close one-active-process Jobs. Existing
limits remain: compile 60 wall/30 CPU seconds and 1 GiB process-private memory;
runtime 15 wall/10 CPU seconds and 512 MiB; watcher 128 MiB; aggregate 240 seconds
including a 10-second cleanup reserve. Socket admission is TCP only: LISTEN
exactly 127.0.0.1:59474 before the closure marker, none after; existing loopback
states 5-12 only. Sampling cannot prove absence of transient sockets, trusted
BYOND is not OS-network-sandboxed, and inherited CloseHandle return values are
unchecked. Require exact retained-root/cumulative Job reconciliation and record
cleanup errors. No client attachment or live game access is permitted.

Expected case results, all currently UNRUN for this corrected fixture:

| Case | Checks | Exact failures | Diagnostic rows |
| --- | ---: | --- | ---: |
| fixed | 6122 | none | 505 |
| wrong-rgb | 6122 | `blood or brown mud color retained` exactly once | 505 |
| missing-stain | 6119 | `nested stain retained` exactly once | 504 |

Controls affect only the first stained assertion view and restore its original
appearance list before later snapshots. Wrong-rgb changes a real channel to
`#A10809`; missing-stain removes the child, and the guard avoids dereferencing
an absent appearance. Any other failure, runtime diagnostic, count mismatch or
missing control fails acceptance. The three skipped checks in missing-stain are
its unavailable child's state, color and plane checks.

Diagnostics retain raw text equality plus the corrected RGB result and detached
copy controls. Bounds remain 512 rows, 4,096 JSON characters per row, 128 text
characters, 20 matrix entries and 3 MiB serialized text; drops/truncation emit a
failure. Actual pixels remain explicitly unverified. Do not relabel historical
failures even if a later corrected fixture passes.

## Native visual acceptance still required

Use an authorized isolated game at the reviewed patch commit, with real client
captures and map/coordinates recorded. Do not use the live installation or
another branch's captures. Use `/obj/item/clothing/shoes/leatherboots`
(`sailorboots2`), clean/blood/mud variants and a tinted/override variant:

1. On dry land, compare original boot and stain pixels in all four directions.
2. Enter/leave shallow water and a flooded trench; submerged boot and stain
   pixels must disappear together, with the stain returning on land unchanged.
3. On a sub deck, change depth in place through 0, 1, 29, 30, 99, 100 and back
   down; compare boot/stain at every mask boundary. Include drowning and a
   lifejacket, covered water, ice and existing boat exceptions.
4. Turn, stand, lie and go prone; capture video for the transitions. Equip,
   remove and replace footwear while submerged, including blood acquisition,
   clean shoes, a shoe-hiding suit and bare feet. Check immediately and after
   the next environmental refresh for stale or accumulating filters.
5. Check ordinary lighting against the same scene; this patch does not touch
   lighting planes or the separate oversized-sprite lighting investigation.

Historical headless runs are recorded above; the corrected three-case packet
remains unexecuted pending review. No full-game/client capture, live change, merge
or deployment is established. OpenDream remains paused. Passing source, compiler
or headless state checks leaves all actual-pixel acceptance gates open.
