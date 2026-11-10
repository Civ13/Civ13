"""Exercise the post-prompt deal decision with changing game state."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest


ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('card_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SOURCE = (ROOT / 'code/game/objects/items/cards.dm').read_text(encoding='utf-8-sig')


def deal_after_prompt(*, adjacent=True, actor_stat=0, target_stat=0, visible=True, count=1):
    body = adapter.extract(SOURCE, '/obj/item/weapon/deck/verb/deal_card').splitlines()
    prompt = next(i for i, line in enumerate(body) if 'WWinput(' in line)
    tail = '\n'.join(body[prompt + 1:])
    calls = []
    user = SimpleNamespace(stat=actor_stat)
    target = SimpleNamespace(stat=target_stat)
    env = {'Adjacent': lambda _: adjacent, 'viewers': lambda *args: [target] if visible else [],
           'QDELETED': lambda obj: obj is None, 'cards': SimpleNamespace(len=count),
           'deal_at': lambda *args: calls.append('deal')}
    proc = adapter.project('/test/proc/run()\n' + tail + '\n', '/test/proc/run', 'usr, src, M', env)
    proc(user, object(), target)
    return calls


class CardDealingPrompt(unittest.TestCase):
    def test_valid_deal_proceeds(self):
        self.assertEqual(deal_after_prompt(), ['deal'])

    def test_changed_state_cancels_deal(self):
        for change in ({'adjacent': False}, {'actor_stat': 1}, {'target_stat': 1},
                       {'visible': False}, {'count': 0}):
            with self.subTest(change=change):
                self.assertEqual(deal_after_prompt(**change), [])


if __name__ == '__main__':
    unittest.main()
