"""Offline NPC admission/staging contracts; these do not execute native Move."""
from pathlib import Path
import copy
import importlib.util
import math
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
BASE = '10d264e5896221b34949ee4b67c0fd2b94bde249'
MODULE = 'code/game/mob/living/simple_animal/subtile_movement.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def baseline(path):
    return subprocess.check_output(['git', 'show', BASE + ':' + path], cwd=ROOT).decode().replace('\r\n', '\n')


def section(text, start, end):
    return text[text.index(start):text.index(end, text.index(start))]


class NpcContracts(unittest.TestCase):
    def test_disk_archive_preparer_preserves_exact_git_and_historical_helpers(self):
        spec = importlib.util.spec_from_file_location('npc_stage_runner', ROOT / 'tests/human_subtile/run-npc.py')
        runner = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(runner)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'repo'
            root.mkdir()
            files = {'civ13.dme': '#include "maps/removed.dmm"\n',
                     'code/world.dm': '/datum/global_init/New()\n\tinitialize()\n/world/New()\n\t..()\n\tstartup()\n',
                     'code/controllers/mc/globals.dm': '/datum/controller/global_vars/New()\n\tinitialize()\n',
                     'tests/human_subtile/probe.dm': '// committed probe\n'}
            for name in ('icons', 'sound', 'UI', 'interface', 'config'):
                files[name + '/fixture.txt'] = name + '\n'
            for name, value in files.items():
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(value)
            for argv in (['init', '-q'], ['add', '.'], ['-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'fixture']):
                subprocess.run(['git', '-C', str(root), *argv], check=True, capture_output=True, timeout=10)
            (root / 'tests/human_subtile/probe.dm').write_text('// dirty probe must stay out\n')
            (root / 'private.txt').write_text('not an input\n')
            out = Path(directory) / 'prepared'
            manifest = runner.prepare_source(root, out)
            self.assertEqual((out / 'stage/tests/human_subtile/probe.dm').read_text(), '// committed probe\n')
            self.assertFalse((out / 'stage/private.txt').exists())
            self.assertEqual(manifest['archive']['sha256'], runner.file_digest(out / 'source.tar'))
            self.assertNotIn('.dmm', (out / manifest['dme']).read_text())
            self.assertIn('\treturn\n', (out / 'stage/code/world.dm').read_text())
            with self.assertRaises(RuntimeError):
                runner.prepare_source(root, out)
        path = 'tests/human_subtile/run.py'
        self.assertEqual(read(path), baseline(path))

    def test_prepared_runtime_oracle_rejects_false_green_receipts(self):
        spec = importlib.util.spec_from_file_location('npc_compile_runner', ROOT / 'tests/human_subtile/run-npc.py')
        runner = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(runner)
        # Synthetic oracle controls only: no BYOND execution or native result.
        row = dict(head=BASE, error=None, port=0, byond_version=516, byond_build=1688,
                   npc_checks=46, npc_rows=[])
        for direction in (1, 2, 4, 8, 5, 9, 6, 10):
            dx = 1 if direction & 4 else -1 if direction & 8 else 0
            dy = 1 if direction & 1 else -1 if direction & 2 else 0
            pulses = []
            for i in range(1, 17):
                x, sx = divmod(160 + i * 2 * dx, 32)
                y, sy = divmod(160 + i * 2 * dy, 32)
                pulses.append(dict(x=x, y=y, sx=sx, sy=sy, at=math.ceil((i - 1) * .25 / .5) * .5))
            row['npc_rows'].append(dict(direction=direction, started=0, deadline=4, pulses=pulses))
        runner.validate_npc_receipt(row, BASE)
        mutations = [lambda r: r.update(head='0' * 40),
                     lambda r: r.update(npc_checks=45),
                     lambda r: r.update(byond_build=1681),
                     lambda r: r.update(error='unrelated failure'),
                     lambda r: r['npc_rows'][0]['pulses'][0].update(sy=0),
                     lambda r: r['npc_rows'][0]['pulses'][3].update(at=0),
                     lambda r: r['npc_rows'][0].update(deadline=3),
                     lambda r: r['npc_rows'].pop()]
        for mutate in mutations:
            wrong = copy.deepcopy(row)
            mutate(wrong)
            with self.assertRaises(RuntimeError):
                runner.validate_npc_receipt(wrong, BASE)
        source = read('tests/human_subtile/run-npc.py')
        self.assertNotIn('dd.exe', source)
        self.assertNotIn('DreamDaemon', source)

    def test_player_crawl_pathfinding_and_authority_unchanged(self):
        # Focused absence checks: whole-file equality against a fixed commit broke
        # whenever master changed these files for unrelated reasons.
        for path in ('code/_onclick/click.dm', 'code/pathfinding.dm',
                     'code/game/mob/living/carbon/human/subtile_movement.dm'):
            self.assertNotIn('npc_subtile', read(path), path)
        client_move = read('code/game/mob/mob_movement.dm').split('/client/Move(n, direct, ordinal = FALSE)', 1)[1]
        self.assertNotIn('npc_subtile', client_move)
        self.assertNotIn('simple_animal', client_move)

    def test_only_vendor_family_opts_in(self):
        source = read(MODULE)
        self.assertIn('var/npc_subtile_enabled = FALSE', source)
        vendor = read('code/game/objects/structures/vending/npc_vendors.dm')
        self.assertIn('\tmove_to_delay = 4\n\tnpc_subtile_enabled = TRUE', vendor)
        self.assertIn('/mob/living/simple_animal/npc_vendor/smuggler', vendor)
        self.assertNotIn('client.fps', source)
        self.assertNotIn('pixel_x =', source)
        self.assertNotIn('pixel_y =', source)

    def test_ai_throttles_and_pathfinding_work_are_not_multiplied(self):
        path = 'code/game/mob/living/simple_animal/simple_ai.dm'
        source = read(path).replace('ai_step(get_step(src, moving_to), move_to_delay)', 'Move(get_step(src, moving_to))')
        self.assertEqual(source.rstrip(), baseline(path).rstrip())
        worker = section(read(MODULE), '/datum/npc_subtile_transaction/proc/perform_rest(', '/datum/npc_subtile_transaction/proc/finish()')
        for forbidden in ('get_path(', 'cirrAstar(', 'FindTarget(', 'do_behaviour(', 'pick(', 'rand(', 'walk('):
            self.assertNotIn(forbidden, worker)
        self.assertIn('i <= 16', worker)
        self.assertIn('start_time + (i - 1) * (end_time - start_time) / 16', worker)
        admit = section(read(MODULE), '/mob/living/simple_animal/proc/ai_step(', '/datum/npc_subtile_pulse\n')
        self.assertIn('npc_subtile_transaction || world.time < npc_subtile_until', admit)
        self.assertEqual(admit.count('spawn(0)'), 1)
        self.assertLess(admit.index('npc_subtile_until = T.end_time'), admit.index('spawn(0)'))

    def test_refusal_does_not_fall_back_at_owned_offsets(self):
        source = read(MODULE)
        self.assertIn('!client && !stat && canmove', source)
        for guard in ('!pulling', '!pulledby', '!buckled', '!restrained()', '!weakened', '!resting'):
            self.assertIn(guard, source)
        admit = section(source, '/mob/living/simple_animal/proc/ai_step(', '/datum/npc_subtile_pulse\n')
        self.assertIn('if (npc_subtile_offset_owned && (step_x || step_y))\n\t\t\treturn FALSE', admit)
        self.assertIn('if ((step_x || step_y) && !npc_subtile_offset_owned)', admit)
        self.assertIn('return Move(destination, direction)', admit)

    def test_native_seam_authenticates_exact_single_use_pulse(self):
        source = read(MODULE)
        take = section(source, '/mob/living/simple_animal/proc/npc_subtile_take_pulse', '/mob/living/simple_animal/persistence_runtime_var')
        for guard in ('!P.armed', 'P.actor != src', 'P.destination != destination', 'P.direction != direction', 'P.before', 'npc_subtile_transaction.valid()'):
            self.assertIn(guard, take)
        self.assertIn('P.armed = FALSE', take)
        seam = read('code/game/mob/mob_movement.dm')
        self.assertIn('npc.npc_subtile_take_pulse(newloc, direct)', seam)
        self.assertIn('..(newloc, direct, P.sx, P.sy)', seam)
        self.assertIn('if (!subtile_pulse && (direct & (direct - 1)))', seam)

    def test_zero_partial_and_blocked_attempts_have_once_only_hooks(self):
        source = read(MODULE)
        advance = section(source, '/datum/npc_subtile_transaction/proc/advance()', '/datum/npc_subtile_transaction/proc/perform_rest(')
        finish = section(source, '/datum/npc_subtile_transaction/proc/finish()', '/mob/living/simple_animal/proc/npc_subtile_take_pulse')
        self.assertNotIn('living_movement_completed()', advance)
        self.assertIn('!completed', finish)
        self.assertIn('if (attempted)\n\t\t\tactor.living_movement_completed()', finish)
        self.assertIn('if (!T.distance)', source)
        living = read('code/game/mob/living/living.dm')
        self.assertIn('if (subtile_npc.npc_subtile_pulse)\n\t\t\treturn moved', living)

    def test_cancellation_and_restore_protect_owner_and_external_changes(self):
        source = read(MODULE)
        for guard in ('actor.move_gen == generation', 'actor.target_obj == target',
                      'actor.target_mob == combat_target', 'actor.following_mob == following',
                      'actor.npc_subtile_transaction == src', 'persistence_save_in_progress',
                      'human_subtile_same(expected, actor.npc_subtile_snapshot())',
                      'abs(actual_x) > abs(dx)', 'actual_y * dy < 0'):
            self.assertIn(guard, source)
        self.assertIn('if (glide_size == npc_subtile_applied_glide)', source)
        self.assertIn('glide_size = npc_subtile_previous_glide', source)

    def test_save_import_owns_offsets_before_raw_decode_and_refuses_null(self):
        loader = read('code/modules/persistence/loading.dm')
        self.assertLess(loader.index('restored_npc.npc_subtile_prepare_import(savefile)'), loader.index('for(var/v in savefile.dir)'))
        source = read(MODULE)
        self.assertIn('npc_subtile_import_owned = ("npc_subtile_position" in F.dir)', source)
        self.assertIn('!human_subtile_same(S, S)', source)
        for runtime in ('npc_subtile_transaction', 'npc_subtile_pulse', 'npc_subtile_until', 'npc_subtile_enabled'):
            self.assertIn('"' + runtime + '"', source)
        self.assertIn('Cannot snapshot an in-flight NPC pulse', source)
        self.assertIn('NPC sub-tile destination occupied', source)
        self.assertIn('Native NPC sub-tile restoration failed', source)

    def test_cadence_bound_and_diagonal_distance_budget(self):
        # Independent grid-distance budget, including odd legacy-import offsets.
        for duration in (.5, 2, 4, 10, 100):
            due = [i * duration / 16 for i in range(16)]
            rounded = [math.ceil(d / .5 - 1e-10) * .5 for d in due]
            self.assertLessEqual(max(rounded), duration + .5)
        source = read(MODULE)
        self.assertIn('interval < world.tick_lag || interval > 100', source)
        self.assertIn('min(2, remaining_x)', source)
        self.assertIn('min(2, remaining_y)', source)
        for offset in range(32):
            for direction in (-1, 1):
                distance = (32 - offset) if direction == 1 else (offset or 32)
                self.assertLessEqual(math.ceil(distance / 2), 16)
                self.assertEqual((offset + distance * direction) % 32, 0)


if __name__ == '__main__':
    unittest.main(verbosity=2)
