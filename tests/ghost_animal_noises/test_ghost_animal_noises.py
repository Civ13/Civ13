"""Ghost animal noises: ghosts can hear animals only nearby while keeping
global emotes from players. Offline wiring checks."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8', errors='replace')


class GhostAnimalNoises(unittest.TestCase):
    def test_preference_exists_and_defaults_on(self):
        datums = read('code/modules/client/preferencesSQLite/preference_setup/global/setting_datums.dm')
        block = datums[datums.index('/datum/client_preference/ghost_animals'):]
        block = block[:block.index('\n\n')]
        self.assertIn('key = "CHAT_GHOSTANIMALS"', block)
        self.assertNotIn('enabled_by_default = FALSE', block)
        prefs = read('code/modules/client/preferencesSQLite/preferences.dm')
        self.assertIn('"CHAT_GHOSTANIMALS"', prefs[prefs.index('var/list/preferences_enabled'):prefs.index('var/list/preferences_disabled')])

    def test_global_emote_loop_skips_animals_when_muted(self):
        emote = read('code/game/mob/emote.dm')
        body = emote[emote.index('/mob/proc/custom_emote('):emote.index('/mob/proc/emote_dead(')]
        loop = body[body.index('for (var/mob/M in player_list)'):body.index('if (m_type & TRUE)')]
        self.assertIn('var/animal_noise = makes_animal_noises()', body)
        self.assertRegex(loop, r'ghost_sight\).*\n\s+if \(animal_noise && !M\.is_preference_enabled\(/datum/client_preference/ghost_animals\)\)\n\s+continue')
        # Nearby viewers and hearers are not filtered.
        self.assertNotIn('ghost_animals', body[body.index('if (m_type & TRUE)'):])

    def test_only_server_run_animals_count(self):
        emote = read('code/game/mob/emote.dm')
        self.assertRegex(emote, r'/mob/proc/makes_animal_noises\(\)\n\treturn FALSE')
        self.assertRegex(emote, r'/mob/living/simple_animal/makes_animal_noises\(\)\n\treturn !client')
        for path in ('hostile/human', 'hostage', 'wizard'):
            self.assertRegex(emote, rf'/mob/living/simple_animal/{re.escape(path)}/makes_animal_noises\(\)\n\treturn FALSE')

    def test_ghost_verb_toggles_by_key(self):
        ghost = read('code/game/mob/observer/ghost/ghost.dm')
        verb = ghost[ghost.index('/mob/observer/ghost/verb/toggle_animal_noises()'):ghost.index('/mob/observer/ghost/verb/toggle_darkness()')]
        self.assertIn('set category = "Ghost"', verb)
        # set_preference compares keys against the enabled list, so pass the key.
        self.assertIn('set_preference("CHAT_GHOSTANIMALS", hear_all)', verb)


if __name__ == '__main__':
    unittest.main()
