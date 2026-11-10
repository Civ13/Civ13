"""Exercise the production glass-jar capture tail through an offline adapter."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('jar_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SOURCE = (ROOT / 'code/game/objects/items/glassjar.dm').read_text(encoding='utf-8-sig')


class Animal:
    def __init__(self, buckled=False, pinned=False, movable=True):
        self.buckled = buckled
        self.pinned = SimpleNamespace(len=int(pinned))
        self.movable = movable
        self.location = 'floor'

    def forceMove(self, destination):
        if not self.movable:
            return False
        self.location = destination
        return True


def capture(animal):
    body = adapter.extract(SOURCE, '/obj/item/glass_jar/afterattack').splitlines()
    start = next(i for i, line in enumerate(body) if line.strip() == 'var/mob/L = A')
    lines = ['\t' + line[2:] for line in body[start:]]
    jar = object()
    messages = []
    user = SimpleNamespace(visible_message=lambda *args: messages.append(args))
    env = {'to_chat': lambda *args: None, 'SPAN_WARNING': lambda text: text,
           'update_icon': lambda: messages.append('icon')}
    proc = adapter.project('/test/proc/run()\n' + '\n'.join(lines) + '\n', '/test/proc/run', 'A, user, src', env)
    proc(animal, user, jar)
    return animal.location, messages, jar


class GlassJarCaptureTests(unittest.TestCase):
    def test_restrained_animals_stay_put(self):
        for kwargs in ({'buckled': True}, {'pinned': True}):
            with self.subTest(kwargs=kwargs):
                location, messages, _ = capture(Animal(**kwargs))
                self.assertEqual(location, 'floor')
                self.assertEqual(messages, [])

    def test_success_requires_a_move(self):
        location, messages, jar = capture(Animal())
        self.assertIs(location, jar)
        self.assertTrue(messages)
        location, messages, _ = capture(Animal(movable=False))
        self.assertEqual(location, 'floor')
        self.assertEqual(messages, [])


if __name__ == '__main__':
    unittest.main()
