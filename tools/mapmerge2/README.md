# Map Merger (mapmerge2)

Keeps map diffs small and resolves many `.dmm` merge conflicts automatically.
Ported from [CM-SS13](https://github.com/cmss13-devs/cmss13) (`tools/mapmerge2`,
commit `b782b5a`, AGPL-3.0), which inherited it from /tg/station.

Civ13 changes:

- Maps keep their own format. DMM maps stay DMM and TGM maps stay TGM, unless
  the `TGM=1` or `TGM=0` environment variable asks for a conversion.
- DMM output separates var edits with `; ` like DreamMaker.
- `bidict` is optional (`_bidict.py` is a small stand-in), so the parser and
  `scripts/maplint.py` need only the standard library.

## Use it

Install the git hooks once per clone (see [tools/hooks](../hooks/README.md)):

- Windows: double-click `tools/hooks/Install.bat` (needs the `py` launcher).
- Linux/macOS/Git Bash: `tools/hooks/install.sh`.

After that, `git merge`/`git pull` uses the map merge driver for `.dmm` files,
and each commit runs the pre-commit hook, which re-keys changed maps against
the previous version so unchanged tiles keep their keys.

The hooks need `pip install -r tools/hooks/requirements.txt` (pygit2; Pillow
for the icon merger).

## Lint

`python3 scripts/maplint.py` checks every map; `--changed origin/master` checks
only changed maps. CI runs it through the `map_tools` offline suite whenever a
map changes. Errors: map does not parse, merge-conflict markers, a tile with no
turf, more than one area, or the area not last. Warnings (`--warnings`): stacked
turfs, objects listed after a turf, items on wall turfs.
