"""Offline producer contracts and source-derived reverse recovery planning."""
from pathlib import Path
import re
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[2]
BASE='10d264e5896221b34949ee4b67c0fd2b94bde249'
PRODUCER=ROOT/'code/game/mob/living/carbon/human/pull_pair_producer.dm'


def read(path): return (ROOT/path).read_text(encoding='utf-8')


def recovery_plan():
    source=PRODUCER.read_text()
    text=source[source.index('/proc/subtile_pull_recovery_plan'):source.index('/datum/subtile_pull_pair/proc/finish_intent')]
    text=text[text.index('\tvar/list/plan'):].rstrip()
    exact={'var/list/plan = list()':'plan = []',
           'var/catchup = min(2, leading - trailing)':'catchup = min(2, leading - trailing)',
           'plan += list(list("leader", catchup))':'plan.append(("leader", catchup))',
           'plan += list(list("follower", min(2, trailing)))':'plan.append(("follower", min(2, trailing)))',
           'plan += list(list("leader", min(2, leading)))':'plan.append(("leader", min(2, leading)))',
           'leading -= catchup':'leading -= catchup', 'return plan':'return plan'}
    output=['def plan(leading, trailing):']
    for line in text.splitlines():
        indent=len(line)-len(line.lstrip('\t'));value=line.strip()
        if value in exact:value=exact[value]
        elif value in ('if (leading > trailing)','if (trailing)','if (leading)'):value='if '+value[4:-1]+':'
        else:raise ValueError('Unprojected recovery statement: '+value)
        output.append('    '*indent+value)
    namespace={}
    exec(compile('\n'.join(output),'<actual-recovery-plan>','exec'),{'__builtins__':{},'min':min},namespace)
    return namespace['plan']


class PullProducerContracts(unittest.TestCase):
    def test_recovery_plan_maintains_gap_and_finishes_every_owned_state(self):
        plan=recovery_plan();cases=0
        for leading in range(33):
            for trailing in range(33):
                if not 0 <= leading-trailing <= 2:continue
                cases+=1;state={'leader':leading,'follower':trailing};calls=0
                for _ in range(16):
                    if not any(state.values()):break
                    actions=plan(state['leader'],state['follower'])
                    self.assertLessEqual(len(actions),3)
                    for member,amount in actions:
                        self.assertTrue(0 < amount <= 2)
                        state[member]-=amount;calls+=1
                        self.assertGreaterEqual(state[member],0)
                        self.assertTrue(0 <= state['leader']-state['follower'] <= 2)
                self.assertEqual(state,{'leader':0,'follower':0})
                self.assertLessEqual(calls,34)
        self.assertEqual(cases,96)

    def test_default_on_setter_and_target_whitelist(self):
        text=PRODUCER.read_text()
        self.assertIn('var/tmp/human_subtile_pull_enabled = TRUE',text)
        self.assertIn('!set_human_subtile(TRUE)',text)
        self.assertIn('return type == /obj/structure/closet/crate',text)
        self.assertIn('return type in list(/obj/item/stack/material/wood, /obj/item/stack/material/steel, /obj/item/stack/material/iron)',text)
        self.assertNotIn('set name =',text)
        human=read('code/game/mob/living/carbon/human/subtile_movement.dm')
        self.assertIn('if (key == "human_subtile_pull_enabled")\n\t\treturn TRUE',human)

    def test_real_input_routes_after_original_once_only_cost_calculation(self):
        move=read('code/game/mob/mob_movement.dm')
        self.assertIn('H.human_subtile_eligible(direct) || H.human_subtile_pull_ready(direct)',move)
        self.assertIn('human_subtile_deadline(move_delay, world.time, ordinal)',move)
        self.assertLess(move.index('moving = TRUE',move.index('/client/Move(')),move.index('H.SelfMove(n, direct, subtile_deadline)'))
        old=subprocess.check_output(['git','show',BASE+':code/game/mob/mob_movement.dm'],cwd=ROOT).decode().replace('\r\n','\n')
        marker='\t\tvar/t_movement_speed_multiplier = mob.movement_speed_multiplier'
        end='\n#define NO_ACCURACY_MOVEMENT_CHECKS'
        self.assertIn(old[old.index(marker):old.index(end)],move)
        for charge in ('nutrition -=','water -=','stats["stamina"]','get_path('):
            self.assertNotIn(charge,PRODUCER.read_text())

    def test_every_physical_step_uses_exact_capability_native_seam(self):
        move=read('code/game/mob/mob_movement.dm')
        self.assertIn('P.consume(src, newloc, direct, P.after["sx"], P.after["sy"])',move)
        self.assertIn('..(newloc, direct, P.after["sx"], P.after["sy"])',move)
        text=PRODUCER.read_text()
        self.assertIn('member.Move(destination, P.direction)',text)
        for forbidden in ('forceMove(', 'pixel_x =','pixel_y ='):
            self.assertNotIn(forbidden,text)
        self.assertNotRegex(text,r'\b(?:loc|step_x|step_y)\s*=(?!=)')
        self.assertIn('if (controller_allowed() && world.time < deadline)',text)

    def test_legacy_drag_and_completion_subtrees_are_not_replayed_per_pulse(self):
        living=read('code/game/mob/living/living.dm')
        begin=living.index('/mob/living/Move(')
        self.assertLess(living.index('return ..()',begin),living.index('var/moved = FALSE',begin))
        self.assertIn('if (subtile_pull_ownership.owners[src])\n\t\treturn .',read('code/game/mob/living/carbon/human/human.dm'))
        text=PRODUCER.read_text();finish=text[text.index('/datum/subtile_pull_pair/proc/finish_intent'):]
        self.assertIn('if (intent_running || native_inflight || completion_running || intent_completed)\n\t\treturn',finish)
        self.assertEqual(finish.count('leader.living_movement_completed()'),1)
        self.assertEqual(finish.count('leader.human_movement_completed()'),1)
        self.assertNotIn('prob(',text)

    def test_partial_save_is_refused_before_original_hooks_and_no_state_replays(self):
        text=PRODUCER.read_text();save=text[text.index('/atom/movable/before_save_context'):]
        self.assertIn('if (!P.save_checkpoint())',save)
        self.assertIn('throw EXCEPTION("Pull pair requires an aligned save checkpoint")',save)
        self.assertIn('return ..()',save)
        human=read('code/game/mob/living/carbon/human/subtile_movement.dm')
        self.assertIn('if (!human_subtile_shape() || !human_subtile_unlinked())',human)

    def test_stop_and_handoff_revoke_old_work_without_borrowing_authority(self):
        living=read('code/game/mob/living/living.dm')
        self.assertIn('paired_move.lifecycle_stop("pull_stopped")',living)
        self.assertIn('subtile_pull_ownership.owners[src] || subtile_pull_ownership.owners[AM]',living)
        text=PRODUCER.read_text()
        self.assertIn('!human_subtile_authority(client)',text)
        self.assertIn('leader.client != C || C.mob != leader || !C.canmove || !C.moving',text)
        kernel=read('code/game/mob/living/carbon/human/pull_pair_ownership.dm')
        self.assertIn('cancelled = TRUE\n\trecovering = FALSE',kernel)
        self.assertIn('!human_subtile_same(leader_expected, subtile_pull_snapshot(leader))',text)


if __name__=='__main__':unittest.main(verbosity=2)
