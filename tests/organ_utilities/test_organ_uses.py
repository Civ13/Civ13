"""Offline source-contract checks for issue 5126 phases 2-4; not native DM or real-client acceptance."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
USES = 'code/modules/organs/organ_uses.dm'


def read(path):
    return (ROOT / path).read_text()


def proc_body(source, anchor):
    start = source.index(anchor)
    rest = source[start + len(anchor):]
    match = re.search(r'\n(?=[/#])', rest)
    return rest[:match.start()] if match else rest


def audit_preserve(source):
    body = proc_body(source, '/obj/structure/table/wood/anatomy/proc/preserve_specimen(')
    wait = body.index('do_after(user, SPECIMEN_PREP_TIME, src)')
    after = body[wait:]
    required = [
        'user.get_active_hand() != organ_item || user.get_inactive_hand() != J',
        'specimen_organ_kind(organ_item) != kind || specimen_organ_problem(organ_item)',
        'specimen_fluid_amount(J) < SPECIMEN_FLUID',
        'persistence_save_in_progress || persistence_active_operation',
        'qdel(organ_item)\n\tqdel(J)\n\tvar/obj/item/organ_specimen/S = new',
        'log_game(',
    ]
    for guard in required:
        if guard not in after:
            raise AssertionError('Missing post-wait contract: ' + guard)
    if len(re.findall(r'\bnew\b', body)) != 1:
        raise AssertionError('Specimen output is not exactly once')
    if 'spawn(' in body or 'sleep(' in body:
        raise AssertionError('Unexpected asynchronous window')
    return required


class OrganUses(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.uses = read(USES)

    def test_preservation_pays_inputs_once_after_rechecks(self):
        audit_preserve(self.uses)

    def test_each_removed_guard_is_detected(self):
        for guard in audit_preserve(self.uses):
            with self.subTest(guard=guard), self.assertRaises(AssertionError):
                audit_preserve(self.uses.replace(guard, '// omitted'))

    def test_duplicate_output_is_detected(self):
        out = 'var/obj/item/organ_specimen/S = new(get_turf(src))'
        with self.assertRaises(AssertionError):
            audit_preserve(self.uses.replace(out, out + '\n\tnew /obj/item/organ_specimen(get_turf(src))'))

    def test_no_brain_or_limb_specimens_from_people(self):
        kind = proc_body(self.uses, '/proc/specimen_organ_kind(')
        self.assertIn('istype(I, /obj/item/organ/external) || istype(I, /obj/item/organ/brain)', kind)
        human = re.search(r'specimen_human_organs = list\(([^)]*)\)', self.uses).group(1)
        self.assertNotIn('brain', human)

    def test_specimen_is_neither_food_nor_organ(self):
        self.assertIn('\n/obj/item/organ_specimen\n', self.uses)
        self.assertNotIn('/obj/item/organ_specimen\n\tparent_type', self.uses)

    def test_finds_are_finite_and_checked_after_the_wait(self):
        finds = read('code/modules/research_tree/naturalist_finds.dm')
        self.assertIn('return S.studyable() ? "medicine" : null', finds)
        self.assertIn('kind = S.find_kind()', finds)
        record = finds[finds.index('/mob/living/human/proc/record_a_find('):]
        recheck = record.index('!find_discipline(thing)')
        commit = record.index('commit_find(src, carrier, kind, discipline, thing_name, node_id)')
        use = record.index('S.use_study()')
        self.assertLess(recheck, commit)
        self.assertLess(commit, use)
        self.assertIn('if (studies_left <= 0 || !organ_kind || !isturf(loc))', self.uses)

    def test_human_and_animal_kinds_share_one_find(self):
        self.assertIn('return "specimen:[organ_kind]"', self.uses)

    def test_cold_and_seal_never_repair(self):
        self.assertIn('return max(0, base * spoil_rate() * (is_sealed() ? 0.25 : 1))', self.uses)
        organ = read('code/modules/organs/organ.dm')
        self.assertIn('germ_level += spoil_germs(rand(2,6))', organ)
        self.assertIn('damage += rand(1,3) * spoil_rate()', organ)
        for rate in re.findall(r'\? (0\.\d+) : (0\.\d+)', proc_body(self.uses, '/obj/item/organ/proc/spoil_rate(')):
            for value in rate:
                self.assertGreater(float(value), 0)
                self.assertLess(float(value), 1)

    def test_power_loss_weakens_fridge(self):
        rate = proc_body(self.uses, '/obj/item/organ/proc/spoil_rate(')
        self.assertIn('F.refrigeration_powered() ? 0.1 : 0.4', rate)
        self.assertIn('depth <= 4', rate)

    def test_reload_resumes_only_loose_organs(self):
        body = proc_body(self.uses, '/obj/item/organ/after_load(')
        self.assertIn('if (!(status & ORGAN_DEAD) && !owner)', body)

    def test_transplant_slot_race_guard(self):
        surgery = read('code/modules/surgery/organs_internal.dm')
        end = surgery[surgery.index('/datum/surgery_step/internal/replace_organ'):]
        end = end[end.index('end_step('):]
        guard = end.index('target.internal_organs_by_name[O.organ_tag] || O.loc != user')
        self.assertLess(guard, end.index('O.replaced(target,affected)'))

    def test_catgut_is_a_surgical_tool(self):
        self.assertIn('"/obj/item/stack/catgut",70', read('code/modules/surgery/generic.dm'))
        self.assertIn('"/obj/item/stack/catgut",80', read('code/modules/surgery/other.dm'))
        body = proc_body(self.uses, '/obj/item/stack/sausagecasing/attack_self(')
        self.assertLess(body.index('use(1)'), body.index('new(get_turf(user), 2, FALSE)'))

    def test_recipes_and_research_gates(self):
        recipes = read('config/crafting/material_recipes_global.txt')
        self.assertIn(',anatomy table,/obj/structure/table/wood/anatomy,', recipes)
        self.assertIn(',organ box,/obj/item/weapon/storage/organ_box,', recipes)
        nodes = read('code/modules/research_tree/research_node.dm')
        self.assertIn('"/obj/structure/table/wood/anatomy" = "herbalism"', nodes)
        self.assertIn('"/obj/item/weapon/storage/organ_box" = "field_surgery"', nodes)
        self.assertIn('#include "code\\modules\\organs\\organ_uses.dm"', read('civ13.dme'))


if __name__ == '__main__':
    unittest.main()
