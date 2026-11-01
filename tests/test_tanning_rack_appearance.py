"""Offline projection of the pure rack renderer plus actual DMI checks.

Evaluates the production selection predicate and image fields, not a second
wet/dry state machine. Lifecycle checks verify source wiring only. No BYOND,
savefile round trip, engine overlay export or connected client runs here.
"""
import ast
import importlib.util
from pathlib import Path
import re
from types import SimpleNamespace as NS
import unittest

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
RACK = '/obj/structure/converter/tanning'
MATERIAL = '/obj/item/stack/material/'


def block(text, declaration):
    match = re.search(r'^' + re.escape(declaration) + r'(?:\([^\n]*\))?\n(.*?)(?=^/|\Z)', text, re.M | re.S)
    if not match:
        raise AssertionError('Missing declaration: ' + declaration)
    return match[1]


def evaluate(expression, hide):
    expression = re.sub(r'(/[\w/]+)', lambda m: repr(m[1]), expression)
    expression = expression.replace('&&', ' and ').replace('||', ' or ')
    expression = re.sub(r'!(?!=)', ' not ', expression).strip()
    tree = ast.parse(expression, mode='eval')
    allowed = (ast.Expression, ast.BoolOp, ast.And, ast.Or, ast.UnaryOp, ast.Not,
               ast.Compare, ast.Lt, ast.Gt, ast.Eq, ast.NotEq, ast.Call, ast.Name,
               ast.Load, ast.Attribute, ast.Constant)
    assert all(isinstance(n, allowed) for n in ast.walk(tree))
    return eval(compile(tree, '<rack appearance predicate>', 'eval'), {'__builtins__': {}},
                {'hide': hide, 'QDELETED': lambda h: h.deleted,
                 'istype': lambda h, p: h.type == p or h.type.startswith(p + '/')})


def project(source, contents):
    body = block(source, RACK + '/update_icon')
    base = re.search(r'^\ticon_state = (\w+)$', body, re.M)[1]
    frame = re.search(r'^\t' + base + r' = "([^"]+)"', block(source, RACK), re.M)[1]
    assert '\toverlays.Cut()' in body
    assert 'for (var/obj/item/stack/material/hide in contents)' in body
    reject = re.search(r'\t\tif \((.*)\)\n\t\t\tcontinue', body)[1]
    fields = re.search(r'image\(([^\n]+)\)', body)[1]
    color = re.search(r'hide_overlay.color = ([^\n]+)', body)[1]
    result = []
    for hide in contents:
        if not hide.type.startswith(MATERIAL) or evaluate(reject, hide):
            continue
        image = {key: evaluate(value.strip(), hide)
                 for key, value in (part.strip().split(' = ', 1) for part in fields.split(','))}
        image['color'] = evaluate(color, hide)
        result.append(image)
        assert 'overlays += hide_overlay' in body and '\t\tbreak' in body
        break
    return frame, result


def lifecycle(source):
    start = block(source, RACK + '/proc/start_hide_drying')
    finish = block(source, RACK + '/proc/finish_hide_drying')
    release = block(source, RACK + '/proc/release_hides')
    restore = block(source, RACK + '/after_load')
    assert start.index('filled = TRUE') < start.index('update_icon()') < start.index('spawn(delay)')
    assert finish.index('new /obj/item/stack/material/dryhide') < finish.index('update_icon()')
    assert release.index('I.forceMove(site)') < release.index('update_icon()')
    assert restore.index('start_hide_drying(hide)') < restore.index('update_icon()')
    exit_body = block(source, RACK + '/Exited')
    assert exit_body.index('. = ..()') < exit_body.index('update_icon()') < exit_body.index('return .')


class TanningRackAppearance(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = (ROOT/'code/game/objects/structures/converters.dm').read_text()
        cls.leather = (ROOT/'code/game/objects/items/stacks/sheets/leather.dm').read_text()
        spec = importlib.util.spec_from_file_location('existing_sprite_reader', ROOT/'tests/animal_harvest/preview.py')
        cls.preview = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.preview)

    def hide(self, stage, **changes):
        body = block(self.leather, MATERIAL + stage)
        values = dict(type=MATERIAL+stage, deleted=False, amount=3, dir=2,
                      icon='icons/obj/materials.dmi',
                      icon_state=re.search(r'icon_state = "([^"]+)"', body)[1],
                      color=re.search(r'color = "([^"]+)"', body)[1])
        return NS(**(values | changes))

    def test_actual_contents_choose_wet_or_dry_and_clear_empty_display(self):
        for stage in ('wethide', 'dryhide'):
            hide = self.hide(stage)
            frame, overlays = project(self.source, [hide])
            self.assertEqual(frame, 'drying_rack_empty')
            self.assertEqual(overlays, [dict(icon=hide.icon, icon_state=hide.icon_state, dir=hide.dir, color=hide.color)])
        self.assertNotEqual(self.hide('wethide').color, self.hide('dryhide').color)
        self.assertEqual(project(self.source, []), ('drying_rack_empty', []))

    def test_completion_skips_retiring_wet_child_and_uses_actual_custom_appearance(self):
        dry = self.hide('dryhide', color='#ABCDEF', dir=8)
        self.assertEqual(project(self.source, [self.hide('wethide', deleted=True), dry])[1][0]['color'], '#ABCDEF')
        self.assertEqual(project(self.source, [self.hide('wethide', amount=0), dry])[1][0]['dir'], 8)
        unrelated = self.hide('wethide', type=MATERIAL+'leather')
        self.assertEqual(project(self.source, [unrelated])[1], [])

    def test_existing_sprites_are_nonempty_and_colour_changes_only_the_hide(self):
        frame = self.preview.state(ROOT/'icons/obj/structures.dmi', 'drying_rack_empty')
        rendered = []
        for stage in ('wethide', 'dryhide'):
            appearance = project(self.source, [self.hide(stage)])[1][0]
            sprite = self.preview.state(ROOT/appearance['icon'], appearance['icon_state'])
            tinted = ImageChops.multiply(sprite, Image.new('RGBA', sprite.size, appearance['color']))
            composite = Image.alpha_composite(frame, tinted)
            self.assertTrue(sprite.getchannel('A').getbbox())
            for y in range(frame.height):
                for x in range(frame.width):
                    if not sprite.getpixel((x,y))[3]:
                        self.assertEqual(composite.getpixel((x,y)), frame.getpixel((x,y)))
            rendered.append(composite.tobytes())
        self.assertNotEqual(*rendered)

    def test_load_completion_release_exit_and_restore_rebuild_display(self):
        lifecycle(self.source)
        body = block(self.source, RACK + '/update_icon')
        for forbidden in ('filled', 'drying_epoch', 'use(', 'forceMove(', 'spawn(', 'new /obj'):
            self.assertNotIn(forbidden, body)

    def test_old_full_rack_tint_and_missing_completion_refresh_controls_fail(self):
        wrong = self.source.replace('icon_state = idlesprite\n\toverlays.Cut()', 'icon_state = activesprite\n\toverlays.Cut()')
        self.assertNotEqual(project(wrong, [self.hide('wethide')])[0], 'drying_rack_empty')
        wrong = self.source.replace('hide_overlay.color = hide.color', 'hide_overlay.color = "#C9AA84"')
        self.assertNotEqual(project(wrong, [self.hide('wethide')])[1][0]['color'], self.hide('wethide').color)
        wrong = self.source.replace('new /obj/item/stack/material/dryhide(src, count, FALSE)\n\tupdate_icon()', 'new /obj/item/stack/material/dryhide(src, count, FALSE)\n\ticon_state = activesprite')
        with self.assertRaises((AssertionError, ValueError)):
            lifecycle(wrong)


if __name__ == '__main__':
    unittest.main()
