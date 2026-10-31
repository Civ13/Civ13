"""Source-only acceptance preparation: no compiler, daemon, client or world."""
import ast
import importlib.util
import inspect
from pathlib import Path
import re
from types import SimpleNamespace as NS
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


flax = load('prepared_flax_entry_runner', 'tests/flax_processing/run.py')
harvest = load('prepared_harvest_runner', 'tests/animal_harvest/run.py')


class EntryPreparationContracts(unittest.TestCase):
    def test_whole_production_definitions_and_order_survive_staging(self):
        baseline = flax.entry_sources()
        mutant = flax.entry_sources('legacy-return')
        for path in flax.ENTRY_SOURCES:
            original = (ROOT / path).read_text(encoding='utf-8')
            self.assertEqual(baseline[path], original)
            self.assertEqual(mutant[path].count('/mob/living/human/drop_from_inventory('), 1)
            self.assertEqual(mutant[path].count('\treturn ..()'), original.count('\treturn ..()') - 1)
            signature = '/mob/living/human/drop_from_inventory(var/obj/item/W, var/atom/Target = null)'
            body = re.search(re.escape(signature) + r'\n\tif \(W in (internal_organs|organs)\)\n\t\treturn\n\t\.\.\(\)', mutant[path])[0]
            self.assertEqual(mutant[path].replace(body, body.removesuffix('..()') + 'return ..()', 1), original)
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        staged = flax.entry_dme(dme, ['prepared_living.dm', 'prepared_human.dm'])
        self.assertLess(staged.index('code\\game\\mob\\inventory.dm'), staged.index('prepared_living.dm'))
        self.assertLess(staged.index('prepared_living.dm'), staged.index('prepared_human.dm'))
        with self.assertRaises(ValueError):
            flax.entry_sources('invented-control')
        with self.assertRaises(ValueError):
            flax.entry_dme(dme, ['missing-second-definition.dm'])
        with self.assertRaises(RuntimeError):
            flax.entry_dme(dme.replace('#include "code\\game\\mob\\living\\living.dm"', ''), ['a.dm', 'b.dm'])

    def test_entry_actor_never_replaces_inventory_or_manually_invokes_soak(self):
        text = (ROOT / 'tests/flax_processing/human_entry_probe.dm').read_text()
        overrides = re.findall(r'^/mob/living/human/flax_entry_actor/(\w+)\(', text, re.M)
        self.assertEqual(set(overrides), {'New', 'flax_processing_wait'})
        self.assertNotRegex(text, r'\.soak\(')
        self.assertIn('B.afterattack(W, U, TRUE)', text)
        self.assertIn('partial.afterattack(W, U, TRUE)', text)
        self.assertIn('partial.attack_hand(U)', text)
        wait = text.split('/mob/living/human/flax_entry_actor/flax_processing_wait(', 1)[1].split('\n/obj/', 1)[0]
        self.assertIn('return ..()', wait)
        self.assertNotRegex(wait, r'return (TRUE|FALSE)|do_after\(')
        self.assertIn('U.entry_delay == 100', text)
        self.assertIn('raw.tie_bundle(U)', text)
        self.assertIn('!raw.extraction_surface_source', text)

    def test_current_pickup_admission_survives_both_entry_variants(self):
        path = 'code/game/mob/living/carbon/human/human.dm'
        guard = ('\tif (W?.extraction_surface_source && (!W.extraction_surface_source.service || '
                 '!W.extraction_surface_source.service.movement_allowed(W, src))) return FALSE')

        def check_admission(text):
            for hand in ('l', 'r'):
                signature = '/mob/living/human/put_in_' + hand + '_hand(var/obj/item/W)'
                body = re.search('^' + re.escape(signature) + r'\n.*?(?=^/|\Z)', text, re.M | re.S)
                self.assertIsNotNone(body)
                self.assertEqual(body[0].splitlines()[1], guard)
                self.assertLess(body[0].index(guard), body[0].index('W.forceMove(src)'))

        for control in (None, 'legacy-return'):
            staged = flax.entry_sources(control)[path]
            check_admission(staged)
            # Source-only negative control: loss of either current pickup guard
            # must fail this oracle, independently of the drop-return mutation.
            for occurrence in (0, 1):
                offset = [m.start() for m in re.finditer(re.escape(guard), staged)][occurrence]
                mutant = staged[:offset] + staged[offset:].replace(guard, '\t// guard removed', 1)
                with self.assertRaises(AssertionError):
                    check_admission(mutant)

    def test_direct_connected_contract_requires_actual_client_and_cannot_accept_click_delivery(self):
        text = (ROOT / 'tests/flax_processing/connected_entry_contract.dm').read_text()
        self.assertIn('U.type == /mob/living/human', text)
        self.assertIn('U.client == C && C.mob == U', text)
        self.assertIn('B.afterattack(W, U, TRUE)', text)
        self.assertIn('!(B in C.screen)', text)
        self.assertIn('B.soaking', text)
        self.assertIn('D.reattach_paddles(U)', text)
        self.assertIn('T.MouseDrop_T(I, U)', text)
        self.assertIn('"scope" = "direct_proc_only"', text)
        self.assertIn('"connected_acceptance" = FALSE', text)
        self.assertNotIn('"click_delivery" =', text)
        self.assertNotIn('"paddle_notice" =', text)
        self.assertIn('left_site != right_site', text)
        pair = text.split('/proc/flax_entry_direct_connected_proc_pair(', 1)[1]
        self.assertLess(pair.index('for (var/left_hand'), pair.index('new(left_hand ? left_site : right_site)'))
        self.assertLess(pair.index('new(left_hand ? left_site : right_site)'), pair.index('flax_entry_direct_connected_proc_contract('))
        self.assertNotIn('flax_entry_connected_contract(', text)
        self.assertNotRegex(text, re.compile(r'\.soak\(|^/(?:world|client)\b|/verb\b|/flax_processing_wait\(|new\s*/client', re.M))
        for name in ('civ13.dme', 'tests/flax_processing/run.py', '.github/workflows/test.yml'):
            self.assertNotIn('connected_entry_contract.dm', (ROOT / name).read_text())

    def test_proposed_oracles_cover_guards_forwarding_and_real_ui_state(self):
        text = (ROOT / 'tests/flax_processing/human_entry_probe.dm').read_text()
        for marker in ('internal_organs += internal_item', 'organs += external_item',
                       'U.drop_from_inventory(B, W, TRUE)', 'U.drop_from_inventory(B, W, FALSE)',
                       'U.drop_from_inventory(default_target)', 'entry_deny', 'entry_redirect',
                       'entry_special', 'client.screen', 'overlays_standing[L_HAND_LAYER]',
                       'overlays_standing[R_HAND_LAYER]', 'T.MouseDrop_T(I, U)', 'D.reattach_paddles(U)',
                       'not covered: no connected client', '!world.port && !OpenPort(12345)'):
            self.assertIn(marker, text)
        self.assertLess(text.index('human afterattack enters production wait'),
                        text.index('production internal-organ guard refuses before removal'))

    def test_both_runners_require_current_exact_banner_and_preserve_failure(self):
        expected = flax.byond_toolchain.load()['version']
        self.assertEqual(expected, '516.1688')
        clean = 'DM compiler version 516.1688\nprobe.dmb - 0 errors, 0 warnings\n'
        for runner in (flax, harvest):
            runner.check_compile(NS(returncode=0, stdout=clean, stderr=''), expected)
            for text in (clean.replace('1688', '1681'), clean.replace('1688', '1689'),
                         clean + 'DM compiler version 516.1688\n', clean.replace('0 warnings', '1 warnings')):
                with self.subTest(runner=runner.__name__, text=text), self.assertRaises((RuntimeError, ValueError)):
                    runner.check_compile(NS(returncode=0, stdout=text, stderr=''), expected)
            with self.assertRaises(RuntimeError):
                runner.check_compile(NS(returncode=1, stdout=clean, stderr=''), expected)

    def test_harvest_reuses_exact_identity_and_retains_existing_supervision_bounds(self):
        binary, archive = Path('bin'), Path('pinned.zip')
        with patch.object(harvest.sys, 'platform', 'linux'), \
                patch.object(harvest.byond_runtime, 'verify_linux', return_value={'version': '516.1688'}) as verify:
            with self.assertRaises(ValueError):
                harvest.runtime_identity(binary, None)
            self.assertEqual(harvest.runtime_identity(binary, archive), {'version': '516.1688'})
            verify.assert_called_once_with(binary, archive)
        tree = ast.parse(inspect.getsource(harvest.main))
        timeouts = [keyword.value.value for node in ast.walk(tree)
                    if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == 'run_retained'
                    for keyword in node.keywords if keyword.arg == 'timeout']
        self.assertEqual(timeouts, [120, 60])
        body = inspect.getsource(harvest.main)
        self.assertIn('owned_exit_evidence_complete', body)
        self.assertNotIn('path.unlink', body)
        self.assertIn('verify_external_cleanup', body)
        self.assertIn('*no_port_args()', body)
        self.assertIn("'port-closed.txt'", body)

    def test_prepared_entry_requires_explicit_mode_exact_head_and_no_lane_expansion(self):
        body = inspect.getsource(flax.main)
        self.assertIn('args.expected_head != commit', body)
        self.assertIn("args.human_entry and sys.platform != 'linux'", body)
        self.assertIn('FAIL: human afterattack enters production wait', body)
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        self.assertNotIn('--human-entry', workflow)
        harvest_step = workflow.split('- name: Verify bounded animal harvesting and binding conservation', 1)[1].split('\n      - name:', 1)[0]
        self.assertIn("contains(fromJSON(needs.changes.outputs.new_tests || '[]'), 'tests/animal_harvest')", harvest_step)
        self.assertIn('--byond-archive "$PWD/BYOND/pinned.zip"', harvest_step)


if __name__ == '__main__':
    unittest.main(verbosity=2)
