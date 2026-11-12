"""Reactor coolant refills need an open container (issue #4856)."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/machinery/nuclear_generation.dm'
HEADER = '/obj/structure/civ_generator/nuclear/attackby(obj/item/W, mob/user)'


def attackby_body():
    text = SOURCE.read_text(encoding='utf-8')
    start = text.index(HEADER + '\n') + len(HEADER) + 1
    lines = []
    for line in text[start:].splitlines():
        if line and not line.startswith('\t'):
            break
        lines.append(line)
    return '\n'.join(lines)


class ReactorCoolantSealTest(unittest.TestCase):
    def test_sealed_check_precedes_any_transfer(self):
        body = attackby_body()
        branch = body.index('get_reagent_amount("water") >= 1 && coolant < 100')
        seal = body.index('if (!W.is_open_container())', branch)
        remove = body.index('W.reagents.remove_reagent("water", transfer)', branch)
        credit = body.index('coolant += transfer', branch)
        self.assertTrue(branch < seal < remove < credit)
        # The sealed branch stops before touching either reservoir.
        sealed_block = body[seal:remove].splitlines()[1:]
        self.assertTrue(any(line.strip() == 'return' for line in sealed_block), sealed_block)


if __name__ == '__main__':
    unittest.main()
