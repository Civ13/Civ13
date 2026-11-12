"""Model external engine callback chains from source, not BYOND."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/machinery/engines/external_combustion.dm'

# The pre-fix running() and turn_on() core, frozen as a negative control.
OLD = '''/obj/structure/engine/external/turn_on(var/mob/user = null)
			on = TRUE
			update_icon()
			running()
/obj/structure/engine/external/running()
	var/pwd=0
	if (!pwd)
		visible_message("The engine stalls.")
		return
	else
		spawn(10)
			running()
		return
'''


def proc(source, name):
    start = source.index('/obj/structure/engine/external/%s(' % name)
    end = source.find('\n/', start + 1)
    return source[start:end if end != -1 else None]


class Engine:
    """Executes the guards the source declares around running() and its spawn(10) callback."""

    def __init__(self, source, heat=True):
        self.source = source
        self.run_body = proc(source, 'running')
        self.turn_body = proc(source, 'turn_on')
        self.on = False
        self.run_generation = 0
        self.heat = heat
        self.pending = []
        self.stalls = 0
        self.ticks = 0

    def cond(self, expr, generation=None):
        expr = expr.replace('generation == run_generation', str(generation == self.run_generation))
        expr = re.sub(r'\bon\b', str(self.on), expr).replace('&&', ' and ')
        return bool(eval(expr))

    def turn_on(self):
        self.on = True
        if 'run_generation++' in self.turn_body:
            self.run_generation += 1
        self.running()

    def turn_off(self):
        self.on = False

    def running(self):
        first = self.run_body.split('\n')[1].strip()
        if first == 'if (!on)' and not self.on:
            return
        if not self.heat:
            self.stalls += 1
            self.on = False
            return
        self.ticks += 1
        guard = re.search(r'spawn\(10\)\n\t+if \((.*)\)\n\t+running\(\)', self.run_body)
        self.pending.append((guard.group(1) if guard else None, self.run_generation))

    def advance(self):
        due, self.pending = self.pending, []
        for guard, generation in due:
            if guard is None or self.cond(guard, generation):
                self.running()


class EngineCallbackTest(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')

    def test_shutdown_stops_the_chain(self):
        e = Engine(self.source)
        e.turn_on()
        e.turn_off()
        e.advance()
        e.advance()
        self.assertEqual(e.ticks, 1)
        self.assertEqual(e.pending, [])

    def test_restart_before_pending_tick_keeps_one_chain(self):
        e = Engine(self.source)
        e.turn_on()
        e.turn_off()
        e.turn_on()
        for _ in range(3):
            e.advance()
            self.assertEqual(len(e.pending), 1)

    def test_heat_loss_still_stalls_a_running_engine(self):
        e = Engine(self.source)
        e.turn_on()
        e.heat = False
        e.advance()
        self.assertEqual(e.stalls, 1)
        self.assertFalse(e.on)

    def test_switched_off_engine_does_not_stall_later(self):
        e = Engine(self.source)
        e.turn_on()
        e.turn_off()
        e.heat = False
        e.advance()
        self.assertEqual(e.stalls, 0)

    def test_negative_control_old_chain_survives_shutdown(self):
        e = Engine(OLD)
        e.turn_on()
        e.turn_off()
        e.turn_on()
        e.advance()
        self.assertEqual(len(e.pending), 2)


if __name__ == '__main__':
    unittest.main()
