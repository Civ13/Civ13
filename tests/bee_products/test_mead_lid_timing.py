"""Offline projection of barrel lid actions and timer scheduling."""
from pathlib import Path
import re
import unittest

SOURCE = Path(__file__).resolve().parents[2] / 'code/modules/1713/mead.dm'
BARREL = '/obj/item/weapon/reagent_containers/glass/barrel'


class MeadTimerTests(unittest.TestCase):
    def test_reclosing_requires_a_fresh_closed_interval(self):
        source = SOURCE.read_text(encoding='utf-8')
        open_lid = True
        now = 0
        next_id = 0
        deadlines = {}
        must = 10

        def flip_lid():
            nonlocal open_lid
            open_lid = not open_lid

        def addtimer(_callback, delay, flags=None):
            nonlocal next_id
            next_id += 1
            deadlines[next_id] = now + delay
            return next_id

        seconds = int(re.search(r'^#define MEAD_SPELL \((\d+) MINUTES\)', source, re.M)[1]) * 60
        env = dict(src=object(), MEAD_SPELL=seconds, TIMER_STOPPABLE=8,
                   mead_timer=None, mead_working=False,
                   reagents=object(), is_open_container=lambda: open_lid,
                   QDELETED=lambda _: False, has_must=lambda: must,
                   flip_lid=flip_lid, addtimer=addtimer, deltimer=lambda key: deadlines.pop(key))

        for name, declaration in (
            ('attack_self', '/attack_self'),
            ('mead_schedule', '/proc/mead_schedule'),
            ('mead_cancel', '/proc/mead_cancel'),
        ):
            match = re.search(r'^' + re.escape(BARREL + declaration) + r'\([^)]*\)\n((?:\t.*\n)+)',
                              source, re.M)
            if not match and name == 'mead_cancel':
                continue  # Historical source did not have cancellation.
            self.assertIsNotNone(match, name)
            body = match[1].replace('. = ..()', 'flip_lid()')
            body = body.replace('CALLBACK(src, PROC_REF(mead_work))', 'None')
            body = body.replace('reagents.get_reagent_amount("honey_must")', 'has_must()')
            body = body.replace('||', 'or').replace('!', 'not ')
            body = re.sub(r'\b(NULL|null|FALSE|TRUE)\b',
                          lambda token: dict(NULL='None', null='None', FALSE='False', TRUE='True')[token[0]], body)
            body = re.sub(r'if \((.+)\)$', r'if (\1):', body, flags=re.M)
            body = re.sub(r'^(\t*)else$', r'\1else:', body, flags=re.M)
            exec(f'def {name}():\n\tglobal mead_timer, mead_working\n' + body, env)

        env['attack_self']()
        self.assertEqual(list(deadlines.values()), [120])
        now = 1
        env['attack_self']()
        self.assertEqual(deadlines, {})
        now = 119
        must = 5  # Replace the batch while open.
        env['attack_self']()
        self.assertEqual(list(deadlines.values()), [239])
        env['mead_schedule']()
        self.assertEqual(list(deadlines.values()), [239])  # No duplicate timer.

    def test_loading_uses_same_sealed_barrel_gate(self):
        source = SOURCE.read_text(encoding='utf-8')
        self.assertIn(BARREL + '/after_load()\n\t..()\n\tmead_schedule()', source)
        self.assertIn('key == "mead_timer" || ..()', source)
        self.assertIn('is_open_container() || !reagents || reagents.get_reagent_amount("honey_must") <= 0', source)


if __name__ == '__main__':
    unittest.main()
