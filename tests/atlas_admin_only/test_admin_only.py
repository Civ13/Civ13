"""Admin-only atlas section: listed types stay out of every public atlas output.

Source contracts only; no compiler or DM runtime is started.
"""
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))

from atlas.admin_only import SOURCE, admin_only_types, check_public, covers, leaks, without_mentions  # noqa: E402


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


class AdminOnlyAtlasTests(unittest.TestCase):
    def setUp(self):
        self.hidden = admin_only_types({SOURCE: read(SOURCE)})

    def test_list_is_deliberate_and_noted(self):
        self.assertIn('/obj/item/weapon/book/divine', self.hidden)
        for path, note in self.hidden.items():
            self.assertTrue(note.strip(), path + ' needs a staff note')
        self.assertIn('#include "code\\game\\mob\\crafting_atlas_admin.dm"', read('civ13.dme'))

    def test_shipped_game_atlas_mentions_no_listed_type(self):
        text = read('UI/crafting-atlas.json')
        self.assertEqual(leaks(self.hidden, text), [])
        catalog = json.loads(text)
        for key, entry in catalog['resources'].items():
            self.assertFalse(covers(self.hidden, key) or covers(self.hidden, entry.get('type') or ''), key)

    def test_leak_check_covers_subtypes_but_not_name_prefixes(self):
        hidden = {'/obj/item/weapon/book/divine': 'note'}
        self.assertEqual(leaks(hidden, '"/obj/item/weapon/book/divine/copy"'), ['/obj/item/weapon/book/divine'])
        self.assertEqual(leaks(hidden, '"/obj/item/weapon/book/divine"'), ['/obj/item/weapon/book/divine'])
        self.assertEqual(leaks(hidden, '"/obj/item/weapon/book/divinely_bound"'), [])
        with self.assertRaises(SystemExit):
            check_public(hidden, '{"id":"/obj/item/weapon/book/divine"}', 'a test output')

    def test_spawn_sites_of_listed_types_leave_the_public_site_index(self):
        hidden = {'/obj/item/cursedtreasure': 'note'}
        rows = [dict(text='var/obj/item/cursedtreasure/T = new/obj/item/cursedtreasure(loc)'),
                dict(text='new/obj/item/cursedtreasure_map(loc)'), dict(text='new/obj/item/stack/money(loc)')]
        self.assertEqual(without_mentions(hidden, rows, 'text'), rows[1:])
        text = read('scripts/build-crafting-atlas.py')
        self.assertLess(text.index("data['production_sites']=without_mentions(admin_only,data['production_sites'],'text')"),
                        text.index("check_public(admin_only,json.dumps(data),'the published web atlas')"))

    def test_unreadable_or_missing_list_fails_the_build(self):
        with self.assertRaises(SystemExit):
            admin_only_types({})
        with self.assertRaises(SystemExit):
            admin_only_types({SOURCE: 'var/global/list/crafting_atlas_admin_only = list(\n\t/obj/item/x)\n'})

    def test_builder_checks_both_public_outputs_before_writing(self):
        text = read('scripts/build-crafting-atlas.py')
        self.assertIn("if not covers(admin_only,k)", text)
        for where in ("'the game atlas'", "'the published web atlas'"):
            self.assertIn(where, text)
        # Each check runs before the file it guards is written.
        self.assertLess(text.index("check_public(admin_only,game_text,'the game atlas')\n    if options.game_catalog:"),
                        text.index('Generated '))
        self.assertLess(text.index("check_public(admin_only,json.dumps(data),'the published web atlas')"),
                        text.index("(OUT/'crafting-data.json').write_text"))

    def test_game_shows_the_section_to_admins_only(self):
        admin = read(SOURCE)
        self.assertRegex(admin, r'/proc/crafting_atlas_admin_reader\(mob/viewer\)\n\treturn viewer && viewer\.client && check_rights\(R_ADMIN, FALSE, viewer\)')
        self.assertRegex(admin, r'crafting_atlas_admin_type\(mob/viewer, resource_id\)\n\tif \(!istext\(resource_id\) \|\| !crafting_atlas_admin_reader\(viewer\)\)\n\t\treturn null')
        self.assertIn('if (!crafting_atlas_admin_reader(viewer))\n\t\treturn rows', admin)
        tgui = read('code/game/mob/crafting_atlas_tgui.dm')
        self.assertIn('if (crafting_atlas_admin_reader(viewer))\n\t\tdata["admin_entries"] = admin_entries(reference, viewer, words)', tgui)
        self.assertIn('reference.resource_exists(resource_id) || crafting_atlas_admin_type(viewer, resource_id)', tgui)
        self.assertIn('if (admin_type)\n\t\t\treturn admin_resource_model(viewer, data, admin_type)', tgui)
        # The legacy HTML renderer and plain Topic links never admit listed types.
        legacy = read('code/game/mob/crafting_atlas.dm')
        self.assertNotIn('admin', legacy.lower())


if __name__ == '__main__':
    unittest.main()
