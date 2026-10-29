"""Execute production grant/HUD refresh with inert screen and HUD boundaries."""
from pathlib import Path
import re
import sys
from types import SimpleNamespace as NS
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tests/save_movement'))
from source_adapter import extract, project


class Screen(set):
    def __iadd__(self, value): self.add(value); return self
    def __isub__(self, value): self.discard(value); return self
    def __ior__(self, value):
        if isinstance(value, (list, set, tuple)): self.update(value)
        else: self.add(value)
        return self


class Button:
    moved = False
    def UpdateIcon(self): pass


class Action:
    def __init__(self): self.owner, self.button = None, Button()
    def UpdateName(self): return 'restored scope action'
    def Remove(self, owner): raise AssertionError('Existing owner must not be removed during reconnect')


def source(path):
    # Remove comments only; project complete selected executable bodies.
    return re.sub(r'/\*.*?\*/', '', (ROOT/path).read_text(encoding='utf-8-sig'), flags=re.S)


def fixture():
    holder = NS(client=None, actions=Screen(), contents=Screen())
    hud = NS(ButtonNumberToScreenCoords=lambda number: 'button-'+str(number))
    env = dict(client=None, hud_used=hud, actions=holder.actions, contents=holder.contents,
               typed_iter=lambda values, kind: values, new=lambda owner: Button())
    refresh = project(source('code/game/mob/living/living_defense.dm'), '/mob/living/update_action_buttons', '', env)
    holder.update_action_buttons = refresh
    grant_decl = '/datum/action/proc/Grant'
    body = extract(source('code/_onclick/hud/action.dm'), grant_decl)
    for name in ('owner', 'button', 'Remove'):
        body = re.sub(r'(?<![\w.])'+name+r'\b', 'src.'+name, body)
    grant = project(grant_decl+'(T)\n'+body+'\n', grant_decl, 'src, T', env)
    def rebuild():
        # Native HUD reconstruction is the injected boundary. The production
        # show_HUD source guard below establishes its screen-clearing contract.
        env['client'].screen.clear()
        env['client'].screen.add('base HUD')
    env.update(check_HUD=rebuild, update_action_buttons=refresh)
    update_hud = project(source('code/game/mob/living/carbon/human/human_hud.dm'), '/mob/living/human/update_hud', '', env)
    return holder, env, grant, update_hud


class ActionReconnect(unittest.TestCase):
    def test_reconnect_repopulates_constructor_buttons_after_hud_clears_screen(self):
        holder, env, grant, update = fixture()
        action = Action()
        button = action.button
        grant(action, holder)  # Restore before a client exists.
        self.assertIs(action.owner, holder)
        self.assertIn(action, holder.actions)
        for _ in range(2):  # Separate fresh clients model disconnect/reconnect.
            holder.client = env['client'] = NS(prefs=None, screen=Screen())
            grant(action, holder)  # Same-owner early return cannot add the button.
            self.assertNotIn(button, holder.client.screen)
            update()
            self.assertIn(button, holder.client.screen)
            self.assertIn('base HUD', holder.client.screen)
            self.assertIs(action.button, button)
            self.assertEqual(len(holder.actions), 1)
            button.moved, button.screen_loc = True, 'custom-position'
            update()
            self.assertIn(button, holder.client.screen)
            self.assertEqual(button.screen_loc, 'custom-position')

    def test_refresh_runs_after_human_hud_and_inventory_screen_rebuild(self):
        hud = extract(source('code/game/mob/living/carbon/human/human_hud.dm'), '/mob/living/human/update_hud')
        self.assertLess(hud.index('check_HUD()'), hud.index('update_action_buttons()'))
        self.assertLess(hud.index('client.screen |= contents'), hud.index('update_action_buttons()'))
        show = extract(source('code/game/mob/living/living_hud.dm'), '/mob/living/proc/show_HUD')
        self.assertIn('client.screen.Cut()', show)


if __name__ == '__main__': unittest.main()
