"""The validate-only boot (save_validator.dm) must end before the world goes live.

The host supervisor boots a region's build on a copied save with -params
validate_save=1. That world must never reach the hub, scheduler, round setup or
any relay/bot link, and must never answer a Topic.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
WORLD = (ROOT / 'code/world.dm').read_text(encoding='utf-8')
VALIDATOR = (ROOT / 'code/modules/persistence/save_validator.dm').read_text(encoding='utf-8')


def proc_body(text, header):
    start = text.index(header)
    match = re.compile(r'\n/[A-Za-z]').search(text, start + len(header))  # the next definition, not a // comment
    return text[start:match.start() if match else len(text)]


class SaveValidatorBootTest(unittest.TestCase):
    def test_world_new_returns_before_anything_goes_live(self):
        body = proc_body(WORLD, '/world/New()')
        gate = body.index('if (persistence_validate_only_requested())')
        self.assertIn('return', body[gate:body.index('\n\t// A standby world', gate)])
        self.assertLess(body.index('persistence_restart.detect_startup()'), gate)
        self.assertLess(body.index('config.post_load()'), gate)
        for live in ('callHook("startup")', 'update_status()', 'processScheduler = new', 'setup_everything(', 'world.log = file('):
            self.assertLess(gate, body.index(live), live)

    def test_topics_are_refused(self):
        body = proc_body(WORLD, '/world/Topic(')
        self.assertLess(body.index('if (persistence_validate_only)\n\t\treturn'), body.index('bannedsourceaddrs[addr]'))

    def test_the_check_is_a_full_walk_at_the_saved_height(self):
        body = proc_body(VALIDATOR, '/proc/persistence_run_validate_only()')
        order = [body.index(text) for text in ('clear_validation_record()', 'saved_dimension_target()',
                                               'validate_world_save()', 'validation_maxz = 0', 'validation_result.json', 'del(world)')]
        self.assertEqual(order, sorted(order))
        self.assertIn('last_validation_full', body)
        self.assertIn('world.params["validate_save"] == "1"', VALIDATOR)


if __name__ == '__main__':
    unittest.main()
