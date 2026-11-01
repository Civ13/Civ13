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


def fixture(update_text=None):
    holder = NS(client=None, actions=Screen(), contents=Screen())
    hud = NS(ButtonNumberToScreenCoords=lambda number: 'button-'+str(number))
    holder.hud_used = hud
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
        # Parent login already supplied a fresh screen. A healthy HUD check
        # reattaches its own members without clearing another screen owner.
        env['client'].screen.add('base HUD')
        return False
    env.update(check_HUD=rebuild, update_action_buttons=refresh, holder=holder,
               handle_ui_visibility=lambda: None)
    declaration = '/mob/living/human/update_hud'
    body = extract(update_text or source('code/game/mob/living/carbon/human/human_hud.dm'), declaration)
    # hud_used is a mob field, including on assignment during missing-HUD
    # recovery. Keep it qualified rather than making a Python local shadow.
    body = re.sub(r'(?<![\w.])hud_used\b', 'holder.hud_used', body)
    update_hud = project(declaration+'()\n'+body+'\n', declaration, '', env)
    return holder, env, grant, update_hud


class ActionReconnect(unittest.TestCase):
    def test_possessed_animal_reconnect_restores_pregranted_buttons_after_parent_login(self):
        holder, env, grant, _ = fixture()
        declaration = '/mob/living/simple_animal/Login'
        body = extract(source('code/game/mob/living/simple_animal/simple_animal.dm'), declaration)
        # Parent login owns retirement and the screen reset. The subclass must
        # leave the old owner's screen intact until that boundary is entered.
        self.assertEqual(body.count('..()'), 1)
        body = body.replace('client.screen = null', 'client.screen.clear()').replace('..()', 'parent_login()')
        def parent_login():
            self.assertIn('prior-owner HUD', env['client'].screen)
            env['client'].screen.clear()
            env['client'].screen.add('animal HUD')
        env.update(src=holder, parent_login=parent_login)
        login = project(declaration+'()\n'+body+'\n', declaration, '', env)
        action = Action()
        button = action.button
        grant(action, holder)
        for _ in range(2):
            holder.client = env['client'] = NS(screen=Screen())
            grant(action, holder)
            self.assertNotIn(button, holder.client.screen)
            holder.client.screen.add('prior-owner HUD')
            login()
            self.assertNotIn('prior-owner HUD', holder.client.screen)
            self.assertIn(button, holder.client.screen)
            self.assertIn('animal HUD', holder.client.screen)
            self.assertIs(action.owner, holder)
            self.assertIs(action.button, button)
            self.assertEqual(len(holder.actions), 1)
            button.moved, button.screen_loc = True, 'animal-custom-position'
            holder.client.screen.add('prior-owner HUD')
            login()
            self.assertNotIn('prior-owner HUD', holder.client.screen)
            self.assertIn(button, holder.client.screen)
            self.assertEqual(button.screen_loc, 'animal-custom-position')

        # Reintroducing the former subclass clear must break the ownership
        # boundary, even though the parent would rebuild the final screen.
        mutant_body = '\tif (src && client)\n\t\tclient.screen.clear()\n' + body
        mutant = project(declaration+'()\n'+mutant_body+'\n', declaration, '', env)
        holder.client.screen.add('prior-owner HUD')
        with self.assertRaisesRegex(AssertionError, 'prior-owner HUD'):
            mutant()

        parent = extract(source('code/game/mob/login.dm'), '/mob/Login')
        living = extract(source('code/game/mob/living/login.dm'), '/mob/living/Login')
        self.assertIn('client.screen = null', parent)
        self.assertLess(parent.index('client.los_context.retire()'), parent.index('client.screen = null'))
        self.assertIn('hud_used = new /datum/hud(src)', parent)
        self.assertNotIn('update_action_buttons()', parent+living)

    def test_reconnect_repopulates_constructor_buttons_after_login_clears_screen(self):
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
            holder.client.screen.add('unrelated screen owner')
            update()
            self.assertIn(button, holder.client.screen)
            self.assertIn('base HUD', holder.client.screen)
            self.assertIn('unrelated screen owner', holder.client.screen)
            self.assertIs(action.button, button)
            self.assertEqual(len(holder.actions), 1)
            button.moved, button.screen_loc = True, 'custom-position'
            update()
            self.assertIn(button, holder.client.screen)
            self.assertEqual(button.screen_loc, 'custom-position')

        # Omitting the production reattachment must leave a restored,
        # already-owned action absent after login supplied a fresh screen.
        text = source('code/game/mob/living/carbon/human/human_hud.dm').replace('\t\tupdate_action_buttons()', '\t\t// omitted')
        holder, env, grant, update = fixture(text)
        action = Action()
        grant(action, holder)
        holder.client = env['client'] = NS(prefs=None, screen=Screen())
        grant(action, holder)
        update()
        self.assertIn('base HUD', holder.client.screen)
        self.assertNotIn(action.button, holder.client.screen)

    def test_refresh_runs_after_human_hud_and_inventory_screen_rebuild(self):
        hud = extract(source('code/game/mob/living/carbon/human/human_hud.dm'), '/mob/living/human/update_hud')
        self.assertLess(hud.index('check_HUD()'), hud.index('update_action_buttons()'))
        self.assertLess(hud.index('client.screen |= contents'), hud.index('update_action_buttons()'))
        show = extract(source('code/game/mob/living/living_hud.dm'), '/mob/living/proc/show_HUD')
        self.assertNotIn('client.screen.Cut()', show)
        self.assertNotIn('PM.backdrop(src)', show)
        self.assertIn('client.screen |= HUDneed[p]', show)


if __name__ == '__main__': unittest.main()
