"""Offline complete-source control-flow evidence, not BYOND/game acceptance.

Execute the entire current OpenFire, Shoot, load_sidearm, foe_ok and bound
procedures. Visibility, time, projectile launch and the gun's casing lifecycle
are explicit fake engine/subsystem boundaries. The fixture does not establish
native collision, wall penetration, timers, rendering or gun subsystem behavior.
No Git history, compiler, game process or network is used.
"""
import ast
import importlib.util
from pathlib import Path
import re
from types import SimpleNamespace, MethodType
import unittest

ROOT = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location('save_movement_source', ROOT / 'tests/save_movement/source_adapter.py')
_adapter = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_adapter)
extract = _adapter.extract
RAIDER = '/mob/living/simple_animal/hostile/human/nomad_raider'
REVOLVER = '/obj/item/weapon/gun/projectile/revolver/coltpolicepositive/standardized'
SOURCE = (ROOT / 'code/modules/nomad_raids/nomad_raider.dm').read_text()
VISIT = (ROOT / 'code/modules/nomad_raids/nomad_visit.dm').read_text()
CAPTURE = (ROOT / 'code/modules/nomad_raids/nomad_capture.dm').read_text()
FIELDS = {'stat', 'ranged', 'gun', 'party', 'target_mob', 'aggro_vision_range',
          'last_fire', 'firedelay', 'reload_at', 'Shoot', 'load_sidearm',
          'check_friendly_fire', 'visible_message', 'members'}


def project(source, declaration, args, env):
    """Strict small DM projection: every executable statement is translated.

    Unknown syntax/names/calls fail at preparation, including unreachable lines.
    Strings are opaque message values; no interpolation is asserted here.
    """
    lines = ['def projected(' + args + '):']
    for raw in extract(source, declaration).splitlines():
        code = raw.split('//', 1)[0].rstrip()
        if not code.strip():
            continue
        depth = len(code) - len(code.lstrip('\t'))
        code = code.strip()
        code = re.sub(r'\bvar/(?:\w+/)*(\w+)\b', r'\1', code)
        code = code.replace('/mob/living/simple_animal/hostile/human/nomad_raider', repr(RAIDER))
        code = re.sub(r'/mob/living/simple_animal(?=\))', repr('/mob/living/simple_animal'), code)
        code = code.replace('/atom/proc/set_light', repr('/atom/proc/set_light'))
        code = code.replace('new G.ammo_type(G)', 'new_casing(G)')
        # DM one-argument istype infers the variable's declared type.
        code = code.replace('istype(G)', 'is_sidearm(G)')
        code = code.replace('istype(H)', 'ishuman(H)')
        code = re.sub(r'\b(\d+) SECONDS\b', r'(\1 * 10)', code)
        # Avoid rewriting names, operators or DM escapes inside text literals.
        pieces = re.split(r'("(?:[^"\\]|\\.)*")', code)
        for i in range(len(pieces)):
            if i % 2:
                pieces[i] = repr(pieces[i][1:-1])
                continue
            part = pieces[i].replace('&&', ' and ').replace('||', ' or ')
            part = re.sub(r'!(?!=)', 'not ', part)
            for name, value in [('TRUE', 'True'), ('FALSE', 'False'), ('null', 'None')]:
                part = re.sub(r'\b' + name + r'\b', value, part)
            for name in FIELDS:
                part = re.sub(r'(?<![\w.])' + name + r'\b', 'src.' + name, part)
            pieces[i] = part
        code = ''.join(pieces)
        if code.startswith('else if '):
            code = 'elif ' + code[8:] + ':'
        elif code.startswith('if ') or code.startswith('while '):
            code += ':'
        elif code == 'else':
            code += ':'
        elif code.startswith('for '):
            match = re.fullmatch(r'for \((\w+) in (.*)\)', code)
            if not match:
                raise AssertionError('Unsupported loop: ' + code)
            code = f'for {match[1]} in {match[2]}:'
        elif not (code.startswith('return ') or re.fullmatch(r'[\w.]+ (?:=|\+=|-=) .+', code)
                  or re.fullmatch(r'[\w.]+\(.*\)', code)):
            raise AssertionError('Unsupported statement: ' + code)
        lines.append('    ' * depth + code)
    translated = '\n'.join(lines) + '\n'
    try:
        tree = ast.parse(translated)
    except SyntaxError as error:
        raise AssertionError('Unsupported DM syntax: ' + translated) from error
    names = set(args.replace('=False', '').replace(' ', '').split(',')) | {
        'projected', 'projectile', 'target_zone', 'G', 'C', 'SA'} | set(env)
    calls = {'QDELETED', 'view', 'get_dist', 'max', 'prob', 'pick', 'addtimer',
             'CALLBACK', 'SPAN_NOTICE', 'istype', 'ishuman', 'nomad_raid_bound',
             'qdel', 'new_casing', 'is_sidearm', 'Shoot', 'load_sidearm', 'check_friendly_fire',
             'visible_message', 'foe_ok', 'consume_next_projectile', 'handle_click_empty',
             'process_projectile', 'handle_post_fire', 'Copy', 'update_icon', 'los_terrain_ray_blocked'}
    allowed = {ast.Module, ast.FunctionDef, ast.arguments, ast.arg, ast.If, ast.While,
               ast.For, ast.Return, ast.Assign, ast.AugAssign, ast.Expr, ast.Name,
               ast.Load, ast.Store, ast.Constant, ast.Attribute, ast.Call, ast.BoolOp,
               ast.And, ast.Or, ast.UnaryOp, ast.Not, ast.Compare, ast.Eq, ast.NotEq,
               ast.Lt, ast.Gt, ast.In, ast.BinOp, ast.Add, ast.Sub, ast.Mult}
    for node in ast.walk(tree):
        if type(node) not in allowed:
            raise AssertionError('Unsupported AST: ' + type(node).__name__)
        if isinstance(node, ast.Name) and node.id not in names:
            raise AssertionError('Unknown symbol: ' + node.id)
        if isinstance(node, ast.Call):
            name = node.func.id if isinstance(node.func, ast.Name) else node.func.attr
            if name not in calls:
                raise AssertionError('Unsupported call: ' + name)
    namespace = dict(env)
    exec(compile(tree, declaration, 'exec'), namespace)
    return namespace['projected']


class DMList(list):
    @property
    def len(self):
        return len(self)

    def Copy(self):
        return list(self)

    def __iadd__(self, value):
        self.append(value)
        return self

    def __isub__(self, value):
        self.remove(value)
        return self


class Atom:
    def __init__(self, **values):
        self.deleted = False
        self.stat = 0
        self.handcuffed = False
        self.human = True
        self.__dict__.update(values)


class Gun(Atom):
    """Fake gun boundary: consume removes head; postfire/empty cycles it back.

    Intentionally not presented as execution of production gun procedures.
    The source contracts below pin the production configuration this fake needs.
    """
    def __init__(self, owner):
        super().__init__(loc=owner, loaded=DMList(), max_shells=6, load_delay=6,
                         fire_delay=3, next_fire_time=0, chambered=None,
                         chamber_offset=0, ammo_type='/obj/item/ammo_casing/a32')
        self.shots = []
        self.postfires = self.clicks = self.icons = self.consumes = 0
        self.launch_failure = False

    def consume_next_projectile(self):
        self.consumes += 1
        self.chambered = self.loaded.pop(0) if self.loaded else None
        return self.chambered.BB if self.chambered else None

    def process_projectile(self, projectile, owner, target, zone):
        self.shots.append((projectile, target, zone))
        return self.launch_failure

    def cycle(self):
        if self.chambered:
            self.loaded.append(self.chambered)
            self.chambered = None

    def handle_post_fire(self, owner):
        self.postfires += 1
        self.chambered.BB = None
        self.cycle()

    def handle_click_empty(self, owner):
        self.clicks += 1
        self.cycle()

    def update_icon(self):
        self.icons += 1


class Fixture:
    def __init__(self, source=SOURCE):
        self.world = SimpleNamespace(time=100)
        self.foe = Atom()
        self.visible = [self.foe]
        self.distance = 4
        self.friendly = False
        self.ridge = False
        self.timers = []
        self.messages = []
        self.rolls = []
        self.raider = Atom(ranged=True, target_mob=self.foe, aggro_vision_range=7,
                           last_fire=0, firedelay=5, reload_at=0)
        self.gun = self.raider.gun = Gun(self.raider)
        party = self.raider.party = Atom(hostile=True, members=[self.raider])
        env = dict(world=self.world, CONSCIOUS=0,
                   QDELETED=lambda value: value is None or value.deleted,
                   view=lambda distance, src: self.visible,
                   get_dist=lambda src, target: self.distance,
                   los_terrain_ray_blocked=lambda src, target: self.ridge,
                   max=max, prob=lambda chance: self.rolls.pop(0) if self.rolls else False,
                   pick=lambda *choices: choices[0],
                   SPAN_NOTICE=lambda text: text,
                   CALLBACK=lambda *args: args,
                   addtimer=lambda *args: self.timers.append(args),
                   qdel=lambda obj: setattr(obj, 'deleted', True),
                   new_casing=lambda gun: Atom(loc=gun, kind=gun.ammo_type,
                                               BB=Atom(kind='/obj/item/projectile/bullet/pistol/a32')),
                   is_sidearm=lambda value: isinstance(value, Gun),
                   istype=lambda value, kind=None: isinstance(value, Atom) if kind is None
                   else getattr(value, 'kind', None) == kind,
                   ishuman=lambda value: value is not None and value.human)
        env['nomad_raid_bound'] = project(CAPTURE, '/proc/nomad_raid_bound', 'H', env)
        party.foe_ok = MethodType(project(VISIT, '/datum/nomad_raid/proc/foe_ok', 'src,L', env), party)
        for proc, args in [('OpenFire', 'src,target,suppress=False'), ('Shoot', 'src,target'),
                           ('proc/load_sidearm', 'src')]:
            setattr(self.raider, proc.split('/')[-1], MethodType(project(source, RAIDER + '/' + proc, args, env), self.raider))
        self.raider.check_friendly_fire = lambda target: self.friendly
        self.raider.visible_message = self.messages.append
        self.raider.load_sidearm()

    def fire(self, direct=False):
        return (self.raider.Shoot if direct else self.raider.OpenFire)(self.foe)


class CombatTests(unittest.TestCase):
    def test_configuration_contract(self):
        revolvers = (ROOT / 'code/modules/1713/weapons/guns/revolvers.dm').read_text()
        base = revolvers.split('/obj/item/weapon/gun/projectile/revolver/update_icon()', 1)[0]
        colt = revolvers.split('/obj/item/weapon/gun/projectile/revolver/coltpolicepositive\n', 1)[1].split('\n/obj/', 1)[0]
        for setting in ['fire_delay = 3', 'load_delay = 6']:
            self.assertIn(setting, base)
        for setting in ['max_shells = 6', 'ammo_type = /obj/item/ammo_casing/a32', 'handle_casings = CYCLE_CASINGS']:
            self.assertIn(setting, colt)
        casing = (ROOT / 'code/modules/projectiles/_ammo_casing.dm').read_text().split('/obj/item/ammo_casing/a32\n', 1)[1].split('\n/obj/', 1)[0]
        self.assertIn('projectile_type = /obj/item/projectile/bullet/pistol/a32', casing)
        human = (ROOT / 'code/game/mob/living/simple_animal/hostile/humans/human.dm').read_text()
        self.assertIn('\tvar/firedelay = 5\n', human)
        self.assertNotRegex(SOURCE, r'(?m)^\tfiredelay\s*=')
        arm = extract(SOURCE, RAIDER + '/proc/arm_for_age')
        self.assertIn('new ' + REVOLVER + '(src)', arm)
        self.assertIn('load_sidearm()', arm)

    def test_sync_and_both_cooldowns_including_direct_reentry(self):
        f = Fixture()
        self.assertTrue(f.fire())
        self.assertEqual((f.raider.last_fire, f.gun.next_fire_time), (100, 103))
        self.assertEqual(len(f.gun.shots), 1)
        self.assertEqual(f.gun.postfires, 1)
        self.assertEqual(len(f.timers), 1)
        self.assertFalse(f.fire())
        self.assertFalse(f.fire(direct=True))
        f.world.time = 104
        self.assertFalse(f.fire(direct=True))
        f.world.time = 105
        f.gun.next_fire_time = 108
        self.assertFalse(f.fire(direct=True))
        f.world.time = 108
        self.assertTrue(f.fire(direct=True))
        self.assertEqual(len(f.gun.shots), 2)

    def test_refusals_do_not_consume_ammo_or_schedule_work(self):
        changes = {
            'peace': lambda f: setattr(f.raider.party, 'hostile', False),
            'no party': lambda f: setattr(f.raider, 'party', None),
            'downed foe': lambda f: setattr(f.foe, 'stat', 1),
            'dead foe': lambda f: setattr(f.foe, 'stat', 2),
            'deleted foe': lambda f: setattr(f.foe, 'deleted', True),
            'cuffed foe': lambda f: setattr(f.foe, 'handcuffed', True),
            'retargeted': lambda f: setattr(f.raider, 'target_mob', Atom()),
            'dead shooter': lambda f: setattr(f.raider, 'stat', 2),
            'deleted shooter': lambda f: setattr(f.raider, 'deleted', True),
            'unarmed': lambda f: setattr(f.raider, 'gun', None),
            'deleted gun': lambda f: setattr(f.gun, 'deleted', True),
            'dropped gun': lambda f: setattr(f.gun, 'loc', Atom()),
            'melee': lambda f: setattr(f.raider, 'ranged', False),
            'out of range': lambda f: setattr(f, 'distance', 13),
            'friendly in path': lambda f: setattr(f, 'friendly', True),
            'party member': lambda f: f.raider.party.members.append(f.foe),
            'other raider': lambda f: setattr(f.foe, 'kind', RAIDER),
            'hidden moving foe': lambda f: (f.visible.clear(), setattr(f, 'distance', 6)),
        }
        for label, change in changes.items():
            for direct in [False, True]:
                with self.subTest(label=label, direct=direct):
                    f = Fixture()
                    change(f)
                    self.assertFalse(f.fire(direct))
                    self.assertEqual(f.gun.consumes, 0)
                    self.assertEqual(f.raider.reload_at, 0)
                    self.assertFalse(f.timers)
        f = Fixture()
        self.assertFalse(f.raider.OpenFire(f.foe, True))
        self.assertEqual(f.gun.consumes, 0)

    def test_fresh_visibility_after_previous_success(self):
        f = Fixture()
        self.assertTrue(f.fire())
        f.world.time += 5
        f.visible.clear()
        self.assertFalse(f.fire(True))
        self.assertEqual(f.gun.consumes, 1)
        f.visible.append(f.foe)
        self.assertTrue(f.fire(True))

    def test_ridge_between_hides_the_target(self):
        f = Fixture()
        f.ridge = True
        self.assertFalse(f.fire(True))
        self.assertEqual(f.gun.consumes, 0)
        f.ridge = False
        self.assertTrue(f.fire(True))

    def test_six_shots_then_seventh_starts_reload_without_shooting(self):
        for load_delay, expected_delay in [(6, 40), (8, 48)]:
            with self.subTest(load_delay=load_delay):
                f = Fixture()
                f.gun.load_delay = load_delay
                for index in range(6):
                    self.assertTrue(f.fire(index % 2 == 0))
                    f.world.time += 5
                self.assertEqual(len(f.gun.shots), 6)
                self.assertEqual(len(f.gun.loaded), 6)
                self.assertTrue(all(c.BB is None for c in f.gun.loaded))
                self.assertFalse(f.fire(True))
                deadline = f.world.time + expected_delay
                self.assertEqual(f.raider.reload_at, deadline)
                self.assertEqual(f.gun.clicks, 1)
                self.assertEqual(len(f.messages), 1)
                for now in [f.world.time, deadline - 1]:
                    f.world.time = now
                    self.assertFalse(f.fire())
                self.assertEqual(f.gun.consumes, 7)
                f.world.time = deadline
                self.assertTrue(f.fire(True))
                self.assertEqual(f.raider.reload_at, 0)
                self.assertEqual(len(f.gun.shots), 7)
                self.assertEqual(sum(c.BB is not None for c in f.gun.loaded), 5)

    def test_reload_retains_live_rounds_and_does_not_overfill(self):
        f = Fixture()
        live = list(f.gun.loaded)[2:]
        spent = list(f.gun.loaded)[:2]
        for casing in spent:
            casing.BB = None
        f.gun.chambered = spent[0]
        f.gun.chamber_offset = 3
        self.assertTrue(f.raider.load_sidearm())
        self.assertEqual(len(f.gun.loaded), 6)
        self.assertEqual(f.gun.loaded[:4], live)
        self.assertTrue(all(c.deleted for c in spent))
        self.assertTrue(all(c.kind == '/obj/item/ammo_casing/a32' for c in f.gun.loaded))
        self.assertTrue(all(c.BB.kind == '/obj/item/projectile/bullet/pistol/a32' for c in f.gun.loaded))
        self.assertIsNone(f.gun.chambered)
        self.assertEqual(f.gun.chamber_offset, 0)
        before = list(f.gun.loaded)
        self.assertTrue(f.raider.load_sidearm())
        self.assertEqual(f.gun.loaded, before)

    def test_reload_refuses_missing_deleted_or_dropped_gun(self):
        for change in [lambda f: setattr(f.raider, 'gun', None),
                       lambda f: setattr(f.raider, 'gun', Atom(loc=f.raider)),
                       lambda f: setattr(f.gun, 'deleted', True),
                       lambda f: setattr(f.gun, 'loc', Atom())]:
            f = Fixture()
            change(f)
            self.assertFalse(f.raider.load_sidearm())
            self.assertEqual(f.gun.icons, 1)

    def test_hit_zone_and_failed_launch_branches(self):
        for rolls, zone in [([True], 'head'), ([False, True], 'l_arm'), ([False, False], 'chest')]:
            f = Fixture()
            f.rolls = rolls
            self.assertTrue(f.fire())
            self.assertEqual(f.gun.shots[0][2], zone)
        f = Fixture()
        f.gun.launch_failure = True
        self.assertFalse(f.fire())
        self.assertEqual(f.gun.postfires, 0)
        self.assertFalse(f.timers)
        self.assertEqual(f.raider.last_fire, 100)

    def test_mutation_controls(self):
        mutants = [
            ('if (suppress)', 'if (FALSE)', lambda f: f.raider.OpenFire(f.foe, True)),
            ('world.time < last_fire + firedelay', 'FALSE',
             lambda f: (f.fire(), setattr(f.world, 'time', 104), f.fire(True))[-1]),
            ('!(target in view(aggro_vision_range, src))', 'FALSE',
             lambda f: (f.visible.clear(), f.fire(True))[-1]),
            ('world.time < reload_at', 'FALSE',
             lambda f: (setattr(f.raider, 'reload_at', 200), f.fire(True))[-1]),
        ]
        for old, new, forbidden in mutants:
            with self.subTest(mutation=old):
                self.assertIn(old, SOURCE)
                self.assertFalse(forbidden(Fixture()))
                self.assertTrue(forbidden(Fixture(SOURCE.replace(old, new, 1))))

    def test_unsupported_unreachable_syntax_fails_preparation(self):
        for statement in ['sleep(10)', 'spawn(1)', 'unknown = 1', 'return unknown', 'switch(target)']:
            source = SOURCE.replace('\treturn Shoot(target)', '\treturn Shoot(target)\n\t' + statement, 1)
            with self.subTest(statement=statement):
                with self.assertRaises(AssertionError):
                    Fixture(source)


if __name__ == '__main__':
    unittest.main()
