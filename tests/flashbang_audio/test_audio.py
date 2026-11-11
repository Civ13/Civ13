"""Offline projection of flashbang dispatch and sound, with injected engine boundaries."""
import hashlib
import importlib.util
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/objects/items/weapons/grenades/flashbang.dm'
ORIGINAL = Path(__file__).with_name('original_flashbang.dm')
ORIGINAL_BLOB = 'dc10dd4d5ec7526fe483df12eecd06f31f4e7a9d'
spec = importlib.util.spec_from_file_location('source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


def project_flashbang(source, outdoors, enclosed):
    """Project source loops and bang's output prefix, faking DM engine operations.

    The rest of bang is represented by a per-target effect callback. Its sound
    calls are checked separately so this boundary cannot hide a second blast.
    """
    prime = adapter.extract(source, 'prime')
    bang = adapter.extract(source, 'proc/bang')
    prefix, separator, tail = bang.partition('\tvar/eye_safety = 0')
    if not separator or re.search(r'\bplaysound\s*\(', tail):
        raise AssertionError('bang effect boundary changed or contains a sound call')
    prefix = re.sub(r'\tto_chat\(M, [^\n]*\)', '\tto_chat(M)', prefix)
    if 'to_chat(M)' not in prefix:
        raise AssertionError('bang message boundary changed')
    prefix += '\n\teffect(M)\n'

    events, affected = [], []
    src = SimpleNamespace(loc='blast turf')
    closets = [SimpleNamespace(contents=list(enclosed))] if enclosed else []

    def typed_iter(values, kind):
        if kind == '/obj/structure/closet':
            return [v for v in values if hasattr(v, 'contents')]
        if kind == '/mob/living/human':
            if hasattr(values, 'contents'):
                return values.contents
            return [v for v in values if not hasattr(v, 'contents')]
        raise AssertionError('unexpected loop type ' + kind)

    def playsound(*args):
        events.append(args)

    env = {'src': src, 'loc': src.loc, 'playsound': playsound,
           'to_chat': lambda *_: None, 'effect': affected.append}
    execute_bang = adapter.project('/fixture/bang(T, M)\n' + prefix,
                                   '/fixture/bang', 'T, M', env)
    prime = prime.replace('\t\t..()', '\t\tparent_prime()')
    prime = prime.replace('locate(/mob/living/human/, L)', 'locate_human(L)')
    prime = re.sub(r'\t\tnew/obj/effect/[^\n]+', '\t\tvisual_effect()', prime)
    # extract() strips the declaration's one-tab nesting, leaving its body at
    # one tab. Normalize only the specific engine operations, never the loops.
    prime = prime.replace('\t..()', '\tparent_prime()')
    prime = re.sub(r'\tnew/obj/effect/[^\n]+', '\tvisual_effect()', prime)
    env.update({'parent_prime': lambda: None, 'typed_iter': typed_iter,
                'hear': lambda *_: closets + list(outdoors),
                'get_turf': lambda *_: src.loc,
                'locate_human': lambda closet: bool(closet.contents),
                'bang': execute_bang, 'visual_effect': lambda: None,
                'qdel': lambda *_: None})
    execute_prime = adapter.project('/fixture/prime()\n' + prime + '\n',
                                    '/fixture/prime', '', env)
    execute_prime()
    return events, affected


class FlashbangAudioTests(unittest.TestCase):
    def test_frozen_original_reproduces_victim_dependent_sound_count(self):
        # The Windows checkout may expand the Git blob's LF to CRLF.
        data = ORIGINAL.read_bytes().replace(b'\r\n', b'\n')
        digest = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
        self.assertEqual(digest, ORIGINAL_BLOB)
        old = data.decode('utf-8-sig')
        for count in (0, 1, 3):
            with self.subTest(count=count):
                targets = [object() for _ in range(count)]
                events, affected = project_flashbang(old, targets, [])
                self.assertEqual(len(events), count)
                self.assertEqual(affected, targets)

    def test_one_blast_sound_with_zero_one_or_multiple_affected_humans(self):
        source = SOURCE.read_text(encoding='utf-8-sig')
        for outdoor_count, enclosed_count in ((0, 0), (1, 0), (2, 1)):
            with self.subTest(outdoor=outdoor_count, enclosed=enclosed_count):
                outdoors = [object() for _ in range(outdoor_count)]
                enclosed = [object() for _ in range(enclosed_count)]
                events, affected = project_flashbang(source, outdoors, enclosed)
                self.assertEqual(len(events), 1)
                self.assertCountEqual(affected, outdoors + enclosed)
                self.assertEqual(events[0][1], 'sound/effects/bang.ogg')


if __name__ == '__main__':
    unittest.main()
