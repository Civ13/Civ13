"""Offline projection of the pure rack renderer plus actual DMI checks.

Evaluates the production selection predicate and image fields, not a second
wet/dry state machine. Lifecycle checks verify source wiring only. No BYOND,
savefile round trip, engine overlay export or connected client runs here.
"""
import ast
from functools import lru_cache
from pathlib import Path
import re
import struct
from types import SimpleNamespace as NS
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[1]
RACK = '/obj/structure/converter/tanning'
MATERIAL = '/obj/item/stack/material/'


@lru_cache(maxsize=2)
def png(path):
    """Read the existing bounded, noninterlaced RGBA8 DMI files with stdlib only."""
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    offset, compressed, description = 8, bytearray(), None
    while offset < len(data):
        size, kind = struct.unpack('>I4s', data[offset:offset+8])
        payload = data[offset+8:offset+8+size]
        crc = struct.unpack('>I', data[offset+8+size:offset+12+size])[0]
        assert zlib.crc32(kind + payload) & 0xffffffff == crc
        if kind == b'IHDR':
            width, height, depth, color, compression, filters, interlace = struct.unpack('>IIBBBBB', payload)
            assert (depth, color, compression, filters, interlace) == (8, 6, 0, 0, 0)
            assert 0 < width * height <= 4_000_000
        elif kind == b'IDAT':
            compressed.extend(payload)
        elif kind == b'zTXt' and payload.startswith(b'Description\0\0'):
            description = zlib.decompress(payload[len(b'Description\0\0'):]).decode()
        offset += size + 12
        if kind == b'IEND':
            break
    stride = width * 4
    decoder = zlib.decompressobj()
    filtered = decoder.decompress(compressed, height * (stride + 1) + 1)
    assert decoder.eof and len(filtered) == height * (stride + 1) and description
    pixels, previous = bytearray(), bytearray(stride)
    for row in range(height):
        start = row * (stride + 1)
        mode = filtered[start]
        scan = bytearray(filtered[start+1:start+1+stride])
        assert 0 <= mode <= 4
        if mode:
            for i in range(stride):
                left, up, corner = scan[i-4] if i >= 4 else 0, previous[i], previous[i-4] if i >= 4 else 0
                if mode == 1:
                    prediction = left
                elif mode == 2:
                    prediction = up
                elif mode == 3:
                    prediction = (left + up) // 2
                else:
                    p = left + up - corner
                    distances = (abs(p-left), abs(p-up), abs(p-corner))
                    prediction = (left, up, corner)[distances.index(min(distances))]
                scan[i] = (scan[i] + prediction) & 255
        pixels.extend(scan)
        previous = scan
    return width, height, description, bytes(pixels)


def sprite(path, state):
    width, _, description, pixels = png(path)
    cell_width = int(re.search(r'\bwidth = (\d+)', description)[1])
    cell_height = int(re.search(r'\bheight = (\d+)', description)[1])
    offset = 0
    for match in re.finditer(r'state = "([^"]*)"(.*?)(?=\nstate =|\Z)', description, re.S):
        dirs, frames = (int(m[1]) if (m := re.search(r'\b'+key+r' = (\d+)', match[2])) else 1
                        for key in ('dirs', 'frames'))
        if match[1] == state:
            assert (dirs, frames) == (1, 1)
            x, y = offset % (width // cell_width) * cell_width, offset // (width // cell_width) * cell_height
            result = [tuple(pixels[(py*width+px)*4:(py*width+px)*4+4])
                      for py in range(y, y+cell_height) for px in range(x, x+cell_width)]
            assert any(p[3] for p in result)
            return result
        offset += dirs * frames
    raise AssertionError('Missing DMI state: ' + state)


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
    runtime = block(source, RACK + '/persistence_runtime_var')
    assert '"overlays"' in runtime and '|| ..()' in runtime
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
    for callback in ('Destroy', 'Del'):
        body = block(source, RACK + '/' + callback)
        assert body.index('release_hides()') < body.index('return ..()')


class TanningRackAppearance(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = (ROOT/'code/game/objects/structures/converters.dm').read_text()
        cls.leather = (ROOT/'code/game/objects/items/stacks/sheets/leather.dm').read_text()

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
        frame = sprite(ROOT/'icons/obj/structures.dmi', 'drying_rack_empty')
        rendered = []
        for stage in ('wethide', 'dryhide'):
            appearance = project(self.source, [self.hide(stage)])[1][0]
            hide = sprite(ROOT/appearance['icon'], appearance['icon_state'])
            tint = tuple(int(appearance['color'][i:i+2], 16) for i in (1,3,5))
            composite = []
            for background, foreground in zip(frame, hide):
                rgb = tuple(channel * scale // 255 for channel, scale in zip(foreground[:3], tint))
                alpha = foreground[3] / 255
                output_alpha = alpha + background[3] / 255 * (1-alpha)
                pixel = tuple(round((rgb[i]*alpha + background[i]*background[3]/255*(1-alpha))/output_alpha)
                              if output_alpha else background[i] for i in range(3)) + (round(output_alpha*255),)
                if not foreground[3]:
                    self.assertEqual(pixel, background)
                composite.append(pixel)
            rendered.append(composite)
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
        wrong = self.source.replace('"drying_epoch", "filled", "overlays"', '"drying_epoch", "filled"')
        with self.assertRaises(AssertionError):
            lifecycle(wrong)


if __name__ == '__main__':
    unittest.main()
