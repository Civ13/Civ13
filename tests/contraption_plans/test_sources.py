"""Offline checks for the contraption sheet/runtime contract."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(name):
    return (ROOT / name).read_text(encoding='utf-8')


PLAN = read('code/modules/1713/contraption_plan.dm')
UI = read('code/modules/1713/contraption_designer.dm')
MECHANISMS = read('code/modules/1713/mechanisms.dm')
WINCH = read('code/modules/1713/siege/siege_engines.dm')


class ContraptionPlanSources(unittest.TestCase):
    def test_range_limits_follow_actual_mechanisms(self):
        def literal(source, name):
            return int(re.search(r'(?m)^#define ' + name + r' (\d+)', source)[1])
        self.assertEqual(literal(PLAN, 'CONTRAPTION_CORD_REACH'),
                         literal(MECHANISMS, 'MECHANISM_LINK_RANGE'))
        self.assertEqual(literal(PLAN, 'CONTRAPTION_TRIGGER_CORDS'),
                         literal(MECHANISMS, 'MECHANISM_MAX_LINKS'))
        reach = literal(PLAN, 'CONTRAPTION_WINCH_REACH')
        self.assertRegex(WINCH, r'castle_winch/proc/gates\(\)[\s\S]+castle_gate/G in range\(' + str(reach) + ', src')

    def test_sheet_and_design_report_are_wired(self):
        dme = read('civ13.dme')
        for source in ('code/__defines/contraption_plans.dm', 'code/modules/1713/contraption_plan.dm',
                       'code/modules/1713/contraption_designer.dm'):
            self.assertIn('#include "' + source.replace('/', '\\') + '"', dme)
        self.assertIn('"MECH" = list(', read('code/modules/naval/draught_kinds.dm'))
        self.assertIn('open_contraption_designer(H)', read('code/modules/naval/ship_draught.dm'))
        self.assertIn('design_report("contraption_plan", src)', PLAN)
        self.assertIn('design_part_help_for("contraption_plan")', UI)

    def test_forecast_changes_no_world_and_only_save_writes_paper(self):
        model = PLAN.split('/obj/item/ship_draught', 1)[0]
        self.assertNotRegex(model, r'\b(mechanism_actuate|mechanism_pull_links|get_turf|locate|playsound|addtimer)\(')
        self.assertNotRegex(UI, r'\b(mechanism_actuate|mechanism_pull_links|playsound|do_after|addtimer)\(')
        self.assertNotIn('<script', UI.lower())
        self.assertIn('html_encode(plan.name)', UI)
        self.assertIn('html_encode(status)', UI)
        topic = UI.split('/Topic(', 1)[1].split('/proc/work_cell', 1)[0]
        self.assertEqual(topic.count('sheet.take_contraption(plan)'), 1)
        self.assertLess(topic.index('!can_edit(H)'), topic.index('sheet.take_contraption(plan)'))
        self.assertIn('sheet.draught_code == paper_code', UI)
        self.assertIn('persistence_admission_changed(admission)', UI)
        self.assertIn('|| importing ||', topic)
        kinds = read('code/modules/naval/draught_kinds.dm')
        # The editor's can_edit() runs again, through the recheck callback, after the prompt.
        self.assertIn('draught_import_in_window(H, CONTRAPTION_WINDOW, CALLBACK(src, PROC_REF(can_edit), H))', UI)
        self.assertLess(kinds.index('design_code_ask(H,'),
                        kinds.index('(recheck && !recheck.Invoke())'))
        self.assertLess(kinds.index('(recheck && !recheck.Invoke())'),
                        kinds.index('call(src, K["take"])(D)'))

    def test_native_probe_has_bounded_negative_controls(self):
        probe = read('tests/mechanisms/probe.dm')
        for label in ('contraption_bad_coordinate', 'contraption_wrong_target', 'contraption_fifth_cord',
                      'contraption_eighth_tile', 'contraption_round_trip', 'contraption_forecast_inert'):
            self.assertIn(f'"{label}"', probe)


if __name__ == '__main__':
    unittest.main()
