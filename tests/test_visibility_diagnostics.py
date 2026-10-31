"""Self-report source contracts; not native invocation or rendering acceptance."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'code/modules/visibility/los_diagnostics.dm').read_text()


class VisibilityDiagnostics(unittest.TestCase):
    def test_self_only_zero_argument_verb(self):
        self.assertIn('/client/verb/visibility_diagnostics()', SOURCE)
        self.assertIn('if(!mob || usr != mob || mob.client != src)', SOURCE)
        self.assertIn('P.owner != src || P.retired', SOURCE)
        self.assertNotIn(' as ', SOURCE)
        self.assertNotIn('input(', SOURCE)
        self.assertNotIn('locate(', SOURCE)
        for call in re.findall(r'to_chat\(([^,]+),', SOURCE):
            self.assertEqual(call, 'src')

    def test_reports_explicit_fallback_and_no_hud(self):
        self.assertIn('scene_active=[P.scene_active]', SOURCE)
        self.assertIn('los_diagnostic_text(P.fallback_reason)', SOURCE)
        self.assertIn('fallback_reason=no owned compositor', SOURCE)
        self.assertIn('GAME render_target=(no HUD)', SOURCE)
        self.assertIn('owned relays=(none)', SOURCE)

    def test_only_owned_bounded_relays_and_attached_filters(self):
        self.assertIn('i <= min(length(P.screens), 16)', SOURCE)
        self.assertIn('if(++relays > 8)', SOURCE)
        self.assertIn('var/obj/screen/root_scene_relay/R = P.screens[i]', SOURCE)
        self.assertIn('if(!istype(R))', SOURCE)
        self.assertIn('j <= min(length(R.filters), 2)', SOURCE)
        self.assertIn('var/F = R.filters[j]', SOURCE)
        self.assertIn('if(F:type != "layer")', SOURCE)
        self.assertIn('k <= min(length(R.overlays), 2)', SOURCE)
        self.assertNotIn(' in world', SOURCE)
        self.assertNotIn('client.images', SOURCE)

    def test_requested_render_fields_not_assumed_child_values(self):
        for field in ['G.render_target', 'L.render_target', 'R.plane', 'R.layer',
                      'R.blend_mode', 'R.render_source', 'F:blend_mode',
                      'F:render_source', 'child:plane', 'child:layer',
                      'child:blend_mode', 'child:render_source']:
            self.assertIn(field, SOURCE)
        self.assertIn('parent_plane=', SOURCE)
        self.assertIn('child_count=[length(R.overlays)]', SOURCE)

    def test_no_mutation_or_generic_inspection_capability(self):
        for forbidden in ['.vars', ':vars', 'call(', 'Topic(', 'shell(',
                          'world.log', 'world.Export', 'fcopy(', 'file(',
                          'reconcile_geometric_los(', 'setup_scene(', 'refresh(',
                          'set_geometric_los(', 'animate(', 'filter(', 'new /',
                          'spawn(', 'sleep(']:
            self.assertNotIn(forbidden, SOURCE)
        self.assertNotRegex(SOURCE, r'(?:\.|:)(?:render_source|render_target|filters|screen|overlays)\s*[+|]?=')
        self.assertNotIn('holder', SOURCE)
        self.assertNotIn('rights', SOURCE)

    def test_text_bounded_and_html_escaped(self):
        self.assertIn('html_encode(copytext("[value]", 1, 257))', SOURCE)
        self.assertIn('if(isnull(value))', SOURCE)

    def test_included_once(self):
        self.assertEqual((ROOT/'civ13.dme').read_text().count(
            '#include "code\\modules\\visibility\\los_diagnostics.dm"'), 1)


if __name__ == '__main__':
    unittest.main()
