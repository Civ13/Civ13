"""Project rag ignition admission with fake engine boundaries; no game is launched."""
import importlib.util
from pathlib import Path
import re
from types import SimpleNamespace
import unittest


ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('rag_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
RAG = (ROOT / 'code/game/objects/items/weapons/detective.dm').read_text()
SOURCES = (ROOT / 'code/game/objects/items/weapons/cigs_lighters.dm').read_text()
LIGHTS = (ROOT / 'code/game/objects/items/devices/flashlight.dm').read_text()
LANTERNS = (ROOT / 'code/modules/1713/lantern.dm').read_text()
CLICK = (ROOT / 'code/_onclick/click.dm').read_text()
ITEM_ATTACK = (ROOT / 'code/_onclick/item_attack.dm').read_text()
ATTACK = '/obj/item/weapon/reagent_containers/glass/rag/attackby'
CIGARETTE = '/obj/item/clothing/mask/smokable/cigarette'
FLAME = '/obj/item/weapon/flame'
FLASHLIGHT = '/obj/item/flashlight'


def project_proc(source, declaration, args, env):
    body = adapter.extract(source, declaration)
    return adapter.project('/test/proc/run()\n' + body + '\n', '/test/proc/run', args, env)


flame_check = project_proc(SOURCES, FLAME + '/is_open_flame', 'lit', {})
light_check = project_proc(SOURCES, FLASHLIGHT + '/is_open_flame', 'open_flame, on', {})
default_check = project_proc(SOURCES, '/atom/proc/is_open_flame', '', {})
isflamesource = project_proc(SOURCES, '/proc/isflamesource', 'A',
                             {'isatom': lambda value: hasattr(value, 'is_open_flame')})


def item(kind, active):
    # Model the production type hierarchy and dispatch to projected production
    # is_open_flame overrides, not a duplicate of the admission expression.
    if kind == 'cigarette':
        return SimpleNamespace(path=CIGARETTE, lit=active, is_open_flame=default_check)
    if kind == 'flame':
        return SimpleNamespace(path=FLAME, lit=active, is_open_flame=lambda: flame_check(active))
    return SimpleNamespace(path=FLASHLIGHT + ('/torch' if kind == 'torch' else '/flashlight'),
                           on=active, is_open_flame=lambda: light_check(kind == 'torch', active))


def admit(kind, active, already_burning=False):
    source = item(kind, active)
    calls = []
    body = adapter.extract(RAG, ATTACK).splitlines()
    end = next(i for i, line in enumerate(body) if line.strip() == 'ignite()')
    # Keep every control-flow line through ignite(). Presentation, the parent
    # call and name update follow this slice and are outside this contract.
    segment = '\n'.join(body[:end + 1])
    segment = re.sub(r'(?<=, )(/obj/[\w/]+)', r'"\1"', segment)
    segment = re.sub(r'\b(\w+):(\w+)\b', r'\1.\2', segment)
    # One-argument istype() uses the declared type of the variable in DM.
    declared = dict(re.findall(r'var(/obj/[\w/]+)/(\w+)\s*=\s*', segment))
    for path, name in declared.items():
        segment = segment.replace('istype(' + name + ')', f'istype({name}, "{path}")')

    def istype(value, path):
        return value.path == path or value.path.startswith(path + '/')

    proc = adapter.project('/test/proc/run()\n' + segment + '\n', '/test/proc/run',
                           'W, on_fire', {'istype': istype, 'isflamesource': isflamesource,
                                          'ignite': lambda: calls.append('ignite')})
    proc(source, already_burning)
    return calls


def click_rag(kind, active, can_ignite, parent_result=False, initial_volume=10):
    """Project the rag, item resolver, and cigarette transfer on an adjacent click."""
    held = item(kind, active)
    events = []
    rag = SimpleNamespace(on_fire=False, volume=initial_volume)
    rag.struck_by_tool = lambda *args: False
    def transfer(*args):
        events.append('transfer')
        amount = min(rag.volume, 5)
        rag.volume -= amount
        return amount
    rag.reagents = SimpleNamespace(trans_to_obj=transfer)
    held.resolve_attack_obj = lambda *args: False
    user = object()

    def istype(value, path):
        return value.path == path or value.path.startswith(path + '/')

    body = adapter.extract(RAG, ATTACK)
    declarations = dict(re.findall(r'var(/obj/[\w/]+)/(\w+)\s*=\s*', body))
    for path, name in declarations.items():
        body = body.replace('istype(' + name + ')', f'istype({name}, "{path}")')
    body = re.sub(r'\bon_fire\b', 'rag.on_fire', body)
    body = re.sub(r'(?m)^(\t*)(?:visible_message|to_chat)\(.*$', r'\1notice()', body)
    body = body.replace('..()', 'inherited()') + '\n\treturn result'
    def ignite():
        events.append('ignite')
        if can_ignite:
            rag.on_fire = True

    proc = adapter.project('/test/proc/run()\n' + body + '\n', '/test/proc/run', 'W, user',
                           {'istype': istype, 'isflamesource': isflamesource, 'rag': rag,
                            'ignite': ignite, 'notice': lambda: None,
                            'inherited': lambda: parent_result, 'update_name': lambda: None})
    rag.attackby = lambda W, user, *args: proc(W, user)

    resolver = project_proc(ITEM_ATTACK, '/obj/item/proc/resolve_attackby',
                            'A, user, icon_x, icon_y',
                            {'src': held, 'add_fingerprint': lambda *args: None,
                             'tool_meets_work': lambda *args: False, 'isturf': lambda _: False,
                             'isobj': lambda _: True})
    resolved = resolver(rag, user, None, None)
    if kind == 'cigarette' and not resolved:
        dip = adapter.extract(SOURCES, CIGARETTE + '/afterattack').splitlines()
        end = next(i for i, line in enumerate(dip) if 'trans_to_obj(' in line)
        body = '\n'.join(dip[:end + 1]).replace('..()', 'inherited()')
        body = body.replace('istype(glass)', 'istype(glass, glass_type)')
        projected = adapter.project('/test/proc/run()\n' + body + '\n', '/test/proc/run',
                                    'glass, user, proximity',
                                    {'inherited': lambda: None, 'istype': lambda value, path: value is rag,
                                     'glass_type': object(), 'src': held, 'chem_volume': 15})
        projected(rag, user, True)
    return resolved, rag.on_fire, rag.volume, events


class RagIgnitionTest(unittest.TestCase):
    def test_torch_and_electric_types_have_expected_flame_flags(self):
        base = LIGHTS.split('/obj/item/flashlight\n', 1)[1].split('\n/', 1)[0]
        torch = LANTERNS.split('/obj/item/flashlight/torch\n', 1)[1].split('\n/', 1)[0]
        self.assertIn('var/open_flame = FALSE', base)
        self.assertIn('open_flame = TRUE', torch)

    def test_active_sources_and_inactive_controls(self):
        for kind in ('cigarette', 'flame', 'torch'):
            for active in (False, True):
                with self.subTest(kind=kind, active=active):
                    self.assertEqual(admit(kind, active), ['ignite'] if active else [])

    def test_electric_light_cannot_ignite(self):
        for active in (False, True):
            with self.subTest(active=active):
                self.assertEqual(admit('electric', active), [])

    def test_already_burning_rag_is_not_reignited(self):
        for kind in ('cigarette', 'flame', 'torch'):
            with self.subTest(kind=kind):
                self.assertEqual(admit(kind, True, already_burning=True), [])

    def test_click_dispatcher_skips_afterattack_when_resolved(self):
        # Both ordinary adjacent paths use the resolver gate before afterattack.
        self.assertEqual(CLICK.count('if (!resolved && A && W)'), 2)
        self.assertEqual(CLICK.count('var/resolved = W.resolve_attackby(A, src, icon_x, icon_y)'), 2)

    def test_successful_cigarette_ignition_does_not_dip(self):
        self.assertEqual(click_rag('cigarette', True, True), (True, True, 10, ['ignite']))

    def test_unlit_or_nonflammable_rag_preserves_cigarette_dipping(self):
        self.assertEqual(click_rag('cigarette', False, True), (False, False, 5, ['transfer']))
        self.assertEqual(click_rag('cigarette', True, False), (False, False, 5, ['ignite', 'transfer']))
        self.assertEqual(click_rag('cigarette', True, False, initial_volume=0),
                         (False, False, 0, ['ignite', 'transfer']))

    def test_other_items_preserve_parent_result(self):
        for kind in ('flame', 'torch', 'electric'):
            for parent_result in (False, True):
                with self.subTest(kind=kind, parent_result=parent_result):
                    resolved, _, _, _ = click_rag(kind, True, True, parent_result)
                    self.assertEqual(resolved, parent_result)


if __name__ == '__main__':
    unittest.main()
