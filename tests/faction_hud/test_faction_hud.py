"""Faction HUD icons are chosen per map, not in human Life code.

code/_helpers/faction_hud.dm picks a player's faction icon: job rules first,
then the map (its `faction_hud_icons` list or faction_hud_icon() override),
then the faction's era default. The icons each map lists are frozen here so a
move or typo shows up, and human_life.dm may not grow map checks again.
"""
from pathlib import Path
import importlib.util
from itertools import product
from types import SimpleNamespace
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
MAPS = ROOT / 'code/game/objects/map_metadata'
LIFE = ROOT / 'code/game/mob/living/carbon/human/human_life.dm'
HELPER = ROOT / 'code/_helpers/faction_hud.dm'
LISTED = re.compile(r'^/obj/map_metadata/([\w/]+)/faction_hud_icons = list\((.*)\)$', re.M)
FROZEN = {
    'twotribes': {'BRITISH': 'civ1', 'FRENCH': 'civ3'},
    'east_los_santos': {'INDIANS': 'ballas', 'AMERICAN': 'civ2'},
    'arab_town': {'ARAB': 'hez_basic', 'AMERICAN': 'idf_basic'},
    'whiterun': {'ROMAN': 'empire', 'CIVILIAN': 'stormcloak'},
    'clash': {'NORWEGIAN': 'ger0_basic', 'DANISH': 'barbarian_basic'},
    'yeltsin': {'RUSSIAN': 'ru_basic', 'CIVILIAN': 'sov_basic'},
    'grozny': {'RUSSIAN': 'ru_basic'},
    'operation_falcon': {'RUSSIAN': 'ru_basic'},
    'vadso_city': {'RUSSIAN': 'ru_basic'},
    'landing_at_constantinopoli': {'RUSSIAN': 'ru_basic'},
    'tantiveiv': {'AMERICAN': 'imp_basic', 'CIVILIAN': 'rebel_basic'},
    'retreat': {'CHINESE': 'sov_basic'},
    'capitol_hill': {'CIVILIAN': 'civ1'},
    'tadojsville': {'CIVILIAN': 'un'},
    'tsaritsyn': {'CIVILIAN': 'sov_basic'},
    'long_march': {'CIVILIAN': 'sov_basic'},
    'eft_factory': {'RUSSIAN': 'none', 'AMERICAN': 'none', 'CIVILIAN': 'none'},
    'bank_robbery': {'RUSSIAN': 'robbers'},
    'drug_bust': {'RUSSIAN': 'rednikov'},
}
OVERRIDES = ('african_warlords', 'syria', 'nationsrp/coldwar', 'wizard_boy', 'gulag13', 'bank_robbery', 'drug_bust')
LIFE_ICON_CEILING = 4  # the Occupation civilian blanks


class FactionHudTest(unittest.TestCase):
    def test_map_icon_lists_are_frozen(self):
        found = {}
        for path in MAPS.rglob('*.dm'):
            for m in LISTED.finditer(path.read_text(encoding='utf-8', errors='replace')):
                found[m.group(1)] = dict(re.findall(r'(\w+) = "([^"]*)"', m.group(2)))
        self.assertEqual(found, FROZEN)

    def test_conditional_maps_override_the_proc(self):
        text = '\n'.join(p.read_text(encoding='utf-8', errors='replace') for p in MAPS.rglob('*.dm'))
        for path in OVERRIDES:
            self.assertIn(f'/obj/map_metadata/{path}/faction_hud_icon(mob/living/human/H, faction_flag)', text)

    def test_map_decides_before_the_era_default(self):
        text = HELPER.read_text(encoding='utf-8')
        body = text[text.index('/proc/faction_hud_icon_state('):text.index('/proc/default_faction_hud_icon(')]
        self.assertLess(body.index('map.faction_hud_icon(H, faction_flag)'), body.index('default_faction_hud_icon(H, faction_flag)'))
        default = text[text.index('/proc/default_faction_hud_icon('):]
        self.assertNotIn('map.ID', default)
        self.assertNotIn('istype(map', default)

    def test_life_code_has_no_per_map_icons(self):
        text = LIFE.read_text(encoding='utf-8')
        start = text.index('/mob/living/human/proc/handle_hud_list()')
        body = text[start:text.index('\n/mob/', start + 1)]
        self.assertIn('var/faction_icon = faction_hud_icon_state(src)', body)
        self.assertIn('map.add_faction_hud_overlays(src, holder2)', body)
        self.assertLessEqual(body.count('holder2.icon_state = "'), LIFE_ICON_CEILING)



class FactionHudViewerChecks(unittest.TestCase):
    def test_admission_and_faction_decisions_match_original(self):
        spec = importlib.util.spec_from_file_location('hud_adapter', ROOT / 'tests/save_movement/source_adapter.py')
        adapter = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(adapter)
        source = (ROOT / 'code/game/mob/living/carbon/human/human_hud.dm').read_text(encoding='utf-8')
        proc = source[source.index('/proc/process_faction_hud('):source.index('/datum/arranged_hud_process')]
        self.assertIn('\tif (!ishuman(M))\n\t\treturn', proc)
        start = proc.index('\t\tvar/shared_job_check = FALSE')
        end = proc.index('\t\tif(!map.nomads)', start)
        current = proc[start:end]
        # Frozen reviewed base; keep the production decision and old guard comparable.
        original = '\t\tvar/shared_job_check = FALSE\n\n\t\tif (viewer == perp)\n\t\t\tshared_job_check = TRUE\n\t\telse if (viewer.original_job.base_type_flag() == perp.original_job.base_type_flag())\n\t\t\tshared_job_check = TRUE\n\t\tif (ishuman(M))\n\t\t\tif (M.original_job_title != perp.original_job_title && map.civilizations == TRUE)\n\t\t\t\tshared_job_check = FALSE\n\t\t\telse if (M.original_job_title == perp.original_job_title && map.civilizations == TRUE && perp.original_job_title != "Nomad")\n\t\t\t\tshared_job_check = TRUE\n\t\t\tif ((perp.original_job_title == "Nomad" && viewer.civilization == perp.civilization) && perp.civilization != "none")\n\t\t\t\tshared_job_check = TRUE\n'
        guard = original.index('\t\tif (ishuman(M))\n')
        expected = (original[:guard] + ''.join(line[1:] if line.startswith('\t\t\t') else line
                    for line in original[guard:].splitlines(keepends=True)[1:]))
        self.assertEqual(current, expected)
        self.assertNotIn('ishuman(M)', current)

        def project(fragment):
            program = ('/check()\n\tif (!ishuman(M))\n\t\treturn\n'
                       '\tfor (var/mob/living/human/perp in people)\n' + fragment +
                       '\t\tobserve(shared_job_check)\n')
            return adapter.project(program, '/check', 'M, viewer, people, map, ishuman, typed_iter, observe',
                                   {'TRUE': True, 'FALSE': False})

        before, after = project(original), project(current)
        mutant = project(current.replace('M.original_job_title != perp.original_job_title',
                                         'M.original_job_title == perp.original_job_title', 1))

        class Job:
            def __init__(self, flag):
                self.flag = flag
            def base_type_flag(self):
                return self.flag

        changed = False
        for civilization_map, viewer_title, other_title, same_flag, same_civ, viewer_is_human in product(
                (False, True), ('Soldier', 'Nomad'), ('Soldier', 'Nomad'),
                (False, True), (False, True), (False, True)):
            viewer = SimpleNamespace(original_job_title=viewer_title, civilization='A', original_job=Job('A'))
            other = SimpleNamespace(original_job_title=other_title, civilization='A' if same_civ else 'B',
                                    original_job=Job('A' if same_flag else 'B'))
            people = [viewer, other, other]
            map_value = SimpleNamespace(civilizations=civilization_map)
            def run(fn):
                calls, results = [], []
                def ishuman(value):
                    calls.append(value)
                    return viewer_is_human
                def typed_iter(values, kind):
                    self.assertEqual(kind, '/mob/living/human')
                    return iter(values)
                fn(viewer, viewer, people, map_value, ishuman, typed_iter, results.append)
                return results, len(calls)
            old_values, old_calls = run(before)
            new_values, new_calls = run(after)
            self.assertEqual(new_values, old_values)
            self.assertEqual(new_calls, 1)
            self.assertEqual(old_calls, 4 if viewer_is_human else 1)
            changed |= run(mutant)[0] != new_values
        self.assertTrue(changed, 'title comparison mutation must change a decision')


if __name__ == '__main__':
    unittest.main()
