"""Tap to step: default, HUD toggle and Settings wiring (offline source checks)."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODULE = (ROOT / 'code/game/mob/living/carbon/human/subtile_movement.dm').read_text()


class TapToStepSetting(unittest.TestCase):
    """Tap to step: on by default, a HUD toggle in every style, and in Settings."""

    def test_on_by_default_and_told_once(self):
        self.assertIn('/datum/preferences\n\tvar/tap_step = TRUE\n\tvar/tap_step_told = FALSE', MODULE)
        saving = (ROOT / 'code/modules/client/preferencesSQLite/preferences_saving&loading&del.dm').read_text()
        # Only a value that differs from the default is saved, so "off" is kept.
        self.assertIn('"tap_step", "tap_step_told"', saving)
        self.assertIn("if (vars[key] == initial(vars[key]))", saving)
        notice = MODULE.split('/mob/living/human/proc/tap_step_first_notice()', 1)[1].split('\n/obj/screen', 1)[0]
        self.assertIn('client.prefs.tap_step_told || !client.prefs.tap_step', notice)

    def test_the_verb_the_button_and_settings_share_one_setter(self):
        self.assertEqual(MODULE.count('set_tap_step('), 3)  # the proc, the verb, the button
        setup = (ROOT / 'code/modules/client/preferencesSQLite/character_setup_ui.dm').read_text()
        self.assertIn('user.client.set_tap_step(value ? TRUE : FALSE)', setup)
        for action in ('tap_step', 'hover_text', 'hover_text_scale', 'hud_scale', 'edit_hud_layout', 'reset_hud_layout', 'keybindings'):
            self.assertIn('"%s"' % action, setup.split('/datum/preferences/ui_actions(ui_key)', 1)[1].split('\n', 2)[1], action)
            self.assertIn('if ("%s")' % action, setup, action)
        screen = (ROOT / 'tgui/src/interfaces/CharacterSetup.tsx').read_text()
        self.assertIn('<Section title="Controls and HUD">', screen)
        for action in ('tap_step', 'hover_text', 'hover_text_scale', 'hud_scale', 'edit_hud_layout', 'reset_hud_layout', 'keybindings'):
            self.assertIn('action="%s"' % action, screen, action)

    def test_every_hud_style_has_the_button_on_its_own_spot(self):
        hud = (ROOT / 'code/datums/hud.dm').read_text()
        blocks = re.split(r'^(?=/datum/hud/human)', hud, flags=re.M)[1:]
        self.assertEqual(len(blocks), 5)
        for block in blocks:
            spot = re.search(r'"tap step" = \s*list\("type" = /obj/screen/tap_step,\s*"loc" = "([^"]+)"\)', block)
            self.assertIsNotNone(spot)
            self.assertEqual(len(re.findall(r'"loc" = "' + re.escape(spot[1]) + '"', block)), 1)
        species = (ROOT / 'code/game/mob/living/carbon/human/species/species_hud.dm').read_text()
        self.assertIn('"go down", "tap step")', species)

    def test_every_sheet_has_the_lit_and_unlit_button(self):
        import struct
        import zlib
        for sheet in ('1713Style', 'ConsoleStyle', 'litewebStyle', 'FoFStyle'):
            data = (ROOT / f'icons/mob/screen/{sheet}.dmi').read_bytes()
            i = data.find(b'zTXt')
            length = struct.unpack('>I', data[i - 4:i])[0]
            chunk = data[i + 4:i + 4 + length]
            text = zlib.decompress(chunk[chunk.index(bytes(1)) + 2:]).decode()
            for state in ('tap_step_on', 'tap_step_off'):
                self.assertEqual(text.count(f'state = "{state}"'), 1, sheet)

    def test_the_game_menu_opens_settings_directly(self):
        menu = (ROOT / 'code/modules/client/escape_menu.dm').read_text()
        self.assertIn('L["controls"] = list("Controls and HUD"', menu)
        self.assertIn('owner.prefs.setup_open_tab = "settings"', menu)


if __name__ == '__main__':
    unittest.main(verbosity=2)
