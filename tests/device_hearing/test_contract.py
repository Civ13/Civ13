"""Frozen pre-extraction source parity; no native execution is claimed."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / "code/game/mob/hear_say.dm").read_text()
LEGACY = (Path(__file__).parent / "legacy_comprehension.dm").read_text()

def body(name):
    return SOURCE.split("/mob/proc/" + name + "(", 1)[1].split("\n/mob/proc/", 1)[0].split("\n", 1)[1]

class DeviceHearingContract(unittest.TestCase):
    def test_extraction_preserves_branch_order_and_calls(self):
        helper = body("comprehend_device_speech")
        self.assertEqual(helper.strip(), (LEGACY + "\n\treturn list(message)\n").strip())

    def test_each_device_uses_helper_after_sleep_before_presentation(self):
        for name in ("hear_radio", "hear_phone", "hear_voicepipe"):
            with self.subTest(name=name):
                code = body(name)
                self.assertEqual(code.count("comprehend_device_speech(message, language, speaker)"), 1)
                self.assertIn("if (isnull(comprehended))\n\t\treturn\n\tmessage = comprehended[1]", code)
                self.assertLess(code.index("hear_sleep(message)"), code.index("comprehend_device_speech"))
                self.assertLess(code.index("comprehended[1]"), code.index("var/speaker_name"))
                self.assertNotIn("say_understands(", code)

    def test_nearby_speech_remains_separate(self):
        code = body("hear_say")
        self.assertNotIn("comprehend_device_speech", code)
        self.assertIn("H.knows_language(language)", code)

    def test_transport_differences_remain(self):
        self.assertIn("ten_code(message, speaker)", body("hear_radio"))
        self.assertIn("origin.contacts", body("hear_phone"))
        self.assertIn('replacetext(message,";","")', body("hear_voicepipe"))

if __name__ == "__main__":
    unittest.main()
