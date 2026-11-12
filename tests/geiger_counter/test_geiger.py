"""Offline check of the Geiger counter scan loop (native probe: probe.dm).

Covers one loop per switch-on (#4918), resuming after load (#4919) and
expiring old pulses (#4920).
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/radiation.dm'
PREFIX = '/obj/item/weapon/geiger_counter'

# Pre-fix loop and toggle, frozen as a negative control.
OLD = '''/obj/item/weapon/geiger_counter/rad_act(var/severity)
	radiation_count = severity*100 //to convert to mSv
	update_icon()

/obj/item/weapon/geiger_counter/verb/turn_on()
	scanning = !scanning
	if (!scanning)
		radiation_count = 0
	if (scanning)
		processing()

/obj/item/weapon/geiger_counter/proc/processing()
	if (scanning)
		update_icon()
		checked = TRUE
		spawn(10)
			processing()
	else
		radiation_count = 0
		return
'''


def block(source, header):
    start = source.find(header)
    if start == -1:
        return ''
    end = source.find('\n/', start + 1)
    return source[start:end if end != -1 else None]


def single_loop(source):
    """Stale callbacks stop: the loop carries a generation it checks against the counter's."""
    loop = block(source, PREFIX + '/proc/processing(generation)')
    toggle = block(source, PREFIX + '/verb/turn_on()')
    return ('if (generation != scan_generation)' in loop and 'processing(generation)' in loop
            and 'scan_generation++' in toggle and 'start_scanning()' in toggle)


def resumes_after_load(source):
    load = block(source, PREFIX + '/after_load()')
    return 'if (scanning)' in load and 'start_scanning()' in load


def pulses_expire(source):
    act = block(source, PREFIX + '/rad_act(')
    loop = block(source, PREFIX + '/proc/processing(generation)')
    return 'last_pulse_time = world.time' in act and 'world.time - last_pulse_time' in loop


class GeigerCounterTest(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')

    def test_one_scan_loop(self):
        self.assertTrue(single_loop(self.source))

    def test_resumes_after_load(self):
        self.assertTrue(resumes_after_load(self.source))

    def test_old_pulses_expire(self):
        self.assertTrue(pulses_expire(self.source))

    def test_loop_state_is_runtime_only(self):
        self.assertIn('var/tmp/scan_generation', self.source)
        self.assertIn('var/tmp/last_pulse_time', self.source)
        saved = block(self.source, PREFIX + '/get_saved_vars()')
        self.assertIn('"scan_generation", "last_pulse_time"', saved)

    def test_negative_control_old_source(self):
        self.assertFalse(single_loop(OLD))
        self.assertFalse(resumes_after_load(OLD))
        self.assertFalse(pulses_expire(OLD))


if __name__ == '__main__':
    unittest.main()
