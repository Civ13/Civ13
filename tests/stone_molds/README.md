# Focused casting and headless appearance proposal

Stopping rule: prepare exact source and this bounded hosted plan for Main review;
do not publish or execute the new native fixture before that review.

This follow-up is based on merged stone-mold source
`c95cf23fbe69be0d9c54c570b3c20e0bacce8283`. The earlier crafting fixture proved
carving and seeded-state oven behavior; it did not prove pouring or casting.

## Production paths exercised

`casting.dm` starts through the existing isolated crafting runner, with normal
game/global startup and maps bypassed. The included canopy fixture sets the world
to 4x3x1 plating; the focused actor uses tile (2,1,1). It uses an existing inert
human subclass, with crafting coefficient 2 and Blacksmith job.
No metal contents, material, capacity or icon state is assigned by the fixture.

- Actual mold `attackby` loads 20 of 25 copper ore into a fired clay pot, leaving
  five ore. Actual kiln `attackby` and `process` convert the charged ore. A separate
  six-unit gold ore charge follows the same paths.
- Actual mold `attackby` pours one copper into a sandstone pickaxe mold. It
  rejects gold with free mold space, rejects a zero amount, clamps a request of
  999 to two remaining units and refuses an already full mold.
- Actual stone-anvil `attackby` and production `do_after` consume three copper
  and construct one real copper pickaxe head. The same mold refills and casts
  again. Gold is rejected by the stone anvil with charge and output preserved.
- The fixture counts output types, checks their actual material, tests mold
  identity/reuse, and checks total copper/gold conservation.

The one production-source adapter replaces only the numeric `input(...) as num`
expression in a temporary copy of molds.dm, using `replace_once` to reject drift.
It supplies deterministic client choices; all admission, transfer, capacity,
debits, updates and output paths remain production code. Original and adapted
includes are retained. Character startup, skills and HUD remain existing fixture
adapters. The kiln process is called directly; ignition, fuel and elapsed smelting
are outside this test. No casting menu adapter is needed for pickaxe heads.

## Actual engine sprite output

All eight stone shapes and matching clay controls are exported in empty and
copper-filled states: 32 PNGs. Filling and emptying use the actual pour path, and
the charge is returned to its vessel after each pair. The game helper
`getFlatIcon` resolves current object appearance and applies the object's color
matrix via native `MapColors`. `fcopy` writes the engine-produced icon to PNG.
This does not use the existing static initial-icon extractor, which omits color.

`check_render.py` only reads PNGs. It checks 32x32 dimensions, nonempty pixels,
matching alpha coverage, visible stone/clay differences, runtime state/metal and
the color transform within one channel unit. It produces checksums for each pair.
Main should also inspect the exported engine PNGs. Scene lighting, client/UI
placement, animation timing and connected gameplay remain unverified. The filled
metal pixels receive the same tint, as already documented in the feature.

## Proposed hosted selection and limits

Use existing `.github/workflows/test.yml` on the exact reviewed branch head,
`comparison_base=c95cf23fbe69be0d9c54c570b3c20e0bacce8283`,
`stone_mold_casting_regressions=true`, `extensive_regressions=false`; every other
optional native input stays false. `stone_mold_expected_head` must equal the
immutable reviewed head. A guard before checkout/bootstrap rejects a missing or
mismatched SHA, nonempty introduced-native selection, extensive mode or another
optional input. Main must respect the current testing deadline. No dispatch has
occurred. Existing selection code is unchanged. Added test files are under
`tests/stone_molds`, so they do not select the broad `tests/crafting` native cases.
Normal required offline policy/compile checks remain enabled.

The only new native command is:

```
python3 -B scripts/check-recipes.py --stone-casting-only --report "$RUNNER_TEMP/stone-casting-report.txt" --evidence-dir "$RUNNER_TEMP/stone-casting"
```

Existing BYOND 516.1688 bootstrap and archive identity remain unchanged: archive
SHA-256 `16278f318cdeb4b77c57868dd7135032fde717ea6226269d22b2a1a50968e7f9`,
4,887,281 bytes. Bootstrap step 15 minutes; full-game compiler 300 seconds plus
five-second kill grace; existing APT phases 30/120/180 seconds, archive transfer
65, extraction 30, make 60 and Atlas generation 60 seconds. Dependencies are the
existing Python3/wget/git/unzip/make/sudo and 32-bit BYOND libraries.

The added Pillow 11.3.0 install has a 120-second direct timeout plus five-second
kill grace inside a three-minute step. Focused native/inspection step is six
minutes: existing compiler <=180 seconds, direct daemon <=90 seconds, then PNG
inspection <=30 seconds plus five-second kill grace. Expected runtime has two
three-second production casting waits and 32 exports. The existing outer CI job
limit is unchanged; no broader native matrix is requested.

The existing temporary build/runtime directories, copied crafting/names config,
startup bypass, direct-child timeout/wait and cleanup are retained. Runtime flags
remain `0 -invisible -close -trusted`; no local raw daemon, Gaia, live saves,
player/client session, credentials, network settings or paid service. These
controls do not establish process-tree or OS socket observation/containment.

Artifact `stone-casting-<head>-<run>-<attempt>` retains metadata/source hashes,
original/adapted mold source, compiler/runtime/errors/report, case and sprite
JSON, all PNGs and render verification JSON. The upload step runs on failure too;
missing outputs remain missing and are never converted into a pass. Compiler and
runtime artifacts are not uploaded. Existing exact-head compiler, selection,
baseline and aggregate artifacts remain separate.
