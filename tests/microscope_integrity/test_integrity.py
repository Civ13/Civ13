"""Source contracts for microscope sample ownership and report sequencing."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/forensics.dm'


def body(source, path):
    return source.split(path, 1)[1].split('\n/obj/', 1)[0]


def assert_integrity(test, source):
    insert = body(source, '/obj/machinery/microscope/attackby(')
    scan = body(source, '/obj/machinery/microscope/attack_hand(')
    remove = body(source, '/obj/machinery/microscope/proc/remove_sample(')
    test.assertIn('var/tmp/sample_revision = 0', source)
    test.assertIn('sample = W\n\t\tsample_revision++', insert)
    test.assertLess(remove.index('sample_revision++'), remove.index('sample.forceMove('))
    test.assertIn('var/obj/item/weapon/forensics/examined_sample = sample', scan)
    test.assertIn('var/examined_revision = sample_revision', scan)
    for term in ('do_after(user, 25, src)', 'QDELETED(src)', 'sample != examined_sample',
                 'sample_revision != examined_revision', 'QDELETED(examined_sample)',
                 'examined_sample.loc != src'):
        test.assertIn(term, scan.split('var/obj/item/weapon/paper/report', 1)[0])
    test.assertEqual(scan.count('report_num++'), 1)
    test.assertNotIn('++report_num', scan)
    test.assertIn('GSR report #[report_num]', scan)


class MicroscopeIntegrityTest(unittest.TestCase):
    def test_sample_changes_cancel_before_report_and_gsr_uses_one_number(self):
        assert_integrity(self, SOURCE.read_text(encoding='utf-8'))

    def test_original_race_and_double_increment_are_rejected(self):
        source = SOURCE.read_text(encoding='utf-8')
        for old in (source.replace('sample_revision != examined_revision', 'FALSE', 1),
                    source.replace('GSR report #[report_num]', 'GSR report #[++report_num]', 1)):
            with self.assertRaises(AssertionError):
                assert_integrity(self, old)


if __name__ == '__main__':
    unittest.main()
