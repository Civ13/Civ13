"""Source checks for razor grooming and the razor's crafting route; no native world."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
KITCHEN = ROOT / 'code/game/objects/items/weapons/material/kitchen.dm'
WINDOW = ROOT / 'code/game/objects/items/weapons/material/haircut_window.dm'
ICONS = ROOT / 'code/game/mob/living/carbon/human/update_icons.dm'
GLOBAL = ROOT / 'config/crafting/material_recipes_global.txt'
RESEARCH = ROOT / 'code/modules/research_tree/research_node.dm'
RAZOR = '/obj/item/weapon/material/kitchen/utensil/knife/razorblade'


def proc_body(source, header):
    start = source.index(header)
    lines = source[start:].splitlines()[1:]
    body = []
    for line in lines:
        if line and not line[0].isspace():
            break
        body.append(line)
    return '\n'.join(body)


class RazorGrooming(unittest.TestCase):
    def setUp(self):
        self.source = KITCHEN.read_text(encoding='utf-8-sig')

    def test_any_non_harm_intent_on_head_or_face_grooms(self):
        attack = proc_body(self.source, RAZOR + '/attack(')
        guard = attack.splitlines()[0]
        self.assertIn('user.a_intent != I_HARM', guard)
        self.assertNotIn('I_DISARM', guard)
        for zone in ('"head"', '"eyes"', '"mouth"'):
            self.assertIn(zone, guard)
        self.assertIn('groom(M, user)', attack)

    def test_cut_checks_eligibility_again_after_the_wait(self):
        cut = proc_body(self.source, RAZOR + '/proc/groom_cut(')
        self.assertNotIn('WWinput(', cut)
        self.assertNotIn('usr', re.sub(r'"[^"]*"', '', cut))
        wait = cut.index('if (!do_after(user, 80, M)')
        check = cut.index('new_hstyle in grooming_hair_choices(M)')
        commit = cut.index('M.h_style = new_hstyle')
        self.assertTrue(wait < check < commit)
        self.assertNotIn('M.h_style =', cut[:wait])
        self.assertNotIn('M.f_style =', cut[:wait])
        self.assertIn('!grooming_valid(M, user) || M.h_style != old_hstyle || M.f_style != old_fstyle', cut[wait:commit])
        self.assertIn('new_fstyle in grooming_beard_choices(M)', cut[wait:commit])
        self.assertIn('generate_valid_hairstyles(TRUE, TRUE)', proc_body(self.source, RAZOR + '/proc/grooming_hair_choices('))
        self.assertIn('M.gender == MALE ? M.generate_valid_facial_hairstyles(TRUE)', proc_body(self.source, RAZOR + '/proc/grooming_beard_choices('))

    def test_connected_players_get_the_window_for_any_target(self):
        groom = proc_body(self.source, RAZOR + '/proc/groom(')
        self.assertIn('if (!C)\n\t\treturn groom_classic(M, user)', groom)
        self.assertNotIn('M != user', groom)
        self.assertLess(groom.index('grooming_valid(M, user)'), groom.index('P = new(user, M, src)'))
        self.assertIn('if (P.cutting)\n\t\t\treturn', groom)
        self.assertIn('P.ui_interact(user)', groom)
        classic = proc_body(self.source, RAZOR + '/proc/groom_classic(')
        hair = classic.index('if (new_hstyle && (new_hstyle in hairlist))')
        beard = classic.index('if (new_fstyle && (new_fstyle in fhairlist))')
        self.assertNotIn('return', classic[hair:beard])

    def test_window_draws_without_touching_the_character(self):
        window = WINDOW.read_text(encoding='utf-8-sig')
        body = proc_body(ICONS.read_text(encoding='utf-8-sig'), '/mob/living/human/proc/grooming_body_sheet(')
        self.assertIn('layer < HAIR_LAYER', body)
        self.assertNotIn('HEAD_LAYER', body)
        self.assertNotIn('FACEMASK_LAYER', body)
        for source in (window, body):
            self.assertNotRegex(source, r'(?m)^\s*(?:subject\.|M\.|src\.)?[hf]_(?:style|growth)\s*=[^=]')
            self.assertNotIn('update_hair()', source)
            self.assertNotIn('update_body()', source)
        data = proc_body(window, '/datum/grooming_preview/proc/window_data(')
        self.assertIn('razor.grooming_hair_choices(subject)', data)
        self.assertIn('razor.grooming_beard_choices(subject)', data)
        # One shared sheet and one figure per opening, not a file per style.
        self.assertEqual(window.count('browse_rsc('), 2)
        self.assertIn('if (grooming_sheet_icon)\n\t\treturn grooming_sheet_icon', proc_body(window, '/proc/grooming_sheet('))
        self.assertNotIn('deadline', window)
        self.assertNotIn('sleep(', window)

    def test_only_the_holder_can_act_and_only_on_eligible_styles(self):
        window = WINDOW.read_text(encoding='utf-8-sig')
        act = proc_body(window, '/datum/grooming_preview/ui_act(')
        start = act.index('cutting = TRUE')
        for gate in ('user != viewer || cutting || !valid()', '!istext(new_hair) || !istext(new_beard)',
                     'new_hair in razor.grooming_hair_choices(subject)', 'new_beard in razor.grooming_beard_choices(subject)',
                     'new_hair == subject.h_style && new_beard == subject.f_style'):
            self.assertLess(act.index(gate), start)
        self.assertLess(start, act.index('razor.groom_cut(subject, viewer, new_hair, new_beard)'))
        self.assertIn('return list("cut", "cancel")', window)
        self.assertIn('return action == "cut" ? list("beard") : null', window)
        valid = proc_body(window, '/datum/grooming_preview/proc/valid(')
        self.assertIn('viewer_client.mob == viewer', valid)
        self.assertIn('viewer_client.grooming_preview == src', valid)
        self.assertIn('razor.grooming_valid(subject, viewer)', valid)
        state = proc_body(window, '/datum/topic_state/grooming/can_use_topic(')
        self.assertIn('user != P.viewer || P.cutting || !P.valid()', state)
        self.assertIn('/datum/topic_state/grooming)', proc_body(window, '/datum/grooming_preview/ui_interact('))


class RazorCrafting(unittest.TestCase):
    def test_global_crafting_has_hygiene_gated_razors(self):
        rows = [line[len('RECIPE: '):].split(',') for line in GLOBAL.read_text(encoding='utf-8-sig').splitlines()
                if line.startswith('RECIPE: ') and '//' not in line]
        razors = [row for row in rows if len(row) > 2 and row[2] == RAZOR]
        self.assertTrue(razors, 'no global crafting recipe makes a razor blade')
        materials = set()
        for row in razors:
            self.assertEqual(len(row), 13)
            self.assertEqual(row[7], 'hygiene')
            self.assertEqual(row[12], row[0].split('/')[2])
            materials.add(row[12])
        self.assertIn('copper', materials)

    def test_razor_maps_to_a_root_hygiene_node(self):
        research = RESEARCH.read_text(encoding='utf-8-sig')
        self.assertIn('"%s" = "hygiene"' % RAZOR, research)
        self.assertRegex(research, r'new /datum/research_node\("hygiene", "Hygiene", "Health", \d+, 0, RESEARCH_MODE_ANALYSIS, null,')


if __name__ == '__main__':
    unittest.main()
