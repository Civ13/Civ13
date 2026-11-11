"""Rain sound loops on the client (offline source check, no BYOND).

The server used to replay rain.ogg every 145 seconds, so the rain went quiet
whenever the server stalled past one replay. The sound now loops on the client
with repeat = TRUE; the server only starts it, changes its volume with
SOUND_UPDATE and stops it.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(relative):
    return (ROOT / relative).read_text(encoding='utf-8')


class RainLoopTests(unittest.TestCase):
    def setUp(self):
        life = read('code/game/mob/living/life.dm')
        start = life.index('/mob/living/proc/update_rain_sound(volume)')
        self.life = life
        self.update = life[start:life.index('/proc/stop_rain_sound', start)]

    def test_rain_loops_on_client(self):
        self.assertRegex(self.update, r"sound\('sound/ambience/rain\.ogg', repeat = TRUE")
        self.assertIn('S.status = SOUND_UPDATE', self.update)
        self.assertIn('channel = SOUND_CHANNEL_RAIN', self.update)

    def test_no_server_timed_replay(self):
        self.assertNotIn('next_weather_sound', self.life)
        self.assertNotIn('next_weather_sound', read('code/modules/persistence/world_time_stamps.dm'))
        self.assertIn('update_rain_sound(near_rainy_area ? (100 - (rdist*2)) : 0)', self.life)

    def test_state_lives_on_client(self):
        self.assertRegex(read('code/modules/client/client_defines.dm'), r'var/rain_sound_volume = 0')
        self.assertIn('#define SOUND_CHANNEL_RAIN 778', read('code/__defines/mobs.dm'))
        ghost = read('code/game/mob/observer/ghost/ghost.dm')
        self.assertIn('stop_rain_sound(src)', ghost)
        self.assertNotRegex(ghost, r'channel = 778')

    def test_ambience_already_loops(self):
        areas = read('code/game/area/areas.dm')
        self.assertTrue(re.search(r'sound\(sound, repeat = TRUE.*channel = SOUND_CHANNEL_AMBIENCE', areas))


if __name__ == '__main__':
    unittest.main()
