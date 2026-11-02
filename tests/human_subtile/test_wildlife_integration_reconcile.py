"""Offline source/ownership contracts; not BYOND movement or save acceptance."""
from pathlib import Path
from types import SimpleNamespace
import sys, unittest

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/save_movement'))
from source_adapter import project

def read(path):return (ROOT/path).read_text(encoding='utf-8')
def body(text,start,end):return text.split(start,1)[1].split(end,1)[0]

class IntegratedOwnership(unittest.TestCase):
 def setUp(self):
  self.npc=read('code/game/mob/living/simple_animal/subtile_movement.dm')
 def test_native_lag_conversion_rejects_old_half_tick_multiplier(self):
  world=SimpleNamespace(tick_lag=.5)
  def compile_source(source):
   return project(source,'/mob/living/simple_animal/proc/npc_subtile_native_interval','src, lag',{'world':world})
  convert=compile_source(self.npc)
  for tick in (.5,1):
   world.tick_lag=tick
   for lag in (3,4):self.assertEqual(convert(None,lag),lag)
  mutant=self.npc.replace('return lag\n','return lag * world.tick_lag\n',1)
  world.tick_lag=.5
  self.assertNotEqual(compile_source(mutant)(None,4),4)
 def test_cardinal_diagonal_and_blocking_use_authorized_pulses(self):
  advance=body(self.npc,'/datum/npc_subtile_transaction/proc/advance()\n','/datum/npc_subtile_transaction/proc/perform_rest(')
  for token in ('min(2, remaining_x)','min(2, remaining_y)','direction & (direction - 1)',
                'fronts += direction & (NORTH | SOUTH)','fronts += direction & (EAST | WEST)',
                'map.check_caribbean_block(actor, front)','actor.Move(destination, direction)',
                'P.armed || actual_x != dx || actual_y != dy','failed_pulse = TRUE'):
   self.assertIn(token,advance)
  self.assertLess(advance.index('map.check_caribbean_block'),advance.index('actor.Move(destination, direction)'))
  # Omission control: blocked cardinal or either diagonal edge must be checked
  # before the pulse; this offline check does not emulate BYOND collision.
  def guards_complete(src):
   return all(x in src for x in ('map.check_caribbean_block(actor, front)',
                                 'fronts += direction & (NORTH | SOUTH)',
                                 'fronts += direction & (EAST | WEST)'))
  for removed in ('map.check_caribbean_block(actor, front)',
                  'fronts += direction & (NORTH | SOUTH)',
                  'fronts += direction & (EAST | WEST)'):
   self.assertFalse(guards_complete(advance.replace(removed,'',1)))
 def test_stop_preserves_legacy_walk_and_releases_continuous_owners(self):
  stop=body(self.npc,'/mob/living/simple_animal/proc/npc_subtile_stop_continuous_walk()\n','/mob/living/simple_animal/proc/npc_subtile_authority_ready()')
  for owner in ('follow','flee','pet_walk','wild_walk'):
   self.assertIn('src.npc_subtile_stop_'+owner+'()',stop)
  self.assertEqual(stop.count('walk(src, 0)'),1)
  self.assertNotIn('following_mob = null',stop)
 def test_owned_rider_teardown_invalidates_pending_before_release(self):
  for path,guard in [('code/game/mob/living/carbon/human/human.dm','if (!QDELETED(old_mount) && old_mount.rider == src)'),
                     ('code/game/mob/living/carbon/human/human_life.dm','if (!QDELETED(old_mount) && old_mount.rider == src && riding_mob != old_mount)')]:
   text=read(path);fragment=text.split(guard,1)[1].split('old_mount.ride = FALSE',1)[0]
   self.assertIn('old_mount.npc_subtile_pending_intent = null',fragment)
   self.assertNotIn('npc_subtile_pending_intent = null',text.split(guard,1)[0].rsplit('/mob/',1)[-1])
 def test_destroy_preserves_both_frame_retirement_and_owned_rider_unlink(self):
  text=read('code/game/mob/living/simple_animal/simple_animal.dm')
  destroy=body(text,'/mob/living/simple_animal/Destroy()\n','/mob/living/simple_animal/death(')
  self.assertIn('if (F && F.actor == src)',destroy)
  self.assertLess(destroy.index('F.retire()'),destroy.index('if (!QDELETED(rider) && rider.riding_mob == src)'))
  self.assertIn('rider.riding_mob = null',destroy)
  self.assertIn('npc_subtile_pending_intent = null',destroy)
 def test_existing_swap_veto_and_los_context_are_retained(self):
  living=read('code/game/mob/living/living.dm')
  self.assertIn('/mob/living/proc/ordinary_human_animal_swap',living)
  swap=living.split('if (can_swap_with(tmob))',1)[1]
  self.assertLess(swap.index('ordinary_human_animal_swap(tmob)'),swap.index('tmob.forceMove(oldloc)'))
  move=read('code/game/mob/mob_movement.dm')
  self.assertIn('los_move_contexts = los_invalidate_movement(src)',move)
  self.assertEqual(move.count('los_refresh_moved_viewer(src, FALSE, los_move_contexts)'),3)
 def test_wildlife_defaults_and_large_geometry_remain_off(self):
  for field in ('npc_subtile_enabled','npc_subtile_species_enabled','npc_subtile_recovery_enabled',
                'npc_subtile_large_exit_enabled'):
   self.assertRegex(self.npc,r'var(?:/tmp)?/'+field+r' = FALSE')
  shape=body(self.npc,'/mob/living/simple_animal/proc/npc_subtile_shape()\n','/mob/living/simple_animal/proc/npc_subtile_settled()')
  for guard in ('bound_x == 0','bound_y == 0','bound_width == 32','bound_height == 32'):
   self.assertIn(guard,shape)

if __name__=='__main__':unittest.main(verbosity=2)
