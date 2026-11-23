"""Offline harbor planner contracts; no native UI or gameplay acceptance."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
PLAN = ROOT / 'code/modules/naval/harbor_planner.dm'
SOURCE = PLAN.read_text(encoding='utf-8')


def body(header, source=SOURCE):
    return source.split(header, 1)[1].split('\n/', 1)[0]


def project_offsets(source=SOURCE):
    """Evaluate the exact four coordinate expressions in both DM switches."""
    code = body('/datum/harbor_plan/proc/tile(u, v = 0)', source)
    lines = re.findall(
        r'if \((NORTH|EAST|SOUTH|WEST)\) return locate\(site\.x ([+\-]) ([uv]), '
        r'site\.y ([+\-]) ([uv]), site\.z\)', code
    )
    if len(lines) != 8:
        raise AssertionError('Expected exactly four boathouse and four standard offsets')
    return lines[:4], lines[4:]


def cell(rows, heading, u, v):
    variables = {'u': u, 'v': v}
    dx, x, dy, y = next(row[1:] for row in rows if row[0] == heading)
    return ((-1 if dx == '-' else 1) * variables[x],
            (-1 if dy == '-' else 1) * variables[y])


class HarborPlannerTest(unittest.TestCase):
    def test_standard_rectangles_align_bow_and_cover_a_unique_envelope(self):
        _, normal = project_offsets()
        for heading, forward in {'NORTH': (0, 1), 'EAST': (1, 0),
                                 'SOUTH': (0, -1), 'WEST': (-1, 0)}.items():
            with self.subTest(heading=heading):
                self.assertEqual(cell(normal, heading, 1, 0), forward)
                self.assertEqual({cell(normal, heading, 1, v) for v in (-1, 0, 1)},
                                 {(forward[0] + i * forward[1], forward[1] - i * forward[0])
                                  for i in (-1, 0, 1)})
                self.assertEqual(len({cell(normal, heading, u, v)
                                      for u in range(1, 15) for v in range(-2, 3)}), 70)

    def test_boathouse_uses_real_corner_not_centered_vessel_strip(self):
        corner, _ = project_offsets()
        self.assertIn('v += 4', body('/datum/harbor_plan/proc/tile(u, v = 0)'))
        for heading, signs in {'NORTH': (1, 1), 'EAST': (1, -1),
                               'SOUTH': (-1, -1), 'WEST': (-1, 1)}.items():
            with self.subTest(heading=heading):
                self.assertEqual({cell(corner, heading, u, v) for u in range(1, 8)
                                  for v in range(1, 8)},
                                 {(i * signs[0], j * signs[1]) for i in range(1, 8)
                                  for j in range(1, 8)})
        # A swapped sign produces the wrong physical slip, not a valid projection.
        broken = SOURCE.replace('site.x + v, site.y + u', 'site.x - v, site.y + u', 1)
        self.assertNotEqual(cell(project_offsets(broken)[0], 'NORTH', 1, 1), (1, 1))

    def test_draught_codec_never_serializes_survey_state(self):
        encoded = body('/datum/harbor_plan/proc/to_code()').strip()
        self.assertEqual(encoded, 'return "C13HARBOR/1/[part]/[length]/[width]/[hull]"')
        parsed = body('/proc/harbor_plan_from_code(code)')
        for condition in ('fields.len != 4', 'fields[1] in harbor_parts()', 'len_value > 12',
                          'len_value > 24', 'beam_value in list(3, 5, 7, 9, 11)',
                          'initial(profile.length)', 'initial(profile.beam)'):
            self.assertIn(condition, parsed)
        self.assertNotIn('.site =', parsed)
        self.assertNotIn('.heading =', parsed)

    def test_shared_check_types_and_actual_depth_distinctions(self):
        expected = dict(site=10, footprint=20, access=30)
        for name, order in expected.items():
            self.assertIn(f'/datum/design_check/harbor/{name}\n\torder = {order}', SOURCE)
        check = body('/datum/design_check/harbor/footprint/check(datum/D, datum/design_report/R)')
        self.assertIn('P.part == "steel" && depth == "deep"', check)
        self.assertIn('P.part == "dock" ? "Dig these basin tiles', check)
        self.assertIn('vessel_at(T)', check)
        access = body('/datum/design_check/harbor/access/check(datum/D, datum/design_report/R)')
        self.assertIn('range(1, T)', access)
        self.assertIn('if (N == P.site || basin[N])', access)
        self.assertIn('if (is_open_water(N))', access)
        self.assertIn('hold also needs clearance below', access)
        depth = body('/proc/harbor_depth(turf/T)')
        self.assertLess(depth.index('/saltwater/underwater'), depth.index('return "deep"'))

    def test_ui_revalidates_survey_and_mutates_only_the_drawing(self):
        topic = body('/datum/harbor_designer/Topic(href, list/href_list)')
        self.assertIn('H.client != viewer', topic)
        can_edit = body('/datum/harbor_designer/proc/can_edit(mob/living/human/H)')
        can_draw = body('/proc/harbor_can_draw(mob/living/human/H, obj/item/ship_draught/S)')
        for guard in ('H.client == viewer', 'sheet.draught_code == saved_code',
                      '!persistence_admission_changed(admission)', 'harbor_designers()[H] == src'):
            self.assertIn(guard, can_edit)
        for guard in ('H.client.mob == H', 'S.loc == H',
                      '(H.get_active_hand() == S || H.get_inactive_hand() == S)'):
            self.assertIn(guard, can_draw)
        self.assertIn('if (!can_edit(H))', topic)
        self.assertIn('saved_code = sheet.draught_code', topic)
        self.assertIn('if (plan.site && H.loc != plan.site)', topic)
        self.assertLess(topic.index('H.client != viewer'), topic.index('sheet.take_harbor(plan)'))
        for mutation in ('ChangeTurf(', 'build_span(', 'launch(', 'set_shut(', 'forceMove('):
            self.assertNotIn(mutation, SOURCE)
        self.assertIn('new\n\tD.part = fields[1]', SOURCE)
        world_mutation = body('/datum/harbor_designer/proc/survey_here()')
        self.assertIn('drawer.loc', world_mutation)
        self.assertNotIn('href', world_mutation)

    def test_survey_cannot_infer_unseen_map_geometry_or_approval(self):
        render = body('/datum/harbor_designer/proc/show()')
        self.assertIn('viewer.eye == drawer', render)
        self.assertIn('cartography_visible_turfs(drawer)', render)
        self.assertIn('seen ? harbor_depth(T) : "unseen"', render)
        self.assertIn('seen && (bad[', render)
        self.assertIn('P.survey_seen = null', render)
        footprint = body('/datum/design_check/harbor/footprint/check(datum/D, datum/design_report/R)')
        self.assertRegex(footprint, r'(?s)if \(!P.survey_can_read\(T\)\).*?unknown \+= .*?continue.*?harbor_depth\(T\)')
        access = body('/datum/design_check/harbor/access/check(datum/D, datum/design_report/R)')
        self.assertRegex(access, r'(?s)if \(!P.survey_can_read\(T\) \|\| !P.survey_can_read\(N\)\).*?continue.*?is_open_water\(N\)')
        self.assertRegex(access, r'(?s)if \(!P.survey_can_read\(T\)\).*?unknown_way = TRUE.*?clear_ways = FALSE.*?continue.*?harbor_depth\(T\)')
        self.assertIn('else if (!found)', access)

    def test_harbor_import_rechecks_same_sheet_client_and_admission_after_prompt(self):
        source = (ROOT / 'code/modules/naval/draught_kinds.dm').read_text(encoding='utf-8')
        imp = body('/obj/item/ship_draught/proc/draught_import(', source)
        for guard in ('!harbor_can_draw(H, src)', 'H.client != connection',
                      'draught_code != expected_code', 'persistence_admission_changed(admission)',
                      '(recheck && !recheck.Invoke())'):
            tail = imp.split('design_code_ask(', 1)[1]
            self.assertLess(tail.index(guard), tail.index('call(src, K["take"])(D)'))
        menu = body('/obj/item/ship_draught/proc/harbor_sheet_menu(')
        self.assertLess(menu.index('draught_code != expected_code'), menu.index('draught_import(H)'))
        # The open editor's own checks run again after the import prompt.
        editor = body('/datum/harbor_designer/Topic(')
        self.assertIn('draught_import_in_window(H, HARBOR_WINDOW, CALLBACK(src, PROC_REF(can_edit), H))', editor)


if __name__ == '__main__':
    unittest.main()
