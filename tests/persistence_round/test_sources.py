"""Static merge contracts only; native execution is a separate acceptance gate."""
from pathlib import Path
import ast
import unittest

ROOT = Path(__file__).resolve().parents[2]
VOTE = (ROOT / 'code/datums/vote.dm').read_text(encoding='utf-8')
PROBE = (ROOT / 'tests/persistence_round/probe.dm').read_text(encoding='utf-8')


def proc(name, following):
    return VOTE.split(name, 1)[1].split(following, 1)[0]


class PersistenceVoteMergeContracts(unittest.TestCase):
    def test_generation_and_policy_precede_completion(self):
        body = proc('\tproc/result(datum/vote_handle/H)', '\tproc/apply_result(')
        for guard in ('if (!is_current(H))', 'persistence_blocks_vote(mode, H.completion)'):
            self.assertLess(body.index(guard), body.index('H.state = "resolved"'))
        self.assertLess(body.index('H.completion = null'), body.index('call(completion[1], completion[2])'))
        self.assertLess(body.index('H.manager = null'), body.index('call(completion[1], completion[2])'))
        self.assertIn('generation != H.generation || active_request', body)
        self.assertLess(body.index('persistence_blocks_vote(resolved_mode, completion)'), body.index('apply_result(resolved_mode'))

    def test_process_and_application_gates(self):
        body = proc('\tproc/process()', '\tproc/autogamemode()')
        self.assertIn('persistence_blocks_vote(mode, H.completion)', body)
        self.assertIn('cancel_request(H)', body)
        body = proc('\tproc/apply_result(', '\tproc/submit_vote(')
        self.assertLess(body.index('persistence_blocks_vote(resolved_mode, completion)'), body.index('switch(resolved_mode)'))

    def test_creation_and_generic_callbacks(self):
        self.assertEqual(VOTE.count('persistence_blocks_vote(vote_type, _callback)'), 2)
        self.assertIn('persistence_blocks_vote("request", completion)', VOTE)
        guard = proc('/proc/persistence_blocks_vote(', '\n/datum/vote\n')
        for kind in ('epochswap', 'mapswap', 'gamemode'):
            self.assertIn(f'istype(completion[1], /process/{kind})', guard)
        self.assertLess(guard.index('vote_type == "restart"'), guard.index('ticker.current_state < GAME_STATE_PLAYING'))

    def test_fixture_uses_real_handles(self):
        self.assertNotIn('vote.result()', PROBE)
        self.assertNotIn('vote.callback =', PROBE)
        self.assertIn('result_handle.resolve()', PROBE)
        self.assertIn('pending.state == "cancelled"', PROBE)
        self.assertIn('during_callback.state == "resolved"', PROBE)
        self.assertIn('vote.apply_result(kind', PROBE)
        ast.parse((ROOT / 'tests/persistence_round/run.py').read_text(encoding='utf-8'))


if __name__ == '__main__':
    unittest.main()
