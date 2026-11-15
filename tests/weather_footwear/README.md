# Weather footwear

Headless probe for `code/modules/1713/weather_footwear.dm`: snowshoes, mukluks,
hobnailed boots, pattens, rubber boots and mountaineering boots, plus the
terrain ratings given to existing footwear.

```
bash scripts/cloud_byond_setup.sh   # once, installs the pinned compiler
python3 tests/ecology_spawning/run_linux.py . tests/weather_footwear/probe.dm
```

It loads the real global crafting catalogue and checks each new pair appears in
its era (snowshoes and mukluks in the Stone Age, hobnails and pattens by the
Iron Age and Medieval era, rubber boots with ready-made clothing, mountaineering
boots with alloys), that every pair has a research node, the snow, mud, wading,
ice-grip and slope ratings, which feet freeze in snow and which stay dry, which
ground counts as wet or icy, that running on ice slips about 3% of steps
barefoot, less in gripping boots and never in hobnails (walking never slips),
and that every item and four-direction worn sprite state exists and is drawn at
the feet. It prints PASS/FAIL lines and writes `result.json`; exit status 0
means no failures and no runtime errors.

Sprites are drawn by `tests/sprites/create_weather_footwear.py`
(`--preview <png>` writes a review sheet).
