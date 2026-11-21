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
                self.assertIn('flags = ANIMATION_PARALLEL', call)
            self.assertIn('transform = ', call)

    def test_motion_state_is_never_saved(self):
        for name in ('body_motion_until', 'body_motion_priority', 'body_motion_rest',
                     'body_motion_drawn_turned', 'body_motion_watch_checked', 'body_motion_watch_cached'):
            self.assertRegex(MOTION, rf'var/tmp/(matrix/)?{name}\b')

    def test_posture_handshake(self):
        body = proc_body(ICONS, '/mob/living/human/proc/update_posture_transform()')
        self.assertIn('body_motion_posture_change(rest, turned)', body)
        self.assertIn('world.time < body_motion_until', body)
        # The only direct write comes after the running-motion branch.
        self.assertEqual(body.count('transform = rest'), 2)
        self.assertLess(body.index('world.time < body_motion_until'), body.rindex('\ttransform = rest'))

    def test_recoil_hooks(self):
        weapon = proc_body(DEFENSE, '/mob/living/human/hit_with_weapon(')
        self.assertIn('if (effective_force && blocked < 2)\n\t\tbody_motion_recoil(user)', weapon)
        self.assertIn('toxic=H.lizard)\n\t\t\t\tbody_motion_recoil(H)', ATTACKHAND)

    def test_config_line(self):
        self.assertIn('var/body_motion = BODY_MOTION_FULL', CONFIG)
        self.assertIn('if ("body_motion")', CONFIG)
        self.assertIn('BODY_MOTION', read('config/config.txt'))

    def test_fable_budgets(self):
        # Fall 4 ds ease-in through a feet-pivot lean with a 1px settle, stand-up 6 ds ease-out, recoil 3 ds.
        fall = proc_body(MOTION, '/mob/living/human/proc/body_motion_posture_change(')
        self.assertIn('BODY_MOTION_PRIORITY_POSTURE, 4, rest', fall)
        self.assertIn('time = 2, easing = QUAD_EASING | EASE_IN', fall)
        self.assertEqual(fall.count('? 45 : -45'), 2)
        self.assertIn('BODY_MOTION_PRIORITY_POSTURE, 6, rest', fall)
        self.assertIn('SINE_EASING | EASE_OUT', fall)
        recoil = proc_body(MOTION, '/mob/living/human/proc/body_motion_recoil(')
        self.assertIn('BODY_MOTION_PRIORITY_COMBAT, 3, rest', recoil)
        self.assertIn('dx * 3, dy * 3, dx * 8', recoil)


if __name__ == '__main__':
    unittest.main()
