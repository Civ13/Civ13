"""Synthetic witness/source controls, not native execution or visual acceptance."""
import copy,hashlib,json,unittest
from pathlib import Path
from glide_probe import validate_probe
HERE=Path(__file__).resolve().parent

def rows():
    out=[]
    for step,phase,y,t,glide in [(1,'before_step',9,21,0),(1,'after_step',8,21,0),(2,'before_step',8,42,32*.5/21),(2,'after_step',7,42,32*.5/21),(2,'settled_before_restore',7,67,32*.5/21),(2,'restored',7,67,0)]:
        members=[dict(ref=str(i),type='/fixture',x=8,y=y,z=1,dir=2,glide_size=glide,animate_movement=2,appearance_flags=0,bound_width=64 if i==0 else 32,bound_height=96 if i==0 else 32,step_size=32,step_x=0,step_y=0) for i in range(4)]
        out.append(dict(probe='fractional_glide_v1',phase=phase,step=step,world_time_ds=t,world_fps=20,world_tick_lag=.5,client_fps=20,vehicle_delay_ds=20,scheduled_interval_ds=21,movement_mode=0,members=members))
    return out

def encoded(r):return '\n'.join(json.dumps(x) for x in r)

class Probe(unittest.TestCase):
    def test_state_acceptance_never_certifies_pixels_or_production(self):
        result=validate_probe(encoded(rows()))
        self.assertFalse(result['rendered_smoothness_proven'])
        self.assertFalse(result['production_fix_proven'])
    def test_missing_reordered_or_duplicate_phase_rejected(self):
        for r in [rows()[:-1],list(reversed(rows())),rows()+[rows()[0]]]:
            with self.assertRaises(ValueError):validate_probe(encoded(r))
    def test_wrong_units_member_omission_or_cadence_rejected(self):
        for edit in [lambda r:r[2]['members'][0].update(glide_size=32/2.1),lambda r:r[2]['members'][2].update(glide_size=0),lambda r:r[2].update(world_time_ds=43),lambda r:r[2].update(client_fps=60),lambda r:r[2]['members'][0].update(bound_width=32),lambda r:r[-1]['members'][0].update(glide_size=1),lambda r:r[2]['members'][0].update(ref='replaced'),lambda r:r[2].update(movement_mode=1)]:
            r=rows();edit(r)
            with self.assertRaises(ValueError):validate_probe(encoded(r))
    def test_probe_source_only_changes_glide_before_inherited_two_steps(self):
        s=(HERE/'changed-source/filming/scene.dm').read_text().split('// BEGIN FIXTURE-ONLY GLIDE PROBE:')[1]
        self.assertIn('A.glide_size = 32 * world.tick_lag / (vehicle_m_delay + 1)',s)
        self.assertIn('if (intro_glide_probe_steps == 2)',s)
        self.assertIn('intro_glide_probe_steps <= 2 && vehicle_m_delay == 20',s)
        self.assertEqual(s.count('\t. = ..()'),1)
        for prohibited in ['forceMove(', 'TILE_MOVER', 'movement_mode =', 'pixel_x =', 'pixel_y =', 'step_x =','step_y =','sleep(', 'spawn(']:self.assertNotIn(prohibited,s)
        self.assertIn('A.glide_size = intro_glide_probe_original[A]',s)
    def test_integration_requires_witnesses_but_preserves_video_disclaimer(self):
        s=(HERE/'integration.py').read_text()
        self.assertIn("validate_probe((source/'intro-checks.txt').read_text())",s)
        self.assertIn('accepted_for_marketing=False, glide_probe=probe',s)

if __name__=='__main__':unittest.main()
