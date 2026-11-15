# Admin-only Crafting Atlas section

`code/game/mob/crafting_atlas_admin.dm` lists types staff deliberately leave
out of the public atlas. The game builds their entries at runtime and sends them
only to readers with admin rights. `scripts/atlas/admin_only.py` makes the atlas
build fail if a listed type, or a subtype of one, reaches `UI/crafting-atlas.json`
or the published web atlas data.

```sh
python3 -m unittest tests/atlas_admin_only/test_admin_only.py
```

Source contracts only: no compiler or DM runtime. The window itself is covered
by `tgui/src/interfaces/CraftingAtlas.test.tsx`.
