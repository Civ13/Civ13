---
name: civ13-map-renders
description: Lint, render and review Civ13 map (.dmm) changes and map rotation changes before a PR. Use whenever a change adds, edits, renames or deletes a map or touches the map vote lists.
---

# Map changes and renders

Every map change provides renders for review.

1. Lint the changed maps:
   `python3 scripts/maplint.py --changed origin/master --warnings`
2. Render before | after pictures with byond-devtools, as the `map-review`
   workflow does on PRs:

   ```bash
   python3 scripts/map_review.py --base origin/master --devtools ../byond-devtools \
       --byond "$HOME/byond-$(python3 -c 'import json;print(json.load(open("tools/byond/version.json"))["version"])')/byond/bin" \
       --out map-review
   ```

   Run it with the head checked out. It writes `map-review/summary.md` and one
   `<map>.z<N>.png` per changed level (at most 64x64 tiles around the
   changes). Attach the pictures to the PR or link the workflow artifact.
3. For a region outside that window, render it directly (at most 128x128
   tiles per picture; a preview of authored source, not a client screenshot):
   `node ../byond-devtools/src/cli.js render --root . --dme civ13.dme --byond <BYOND bin>
   --map maps/<map>.dmm --z <N> --x1 .. --y1 .. --x2 .. --y2 .. --out <name>.png`
4. Map metadata, level admission and instance rules:
   [Maps and instances guide](../../../docs/agent-guides/maps-instances/README.md).

Rotation: a map is in rotation only when it has an active (not commented-out)
entry in the vote lists in `code/processes/mapswap.dm`.
