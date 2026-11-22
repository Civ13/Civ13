"""Offline source projection of sound dispatch; no BYOND server is launched."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/sound.dm'
MACROS = ROOT / 'code/_macros.dm'
spec = importlib.util.spec_from_file_location('sound_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
DECL = '/proc/playsound'
OLD = 'istype(source) && isnewplayer(M)'
NEW = 'isnewplayer(M) && istype(source)'


class Exclusions:
    def __init__(self, entries):
        self.entries = entries

    def Find(self, value):
        return value in self.entries


class Listener:
    def __init__(self, name, kinds, z=1, client=True, on_play=None):
        self.name, self.kinds, self.client, self.on_play = name, kinds, client, on_play
        self.loc = SimpleNamespace(z=z)

    def playsound_local(self, *args):
        self.events.append(('play', self.name))
        if self.on_play:
            self.on_play()


def execute(source_text, source, players, excluded=(), distance=1):
    events, calls = [], []
    for player in players:
        if player is not None:
            player.events = events
    def istype(value):
        calls.append('source')
        return bool(getattr(value, 'atom', False))
    def isnewplayer(value):
        calls.append('listener')
        return '/mob/new_player' in getattr(value, 'kinds', ())
    def get_turf(value):
        return getattr(value, 'loc', None)
    env = {
        'player_list': players, 'agent_characters': [],
        'isarea': lambda value: False, 'istype': istype, 'isnewplayer': isnewplayer,
        'get_sfx': lambda sound: sound, 'get_rand_frequency': lambda: 123,
        'get_turf': get_turf, 'get_dist': lambda mob, turf: distance if turf is not None else 99,
        'echofiends_hear': lambda *args: events.append(('echo',)),
        'agent_hear_sound': lambda *args: events.append(('agent',)),
    }
    body = adapter.extract(source_text, DECL)
    body = body.replace('players_who_heard += M', 'players_who_heard.append(M)')
    body = body.replace('agent_characters.len', 'len(agent_characters)')
    fn = adapter.project(DECL + '(source,soundin,vol,vary,extrarange,falloff,is_global,excluded)\n' + body + '\n',
                         DECL, 'source,soundin,vol,vary,extrarange,falloff,is_global,excluded', env)
    heard = fn(source, 'sound', 50, False, 0, None, False, Exclusions(excluded))
    return events, [item.name for item in heard], calls


class SoundDispatchTests(unittest.TestCase):
    def setUp(self):
        self.after = SOURCE.read_text(encoding='utf-8')
        self.assertEqual(self.after.count(NEW), 1)
        self.before = self.after.replace(NEW, OLD, 1)
        self.assertIn('#define isnewplayer(A) istype(A, /mob/new_player)', MACROS.read_text(encoding='utf-8'))

    def test_input_matrix_and_modeled_type_checks(self):
        for source_kind in ('atom', 'null', 'invalid'):
            for listener_kind in ('human', 'lobby', 'null', 'invalid'):
                with self.subTest(source=source_kind, listener=listener_kind):
                    source = SimpleNamespace(atom=True, loc=SimpleNamespace(z=1)) if source_kind == 'atom' else (None if source_kind == 'null' else 42)
                    listener = None if listener_kind == 'null' else Listener(listener_kind,
                        {'/mob/new_player'} if listener_kind == 'lobby' else ({'/mob/living'} if listener_kind == 'human' else set()), client=listener_kind != 'invalid')
                    old = execute(self.before, source, [listener])
                    new = execute(self.after, source, [listener])
                    self.assertEqual(old[:2], new[:2])
                    expected = -1 if source_kind == 'atom' and listener_kind != 'lobby' else (1 if source_kind != 'atom' and listener_kind == 'lobby' else 0)
                    self.assertEqual(len(new[2]) - len(old[2]), expected)

    def test_filters_and_source_mutation_preserve_order(self):
        def run(text):
            source = SimpleNamespace(atom=True, loc=SimpleNamespace(z=1))
            first = Listener('first', {'/mob/living'}, on_play=lambda: setattr(source, 'atom', False))
            lobby = Listener('lobby', {'/mob/new_player'})
            excluded = Listener('excluded', {'/mob/living'})
            remote = Listener('remote', {'/mob/living'}, z=2)
            offline = Listener('offline', {'/mob/living'}, client=False)
            return execute(text, source, [first, lobby, excluded, remote, offline], [excluded])[:2]
        self.assertEqual(run(self.before), run(self.after))
        self.assertEqual(run(self.after), ([('echo',), ('play', 'first'), ('play', 'lobby')], ['first', 'lobby']))
        self.assertNotEqual(run(self.after.replace(NEW, 'isnewplayer(M) || istype(source)', 1)), run(self.before))

    def test_out_of_range_does_not_play(self):
        source = SimpleNamespace(atom=True, loc=SimpleNamespace(z=1))
        player = Listener('far', {'/mob/living'})
        self.assertEqual(execute(self.after, source, [player], distance=22)[:2],
                         execute(self.before, source, [player], distance=22)[:2])
        self.assertEqual(execute(self.after, source, [player], distance=22)[1], [])


if __name__ == '__main__':
    unittest.main()
