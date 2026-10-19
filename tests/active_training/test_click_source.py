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
        # check_output invokes Git read commands internally; compiler/runtime
        # launch mechanisms have no place in this preparation API.
        return prepare.prepare(output, original)

    def test_candidate_preserves_real_input_wait_clock_and_bound_sources(self):
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
        source = (prepare.ROOT / prepare.TRAINING).read_text(encoding='utf-8')
        original = prepare.git('show', prepare.ORIGINAL + ':' + prepare.TRAINING).decode()
        reward = '\tvar/list/skills = course ? list("dexterity", "stamina") : list("strength")'
        self.assertEqual(source.rsplit(reward, 1)[1], original.rsplit(reward, 1)[1])
        for marker in ['/obj/structure/exercise/persistence_runtime_var(key)', '/mob/living/human/persistence_runtime_var(key)']:
            self.assertEqual(source.split(marker, 1)[1].split('\n\n', 1)[0], original.split(marker, 1)[1].split('\n\n', 1)[0])

    def test_source_overlay_removes_map_and_production_startup(self):
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
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / 'candidate'
            metadata = self.generate(output)
            self.assertEqual(metadata, json.loads((output / 'metadata.json').read_text()))
            for name, digest in metadata['generated_sha256'].items():
                self.assertEqual(digest, hashlib.sha256((output / 'overlay' / name).read_bytes()).hexdigest())
            self.assertIn('Not run', metadata['execution'])

    def test_output_inside_checkout_or_nonempty_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'outside'):
            self.generate(prepare.ROOT / 'forbidden-training-output')
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp)
            (output / 'preserve.txt').write_text('existing evidence')
            with self.assertRaisesRegex(ValueError, 'Preserve'):
                self.generate(output)
            self.assertEqual((output / 'preserve.txt').read_text(), 'existing evidence')

    def test_git_commands_are_only_read_operations(self):
        actual = prepare.git
        def read_only(*args):
            self.assertIn(args[0], ('rev-parse', 'show'))
            return actual(*args)
        with tempfile.TemporaryDirectory() as temp, mock.patch.object(prepare, 'git', side_effect=read_only):
            self.generate(Path(temp) / 'candidate')
            self.generate(Path(temp) / 'control', True)


if __name__ == '__main__':
    unittest.main()
