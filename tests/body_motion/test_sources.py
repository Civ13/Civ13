"""Offline source checks for whole-body motion (no BYOND).

Body motion animates only the human's transform, composed on the posture
transform, so it never takes pixel offsets from movement, grabs or tree
climbing, and never cuts a glide or a lunge.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


MOTION = read('code/game/mob/living/carbon/human/body_motion.dm')
DEFINES = read('code/__defines/body_motion.dm')
ICONS = read('code/game/mob/living/carbon/human/update_icons.dm')
DEFENSE = read('code/game/mob/living/carbon/human/human_defense.dm')
ATTACKHAND = read('code/game/mob/living/carbon/human/human_attackhand.dm')
CONFIG = read('code/datums/configuration.dm')
EMOTE = read('code/game/mob/living/carbon/human/emotes/emote.dm')
BUCKLING = read('code/game/objects/buckling.dm')
WORK = read('code/game/mob/animations.dm')
DME = read('civ13.dme')


def proc_body(text, header):
    start = text.index(header)
    end = text.find('\n/', start + 1)
    return text[start:] if end < 0 else text[start:end]


class BodyMotionSources(unittest.TestCase):
    def test_included_with_early_defines(self):
        self.assertIn('#include "code\\__defines\\body_motion.dm"', DME)
        self.assertIn('#include "code\\game\\mob\\living\\carbon\\human\\body_motion.dm"', DME)
        for name in ('BODY_MOTION_OFF', 'BODY_MOTION_REDUCED', 'BODY_MOTION_FULL',
                     'BODY_MOTION_PRIORITY_POSTURE', 'BODY_MOTION_MIN_GAP'):
            self.assertIn(f'#define {name} ', DEFINES)
            self.assertNotIn(f'#define {name} ', MOTION)

    def test_only_transform_is_animated(self):
        code = '\n'.join(line for line in MOTION.splitlines() if not line.lstrip().startswith('//'))
        self.assertNotRegex(code, r'\bpixel_[xywz]\s*=')
        self.assertNotRegex(code, r'\bstep_[xy]\s*=')
        for call in re.findall(r'animate\(([^\n]*)\)', code):
            if call.startswith('src'):
                self.assertIn('flags = ANIMATION_PARALLEL, tag = BODY_MOTION_TAG', call)
            self.assertIn('transform = ', call)

    def test_motion_state_is_never_saved(self):
        for name in ('body_motion_until', 'body_motion_priority', 'body_motion_started', 'body_motion_rest',
                     'body_motion_drawn_turned', 'body_motion_watch_checked', 'body_motion_watch_cached',
                     'body_motion_stroke_next', 'body_motion_serial'):
            self.assertRegex(MOTION, rf'var/tmp/(matrix/)?{name}\b')

    def test_posture_handshake(self):
        body = proc_body(ICONS, '/mob/living/human/proc/update_posture_transform()')
        self.assertIn('flags = ANIMATION_PARALLEL, tag = BODY_MOTION_TAG', body)
        self.assertIn('body_motion_posture_change(rest, turned)', body)
        self.assertIn('world.time < body_motion_until', body)
        # The only direct write comes after the running-motion branch.
        self.assertEqual(body.count('transform = rest'), 2)
        self.assertLess(body.index('world.time < body_motion_until'), body.rindex('\ttransform = rest'))

    def test_recoil_hooks(self):
        weapon = proc_body(DEFENSE, '/mob/living/human/hit_with_weapon(')
        self.assertIn('if (effective_force && blocked < 2)\n\t\tbody_motion_recoil(user, (body_motion_blunt(I)', weapon)
        self.assertRegex(ATTACKHAND, r'toxic=H\.lizard\)\n\t+body_motion_recoil\(H\)')

    def test_work_seat_and_emote_hooks(self):
        strike = proc_body(WORK, '/datum/resource_work_animation/proc/show_strike()')
        self.assertIn('if (H.body_motion_work(target))\n\t\t\treach = 8', strike)
        self.assertNotRegex(strike, r'pixel_[xyz] = -?16')
        self.assertIn('\t\tH.body_motion_settle()', proc_body(BUCKLING, '/obj/proc/buckle_mob('))
        self.assertIn('custom_emote(m_type,message)\n\t\t\tbody_motion_emote(act)', EMOTE)

    def test_combat_hooks(self):
        self.assertIn('/mob/living/human/do_attack_animation(atom/A)\n\t..()\n\tbody_motion_swing(A, get_active_hand())', MOTION)
        for path in ('code/game/objects/items/weapons/material/swords.dm',
                     'code/game/objects/items/weapons/material/material_weapons.dm',
                     'code/game/objects/items/weapons/material/twohanded.dm'):
            self.assertIn('body_motion_parry(attacker)', read(path), path)
        reactions = read('code/game/mob/combat_reactions.dm')
        for call in ('body_motion_parry(attacker)', 'body_motion_slip(attacker)', 'body_motion_sprawl(attacker)'):
            self.assertIn(call, reactions)
        self.assertIn('H.body_motion_stance_set()', read('code/game/mob/combat_stance.dm'))

    def test_swim_and_climb_hooks(self):
        self.assertIn('if (H.swim_skill_applies(F) && !H.buckled)\n\t\t\t\t\t\tH.body_motion_swim_stroke()',
                      read('code/game/mob/mob_movement.dm'))
        self.assertIn('swim_under = TRUE\n\t\tbody_motion_sink()', read('code/modules/1713/swimming.dm'))
        self.assertEqual(read('code/game/mob/living/carbon/human/human_helpers.dm').count('</font>"))\n\t\t\tbody_motion_struggle()\n\t\t\tlife_water_refresh()'), 2)
        # Every climb wait starts the pulls and stops them once the wait ends.
        for path, count in (('code/game/objects/structures/tree_climbing.dm', 2),
                            ('code/modules/multiz/edge_climbing.dm', 1),
                            ('code/modules/multiz/pit_climbing.dm', 1),
                            ('code/modules/1713/machinery/modular_vehicles/vehicle_decks.dm', 2),
                            ('code/modules/naval/hull_rigging.dm', 1)):
            text = read(path)
            self.assertEqual(text.count('climb_motion = ') - text.count('var/climb_motion = 0'), count, path)
            self.assertEqual(text.count('body_motion_stop(climb_motion)'), count, path)
        self.assertIn('hull_wait(src, MAST_CLIMB_TIME, M, climb = 1)', read('code/modules/naval/hull_masts.dm'))
        self.assertIn('if (!may_do_after)\n\t\treturn 0', proc_body(MOTION, '/mob/living/human/proc/body_motion_climb('))

    def test_stride_hook_and_gap(self):
        self.assertIn('mob.last_movement = world.time\n\t\tif (ishuman(mob))\n\t\t\tvar/mob/living/human/strider = mob\n\t\t\tstrider.body_motion_stride()',
                      read('code/game/mob/mob_movement.dm'))
        self.assertIn('#define BODY_MOTION_PRIORITY_STRIDE 0', DEFINES)
        # A hit cuts in over a bounce: the start gap holds back equal or lower priorities only.
        self.assertIn('priority <= body_motion_priority && world.time < body_motion_started + BODY_MOTION_MIN_GAP', MOTION)
        stride = proc_body(MOTION, '/mob/living/human/proc/body_motion_stride(')
        for key in ('list(0, 1, 0, 1, 2, SINE_EASING | EASE_OUT)', 'list(0, 2, 0, 1, 1.5, QUAD_EASING | EASE_OUT)',
                    'list(0, 1, 0, 1, 1, QUAD_EASING | EASE_OUT)', 'list(0, -1, 0, 1, 3, SINE_EASING | EASE_IN)',
                    'list(0, -1, 0, 1, 2, QUAD_EASING | EASE_IN)', 'list(0, -1, 0, 1, 1.5, QUAD_EASING | EASE_IN)'):
            self.assertIn(key, stride)
        self.assertIn('swim_skill_applies(loc)', stride)
        self.assertIn('istype(loc, /turf/floor/beach/water/ice)', stride)
        drags = proc_body(MOTION, '/mob/living/human/proc/body_motion_terrain_drags(')
        for check in ('/turf/floor/trench/flooded', 'flood_band_at(F)', 'has_snow_cover()', 'F.muddy'):
            self.assertIn(check, drags)

    def test_gestures_are_full_level_only(self):
        for header in ('/mob/living/human/proc/body_motion_work(', '/mob/living/human/proc/body_motion_settle(',
                       '/mob/living/human/proc/body_motion_emote(', '/mob/living/human/proc/body_motion_stance_set(',
                       '/mob/living/human/proc/body_motion_swim_stroke(', '/mob/living/human/proc/body_motion_climb('):
            self.assertIn('BODY_MOTION_PRIORITY_LOW, BODY_MOTION_FULL', proc_body(MOTION, header))
        self.assertIn('BODY_MOTION_PRIORITY_STRIDE, BODY_MOTION_FULL', proc_body(MOTION, '/mob/living/human/proc/body_motion_stride('))

    def test_config_line(self):
        self.assertIn('var/body_motion = BODY_MOTION_FULL', CONFIG)
        self.assertIn('if ("body_motion")', CONFIG)
        self.assertIn('BODY_MOTION', read('config/config.txt'))

    def test_fable_budgets(self):
        # Fall 4 ds ease-in through a feet-pivot lean with a 1px settle, stand-up 6 ds ease-out, recoil 3 ds.
        fall = proc_body(MOTION, '/mob/living/human/proc/body_motion_posture_change(')
        self.assertIn('BODY_MOTION_PRIORITY_POSTURE, 4, rest', fall)
        self.assertIn('time = 2, easing = QUAD_EASING | EASE_IN', fall)
        self.assertEqual(fall.count('? 45 : -45'), 3)  # topple, lie down, rise
        self.assertIn('BODY_MOTION_PRIORITY_POSTURE, 6, rest)\n\t\tanimate(src, transform = body_motion_matrix(upright', fall)
        self.assertIn('BODY_MOTION_PRIORITY_POSTURE, 6, rest', fall)
        self.assertIn('SINE_EASING | EASE_OUT', fall)
        recoil = proc_body(MOTION, '/mob/living/human/proc/body_motion_recoil(')
        self.assertIn('BODY_MOTION_PRIORITY_COMBAT, 3 + delay, rest', recoil)
        self.assertIn('dx * 3, dy * 3, dx * 8', recoil)
        # Swim stroke 1px, sink 3px with a hold, climb pulls 1px every 10 ds.
        self.assertIn('list(0, -1, 0, 1, 2, SINE_EASING)', proc_body(MOTION, '/mob/living/human/proc/body_motion_swim_stroke('))
        self.assertIn('body_motion_stroke_next = world.time + 12', MOTION)
        sink = proc_body(MOTION, '/mob/living/human/proc/body_motion_sink(')
        self.assertIn('BODY_MOTION_PRIORITY_COMBAT, BODY_MOTION_REDUCED', sink)
        self.assertIn('list(0, -3, 0, 1, 3, LINEAR_EASING)', sink)
        self.assertIn('BODY_MOTION_PRIORITY_LOW, BODY_MOTION_REDUCED', proc_body(MOTION, '/mob/living/human/proc/body_motion_struggle('))
        self.assertIn('round(duration / 10)', proc_body(MOTION, '/mob/living/human/proc/body_motion_climb('))

    def test_action_motions_hooked(self):
        gun = proc_body(read('code/modules/projectiles/gun.dm'), '/obj/item/weapon/gun/proc/handle_post_fire(')
        self.assertIn('shooter.body_motion_fire(target, src)', gun)
        thrower = proc_body(read('code/game/mob/living/carbon/carbon.dm'), '/mob/living/human/throw_item(')
        self.assertLess(thrower.index('body_motion_throw(target)'), thrower.index('item.throw_at('))
        shove = proc_body(ATTACKHAND, '/mob/living/human/proc/try_deliberate_shove(')
        self.assertLess(shove.index('if (!moved)'), shove.index('body_motion_knockback(user)'))
        items = proc_body(read('code/game/objects/items.dm'), '/obj/item/attack_hand(')
        self.assertIn('var/turf/stoop_from = isturf(loc) ? loc : null', items)
        self.assertIn('stooper.body_motion_stoop(stoop_from)', items)
        med = read('code/game/objects/items/stacks/medical.dm')
        treat = proc_body(med, '/obj/item/stack/medical/proc/treat(')
        self.assertLess(treat.index('healer.body_motion_kneel(H, treat_time)'), treat.index('do_mob(user, H'))
        self.assertIn('healer.body_motion_stop(kneel, 3)', treat)
        splint = proc_body(med, '/obj/item/stack/medical/splint/attack(')
        self.assertIn('if (kneel_wait(user, M, 50))', splint)
        wait = proc_body(med, '/obj/item/stack/medical/proc/kneel_wait(')
        self.assertLess(wait.index('healer.body_motion_kneel(M, time)'), wait.index('do_mob(user, M, time)'))
        self.assertIn('healer.body_motion_stop(kneel, 3)', wait)

    def test_action_motion_budgets(self):
        fire = proc_body(MOTION, '/mob/living/human/proc/body_motion_fire(')
        self.assertIn('BODY_MOTION_PRIORITY_COMBAT, BODY_MOTION_REDUCED', fire)
        self.assertIn('ITEM_SIZE_LARGE) ? 3 : 2', fire)
        self.assertIn('-kick * f[1], -kick * f[2], -5 * f[3], 1, 1', fire)
        throw = proc_body(MOTION, '/mob/living/human/proc/body_motion_throw(')
        self.assertIn('3 * f[1], 3 * f[2], 6 * f[3], f[3] ? 1 : 0.96, 1', throw)
        knock = proc_body(MOTION, '/mob/living/human/proc/body_motion_knockback(')
        self.assertIn('4 * f[1], 4 * f[2], 10 * f[3], f[3] ? 1 : 0.94, 2', knock)
        self.assertIn('BODY_MOTION_PRIORITY_LOW, BODY_MOTION_FULL', proc_body(MOTION, '/mob/living/human/proc/body_motion_stoop('))
        kneel = proc_body(MOTION, '/mob/living/human/proc/body_motion_kneel(')
        self.assertIn('BODY_MOTION_PRIORITY_LOW, BODY_MOTION_REDUCED', kneel)
        self.assertIn('!may_do_after || !may_do_mob', kneel)
        self.assertIn('0.8, max(1, duration), LINEAR_EASING', kneel)
        haul = proc_body(MOTION, '/mob/living/human/proc/body_motion_haul_dir(')
        self.assertIn('added * pull_drag_mult() < 1', haul)
        stride = proc_body(MOTION, '/mob/living/human/proc/body_motion_stride(')
        self.assertLess(stride.index('body_motion_haul_dir()'), stride.index('body_motion_terrain_drags()'))
        self.assertIn('BODY_MOTION_PRIORITY_STRIDE, BODY_MOTION_REDUCED', stride)


if __name__ == '__main__':
    unittest.main()
