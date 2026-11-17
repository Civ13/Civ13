"""Offline checks for Ada's voice thread (tools/agent-control/voice.py) and the run watchdog. No BYOND runtime."""

import json
import sys
import types
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "agent-control"))

import autopilot  # noqa: E402
from voice import Voice  # noqa: E402


class Clock:
    def __init__(self):
        self.now = 1000.0

    def __call__(self):
        return self.now


class FakeClient:
    def __init__(self, messages, stat=0):
        self.messages, self.stat, self.sent = messages, stat, []

    def request(self, action, args):
        self.sent.append((action, dict(args)))
        if action == "character_observe":
            fresh = [m for m in self.messages if m["id"] > args.get("since", 0)]
            last = max([m["id"] for m in self.messages] or [0])
            return {"ok": True, "result": {"self": {"name": "Ada", "stat": self.stat}, "messages": fresh, "last_message": last}}
        return {"ok": True}


GINA = {"id": 7, "text": 'Gina Lucan says, "Hey Ada, where is the river?"'}


def voice_for(client, clock, answer='{"say": "Just east of here, follow the slope down."}'):
    asked = []

    def ask(messages):
        asked.append(messages)
        return answer

    v = Voice(client, "[0xada]", ask, "Survive", autopilot.speech_lines, {}, autopilot.SPEECH_GAP,
              clock=clock, sleep=lambda s: None, log=lambda *a: None)
    return v, asked


class VoiceTests(unittest.TestCase):
    def test_answers_while_the_main_loop_is_stuck(self):
        clock = Clock()
        client = FakeClient([GINA])
        v, asked = voice_for(client, clock)
        v.beat(since=0, name="Ada")
        # A busy main loop answers speech itself: the voice stays quiet.
        self.assertEqual(v.turn(), "")
        self.assertEqual(client.sent, [])
        clock.now += 25  # no finished turn for longer than VOICE_LAG
        self.assertEqual(v.turn(), "Just east of here, follow the slope down.")
        said = [args for action, args in client.sent if action == "character_act"]
        self.assertEqual(said, [{"character": "[0xada]", "do": "say", "text": "Just east of here, follow the slope down."}])
        self.assertIn("where is the river", asked[0][1]["content"])
        # The main loop skips what the voice answered, and drops its own late say for those speakers.
        self.assertEqual(v.unanswered([GINA, {"id": 8, "text": "x"}]), [{"id": 8, "text": "x"}])
        self.assertTrue(v.answered_after(["Gina Lucan"], 1000.0))
        self.assertFalse(v.answered_after(["Gina Lucan"], clock.now + 1))
        # The same words are not answered twice.
        clock.now += 30
        self.assertEqual(v.turn(), "")

    def test_quiet_when_out_cold_or_nobody_spoke(self):
        clock = Clock()
        v, asked = voice_for(FakeClient([GINA], stat=1), clock)
        clock.now += 30
        self.assertEqual(v.turn(), "")
        v, asked = voice_for(FakeClient([{"id": 3, "text": "Gina Lucan waves."}]), clock)
        clock.now += 30
        self.assertEqual(v.turn(), "")
        self.assertEqual(asked, [])

    def test_a_bad_model_reply_says_nothing(self):
        clock = Clock()
        client = FakeClient([GINA])
        v, _ = voice_for(client, clock, answer="not json")
        clock.now += 30
        self.assertEqual(v.turn(), "")
        self.assertFalse(any(action == "character_act" for action, _ in client.sent))

    def test_waits_for_a_busy_shared_client(self):
        clock = Clock()

        class Busy(FakeClient):
            def __init__(self, *a):
                super().__init__(*a)
                self.busy = 2

            def request(self, action, args):
                if self.busy:
                    self.busy -= 1
                    raise autopilot.ContractError("another request is pending")
                return super().request(action, args)

        v, _ = voice_for(Busy([GINA]), clock)
        clock.now += 30
        self.assertTrue(v.turn())

    def test_watchdog_dumps_stacks_and_exits_a_hung_turn(self):
        args = types.SimpleNamespace(stall_limit=600, timeout=300)
        with mock.patch.object(autopilot.faulthandler, "dump_traceback_later") as arm:
            autopilot.arm_watchdog(args)
        arm.assert_called_once()
        self.assertEqual(arm.call_args.args[0], 900)  # never shorter than three slow model turns
        self.assertTrue(arm.call_args.kwargs["exit"])
        with mock.patch.object(autopilot.faulthandler, "dump_traceback_later") as arm:
            autopilot.arm_watchdog(types.SimpleNamespace(stall_limit=0, timeout=120))
        arm.assert_not_called()

    def test_command_line_turns_voice_and_watchdog_on(self):
        source = (ROOT / "tools/agent-control/autopilot.py").read_text(encoding="utf-8")
        self.assertIn('"--no-voice", dest="voice", action="store_false"', source)
        self.assertIn('"--stall-limit", type=float, default=STALL_LIMIT', source)
        play = source.split("def _play(", 1)[1]
        self.assertIn("arm_watchdog(args)", play.split("for step in range", 1)[1][:200])
        self.assertIn("voice.unanswered(", play)
        dm = (ROOT / "code/modules/agent_control/agent_characters.dm").read_text(encoding="utf-8")
        self.assertIn('if (action != "say")', dm)


if __name__ == "__main__":
    unittest.main()
