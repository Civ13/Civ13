# Small Stone Age additions

Code: `code/modules/1713/stone_age_extras.dm`. Art: `icons/obj/stone_age_extras.dmi` from
`tests/sprites/create_stone_age_extras.py` (the sickle teeth reuse the flint arrowhead sprite).
Tests: `python3 tests/stone_age_extras/test_source.py`; native probe
`python3 tests/ecology_spawning/run_linux.py . tests/stone_age_extras/probe.dm`.

- **Bone flute** (1 bone) and **frame drum** (2 leather), both under Ritual Worship. Use one in
  hand to play (every 5 s): everyone conscious who hears it within 7 tiles gets +3 mood
  ("music"), at most once every two minutes each. There are no note samples, so playing is an
  emote rather than a song.
- **Flint sickle**: knap "Sickle teeth" from a flint with a hammerstone, then use the teeth on a
  branch. It is a knife subtype (`TOOL_KNIFE`, keeps the name "flint sickle"), so it does what
  a knife does. Harvesting a ripe crop with it also reaps up to 2 touching ripe crops of the same
  kind.
- **Bison herds**: when a bison cow takes damage, every other bison cow within 7 tiles flees
  from the people nearby (`do_behaviour("scared")`), at most once every 5 s. Bulls are a separate
  type and stand their ground.
- **Metal bear trap**: moved from Field Defenses to Iron Tools in `recipe_node_requirements`.
- Snowshoes were already craftable from wood under Weaving, so nothing changed for them.
