"""Offline source contracts for smoke signals from campfires. Gameplay is
covered by the native probe:
python3 tests/ecology_spawning/run_linux.py . tests/signal_fires/probe.dm 300
"""
from pathlib import Path
import re
import struct
import unittest
from types import SimpleNamespace
import zlib

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/signal_fires.dm'
OVEN = ROOT / 'code/game/objects/structures/kitchen/oven.dm'
ICON = ROOT / 'icons/effects/signal_smoke.dmi'


def dmi_states(path):
    data = path.read_bytes()
    pos = 8
    while pos < len(data):
        length, kind = struct.unpack('>I4s', data[pos:pos + 8])
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b'zTXt' and chunk.startswith(b'Description\0'):
            text = zlib.decompress(chunk[len(b'Description\0') + 1:]).decode('utf-8')
            return set(re.findall(r'state = "([^"]*)"', text))
    return set()


class SignalFireSourceTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')
        self.oven = OVEN.read_text(encoding='utf-8')

    def test_included_after_the_campfire(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8').splitlines()
        self.assertLess(dme.index('#include "code\\game\\objects\\structures\\kitchen\\oven.dm"'),
                        dme.index('#include "code\\modules\\1713\\signal_fires.dm"'))

    def test_campfire_hands_cloth_and_leather_to_the_signal(self):
        self.assertIn('signal_fire_material(I)', self.oven)
        self.assertIn('send_smoke_signal(I, H)', self.oven)
        self.assertNotIn('proc/smoke_signals', self.oven)

    def test_cooldown_is_not_saved(self):
        self.assertIn('return key == "next_signal" || ..()', self.source)

    def test_plume_sprite_exists(self):
        self.assertIn('"signal_plume"', self.source)
        self.assertIn('signal_plume', dmi_states(ICON))

    def test_roof_blocks_both_ways(self):
        watchers = self.source[self.source.index('proc/signal_fire_watchers'):self.source.index('proc/send_smoke_signal')]
        self.assertEqual(watchers.count('signal_fire_open_sky('), 2)

    def test_only_recipients_count_without_losing_witness_geometry(self):
        source = self.source.split('for (var/mob/living/human/H in human_mob_list)', 1)[1]
        source = source.split('\n\t\t. += H', 1)[0].strip('\n')
        statements = {
            'if (!H.client && !agent_characters[H])': 'if not H.client and not any(H is agent for agent in agents):',
            ('if (H == signaller || !signal_fire_level_sees(H.z, T) || '
             'signal_fire_flat_dist(H, T) > signal_fire_range(T) || !signal_fire_can_see(H))'):
                'if H is signaller or not H.level or not H.in_range or not H.awake:',
            'if (!signal_fire_open_sky(H))': 'if not H.outdoors:',
            'continue': 'return False',
        }
        lines = ['def sees(H, signaller, agents):']
        for line in source.splitlines():
            if line.lstrip().startswith('//'):
                continue
            indent = len(line) - len(line.lstrip('\t')) - 1
            lines.append('    ' * indent + statements[line.strip()])
        lines.append('    return True')
        env = {}
        exec('\n'.join(lines), env)
        sees = env['sees']
        good = dict(client=True, level=True, in_range=True, awake=True, outdoors=True)
        body = SimpleNamespace(**(good | {'client': False}))
        player = SimpleNamespace(**good)
        self.assertFalse(sees(body, player, []), 'disconnected and uncontrolled body is not a witness')
        self.assertFalse(sees(body, player, [SimpleNamespace(**vars(body))]))
        self.assertTrue(sees(body, player, [body]), 'registered agent still receives its bearing')
        self.assertTrue(sees(player, body, []), 'connected awake player still sees smoke')
        self.assertFalse(sees(player, player, []), 'the signaller is notified separately')
        for attr in ('level', 'in_range', 'awake', 'outdoors'):
            with self.subTest(attr=attr):
                blocked = SimpleNamespace(**(good | {attr: False}))
                self.assertFalse(sees(blocked, body, []))
        self.assertIn('watchers.len ? "Someone out there can see it."', self.source)

    def test_the_fire_and_the_signal_say_how_it_works(self):
        examine = self.source.split('/obj/structure/oven/fireplace/examine(mob/user)', 1)[1]
        self.assertIn('. = ..()', examine)
        self.assertIn('if (on && signal_fire_open_sky(src))', examine)
        self.assertIn('Use leather or cloth on it to send a smoke signal.', examine)
        send = self.source[self.source.index('proc/send_smoke_signal'):self.source.index('/client/var/signal_fire_hint_shown')]
        self.assertIn('!H.client.signal_fire_hint_shown', send)
        self.assertIn('answer with a signal of your own', send)


if __name__ == '__main__':
    unittest.main()
