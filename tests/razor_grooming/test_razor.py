"""Source checks for razor grooming and the razor's crafting route; no native world."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
KITCHEN = ROOT / 'code/game/objects/items/weapons/material/kitchen.dm'
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

    def test_grooming_checks_eligibility_again_after_the_cut_wait(self):
        select = proc_body(self.source, RAZOR + '/proc/groom_select(')
        self.assertIn('else if (hair_choice in hairlist)', select)
        self.assertIn('if (beard_choice in fhairlist)', select)
        self.assertIn('WWinput_list_or_null(hair_choices)', select)
        self.assertIn('WWinput_list_or_null(beard_choices)', select)
        self.assertNotIn('usr', re.sub(r'"[^"]*"', '', select))
        apply = select.index('if (choice != "apply")')
        wait = select.index('if (!do_after(user, 80, M)')
        check = select.index('new_hstyle in M.generate_valid_hairstyles(TRUE, TRUE)')
        commit = select.index('M.h_style = new_hstyle')
        self.assertTrue(apply < wait < check < commit)
        self.assertNotIn('M.h_style =', select[:wait])
        self.assertNotIn('M.f_style =', select[:wait])
        self.assertIn('M.h_style != old_hstyle || M.f_style != old_fstyle', select[wait:commit])
        self.assertIn('new_fstyle in M.generate_valid_facial_hairstyles(TRUE)', select[wait:commit])

    def test_only_self_grooming_gets_a_bare_head_preview(self):
        groom = proc_body(self.source, RAZOR + '/proc/groom(')
        self.assertIn('if (M != user || !C)\n\t\treturn groom_classic(M, user)', groom)
        self.assertLess(groom.index('return groom_classic'), groom.index('P = new()'))
        classic = proc_body(self.source, RAZOR + '/proc/groom_classic(')
        hair = classic.index('if (new_hstyle && (new_hstyle in hairlist))')
        beard = classic.index('if (new_fstyle && (new_fstyle in fhairlist))')
        self.assertNotIn('return', classic[hair:beard])
        self.assertLess(classic.index('M.h_style = new_hstyle'), beard)
        self.assertNotIn('P.ask', classic)
        select = proc_body(self.source, RAZOR + '/proc/groom_select(')
        self.assertIn('Keep current hair', select)
        self.assertIn('Keep current facial hair', select)
        self.assertIn('if (hair_choice == keep_hair)\n\t\t\tnew_hstyle = old_hstyle', select)
        self.assertIn('else if (beard_choice != keep_beard)\n\t\t\t\t\treturn', select)

    def test_preview_does_not_change_character_and_keeps_face_colors(self):
        draw = proc_body(self.source, '/mob/living/human/proc/grooming_portrait(')
        for component in ('species.icobase', 'body_build.index', 'r_skin, g_skin, b_skin',
                          'r_eyes, g_eyes, b_eyes', 'r_hair, g_hair, b_hair',
                          'r_facial, g_facial, b_facial'):
            self.assertIn(component, draw)
        self.assertIn('F.do_colouration', draw)
        self.assertIn('H.do_colouration', draw)
        self.assertLess(draw.index('portrait.Blend(facial'), draw.index('portrait.Blend(scalp'))
        self.assertNotRegex(draw, r'(?m)^\s*[hf]_(?:style|growth)\s*=')
        self.assertNotIn('update_hair()', draw)

    def test_only_current_viewer_and_round_can_apply_retry_or_close(self):
        topic = proc_body(self.source, '/datum/grooming_preview/Topic(')
        self.assertLess(topic.index('usr != viewer || !valid()'), topic.index('answer = action'))
        self.assertLess(topic.index('text2num(href_list["round"]) != round_id'),
                        topic.index('answer = action'))
        self.assertIn('if (href_list["close"])\n\t\twaiting = FALSE\n\t\treturn', topic)
        self.assertIn('action != "apply" && action != "retry" && action != "cancel"', topic)
        ask = proc_body(self.source, '/datum/grooming_preview/proc/ask(')
        self.assertIn('answer = null', ask)
        self.assertIn('world.time < deadline && valid()', ask)
        self.assertIn('viewer_client << browse_rsc(I, file)', ask)
        self.assertIn('for (var/side in list(SOUTH, EAST))', ask)
        self.assertIn('Current</th><th>Proposed', ask)
        valid = proc_body(self.source, '/datum/grooming_preview/proc/valid(')
        self.assertIn('viewer_client.mob == viewer', valid)
        self.assertIn('viewer_client.grooming_preview == src', valid)
        self.assertIn('razor.grooming_valid(subject, viewer)', valid)


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
