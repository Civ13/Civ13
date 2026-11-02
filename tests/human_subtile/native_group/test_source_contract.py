import re,unittest
from pathlib import Path
P=Path(__file__).parent
DM=(P/'native-group-probe.dm').read_text(encoding='utf-8-sig')
DME=(P/'native-group-probe.dme').read_text(encoding='utf-8-sig')
def body(header):
    match=re.search(r'^'+re.escape(header)+r'[^\n]*\n(?P<body>(?:[ \t]+[^\n]*\n|\n)*)',DM,re.M)
    if not match:raise AssertionError('missing '+header)
    return match.group('body')
class FixtureSourceTests(unittest.TestCase):
 def test_self_contained_dme(self):
    self.assertEqual(re.findall(r'^\s*#include\s+"([^"]+)"',DME,re.M),['native-group-probe.dm'])
 def test_no_undeclared_application_anchor(self):
    self.assertNotRegex(DM, r'\banchored\b')
    self.assertEqual(re.findall(r'^\s*#include\s+"([^"]+)"',DME,re.M),['native-group-probe.dm'])
 def test_explicit_engine_and_world(self):
    for token in ('movement_mode = LEGACY_MOVEMENT_MODE','fps = 20','icon_size = 32','world.byond_version != 516','world.byond_build != 1688'):self.assertIn(token,DM)
 def test_real_step_with_directed_group(self):
    b=body('/proc/probe_one(')
    self.assertIn('B.group += A',b);self.assertNotIn('A.group += B',b)
    self.assertIn('step(A, EAST, which == "pixel" ? 2 : 32)',b)
    self.assertNotIn('.Bump(',b);self.assertNotRegex(b,r'\.loc\s*=')
    self.assertIn('A.step_size = 2',b);self.assertNotIn('A.step_x = 30',b)
 def test_wrappers_forward_parent(self):
    for typ,method in [('/turf/group_probe/',m) for m in ('Enter','Exit','Entered','Exited')]+[('/mob/group_probe/',m) for m in ('Move','Bump','Cross','Crossed','Uncross','Uncrossed')]:
        b=body(typ+method+'(');self.assertEqual(b.count('. = ..()'),1,typ+method);self.assertNotIn('sleep(',b)
 def test_turf_receiver_identity_is_observed(self):
    self.assertIn('var/list/receiver_turf = isturf(receiver)',DM)
    self.assertIn('\"receiver_turf\" = receiver_turf',DM)
 def test_all_eight_observer_pairs(self):
    for name in ('enter','exit','entered','exited','cross','crossed','uncross','uncrossed'):
        self.assertIn('"'+name+'_before"',DM);self.assertIn('"'+name+'_after"',DM)
 def test_trace_is_bounded_and_partial_is_retained(self):
    self.assertIn('probe_events.len >= 256',DM);self.assertIn('"partial_events"',DM)
    self.assertIn('probe_record("attempt_return"',DM);self.assertIn('probe_record("settled"',DM)
if __name__=='__main__':unittest.main(verbosity=2)
