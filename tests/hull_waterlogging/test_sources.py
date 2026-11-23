"""Source contracts for a hull's engine recovery; does not run BYOND."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
ENGINES = ROOT / 'code/modules/1713/machinery/engines'
ENGINE = (ENGINES / 'engines.dm').read_text()
EXTERNAL = (ENGINES / 'external_combustion.dm').read_text()
INTERNAL = (ENGINES / 'internal_combustion.dm').read_text()
DRIVES = (ROOT / 'code/modules/naval/hull_drives.dm').read_text()
LIFT = (ROOT / 'code/modules/1713/lifting_machines.dm').read_text()
CRANES = (ROOT / 'code/modules/1713/power_cranes.dm').read_text()


def proc(source, header):
    return source.split(header, 1)[1].split('\n/', 1)[0]


class Waterlogging(unittest.TestCase):
    def test_wet_engine_shutdown_cancels_its_runs_without_changing_other_engines(self):
        stopped = proc(ENGINE, '/proc/ship_waterlog()')
        for token in ('if (waterlogged && !on)', 'waterlogged = TRUE',
                      'run_generation++', 'on = FALSE', 'power_off_connections()'):
            self.assertIn(token, stopped)
        self.assertLess(stopped.index('on = FALSE'), stopped.index('power_off_connections()'))
        self.assertIn('var/waterlogged = FALSE // saved', ENGINE)
        self.assertNotIn('var/tmp/waterlogged', ENGINE)
        self.assertIn('return key == "run_generation" || ..()', ENGINE)
        self.assertIn('running_sound(generation)', EXTERNAL)
        self.assertIn('generation != run_generation', INTERNAL)
        self.assertIn('on && !waterlogged && generation == run_generation',
                      proc(ENGINE, '/proc/running_sound('))

    def test_immersion_does_not_equate_to_every_engine_flooding(self):
        exposure = proc(DRIVES, '/proc/ship_engine_wet(')
        self.assertIn('!submarine_at(T)', exposure)
        self.assertIn('L.depth_disabled && hull_depth_underwater(T) && !sunken_hull_pressure_sheltered(T)', exposure)
        self.assertNotIn('locate(/obj/roof)', exposure)
        self.assertIn('L.water_at(T) >= cap * HULL_ENGINE_FLOOD_SHARE', exposure)
        self.assertIn('L.bay_capacity(bay)', exposure)
        self.assertIn('T.z == B.upper_z() || T.z == B.top_z()', exposure)
        step = proc(DRIVES, '/proc/step_waterlogged_engines()')
        self.assertIn('(!water && !depth_disabled)', step)
        self.assertIn('ship_engine_wet(E, src)', step)

    def test_wrench_service_and_launch_paths_fail_closed(self):
        service = proc(ENGINE, '/proc/dry_service(')
        self.assertIn('persistence_admission_changed(admission)', service)
        self.assertEqual(service.count('ship_engine_wet(src)'), 2)
        self.assertLess(service.rindex('ship_engine_wet(src)'), service.index('waterlogged = FALSE'))
        self.assertNotIn('on = TRUE', service)
        self.assertIn('!E.waterlogged', proc(DRIVES, '/datum/craft_drive/fitted/engine/ready()'))
        for source, kind in ((EXTERNAL, 'external'), (INTERNAL, 'internal')):
            self.assertIn('if (!ship_engine_start_allowed(user))', proc(source, f'/engine/{kind}/turn_on('))

    def test_crane_admission_and_commit_recheck_open_water_and_detached_engine(self):
        water = proc(CRANES, '/steam/haul_below_column(')
        self.assertIn('if (!sea_layer_cell(source))\n\t\treturn ..()', water)
        self.assertIn('sea_layer_open_surface(surface) && !surface.iscovered()', water)
        load = proc(CRANES, '/steam/haul_below_load(')
        self.assertIn('E.waterlogged && !E.anchored && !E.fueltank && !length(E.connections)', load)
        haul = proc(LIFT, '/proc/haul(mob/living/human/')
        self.assertEqual(haul.count('haul_route_valid(load, destination)'), 2)
        self.assertIn('!ledge_landing_clear(destination)', haul)
        self.assertLess(haul.rindex('haul_route_valid(load, destination)'),
                        haul.index('load.persistence_set_loc(destination)'))
