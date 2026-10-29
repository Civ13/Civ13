"""Offline projection of actual DM callback/step bodies, not native DM proof.

Only the small syntax used by these production bodies is translated. Native
location, type checks, probability draws and terminal/recursive effects are
explicit adapters. Unknown syntax/calls fail rather than silently being skipped.
"""
import ast
import argparse
import hashlib
import itertools
import json
from pathlib import Path
import re
from types import MethodType, SimpleNamespace as State
import unittest

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SOURCE = (ROOT / 'code/game/objects/farming.dm').read_text(encoding='utf-8')
BASE_GROWTH = json.loads((HERE / 'baseline_growth.json').read_text(encoding='utf-8'))['source']
PIN = json.loads((HERE / 'source.json').read_text())
BASE = '/obj/structure/farming/plant/'
HELPER = BASE + 'proc/advance_stage_if_allowed(allow_stage)'
GROWTH = BASE + 'proc/growth()'
CROPS = ('potato', 'carrot', 'cabbage', 'tomato', 'beans', 'wheat')
MAPS = ('CONTINENTAL', 'PANGEA', 'NEW_WORLD', 'MEDITERRANEAN', 'EUROPE', 'GAIA')
COMPARISONS = 0


def block(source, signature):
    start = source.index(signature + '\n')
    end = re.search(r'^/[^/*]', source[start + len(signature) + 1:], re.M)
    finish = start + len(signature) + 1 + end.start() if end else len(source)
    return source[start:finish].rstrip()


def callback(growth):
    head, body = growth.split('\t\tspawn(600) // 1 minute \n', 1)
    return head, body


FIELDS = ('vstatic', 'stage', 'readyStageMin', 'readyStageMax', 'biomes', 'seasons', 'plant_nutrition')
METHODS = ('stageGrowth', 'advance_stage_if_allowed', 'set_dead', 'growth', 'prob', 'base_stage')


def expression(value):
    value = re.sub(r'(?<![\w\"\'])/obj/[\w/]+', lambda m: repr(m[0]), value)
    pieces = re.split(r'("[^"\n]*"|\'[^\'\n]*\')', value)
    for i in range(0, len(pieces), 2):
        s = pieces[i].replace('&&', ' and ').replace('||', ' or ')
        s = re.sub(r'!(?!=)', 'not ', s)
        for name, replacement in [('TRUE', 'True'), ('FALSE', 'False'), ('null', 'None'), ('src', 'self')]:
            s = re.sub(r'\b' + name + r'\b', replacement, s)
        s = re.sub(r'(?<![\w.])(' + '|'.join(FIELDS + METHODS) + r')\b', r'self.\1', s)
        s = re.sub(r'\blist\(', 'DMList(', s)
        pieces[i] = s
    return ''.join(pieces).strip()


def compile_body(body, arguments='self'):
    rows = []
    for raw in body.splitlines():
        text = raw.split('//', 1)[0].rstrip()
        if text.strip():
            indent = len(text) - len(text.lstrip('\t'))
            rows.append((indent, text.strip()))
    minimum = min(depth for depth, _ in rows)
    lines = [f'def projected({arguments}):']
    for depth, text in rows:
        if text.startswith('var/'):
            text = re.sub(r'^var/(?:\w+/)*(\w+)\s*=', r'\1 =', text)
        if text == 'return ..()':
            text = 'return self.base_stage()'
        elif text == 'return':
            pass
        elif text.startswith('else if'):
            match = re.fullmatch(r'else if\s*\((.*)\)', text)
            if not match:
                raise ValueError('Unsupported elif: ' + text)
            text = 'elif ' + expression(match[1]) + ':'
        elif text == 'else':
            text = 'else:'
        elif text.startswith('if'):
            match = re.fullmatch(r'if\s*\((.*)\)', text)
            if not match:
                raise ValueError('Unsupported if: ' + text)
            text = 'if ' + expression(match[1]) + ':'
        elif text.startswith('for'):
            match = re.fullmatch(r'for\s*\(var/(\w+) in (\w+)\)', text)
            if not match:
                raise ValueError('Unsupported loop: ' + text)
            text = 'for ' + match[1] + ' in ' + expression(match[2]) + ':'
        elif text.endswith('++'):
            text = expression(text[:-2]) + ' += 1'
        else:
            text = expression(text)
        lines.append('    ' * (depth - minimum + 1) + text)
    try:
        tree = ast.parse('\n'.join(lines))
    except SyntaxError as error:
        raise ValueError('Unsupported projected statement syntax') from error
    allowed = (ast.Module, ast.FunctionDef, ast.arguments, ast.arg, ast.If, ast.For,
               ast.Assign, ast.AugAssign, ast.Return, ast.Expr, ast.Name, ast.Load,
               ast.Store, ast.Constant, ast.Attribute, ast.Call, ast.BoolOp, ast.And,
               ast.Or, ast.UnaryOp, ast.Not, ast.Compare, ast.Eq, ast.NotEq, ast.Lt,
               ast.LtE, ast.Gt, ast.GtE, ast.Add, ast.Sub, ast.BinOp)
    calls = {'DMList', 'get_turf', 'get_area', 'istype', 'winter_crop_plot_error'}
    for node in ast.walk(tree):
        if not isinstance(node, allowed):
            raise ValueError('Unsupported syntax: ' + type(node).__name__)
        if isinstance(node, ast.Attribute) and node.attr.startswith('_'):
            raise ValueError('Private attribute forbidden')
        if isinstance(node, ast.Call):
            name = node.func.id if isinstance(node.func, ast.Name) else node.func.attr
            if name not in calls | set(METHODS) | {'Find'}:
                raise ValueError('Unsupported call: ' + name)
    return compile(tree, '<source-projected-crop-step>', 'exec')


class DMList(list):
    def __init__(self, *items):
        super().__init__(items)

    def Find(self, item):
        return self.index(item) + 1 if item in self else 0


class Plant(State):
    def __bool__(self):
        return not self.retired


def crop_lists(kind):
    def get(path, field, fallback):
        declaration = block(SOURCE, path)
        match = re.search(r'^\t(?:var/list/)?' + field + r' = list\(([^\n]+)\)', declaration, re.M)
        return re.findall(r'"([^\"]+)"', match[1]) if match else fallback
    biomes = get(BASE.rstrip('/'), 'biomes', [])
    seasons = get(BASE.rstrip('/'), 'seasons', [])
    if kind in CROPS:
        return get(BASE + kind, 'biomes', biomes), get(BASE + kind, 'seasons', seasons)
    return biomes, seasons


class Program:
    def __init__(self, source, growth):
        _, body = callback(growth)
        self.callback = compile_body(body)
        stage = block(source, BASE + 'proc/stageGrowth()  // Uses plant_nutrition as Use the plant\'s nutrition as a chance to grow')
        self.base_stage = compile_body('\n'.join(stage.splitlines()[1:]))
        self.helper = compile_body('\n'.join(block(source, HELPER).splitlines()[1:]), 'self, allow_stage') if HELPER in source else None
        self.overrides = {}
        for kind in ('turnip', 'plump_helmet'):
            self.overrides[kind] = compile_body('\n'.join(block(source, BASE + kind + '/stageGrowth()').splitlines()[1:]))

    def run(self, kind='tomato', stage=6, nutrition=100, climate='temperate', season='SUMMER',
            map_id='continental', location=1, rolls=(0, 99, 49), retired=False, vstatic=False,
            turf=True, area=True, blocked=False):
        biomes, seasons = crop_lists(kind)
        p = Plant(kind=kind, stage=stage, plant_nutrition=nutrition, biomes=biomes,
                  seasons=seasons, readyStageMin=7, readyStageMax=10, retired=retired,
                  vstatic=vstatic, events=[])
        a = State(location=location, climate=climate) if area else None
        t = State(area=a, blocked=blocked, plant=p) if turf else None
        stream = itertools.cycle(rolls)
        def prob(chance):
            roll = next(stream)
            p.events.append(('prob', chance, roll))
            return roll < chance
        def get_turf(owner):
            owner.events.append('get_turf')
            return t
        def get_area(tile):
            p.events.append('get_area')
            return tile.area
        def istype(owner, path):
            family = {'plump_helmet': 'mushroom'}.get(owner.kind, owner.kind)
            return path == BASE.rstrip('/') + '/' + family
        env = {'__builtins__': {}, 'DMList': DMList, 'get_turf': get_turf,
               'get_area': get_area, 'istype': istype, 'season': season,
               'map': State(ID=map_id), 'winter_crop_plot_error': lambda tile: tile.blocked}
        env.update({'MAP_NOMADS_' + name: name.lower() for name in MAPS})
        def attach(code):
            exec(code, env)
            return MethodType(env['projected'], p)
        p.prob = prob
        actual_base = attach(self.base_stage)
        p.base_stage = lambda: (p.events.append('base_stage'), actual_base())[1]
        actual_virtual = attach(self.overrides[kind]) if kind in self.overrides else p.base_stage
        p.stageGrowth = lambda: (p.events.append(('virtual', kind)), actual_virtual())[1]
        p.growth = lambda: p.events.append('growth_reentry')
        def dead():
            p.stage = 11
            p.events.append('set_dead')
        p.set_dead = dead
        if self.helper:
            p.advance_stage_if_allowed = attach(self.helper)
        attach(self.callback)()
        return p.stage, p.events


CURRENT_GROWTH = block(SOURCE, GROWTH)
BEFORE = Program(SOURCE, BASE_GROWTH)
AFTER = Program(SOURCE, CURRENT_GROWTH)


class CropStageStep(unittest.TestCase):
    def parity(self, **state):
        global COMPARISONS
        left, right = BEFORE.run(**state), AFTER.run(**state)
        COMPARISONS += 1
        self.assertEqual(left, right, state)
        return right

    def test_only_allowed_farming_changes_project_to_pinned_blob(self):
        intro = '// Shared stage boundary only: callers own eligibility, resources and cadence.\n// Keep virtual stageGrowth dispatch and the terminal check even when paused.\n'
        helper = block(SOURCE, HELPER)
        without = SOURCE.replace(intro + helper + '\n\n', '')
        self.assertNotEqual(without, SOURCE)
        changed_growth = block(without, GROWTH)
        restored = without.replace(changed_growth, BASE_GROWTH.rstrip(), 1)
        payload = restored.encode('utf-8')
        blob = hashlib.sha1(b'blob ' + str(len(payload)).encode() + b'\0' + payload).hexdigest()
        self.assertEqual(blob, PIN['baseline_farming_blob'])

    def test_sampling_and_wait_prefix_are_identical(self):
        self.assertEqual(callback(BASE_GROWTH)[0], callback(CURRENT_GROWTH)[0])
        self.assertEqual(CURRENT_GROWTH.count('spawn(600)'), 1)
        self.assertEqual(block(SOURCE, HELPER).count('stageGrowth()'), 1)
        self.assertNotIn('spawn(', block(SOURCE, HELPER))
        self.assertNotIn('growth()', block(SOURCE, HELPER))

    def test_six_crops_all_restricted_maps_and_thresholds(self):
        for args in itertools.product(CROPS, (1, 6, 7, 10, 11), (0, 39, 40, 80, 81),
                                      ('temperate', 'desert', 'tundra', 'unknown'),
                                      ('SUMMER', 'WINTER', 'SPRING'),
                                      tuple(x.lower() for x in MAPS) + ('fixed-era',),
                                      (0, 1), ((0, 99, 49), (99, 0, 50))):
            kind, stage, nutrition, climate, season, map_id, location, rolls = args
            self.parity(kind=kind, stage=stage, nutrition=nutrition, climate=climate,
                        season=season, map_id=map_id, location=location, rolls=rolls)

    def test_pending_dead_static_retired_and_missing_locations(self):
        for state in ({'stage': 11}, {'vstatic': True}, {'retired': True}, {'turf': False}, {'area': False}):
            for kind in CROPS + ('mushroom', 'mushroompsy', 'plump_helmet', 'turnip'):
                self.parity(kind=kind, **state)
        for state in ({'stage': 11}, {'vstatic': True}, {'retired': True}):
            self.assertEqual(AFTER.run(**state)[1], [])

    def test_virtual_crop_overrides_and_indoor_exception(self):
        for kind, stage, blocked, rolls, nutrition in itertools.product(
                ('mushroom', 'mushroompsy', 'plump_helmet', 'turnip'), (1, 6, 7, 10),
                (False, True), ((0, 0, 0), (99, 99, 99), (49, 79, 19)), (0, 80, 81)):
            self.parity(kind=kind, stage=stage, blocked=blocked, rolls=rolls,
                        nutrition=nutrition, location=0)

    def test_turnip_shelter_and_plump_probability_are_not_bypassed(self):
        stage, calls = self.parity(kind='turnip', blocked=True, stage=6)
        self.assertEqual(stage, 6)
        self.assertNotIn('base_stage', calls)
        stage, calls = self.parity(kind='plump_helmet', location=0, rolls=(99,), stage=6)
        self.assertEqual(stage, 6)
        self.assertIn(('prob', 50, 99), calls)
        self.assertNotIn('base_stage', calls)

    def test_overripe_terminal_order_and_zero_nutrition_probability(self):
        stage, events = self.parity(stage=10, nutrition=100)
        self.assertEqual(stage, 11)
        self.assertLess(events.index('set_dead'), events.index('growth_reentry'))
        self.assertIn(('prob', 20, 0), self.parity(nutrition=0, rolls=(0,))[1])

    def test_helper_false_still_runs_terminal_check(self):
        for stage, expected in ((6, []), (11, ['dead'])):
            events = []
            plant = State(stage=stage, readyStageMax=10,
                          set_dead=lambda: events.append('dead'),
                          stageGrowth=lambda: self.fail('Ineligible virtual call'))
            env = {'__builtins__': {}}
            exec(AFTER.helper, env)
            env['projected'](plant, False)
            self.assertEqual(events, expected)

    def test_timbers_separate_scheduler_remains_owned(self):
        tree = block(SOURCE, BASE + 'tree/growth()')
        self.assertIn('processing_objects |= src', tree)
        self.assertNotIn('advance_stage_if_allowed', tree)
        self.assertNotIn('spawn(', tree)
        # All tree methods are also protected by the complete-file projection.

    def test_native_extractor_current_and_historical_compatibility(self):
        runner = (ROOT / 'tests/plant_lifecycle/run.ps1').read_text()
        self.assertIn("$names += 'advance_stage_if_allowed'", runner)
        conditional = runner.index("if ($source -match '(?m)^/obj/structure/farming/plant/proc/advance_stage_if_allowed")
        self.assertLess(conditional, runner.index('$procs = foreach'))
        # Mirror only the proc-selection rule, without invoking the native runner.
        names = ['readyHarvest', 'growth', 'stageGrowth', 'soil_nutrition_proc', 'set_dead', 'water_proc']
        for source, expected in ((SOURCE, 7), (SOURCE.replace(block(SOURCE, HELPER), ''), 6)):
            selected = names + (['advance_stage_if_allowed'] if re.search(r'^' + re.escape(HELPER), source, re.M) else [])
            self.assertEqual(len(selected), expected)

    def test_intended_semantic_mutation_controls(self):
        helper = block(SOURCE, HELPER)
        controls = [
            ('eligibility', helper.replace('if (allow_stage)', 'if (TRUE)'),
             dict(kind='tomato', climate='unknown', map_id='continental')),
            ('virtual dispatch', helper.replace('stageGrowth()', 'stage += 1'),
             dict(kind='turnip', blocked=True, stage=6)),
            ('terminal appearance', helper.replace('set_dead()', 'return'),
             dict(stage=10, nutrition=100)),
            ('double advancement', helper.replace('\t\tstageGrowth()', '\t\tstageGrowth()\n\t\tstageGrowth()'),
             dict(stage=6, nutrition=100)),
        ]
        for name, replacement, witness in controls:
            mutant = Program(SOURCE.replace(helper, replacement), CURRENT_GROWTH)
            self.assertNotEqual(BEFORE.run(**witness), mutant.run(**witness), name)

    def test_unknown_projection_syntax_is_rejected(self):
        with self.assertRaises(ValueError):
            compile_body('\tspawn(10)\n\t\tstageGrowth()')
        with self.assertRaises(ValueError):
            compile_body('\tworld.Reboot()')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--only', help='Run one named test method for focused repairs')
    options = parser.parse_args()
    suite = (unittest.defaultTestLoader.loadTestsFromName(options.only, CropStageStep)
             if options.only else unittest.defaultTestLoader.loadTestsFromTestCase(CropStageStep))
    outcome = unittest.TextTestRunner(verbosity=2).run(suite)
    report = dict(status='PASS' if outcome.wasSuccessful() else 'FAIL', tests=outcome.testsRun,
                  comparisons=COMPARISONS, upstream_ref=PIN['upstream_ref'],
                  scope='Offline source projection and immutable reverse projection; injected engine boundaries',
                  native_executed=False,
                  mutation_controls=4 if not options.only or options.only == 'test_intended_semantic_mutation_controls' else 0,
                  failures=len(outcome.failures), errors=len(outcome.errors))
    print(json.dumps(report, sort_keys=True))
    raise SystemExit(0 if outcome.wasSuccessful() else 1)
