"""Saved-tile checks; source/model only, not BYOND savefile I/O."""
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]

def tile_admitted(*, tile_type, density, in_grid, identity_matches, object_densities=()):
    return (tile_type == 'turf' and type(density) is int and density == 0 and in_grid and identity_matches
            and all(type(value) is int and value == 0 for value in object_densities))

class TileAdmissionTests(unittest.TestCase):
    def test_clear_tile_and_invalid_controls(self):
        row=dict(tile_type='turf', density=0, in_grid=True, identity_matches=True)
        self.assertTrue(tile_admitted(**row))
        for change in ({'tile_type':'object'},{'density':1},{'density':None},{'density':'0'},
                       {'in_grid':False},{'identity_matches':False},{'object_densities':(1,)},
                       {'object_densities':(None,)}):
            with self.subTest(change=change): self.assertFalse(tile_admitted(**(row|change)))

    def test_source_uses_saved_density_and_no_fractional_sidecar(self):
        saving=(ROOT/'code/modules/persistence/saving.dm').read_text()
        writer=saving.split('/map_storage/proc/BuildVarDirectory(',1)[1].split('\n/datum/',1)[0]
        validator=saving.split('/map_storage/proc/inspect_human_saved_tile_and_links(',1)[1].split('\n/map_storage/proc/',1)[0]
        self.assertIn('changing_vars |= list("density")',writer)
        self.assertNotIn('/human_geometry/',saving)
        self.assertIn('human_candidate_map_ref(F, z, position["y"], position["x"])',validator)
        self.assertIn('human_candidate_scalar_field(F, turf_ref, "density")',validator)
        self.assertIn('Human saved tile is dense',validator)
        self.assertIn('Human saved tile has a dense object',validator)
        self.assertIn('human_candidate_scalar_field(F, text2num("[occupant_ref]"), "density")',validator)
        self.assertNotIn('get_turf(',validator)

if __name__=='__main__': unittest.main()
