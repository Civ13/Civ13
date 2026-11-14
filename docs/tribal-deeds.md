# Tribal deeds

Code: `code/modules/1713/tribal_deeds.dm`. Tests: `python3 tests/tribal_deeds/test_source.py`;
native probe `python3 tests/ecology_spawning/run_linux.py . tests/tribal_deeds/probe.dm`.

Great deeds a tribesman does wait to be carved into one of their tribe's wooden totem poles
(`/obj/structure/religious/totem_pole`, crafted from wood under Ritual Worship).

- `record_deed(H, kind, text)` remembers a deed on the character in `pending_deeds` and tells
  them to carve it. It needs a tribe (`civilization` other than `"none"`), and each kind is
  remembered once: never again once carved (`carved_deeds`).
- Using a knife (`TOOL_KNIFE`) on a pole carves every waiting deed (6 s). The first tribe to
  carve a pole owns it; other tribes are refused. A pole holds `DEED_POLE_CAP` (40) deeds; when
  full, the rest keep waiting for another pole.
- Each carved deed is stored on the pole as `"text|name|date"` (pipes in the text or name are
  replaced with `/`), and examining the pole lists them.

Deeds recorded today (hooked by overrides at the bottom of the file, so the original files are
untouched):

- Bringing down a big beast (`mob_size >= MOB_LARGE` or hostile, at least 100 max health), once
  per animal type. Hidden NPCs are excluded.
- Hollowing out a dugout canoe.
- Taming a wild animal, once per herd kind (cow, goat, sheep, pig).
- Finishing a rock painting.

Persistence: both lists on the character and the pole's `tribe` and `deeds` save as plain text
and need no `after_load`.
