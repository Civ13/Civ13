"""Keep invalidated buckets from debiting bilge."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/naval/small_craft_leaks.dm').read_text()


def proc(name):
    prefix = '/obj/structure/vehicle/proc/' + name + '('
    match = re.search(re.escape(prefix) + r'.*?(?=\n/|\Z)', SOURCE, re.S)
    assert match, name
    return match.group()


class BailingBucket(unittest.TestCase):
    def test_shared_guard_requires_a_live_open_empty_bucket(self):
        guard = proc('small_craft_bucket_ready')
        for requirement in ('!QDELETED(B)', 'B.is_open_container()', 'B.reagents.total_volume <= 0'):
            self.assertIn(requirement, guard)

    def test_admission_and_completion_share_the_guard(self):
        self.assertIn('bilge > 0 && small_craft_bucket_ready(B)', proc('small_craft_attackby'))
        bailing = proc('small_craft_bail')
        guard = bailing.index('!small_craft_bucket_ready(W)')
        self.assertLess(bailing.index('do_after('), guard)
        self.assertLess(guard, bailing.index('bilge -= out'))
        self.assertIn('H.get_active_hand() != W || small_craft_work_refusal(H)', bailing)
