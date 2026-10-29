import json
import unittest
from tools.procedural_maps.reference_annotation import build,near


def expand(component):
    return {(x,y) for y,x1,x2 in component['row_runs_y_x1_x2_native'] for x in range(x1,x2+1)}


class AnnotationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.r=build()
    def test_source_totals_and_component_counts(self):
        self.assertEqual({'FRESHWATER_TYPE':3139,'SALTWATER_TYPE':709,'SWAMP_FRESH_TYPE':734},self.r['class_counts'])
        self.assertEqual([17,3,226],[len(self.r['components'][k]) for k in ['FRESHWATER_TYPE','SALTWATER_TYPE','SWAMP_FRESH_TYPE']])
    def test_row_runs_reconstruct_disjoint_exact_components(self):
        seen=set()
        for kind,cs in self.r['components'].items():
            total=0
            for c in cs:
                points=expand(c)
                self.assertEqual(c['area'],len(points));self.assertFalse(seen & points)
                seen.update(points);total+=len(points)
            self.assertEqual(self.r['class_counts'][kind],total)
        self.assertEqual(4582,len(seen))
    def test_main_network_edge_contacts_are_exact(self):
        c=self.r['components']['FRESHWATER_TYPE'][0]
        self.assertEqual(3022,c['area'])
        self.assertEqual({'W':[[134,147]],'E':[[91,94],[124,124]],'S':[],'N':[[11,20]]},c['edge_contacts_native'])
    def test_route_witnesses_are_fresh_and_cardinal(self):
        fresh=set().union(*(expand(c) for c in self.r['components']['FRESHWATER_TYPE']))
        core=expand(self.r['possible_lake_cores'][0])
        for route in self.r['contact_to_broad_core_routes']:
            path=[tuple(p) for p in route['path_native']]
            self.assertEqual(route['path_length_edges'],len(path)-1)
            self.assertTrue(set(path)<=fresh);self.assertIn(path[-1],core)
            self.assertTrue(all(b in near(a) for a,b in zip(path,path[1:])))
    def test_build_is_deterministic_and_not_human_approved(self):
        self.assertEqual(json.dumps(self.r,sort_keys=True),json.dumps(build(),sort_keys=True))
        self.assertEqual('AGENT_PROPOSAL_NOT_HUMAN_APPROVED',self.r['status'])
        self.assertTrue(all(c['flow_direction'].startswith('UNRESOLVED') for c in self.r['main_network_contact_candidates']))


if __name__=='__main__':unittest.main(verbosity=2)
