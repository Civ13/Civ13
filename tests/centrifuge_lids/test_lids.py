"""Offline guard/order checks, not native gameplay evidence."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "code/modules/reagents/Chemistry-Machinery.dm"

def body(source, proc):
    start = source.index("/obj/structure/centrifuge/" + proc)
    end = source.find("\n/", start + 1)
    return source[start:end]

def input_guard(source):
    text = body(source, "attackby")
    guard = text.find("if (!B.is_open_container())")
    first_effect = min(text.index("B.reagents.trans_to_holder"), text.index("collector =  B"))
    return guard >= 0 and guard < first_effect and "\n\t\t\treturn\n" in text[guard:first_effect]

def output_guard(source):
    text = body(source, "proc/separate_batch")
    guard = text.find("!collector.is_open_container()")
    return guard >= 0 and "return FALSE" in text[guard:text.index("var/largest")]

class CentrifugeLids(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text()
    def test_closed_input_is_refused_before_pour_or_install(self):
        self.assertTrue(input_guard(self.source))
    def test_collector_rechecked_before_output_and_input_debit(self):
        self.assertTrue(output_guard(self.source))
    def test_input_guard_omission_negative_control(self):
        self.assertFalse(input_guard(self.source.replace("if (!B.is_open_container())", "if (FALSE)")))
    def test_collector_guard_omission_negative_control(self):
        self.assertFalse(output_guard(self.source.replace("!collector.is_open_container() || ", "")))

if __name__ == "__main__":
    unittest.main()
