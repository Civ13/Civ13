"""Offline preparation controls. No compiler, daemon, sockets, client or game."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('prepare_training_click', HERE / 'prepare_click.py')
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)


class ClickSourceTests(unittest.TestCase):
    def generate(self, output, original=False):
        """Prepare candidate or pinned-control overlays and return their metadata."""
        # check_output invokes Git read commands internally; compiler/runtime
        # launch mechanisms have no place in this preparation API.
        return prepare.prepare(output, original)

    def test_candidate_preserves_real_input_wait_clock_and_bound_sources(self):
        """Keep production click dispatch, waits and clocks in the hashed overlay."""
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / 'candidate'
            metadata = self.generate(output)
            training = (output / 'overlay' / (prepare.PREFIX + '_training.dm')).read_text(encoding='utf-8')
            fixture = (output / 'overlay' / (prepare.PREFIX + '_fixture.dm')).read_text(encoding='utf-8')
            self.assertIn('return world.time', training)
            self.assertIn('return do_after(H, duration, H.loc)', training)
            self.assertIn('H.ClickOn(E, "icon-x=16;icon-y=16")', fixture)
            self.assertIn('. = ..()', fixture.split('/obj/structure/exercise/click_fixture/exercise_wait', 1)[1])
            self.assertNotIn('training_wait(src,H,duration)', fixture)
            self.assertNotIn('next_click =', fixture)
            self.assertNotIn('next_move =', fixture)
            for path in ['code/_onclick/click.dm', 'code/_helpers/mobs.dm']:
                self.assertEqual(metadata['inputs_sha256'][path], hashlib.sha256((prepare.ROOT / path).read_bytes()).hexdigest())

    def test_original_silence_uses_pinned_production_blob_not_a_fake_boolean(self):
        """Use the pinned training blob with only chat observation substitutions."""
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / 'control'
            metadata = self.generate(output, True)
            original = prepare.git('show', prepare.ORIGINAL + ':' + prepare.TRAINING)
            expected = original.decode('utf-8-sig').replace('\r\n', '\n').replace('to_chat(', 'training_click_chat(')
            actual = (output / 'overlay' / (prepare.PREFIX + '_training.dm')).read_text(encoding='utf-8')
            self.assertEqual(actual, expected)
            self.assertEqual(metadata['original_control_sha256'], hashlib.sha256(original).hexdigest())
            self.assertNotIn('empty active hand', actual)
            self.assertNotIn('You begin lifting', actual)
            self.assertIn('H.adaptStat(skill,', actual)

    def test_reward_and_persistence_blocks_are_identical_to_original(self):
        """Keep reward and persistence code identical to the pinned original."""
        source = (prepare.ROOT / prepare.TRAINING).read_text(encoding='utf-8')
        original = prepare.git('show', prepare.ORIGINAL + ':' + prepare.TRAINING).decode()
        reward = '\tvar/list/skills = course ? list("dexterity", "stamina") : list("strength")'
        self.assertEqual(source.rsplit(reward, 1)[1], original.rsplit(reward, 1)[1])
        for marker in ['/obj/structure/exercise/persistence_runtime_var(key)', '/mob/living/human/persistence_runtime_var(key)']:
            self.assertEqual(source.split(marker, 1)[1].split('\n\n', 1)[0], original.split(marker, 1)[1].split('\n\n', 1)[0])

    def test_source_overlay_removes_map_and_production_startup(self):
        """Emit five overlay files with the map and production world startup removed."""
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / 'candidate'
            self.generate(output)
            dme = (output / 'overlay' / (prepare.PREFIX + '.dme')).read_text(encoding='utf-8')
            world = (output / 'overlay' / (prepare.PREFIX + '_world.dm')).read_text(encoding='utf-8')
            self.assertNotRegex(dme, r'(?m)^#include ".*\.dmm"')
            self.assertIn('/world/proc/unused_active_training_startup()', world)
            self.assertNotIn('/world/New()', world)
            self.assertEqual(len(list((output / 'overlay').iterdir())), 5)

    def test_input_hashes_and_generated_receipts_are_complete(self):
        """Persist matching metadata and content hashes for every generated overlay."""
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / 'candidate'
            metadata = self.generate(output)
            self.assertEqual(metadata, json.loads((output / 'metadata.json').read_text()))
            for name, digest in metadata['generated_sha256'].items():
                self.assertEqual(digest, hashlib.sha256((output / 'overlay' / name).read_bytes()).hexdigest())
            self.assertIn('Not run', metadata['execution'])

    def assert_real_round_identity_before_save(self, source):
        """Require real round initialization before map creation and validated saving."""
        startup = source.split('/world/New()\n', 1)[1]
        identity = '\tgenerate_gameid()\n'
        self.assertEqual(startup.count(identity), 1)
        self.assertLess(startup.index('\tOpenPort("none")'), startup.index(identity))
        self.assertLess(startup.index(identity), startup.index('\tmap = new'))
        self.assertLess(startup.index(identity), startup.index('map_storage.Save_World()'))
        self.assertNotRegex(startup, r'(?m)^\s*(?:global\.)?game_id\s*=')
        self.assertIn('map_storage.Save_World() && map_storage.validate_world_save()', startup)

    def test_accelerated_fixture_uses_real_round_initialization_before_save(self):
        """Restore the round identity prerequisite bypassed by fixture startup."""
        source = (prepare.ROOT / 'tests/active_training/game.dm').read_text(encoding='utf-8')
        self.assert_real_round_identity_before_save(source)
        # Bind to the actual startup prerequisite the runner bypasses, rather
        # than assigning a synthetic ID or weakening the production validator.
        world = (prepare.ROOT / 'code/world.dm').read_text(encoding='utf-8')
        self.assertIn('/datum/global_init/New()\n\tgenerate_gameid()', world)
        runner = (prepare.ROOT / 'tests/active_training/run.ps1').read_text(encoding='utf-8')
        self.assertIn('"/datum/global_init/New()`n`treturn"', runner)

    def test_round_identity_guard_detects_original_omission_literal_and_late_init(self):
        """Reject missing, fabricated or delayed round initialization in source controls."""
        source = (prepare.ROOT / 'tests/active_training/game.dm').read_text(encoding='utf-8')
        original = prepare.git('show', '250ff2ca00c85302f57c8e1a67764fdb536b5596:tests/active_training/game.dm').decode()
        identity = '\tgenerate_gameid()\n'
        mutants = [original,
                   source.replace(identity, '\tglobal.game_id = "fake-round-id"\n'),
                   source.replace(identity, '').replace('\t\tmap_storage.ClearMap()',
                                                        '\t\tgenerate_gameid()\n\t\tmap_storage.ClearMap()')]
        for mutant in mutants:
            with self.subTest(source=mutant[:50]), self.assertRaises(AssertionError):
                self.assert_real_round_identity_before_save(mutant)

    def test_actual_runner_keeps_python_options_an_array_before_both_splats(self):
        """Accept typed Python argument arrays and reject the historical scalar form."""
        def assert_argument_contract(runner):
            """Require an explicit string array splatted into preparation and verification."""
            assignments = [line.strip() for line in runner.splitlines() if '$pythonArguments = ' in line]
            self.assertEqual(assignments, ["[string[]]$pythonArguments = if ($options.Count) { @('-3','-B') } else { @('-B') }"])
            self.assertIn('& $pythonCommand @pythonArguments @prepareArguments', runner)
            self.assertIn('& $pythonCommand @pythonArguments @verifyArguments', runner)
        runner = (prepare.ROOT / 'tests/active_training/run.ps1').read_text(encoding='utf-8')
        assert_argument_contract(runner)
        # This immutable predecessor really unwraps Linux '-B' to a string;
        # pwsh 7.6.7 then splats its chars and Python selects stdin ('-').
        original = prepare.git('show', '09eb8a1378cda690af682cac9d1034c643f2ff1e:tests/active_training/run.ps1').decode()
        with self.assertRaises(AssertionError):
            assert_argument_contract(original)

    def test_output_inside_checkout_or_nonempty_is_rejected(self):
        """Reject checkout-local or nonempty outputs while preserving existing evidence."""
        with self.assertRaisesRegex(ValueError, 'outside'):
            self.generate(prepare.ROOT / 'forbidden-training-output')
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp)
            (output / 'preserve.txt').write_text('existing evidence')
            with self.assertRaisesRegex(ValueError, 'Preserve'):
                self.generate(output)
            self.assertEqual((output / 'preserve.txt').read_text(), 'existing evidence')

    def test_git_commands_are_only_read_operations(self):
        """Limit Git calls made by both preparation modes to rev-parse and show."""
        actual = prepare.git
        def read_only(*args):
            """Assert the Git operation is allowed before forwarding its arguments."""
            self.assertIn(args[0], ('rev-parse', 'show'))
            return actual(*args)
        with tempfile.TemporaryDirectory() as temp, mock.patch.object(prepare, 'git', side_effect=read_only):
            self.generate(Path(temp) / 'candidate')
            self.generate(Path(temp) / 'control', True)


if __name__ == '__main__':
    unittest.main()
