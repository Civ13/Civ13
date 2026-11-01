"""Offline source and behavioral model for destroyed-grab movement cleanup.

Does not execute the DM client path or mutate any running game.
"""
from dataclasses import dataclass
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
SOURCE=(ROOT/'code/game/mob/mob_movement.dm').read_text(encoding='utf-8')
HUMAN=(ROOT/'code/game/mob/living/carbon/human/subtile_movement.dm').read_text(encoding='utf-8')
HELPER=SOURCE.partition('/mob/proc/prune_destroyed_grab_list()')[2].partition('/client/Move(')[0]
CLIENT=SOURCE.split('/client/Move(n, direct, ordinal = FALSE, fine_step = FALSE)',1)[1]

@dataclass(eq=False)
class Grab:
    gcDestroyed: float=0
    gc_destroyed: float=0
    loc: object=None
    assailant: object=None
    affecting: object=None

def prune_model(items):
    if not items:return
    for entry in items[:]:
        if isinstance(entry,Grab) and entry.gcDestroyed:
            while entry in items:items.remove(entry)

class DestroyedGrabContracts(unittest.TestCase):
    def test_source_prunes_before_both_fine_and_normal_smooth_admission(self):
        branch=CLIENT.split('if (ishuman(mob))',1)[1]
        self.assertIn('subtile_input_actor.prune_destroyed_grab_list()',branch)
        self.assertLess(branch.index('subtile_input_actor.prune_destroyed_grab_list()'),branch.index('if (fine_step)'))
        self.assertLess(branch.index('subtile_input_actor.prune_destroyed_grab_list()'),branch.index('human_subtile_input_supported(direct)'))
        self.assertIn('mob.prune_destroyed_grab_list()',CLIENT)
        self.assertEqual(CLIENT.count('mob.prune_destroyed_grab_list()'),1)

    def test_live_grabs_remain_in_the_readiness_gate(self):
        unlinked=HUMAN.split('/mob/living/human/proc/human_subtile_unlinked()',1)[1].split('/atom/movable/proc/',1)[0]
        self.assertIn('(!grab_list || !grab_list.len)',unlinked)
        self.assertIn('(!grabbed_by || !grabbed_by.len)',unlinked)
        supported=HUMAN.split('/mob/living/human/proc/human_subtile_input_supported(direction)',1)[1].split('/mob/living/human/proc/human_subtile_posture_ready',1)[0]
        self.assertIn('if (!step_x && !step_y)',supported)
        self.assertIn('human_subtile_eligible(direction)',supported)

    def test_source_preserves_narrow_existing_gc_condition_and_list_identity(self):
        self.assertIn('for (var/datum/D in grab_list.Copy())',HELPER)
        self.assertIn('if (D.gcDestroyed)',HELPER)
        self.assertIn('grab_list -= D',HELPER)
        for forbidden in ('gc_destroyed','QDELETED','isDeleted(','qdel(','del(',
                          'grabbed_by','canmove','loc =','grab_list = list(',
                          'step_x','step_y','forceMove','human_subtile_transaction'):
            self.assertNotIn(forbidden,HELPER)

    def test_confirmed_destroyed_entry_removed_without_touching_live_grab(self):
        stale=Grab(gcDestroyed=15585.4,gc_destroyed=15585.4)
        active=Grab(loc='human',assailant='human',affecting='animal')
        entries=[stale,active];original=entries
        prune_model(entries)
        self.assertIs(entries,original)
        self.assertEqual(entries,[active])
        self.assertEqual((active.loc,active.assailant,active.affecting),('human','human','animal'))

    def test_in_progress_or_unverified_objects_are_not_treated_as_destroyed(self):
        progress=Grab(gc_destroyed=1,loc='human',assailant='human',affecting='animal')
        unverified=Grab(loc=None,assailant=None,affecting=None)
        entries=[progress,unverified];prune_model(entries)
        self.assertEqual(entries,[progress,unverified])

    def test_multiple_stale_entries_are_not_skipped_or_cleared_with_live(self):
        one,two,live=Grab(gcDestroyed=1),Grab(gcDestroyed=2),Grab()
        entries=[one,two,live,one];prune_model(entries)
        self.assertEqual(entries,[live])

    def test_empty_and_null_like_entries_do_not_cause_global_reset(self):
        entries=[None,Grab()];before=entries[:];prune_model(entries)
        self.assertEqual(entries,before)
        prune_model([]);prune_model(None)

if __name__=='__main__':unittest.main()
