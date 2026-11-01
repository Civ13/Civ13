"""Offline source/model checks for existing vendors and default-off animals.

These do not execute BYOND or claim full legacy/runtime equivalence.
"""
from pathlib import Path
from types import SimpleNamespace
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import project

SOURCE = (ROOT / 'code/game/mob/living/simple_animal/subtile_movement.dm').read_text(encoding='utf-8')
ANIMAL = (ROOT / 'code/game/mob/living/simple_animal/simple_animal.dm').read_text(encoding='utf-8')
def section(text, start, end):
    return text.split(start, 1)[1].split(end, 1)[0]
def evaluate(expression, context):
    expression = expression.replace('&&', ' and ').replace('||', ' or ')
    expression = re.sub(r'!(?!=)', ' not ', expression).strip()
    return bool(eval(expression, {'__builtins__': {}}, context))


class VendorAndLegacy(unittest.TestCase):
    def test_only_vendor_family_declares_base_opt_in(self):
        declarations = []
        for path in (ROOT / 'code').rglob('*.dm'):
            for line in path.read_text(encoding='utf-8', errors='replace').splitlines():
                if re.search(r'^\s*npc_subtile_enabled\s*=\s*TRUE\s*$', line):
                    declarations.append(path.relative_to(ROOT).as_posix())
        self.assertEqual(declarations, ['code/game/objects/structures/vending/npc_vendors.dm'])
        for flag in ('npc_subtile_enabled', 'npc_subtile_follow_enabled', 'npc_subtile_flee_enabled',
                     'npc_subtile_pet_enabled', 'npc_subtile_species_enabled',
                     'npc_subtile_recovery_enabled', 'npc_subtile_large_exit_enabled'):
            self.assertRegex(SOURCE, rf'var(?:/tmp)?/{flag} = FALSE')
        self.assertIn('var/npc_subtile_pursuit_enabled = FALSE',
                      (ROOT / 'code/game/mob/living/simple_animal/hostile/tactical_ai.dm').read_text(encoding='utf-8'))

    def test_vendor_finish_only_cleans_its_own_active_transaction(self):
        finish = section(SOURCE, '/datum/npc_subtile_transaction/proc/finish()\n',
                         '/mob/living/simple_animal/proc/npc_subtile_take_pulse')
        self.assertRegex(finish, r'if \(finished\)\s+return')
        guard = next(line.strip()[3:] for line in finish.splitlines()
                     if line.strip().startswith('if (!completed && actor &&'))
        owner, replacement = object(), object()
        actor = SimpleNamespace(npc_subtile_transaction=owner)
        context = {'completed': False, 'actor': actor, 'src': owner, 'isDeleted': lambda x: False}
        self.assertTrue(evaluate(guard, context))
        actor.npc_subtile_transaction = replacement
        self.assertFalse(evaluate(guard, context))
        actor.npc_subtile_transaction = owner
        context['completed'] = True
        self.assertFalse(evaluate(guard, context))
        self.assertLess(finish.index('actor.npc_subtile_transaction = null'), finish.index('actor.living_movement_completed()'))
        self.assertRegex(finish, r'if \(attempted\)\s+actor\.living_movement_completed\(\)')
        self.assertEqual(finish.count('actor.living_movement_completed()'), 1)

    def test_disabled_walkers_keep_native_commands(self):
        walk = section(SOURCE, '/mob/living/simple_animal/proc/npc_subtile_species_walk(',
                       '/mob/living/simple_animal/proc/npc_subtile_start_wild_walk(')
        legacy = walk.split('if (!npc_subtile_species_enabled)', 1)[1].split('\n\t\treturn', 1)[0]
        for mode, call in (('random', 'walk_rand(src, lag)'), ('towards', 'walk_towards(src, target, lag)'),
                           ('away', 'walk_away_od(src, target, distance_limit, lag)'),
                           ('path', 'walk_to(src, target, distance_limit, lag)'),
                           ('direction', 'walk(src, direction, lag)')):
            block = legacy.split('if ("' + mode + '")', 1)[1].split('\n\t\t\tif ', 1)[0]
            self.assertIn(call, block)
        admit = section(SOURCE, '/mob/living/simple_animal/proc/ai_step(',
                        '/mob/living/simple_animal/proc/ai_step_wait(')
        fallback = admit.split('if (!npc_subtile_enabled', 1)[1].split('\n\tif ((step_x', 1)[0]
        self.assertIn('if (pulse_only)\n\t\t\treturn FALSE', fallback)
        self.assertIn('if (npc_subtile_offset_owned && (step_x || step_y))\n\t\t\treturn FALSE', fallback)
        self.assertIn('return Move(destination, direction)', fallback)

    def test_contact_guard_preserves_unowned_offsets_but_protects_live_vendor(self):
        source = section(SOURCE, '/mob/living/simple_animal/proc/npc_subtile_settled()\n',
                         '/mob/living/simple_animal/proc/npc_subtile_contact_settled(')
        expression = next(line.strip()[len('return '):] for line in source.splitlines()
                          if line.strip().startswith('return '))
        animal = SimpleNamespace(npc_subtile_transaction=None, npc_subtile_pulse=None,
            npc_subtile_until=0, npc_subtile_offset_owned=False, step_x=7, step_y=0)
        context = {'src': animal, 'world': SimpleNamespace(time=10)}
        self.assertTrue(evaluate(expression, context))
        for field, value in (('npc_subtile_transaction', object()), ('npc_subtile_pulse', object()),
                             ('npc_subtile_until', 11), ('npc_subtile_offset_owned', True)):
            with self.subTest(field=field):
                setattr(animal, field, value)
                self.assertFalse(evaluate(expression, context))
                setattr(animal, field, None if field in ('npc_subtile_transaction', 'npc_subtile_pulse') else 0)
        contact = section(SOURCE, '/mob/living/simple_animal/proc/npc_subtile_contact_settled(',
                          '// Other species retain')
        self.assertIn('src.npc_subtile_settled() && (!other || other.npc_subtile_settled())', contact)

    def test_setters_and_stop_preserve_plain_legacy_state(self):
        for declaration, field in (('/mob/living/simple_animal/proc/npc_set_following', 'following_mob'),
                                   ('/mob/living/simple_animal/proc/npc_set_combat_target', 'target_mob'),
                                   ('/mob/living/simple_animal/pet/proc/npc_set_movement_target', 'movement_target')):
            argument = 'new_following' if field == 'following_mob' else 'new_target'
            setter = project(ANIMAL, declaration, 'src, ' + argument, {})
            old, replacement = object(), object()
            actor = SimpleNamespace(**{field: old, 'npc_subtile_pending_intent': None})
            setter(actor, replacement)
            self.assertIs(getattr(actor, field), replacement)
            self.assertIsNone(actor.npc_subtile_pending_intent)
        stop = section(SOURCE, '/mob/living/simple_animal/proc/npc_subtile_stop_continuous_walk()\n',
                       '/mob/living/simple_animal/proc/npc_subtile_authority_ready()')
        self.assertEqual(stop.count('walk(src, 0)'), 1)
        for kind in ('follow', 'flee', 'pet_walk', 'wild_walk'):
            self.assertIn('src.npc_subtile_stop_' + kind + '()', stop)
            body = SOURCE.split('/mob/living/simple_animal/proc/npc_subtile_stop_' + kind + '(', 1)[1].split('\n/', 1)[0]
            self.assertRegex(body, r'if \(![A-Z]\)\s+return')

    def test_shared_move_and_uncross_leave_ordinary_paths_to_parent(self):
        movement = (ROOT / 'code/game/mob/mob_movement.dm').read_text(encoding='utf-8')
        seam = section(movement, '\tif (istype(src, /mob/living/simple_animal))\n',
                       '\tvar/datum/human_subtile_pulse/subtile_pulse')
        self.assertIn('if (npc.npc_subtile_pulse)', seam)
        self.assertIn('if (npc.npc_subtile_large_exit_enabled)', seam)
        self.assertIn('else\n\t\t\t\t. = ..(newloc, direct, P.sx, P.sy)', seam)
        self.assertIn('if (npc.npc_subtile_offset_owned && (step_x || step_y))\n\t\t\treturn FALSE', seam)
        self.assertNotIn('return FALSE\n\tvar/datum/human_subtile', seam)
        atoms = (ROOT / 'code/game/atoms.dm').read_text(encoding='utf-8')
        uncross = section(atoms, '/obj/Uncross(atom/movable/mover, atom/newloc)\n',
                          '/atom/proc/emp_act(')
        self.assertLess(uncross.index('. = ..()'), uncross.index('if (!. || !istype'))
        self.assertIn('if (!. || !istype(mover, /mob/living/simple_animal))\n\t\treturn .', uncross)
        self.assertIn('if (!F)\n\t\treturn .', uncross)
        self.assertIn('return F.check_exit(src)', uncross)
        for name in ('window', 'railing', 'table'):
            source = (ROOT / f'code/game/objects/structures/{name}.dm').read_text(encoding='utf-8')
            body = source.split('/obj/structure/' + name + '/CheckExit(', 1)[1].split('\n/', 1)[0]
            self.assertIn('exit_direction = null', body)
            self.assertIn('isnull(exit_direction) ? get_dir(', body)
        frame = (ROOT / 'code/modules/1713/machinery/modular_vehicles/frame.dm').read_text(encoding='utf-8')
        body = frame.split('/obj/structure/vehicleparts/frame/CheckExit(', 1)[1].split('\n/', 1)[0]
        self.assertIn('exit_direction = null', body)
        self.assertIn('isnull(exit_direction) ? get_dir(', body)


if __name__ == '__main__':
    unittest.main()
