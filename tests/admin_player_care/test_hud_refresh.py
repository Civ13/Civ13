"""Offline production-procedure projections with inert screen/client adapters.

These tests exercise membership, ownership and control flow, not BYOND rendering,
native list implementation, scheduler timing, mouse hits or gameplay acceptance.
"""
import importlib.util
from pathlib import Path
import re
from types import SimpleNamespace as N
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('care_regeneration', Path(__file__).with_name('test_player_care.py'))
CARE = importlib.util.module_from_spec(spec)
spec.loader.exec_module(CARE)
LIVING = 'code/game/mob/living/living_hud.dm'
HUMAN = 'code/game/mob/living/carbon/human/human_hud.dm'
ICONS = 'code/game/mob/living/carbon/human/update_icons.dm'


class Items(list):
    @property
    def len(self):
        return len(self)

    def __bool__(self):
        return True  # A non-null DM list is true even when empty.

    def __getitem__(self, index):
        return super().__getitem__(index - 1) if isinstance(index, int) else super().__getitem__(index)

    def __ior__(self, value):
        for item in value if isinstance(value, Items) else [value]:
            if item not in self:
                self.append(item)
        return self

    def __iadd__(self, value):
        self.extend(value if isinstance(value, Items) else [value])
        return self

    def __isub__(self, value):
        for item in value if isinstance(value, Items) else [value]:
            while item in self:
                self.remove(item)
        return self

    def Cut(self):
        self.clear()


class Mapping(dict):
    @property
    def len(self):
        return len(self)

    def __bool__(self):
        return True

    def __getitem__(self, key):
        return self.get(key)

    def Cut(self):
        self.clear()


class Screen:
    def __init__(self, name):
        self.name = name
        self.filters = Items()
        self.render_target = None
        self.deleted = False
        self.invisibility = 0
        self.backdrops = 0

    def backdrop(self, mob):
        self.backdrops += 1
        self.filters = Items(['shadow'])


FIELDS = ('client', 'HUDprocess', 'HUDneed', 'HUDinventory', 'HUDtech', 'HUDfrippery',
          'hud_used', 'transforming', 'defaultHUD', 'contents', 'prefs',
          'check_HUD', 'check_HUDdatum', 'check_HUD_style', 'show_HUD', 'destroy_HUD',
          'create_HUD', 'recolor_HUD', 'remove_HUD_element', 'regenerate_icons',
          'update_hud', 'update_action_buttons', 'handle_ui_visibility')


def project(source, signature, env, arguments='self'):
    """Translate the small inspected HUD procedures; unsupported syntax fails.

    Effects (qdel/new HUD, diagnostics, input and body appearance calls) are
    injected. No native fixture, external process or transport is imported.
    """
    start = source.index(signature)
    following = re.search(r'^/(?![/*])', source[start + len(signature):], re.M)
    end = start + len(signature) + following.start() if following else len(source)
    body = source[start:end]
    code = ['def projected(' + arguments + '):']
    for raw in body.splitlines()[1:]:
        line = raw.split('//', 1)[0].strip()
        if not line or line.startswith('set '):
            continue
        depth = len(raw) - len(raw.lstrip('\t'))
        line = re.sub(r'^var/(?:\w+/)*(\w+)\s*=', r'\1 =', line)
        line = line.replace('..()', 'parent(self)').replace('new /datum/hud(src)', 'new_hud(self)')
        if line.startswith('UI_style_new = input('):
            if not line.endswith('as null|anything in all_ui_styles'):
                raise AssertionError('Unexpected UI input syntax')
            line = 'UI_style_new = choose_style()'
        line = line.replace('global.HUDdatums', 'HUDdatums')
        line = re.sub(r'\bsrc\b', 'self', line).replace('usr:', 'usr.')
        for name in FIELDS:
            line = re.sub(r'(?<![\w.])' + name + r'\b', 'self.' + name, line)
        line = re.sub(r'\bTRUE\b', 'True', line)
        line = re.sub(r'\bFALSE\b', 'False', line)
        line = re.sub(r'\bnull\b', 'None', line)
        line = line.replace('&&', ' and ').replace('||', ' or ')
        line = re.sub(r'!(?!=)', 'not ', line)
        loop = re.fullmatch(r'for\s*\(var/(?:\w+/)*(\w+) in (.+)\)', line)
        condition = re.fullmatch(r'(if|else if)\s*\((.*)\)', line)
        if loop:
            line = 'for ' + loop[1] + ' in ' + loop[2] + ':'
        elif condition:
            line = ('if ' if condition[1] == 'if' else 'elif ') + condition[2] + ':'
        elif line == 'else':
            line = 'else:'
        elif line.startswith('++'):
            line = line[2:] + ' += 1'
        elif not (line == 'return' or line.startswith('return ') or
                  re.match(r'[\w.\[\]"\x27]+\s*(?:=|\|=|\+=|-=)', line) or
                  re.match(r'[\w.]+\(', line)):
            raise AssertionError('Unsupported HUD statement: ' + line)
        code.append('    ' * depth + line)
    namespace = dict(env, __builtins__={})
    exec(compile('\n'.join(code), signature, 'exec'), namespace)
    return namespace['projected']


def source(path):
    return (ROOT / path).read_text()


class OwnedHUD(unittest.TestCase):
    def model(self, living_source=None, human_source=None):
        living_source = living_source or source(LIVING)
        human_source = human_source or source(HUMAN)
        m = N(transforming=False, defaultHUD='old', scoped=False, events=[], creations=0)
        m.client = N(screen=Items(), prefs=N(UI_style='old', cursor=None, UI_style_color='blue', UI_style_alpha=220),
                     mouse_pointer_icon=None, pixel_x=128, pixel_y=-64, los_camera_union_until=250)
        m.contents = Items([Screen('held item')])
        m.private = Items(Screen(x) for x in ('root master', 'root relay', 'weather relay', 'map label', 'storage'))
        m.vehicle, m.spell, m.action = Screen('vehicle'), Screen('spell'), Screen('action')
        m.external_process = Screen('other owner process')
        m.HUDprocess = Items([m.external_process, m.vehicle])
        def create():
            m.events.append('create')
            m.creations += 1
            m.HUDneed = Mapping(health=Screen('health'), hover=Screen('hover'))
            m.HUDinventory = Items([Screen('inventory')])
            m.HUDfrippery = Items([Screen('frippery')])
            m.HUDtech = Mapping(vision=Screen('vision'))
            m.HUDprocess |= Items(m.HUDneed.values())
            m.HUDprocess |= Items(m.HUDtech.values())
        def new_hud(owner):
            owner.events.append('new planes')
            return N(plane_masters=Mapping(game=Screen('game'), mask=Screen('mask')),
                     vehicle_hud=Items(), wizard_hud=Items())
        create()
        m.events.clear()
        m.creations = 0
        m.hud_used = N(plane_masters=Mapping(game=Screen('game'), mask=Screen('mask')),
                       vehicle_hud=Items([m.vehicle]), wizard_hud=Items([m.spell]))
        m.game = m.hud_used.plane_masters['game']
        m.game.render_target = '*leased-game'
        m.client.screen |= m.private
        m.client.screen |= Items([m.vehicle, m.spell, m.action])
        m.client.screen |= Items(m.hud_used.plane_masters.values())
        m.create_HUD = create
        m.check_HUDdatum = lambda: m.client.prefs.UI_style in ('old', 'new')
        m.check_HUD_style = lambda: True
        m.recolor_HUD = lambda color, alpha: m.events.append('recolor')
        def scope():
            m.events.append('visibility')
            for item in self.owned(m):
                item.invisibility = 100 if m.scoped else 0
        m.handle_ui_visibility = scope
        def actions():
            m.events.append('actions')
            m.client.screen |= m.action
        m.update_action_buttons = actions
        env = dict(qdel=lambda obj: setattr(obj, 'deleted', True), new_hud=new_hud,
                   log_debug=lambda value: None, to_chat=lambda *args: None)
        methods = [(LIVING, living_source, 'remove_HUD_element', 'self, HUDelement'),
                   (LIVING, living_source, 'destroy_HUD', 'self'),
                   (LIVING, living_source, 'show_HUD', 'self'),
                   (HUMAN, human_source, 'check_HUD', 'self'),
                   (HUMAN, human_source, 'update_hud', 'self')]
        for path, text, name, arguments in methods:
            signature = ('/mob/living/proc/' if path == LIVING else '/mob/living/human/') + name + '('
            f = project(text, signature, env, arguments)
            setattr(m, name, lambda *args, f=f: f(m, *args))
        return m

    @staticmethod
    def owned(m):
        return list(m.HUDneed.values()) + list(m.HUDinventory) + list(m.HUDfrippery) + list(m.HUDtech.values())

    def assert_unrelated(self, m, renderer):
        self.assertIs(m.hud_used, renderer)
        for item in [*m.private, m.vehicle, m.spell, *renderer.plane_masters.values()]:
            self.assertIn(item, m.client.screen)
            self.assertFalse(item.deleted)
        self.assertEqual(m.game.filters, [])
        self.assertEqual(m.game.render_target, '*leased-game')
        self.assertEqual(m.game.backdrops, 0)
        self.assertEqual((m.client.pixel_x, m.client.pixel_y, m.client.los_camera_union_until), (128, -64, 250))

    def test_repeated_healthy_update_preserves_members_filters_and_camera_lease(self):
        m = self.model()
        renderer = m.hud_used
        m.update_hud()
        before = tuple(m.client.screen)
        for _ in range(4):
            m.update_hud()
        self.assertEqual(tuple(m.client.screen), before)
        self.assertEqual(m.creations, 0)
        self.assertNotIn('visibility', m.events)
        self.assert_unrelated(m, renderer)

    def test_style_change_replaces_only_owned_controls_and_processing(self):
        m = self.model()
        renderer, old = m.hud_used, self.owned(m)
        m.client.prefs.UI_style = 'new'
        m.scoped = True
        m.update_hud()
        self.assertEqual(m.creations, 1)
        for item in old:
            self.assertTrue(item.deleted)
            self.assertNotIn(item, m.client.screen)
            self.assertNotIn(item, m.HUDprocess)
        self.assertIn(m.external_process, m.HUDprocess)
        self.assertIn(m.vehicle, m.HUDprocess)
        for item in self.owned(m):
            self.assertIn(item, m.client.screen)
            self.assertEqual(item.invisibility, 100)
        self.assertEqual(m.events[-2:], ['actions', 'visibility'])
        self.assert_unrelated(m, renderer)

    def test_destroy_without_client_preserves_other_process_owner(self):
        m = self.model()
        old = self.owned(m)
        m.client = None
        m.destroy_HUD()
        self.assertTrue(all(item.deleted for item in old))
        self.assertEqual(m.HUDneed.len + m.HUDinventory.len + m.HUDtech.len + m.HUDfrippery.len, 0)
        self.assertIn(m.external_process, m.HUDprocess)
        self.assertIn(m.vehicle, m.HUDprocess)

    def test_show_repairs_missing_owned_and_auxiliary_members_idempotently(self):
        m = self.model()
        m.client.screen -= m.vehicle
        m.client.screen -= m.spell
        m.show_HUD()
        first = tuple(m.client.screen)
        m.show_HUD()
        self.assertEqual(tuple(m.client.screen), first)
        for item in [*self.owned(m), m.vehicle, m.spell]:
            self.assertIn(item, m.client.screen)

    def test_missing_collections_recover_but_do_not_replace_planes(self):
        for missing in ('HUDneed', 'HUDinventory'):
            with self.subTest(missing=missing):
                m = self.model()
                renderer = m.hud_used
                getattr(m, missing).Cut()
                m.update_hud()
                self.assertEqual(m.creations, 1)
                self.assert_unrelated(m, renderer)

    def test_missing_renderer_recovery_precedes_visibility_reconciliation(self):
        m = self.model()
        m.hud_used = None
        m.update_hud()
        self.assertEqual(m.events, ['new planes', 'actions', 'visibility'])
        self.assertIsNotNone(m.hud_used)

    def test_missing_renderer_and_collections_recover_together(self):
        m = self.model()
        m.hud_used = None
        m.HUDneed.Cut()
        m.HUDinventory.Cut()
        m.update_hud()
        self.assertEqual(m.events, ['new planes', 'create', 'actions', 'visibility'])
        self.assertGreater(m.HUDneed.len, 0)
        self.assertGreater(m.HUDinventory.len, 0)

    def test_invalid_style_and_recolor_keep_required_recovery(self):
        m = self.model()
        m.client.prefs.UI_style = 'missing-style'
        m.update_hud()
        self.assertEqual(m.defaultHUD, '1713Style')
        self.assertEqual(m.creations, 1)
        m = self.model()
        renderer = m.hud_used
        m.check_HUD_style = lambda: False
        m.client.prefs.cursor = 'red cursor'
        m.update_hud()
        self.assertIn('recolor', m.events)
        self.assertEqual(m.creations, 0)
        self.assertEqual(m.client.mouse_pointer_icon, 'red cursor')
        self.assert_unrelated(m, renderer)

    def test_visibility_reapplication_omission_is_detected(self):
        text = source(HUMAN).replace('handle_ui_visibility()', 'update_action_buttons()')
        m = self.model(human_source=text)
        m.scoped = True
        m.client.prefs.UI_style = 'new'
        m.update_hud()
        with self.assertRaises(AssertionError):
            self.assertTrue(all(item.invisibility == 100 for item in self.owned(m)))

    def test_global_clear_and_backdrop_negative_controls(self):
        text = source(LIVING)
        for mutation in (text.replace('if (client)\n\t\t// Reattach', 'if (client)\n\t\tclient.screen.Cut()\n\t\t// Reattach'),
                         text.replace('src.client.screen |= PM', 'PM.backdrop(src)\n\t\t\t\tsrc.client.screen |= PM')):
            m = self.model(living_source=mutation)
            with self.assertRaises(AssertionError):
                renderer = m.hud_used
                m.update_hud()
                self.assert_unrelated(m, renderer)

    def test_bulk_processing_clear_negative_control(self):
        text = source(LIVING).replace('var/mob/living/H = src', 'var/mob/living/H = src\n\tH.HUDprocess.Cut()')
        m = self.model(living_source=text)
        m.destroy_HUD()
        with self.assertRaises(AssertionError):
            self.assertIn(m.external_process, m.HUDprocess)


class AppearanceAndCallers(unittest.TestCase):
    def bind_regeneration(self, m, calls):
        def icons(refresh=True):
            steps = CARE.project_regeneration(CARE.proc(ICONS, '/mob/living/human/regenerate_icons('), refresh)
            for step in steps:
                calls.append(step)
                if step == 'update_hud':
                    m.update_hud()
                if m.client and step.startswith('update_inv_'):
                    self.assertGreater(m.HUDinventory.len, 0, 'HUD must exist before inventory positioning')
        m.regenerate_icons = icons

    def refresh(self, m, text=None):
        base = project(source('code/game/mob/update_icons.dm'), '/mob/proc/regenerate_appearance(', {})
        human = project(text or source(ICONS), '/mob/living/human/regenerate_appearance(', {'parent': base})
        human(m)

    def test_appearance_only_route_recovers_only_missing_state(self):
        for missing in (None, 'hud_used', 'HUDinventory', 'HUDneed'):
            with self.subTest(missing=missing):
                m = OwnedHUD().model()
                calls = []
                self.bind_regeneration(m, calls)
                if missing == 'hud_used':
                    m.hud_used = None
                elif missing:
                    getattr(m, missing).Cut()
                self.refresh(m)
                self.assertEqual('update_hud' in calls, missing is not None)
                self.assertIn('update_icons', calls)
                self.assertEqual(bool(m.events), missing is not None)
                if missing:
                    self.assertIsNotNone(m.hud_used)
                    self.assertGreater(m.HUDneed.len, 0)
                    self.assertGreater(m.HUDinventory.len, 0)

    def test_transforming_and_disconnected_appearance_do_not_recover(self):
        m = OwnedHUD().model()
        calls = []
        m.regenerate_icons = lambda refresh: calls.append(refresh)
        m.transforming = True
        m.hud_used = None
        self.refresh(m)
        self.assertEqual(calls, [])
        m.transforming = False
        m.client = None
        self.refresh(m)
        self.assertEqual(calls, [False])
        self.assertEqual(m.events, [])

    def test_missing_state_guard_omissions_are_detectable(self):
        for guard in ('!hud_used', '!HUDinventory.len', '!HUDneed.len'):
            m = OwnedHUD().model()
            self.bind_regeneration(m, [])
            if guard == '!hud_used':
                m.hud_used = None
            else:
                getattr(m, guard[1:].split('.')[0]).Cut()
            with self.assertRaises(AssertionError):
                self.refresh(m, source(ICONS).replace(guard, 'FALSE'))
                self.assertIn('visibility', m.events)

    def test_transform_guard_omission_is_detectable(self):
        m = OwnedHUD().model()
        m.transforming = True
        calls = []
        m.regenerate_icons = lambda refresh: calls.append(refresh)
        text = source(ICONS).replace('/mob/living/human/regenerate_appearance()\n\tif (transforming)',
                                     '/mob/living/human/regenerate_appearance()\n\tif (FALSE)')
        self.refresh(m, text)
        with self.assertRaises(AssertionError):
            self.assertEqual(calls, [])

    def test_cosmetic_and_healing_callers_use_recovering_appearance_route(self):
        cases = (
            ('code/game/mob/living/carbon/human/human_organs.dm', '/mob/living/human/proc/update_eyes('),
            ('code/modules/organs/organ_external.dm', '/obj/item/organ/external/proc/droplimb('),
            ('code/game/mob/living/living.dm', '/mob/living/proc/rejuvenate('),
            ('code/game/objects/items/weapons/defib.dm', '/obj/item/weapon/shockpaddles/proc/make_alive('),
            ('code/game/mob/mob.dm', '/mob/proc/update_canmove('),
            ('code/game/mob/observer/ghost/ghost.dm', '/mob/observer/ghost/verb/reenter_corpse('),
        )
        for path, signature in cases:
            with self.subTest(path=path):
                body = CARE.proc(path, signature)
                self.assertIn('regenerate_appearance()', body)
                self.assertNotIn('regenerate_icons()', body)
        for path, signature in (
                ('code/game/mob/living/carbon/human/human_life.dm', '/mob/living/human/Life('),
                ('code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Food-Drinks.dm', '/datum/reagent/drink/health/draught/affect_ingest(')):
            self.assertIn('rejuvenate()', CARE.proc(path, signature))

    def test_explicit_admin_repair_and_login_keep_full_hud_recovery(self):
        admin = source('code/modules/admin/view_variables/topic.dm')
        self.assertIn('M.regenerate_icons()', admin.split('href_list["regenerateicons"]', 1)[1].split('else if', 1)[0])
        self.assertIn('update_hud()', CARE.proc(ICONS, '/mob/living/human/Login('))
        login = CARE.proc('code/game/mob/login.dm', '/mob/Login(')
        self.assertIn('client.screen = null', login)
        self.assertIn('hud_used = new /datum/hud(src)', login)

    def test_species_keeps_renderer_and_invalidates_layout_once(self):
        body = CARE.proc('code/game/mob/living/carbon/human/human.dm', '/mob/living/human/proc/set_species(')
        self.assertEqual(body.count('destroy_HUD()'), 1)
        self.assertIn('spawn(0)\n\t\tregenerate_icons()', body)
        self.assertNotIn('client.screen', body)
        self.assertNotIn('qdel(hud_used)', body)
        self.assertNotIn('new /datum/hud', body)
        m = OwnedHUD().model()
        renderer = m.hud_used
        m.destroy_HUD()
        m.update_hud()  # Deferred regeneration's default HUD repair.
        self.assertEqual(m.creations, 1)
        OwnedHUD().assert_unrelated(m, renderer)


class StyleChoice(unittest.TestCase):
    def choose(self, choice, text=None):
        m = N(prefs=N(UI_style='old', UI_file='old-icon'), saved=0, refreshed=0)
        m.prefs.save_preferences = lambda: setattr(m, 'saved', m.saved + 1)
        usr = N(regenerate_icons=lambda: setattr(m, 'refreshed', m.refreshed + 1))
        env = dict(ishuman=lambda user: True, usr=usr, choose_style=lambda: choice,
                   all_ui_styles=Items(['old', 'new', 'third']), HUDdatums=Mapping(new=N(icon='new-icon')))
        fn = project(text or source('code/modules/client/ui_style.dm'), '/client/verb/change_ui(', env)
        fn(m)
        return m

    def test_cancel_and_same_style_have_no_refresh_or_preferences_write(self):
        for choice in (None, 'old'):
            m = self.choose(choice)
            self.assertEqual((m.saved, m.refreshed, m.prefs.UI_style, m.prefs.UI_file), (0, 0, 'old', 'old-icon'))

    def test_real_style_change_saves_and_rebuilds_once(self):
        m = self.choose('new')
        self.assertEqual((m.saved, m.refreshed, m.prefs.UI_style, m.prefs.UI_file), (1, 1, 'new', 'new-icon'))

    def test_same_style_guard_omission_is_detected(self):
        text = source('code/modules/client/ui_style.dm').replace(' || UI_style_new == prefs.UI_style', '')
        m = self.choose('old', text)
        with self.assertRaises(AssertionError):
            self.assertEqual(m.refreshed, 0)


if __name__ == '__main__':
    unittest.main()
