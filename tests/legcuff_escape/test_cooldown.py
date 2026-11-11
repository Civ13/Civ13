"""Project the resist cooldown path; this does not run BYOND or gameplay."""
import importlib.util
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


def read(path):
    return (ROOT / path).read_text(encoding='utf-8-sig')


def fixture(body):
    return '/fixture/run()\n' + body + '\n'


class ResistProjection:
    def __init__(self, escape_source, *, next_move=0, disabled=False, stat=0, weakened=False):
        self.world = SimpleNamespace(time=100)
        self.actor = SimpleNamespace(next_move=next_move)
        self.config = SimpleNamespace(no_click_cooldown=disabled)
        self.started = False
        click = read('code/_onclick/click.dm')
        can_click = adapter.extract(click, '/mob/proc/canClick').replace('next_move', 'actor.next_move')
        self.can_click = adapter.project(fixture(can_click), '/fixture/run', '', {
            'actor': self.actor, 'world': self.world, 'config': self.config,
        })
        cooldown = adapter.extract(click, '/mob/proc/setClickCooldown').replace('next_move', 'actor.next_move')
        set_cooldown = adapter.project('/fixture/set(timeout)\n' + cooldown + '\n',
                                       '/fixture/set', 'timeout', {
                                           'actor': self.actor, 'world': self.world, 'max': max,
                                       })
        escape = adapter.extract(escape_source, '/mob/living/human/proc/escape_legcuffs')
        # Project every executable line before the strength branch. Reaching that
        # branch means the escape started; the later wait is outside this test.
        prefix, separator, _ = escape.partition('\tif (can_break_cuffs())')
        if not separator:
            raise AssertionError('escape strength branch not found')
        self.escape = adapter.project(fixture(prefix + '\treturn TRUE'), '/fixture/run', '', {
            'canClick': self.can_click, 'setClickCooldown': set_cooldown,
        })
        human = adapter.extract(escape_source, '/mob/living/human/process_resist')
        if '\telse if (legcuffed)\n\t\tspawn() escape_legcuffs()' not in human:
            raise AssertionError('legcuff dispatch changed')
        # The real spawn is deferred. The caller supplies the scheduling tick.
        self.pending = False
        def process_resist():
            self.pending = True
        verb = adapter.extract(read('code/game/mob/living/living.dm'), '/mob/living/verb/resist')
        self.resist = adapter.project(fixture(verb), '/fixture/run', '', {
            'stat': stat, 'weakened': weakened, 'canClick': self.can_click,
            'setClickCooldown': set_cooldown, 'resist_grab': lambda: None,
            'process_resist': process_resist, 'resist_knockdown': lambda: None,
        })

    def dispatch(self, elapsed=1):
        if self.pending:
            self.world.time += elapsed
            self.started = bool(self.escape())
        return self.started


def project_completion(source, actor, original, *, completed=True, buckled=False):
    body = adapter.extract(source, '/mob/living/human/proc/escape_legcuffs')
    start = body.index('\tif (do_after(src, breakouttime,')
    body = body[start:]
    # Message text is an engine output boundary; keep the actual guards and mutations.
    body, count = re.subn(r'\t\tvisible_message\(\n(?:\t\t\t[^\n]*\n)+\t\t\t\)',
                          '\t\tvisible_message()', body)
    if count != 1:
        raise AssertionError('completion message boundary changed')
    body = re.sub(r'(?<![\w.])legcuffed\b', 'actor.legcuffed', body)
    removed = []
    check = adapter.project(fixture(body), '/fixture/run', '', {
        'src': actor, 'actor': actor, 'HC': original, 'buckled': buckled,
        'breakouttime': 300, 'INCAPACITATION_DEFAULT': 0,
        'INCAPACITATION_RESTRAINED': 0, 'do_after': lambda *a, **kw: completed,
        'visible_message': lambda: None, 'drop_from_inventory': removed.append,
        'update_inv_legcuffed': lambda: None,
    })
    check()
    return removed


class LegcuffCooldownTests(unittest.TestCase):
    def setUp(self):
        self.source = read('code/game/mob/living/carbon/resist.dm')

    def test_ready_legcuffed_player_starts_escape_on_next_tick(self):
        action = ResistProjection(self.source)
        action.resist()
        self.assertTrue(action.dispatch())
        self.assertEqual(action.actor.next_move, 201)

    def test_hypothetical_removal_of_redundant_guard_starts_escape(self):
        guard = '\tif (!canClick())\n\t\treturn\n\n'
        prefix, body = self.source.split('/mob/living/human/proc/escape_legcuffs()', 1)
        self.assertLessEqual(body.count(guard), 1)
        fixed = prefix + '/mob/living/human/proc/escape_legcuffs()' + body.replace(guard, '', 1)
        action = ResistProjection(fixed)
        action.resist()
        self.assertTrue(action.dispatch())
        self.assertEqual(action.actor.next_move, 201)

        # Reintroduce the old guard as a negative control after the fix lands.
        old = prefix + '/mob/living/human/proc/escape_legcuffs()\n' + guard + body.replace(guard, '', 1).lstrip('\n')
        blocked = ResistProjection(old)
        blocked.resist()
        self.assertFalse(blocked.dispatch())

    def test_cooldown_exemption_is_a_control(self):
        action = ResistProjection(self.source, disabled=True)
        action.resist()
        self.assertTrue(action.dispatch())
        self.assertEqual(action.actor.next_move, 201)

    def test_existing_cooldown_and_incapacitation_block_the_verb(self):
        for kwargs in ({'next_move': 101}, {'stat': 1}, {'weakened': True}):
            with self.subTest(kwargs=kwargs):
                action = ResistProjection(self.source, **kwargs)
                action.resist()
                self.assertFalse(action.dispatch())

    def test_completion_releases_original_but_not_missing_or_replacement(self):
        # With the existing exemption, the same path reaches the wait even on
        # the unpatched source. Fake the helper's two four-second strip actions;
        # invoke completion at 30 s, with do_after's engine result injected.
        action = ResistProjection(self.source, disabled=True)
        action.resist()
        self.assertTrue(action.dispatch())
        self.assertIn('breakouttime = HC.breakouttime', self.source)
        self.assertRegex(read('code/game/objects/items/weapons/legcuffs.dm'),
                         r'breakouttime\s*=\s*300\b')
        original, replacement = object(), object()
        for current, expected in ((original, [original]), (None, []), (replacement, [])):
            with self.subTest(current=current):
                actor = SimpleNamespace(legcuffed=current)
                self.assertEqual(project_completion(self.source, actor, original), expected)
                self.assertIs(actor.legcuffed, None if current is original else current)

        for kwargs in ({'completed': False}, {'buckled': True}):
            with self.subTest(kwargs=kwargs):
                actor = SimpleNamespace(legcuffed=original)
                self.assertEqual(project_completion(self.source, actor, original, **kwargs), [])
                self.assertIs(actor.legcuffed, original)

    def test_old_completion_guard_is_a_negative_control(self):
        # Derive the vulnerable guard from the current source even after a fix.
        declaration = '/mob/living/human/proc/escape_legcuffs()'
        prefix, body = self.source.split(declaration, 1)
        before, after = body.split('\tif (do_after(src, breakouttime,', 1)
        after, count = re.subn(r'\t\tif \([^\n]*buckled[^\n]*\)',
                               '\t\tif (!legcuffed || buckled)', after, count=1)
        self.assertEqual(count, 1)
        old = prefix + declaration + before + '\tif (do_after(src, breakouttime,' + after
        original, replacement = object(), object()
        actor = SimpleNamespace(legcuffed=replacement)
        self.assertEqual(project_completion(old, actor, original), [replacement])
        self.assertIsNone(actor.legcuffed)


if __name__ == '__main__':
    unittest.main()
