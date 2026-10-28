"""Fail-closed offline projection of production crop procs, not native DM proof."""
import ast
import hashlib
import json
import struct
import zlib
import re
import unittest
from pathlib import Path
from types import SimpleNamespace as State


ROOT = Path(__file__).resolve().parents[2]
FARM = (ROOT / 'code/game/objects/farming.dm').read_text()
GROWN = (ROOT / 'code/modules/reagents/reagent_containers/food/grown.dm').read_text()


def read_rgba_dmi(data):
    """Small strict stdlib decoder for our noninterlaced 8-bit RGBA PNGs only."""
    if not data.startswith(b'\x89PNG\r\n\x1a\n'):
        raise ValueError('Not PNG')
    pos, chunks = 8, []
    while pos < len(data):
        if pos + 12 > len(data):
            raise ValueError('Truncated PNG chunk')
        size, kind = struct.unpack('>I4s', data[pos:pos + 8])
        end = pos + 12 + size
        if end > len(data):
            raise ValueError('Truncated PNG payload')
        payload = data[pos + 8:pos + 8 + size]
        crc = struct.unpack('>I', data[pos + 8 + size:end])[0]
        if zlib.crc32(kind + payload) & 0xffffffff != crc:
            raise ValueError('PNG CRC mismatch')
        chunks.append((kind, payload))
        pos = end
        if kind == b'IEND':
            break
    if pos != len(data) or not chunks or chunks[0][0] != b'IHDR' or chunks[-1] != (b'IEND', b''):
        raise ValueError('Invalid PNG structure')
    if sum(kind == b'IHDR' for kind, _ in chunks) != 1:
        raise ValueError('Duplicate PNG header')
    width, height, depth, color, compression, filtering, interlace = struct.unpack('>IIBBBBB', chunks[0][1])
    if not (0 < width <= 1024 and 0 < height <= 1024) or (depth, color, compression, filtering, interlace) != (8, 6, 0, 0, 0):
        raise ValueError('Unsupported crop PNG layout')
    descriptions = []
    for kind, payload in chunks:
        if kind == b'zTXt' and payload.startswith(b'Description\0\0'):
            descriptions.append(zlib.decompress(payload[len(b'Description\0\0'):]).decode('utf-8'))
    if len(descriptions) != 1:
        raise ValueError('Missing/duplicate DMI description')
    stride = width * 4
    raw = zlib.decompress(b''.join(payload for kind, payload in chunks if kind == b'IDAT'))
    if len(raw) != height * (stride + 1):
        raise ValueError('Wrong decoded pixel length')
    previous = bytearray(stride)
    pixels = bytearray()
    for y in range(height):
        row = bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        filter_type = raw[y * (stride + 1)]
        if filter_type not in range(5):
            raise ValueError('Unknown PNG row filter')
        for x in range(stride):
            left, above = row[x - 4] if x >= 4 else 0, previous[x]
            corner = previous[x - 4] if x >= 4 else 0
            prediction = left + above - corner
            distances = (abs(prediction - left), abs(prediction - above), abs(prediction - corner))
            paeth = (left, above, corner)[distances.index(min(distances))]
            row[x] = (row[x] + (0, left, above, (left + above) // 2, paeth)[filter_type]) & 255
        pixels.extend(row)
        previous = row
    return width, height, descriptions[0], bytes(pixels)


def block(source, signature):
    match = re.search(re.escape(signature) + r'(?:[ \t]*//[^\n]*)?\n', source)
    if not match:
        raise ValueError('Missing source block: ' + signature)
    rest = source[match.end():]
    boundary = re.search(r'^/[^/*]', rest, re.M)
    return rest[:boundary.start()] if boundary else rest


def expression(value, fields=()):
    # Translate only the expression syntax used in the selected production procs.
    value = re.sub(r'(?<![\w\"\'])/(?:obj|turf)/[\w/]+', lambda m: repr(m[0]), value)
    parts = re.split(r'("[^"\n]*"|\'[^\'\n]*\')', value)
    for i in range(0, len(parts), 2):
        text = parts[i].replace('||', ' or ').replace('&&', ' and ')
        text = re.sub(r'!(?!=)', 'not ', text)
        text = re.sub(r'\bnull\b', 'None', text)
        text = re.sub(r'\bsrc\b', 'self', text)
        text = re.sub(r'(?<![\w.])(' + '|'.join(fields or ['UNUSED']) + r')\b', r'self.\1', text)
        parts[i] = text
    value = ''.join(parts).strip()
    tree = ast.parse(value, mode='eval')
    allowed = (ast.Expression, ast.BoolOp, ast.And, ast.Or, ast.UnaryOp, ast.Not,
               ast.Compare, ast.Eq, ast.NotEq, ast.LtE, ast.Lt, ast.Gt, ast.GtE, ast.In, ast.Name, ast.Load,
               ast.Attribute, ast.Call, ast.Constant, ast.BinOp, ast.Add, ast.Sub)
    for node in ast.walk(tree):
        if not isinstance(node, allowed):
            raise ValueError(f'Unsupported projected expression: {value}: {type(node).__name__}')
        if isinstance(node, ast.Call) and not (isinstance(node.func, ast.Name) and
                node.func.id in {'istype', 'get_area', 'findtext', 'min', 'list', 'range', 'locate', 'prob', 'winter_crop_plot_error', 'get_turf'}):
            raise ValueError(f'Unsupported call in projection: {value}')
    return value


def is_type(obj, wanted):
    """Synthetic type boundary honoring explicit production parent_type declarations."""
    candidate = getattr(obj, 'type', '')
    visited = set()
    while candidate and candidate not in visited:
        visited.add(candidate)
        if candidate == wanted:
            return True
        declaration = re.search(r'^' + re.escape(candidate) + r'\n((?:\t[^\n]*\n)*)', FARM, re.M)
        parent = re.search(r'\bparent_type = (/[^\s]+)', declaration[1]) if declaration else None
        candidate = parent[1] if parent else candidate.rsplit('/', 1)[0]
    return False


def compile_proc(body, signature, fields=()):
    """No native parser claim: reject every statement outside this narrow subset."""
    output = [signature]
    for raw in body.splitlines():
        line = raw.split('//', 1)[0].rstrip()
        if not line.strip():
            continue
        depth = len(line) - len(line.lstrip('\t'))
        if depth < 1 or line.startswith(' '):
            raise ValueError('Unexpected indentation')
        text = line.strip()
        text = re.sub(r"^(if|else if)\(", r"\1 (", text)
        if text.startswith('if (') and text.endswith(')'):
            result = 'if ' + expression(text[4:-1], fields) + ':'
        elif text.startswith('else if (') and text.endswith(')'):
            result = 'elif ' + expression(text[9:-1], fields) + ':'
        elif text == 'else':
            result = 'else:'
        elif text == 'for (var/turf/floor/WT in range(2, src))':
            result = 'for WT in range(2, self):'
        elif text in ('return', 'continue'):
            result = text
        elif text == 'return ..()':
            result = 'return parent(self)'
        elif text.startswith('return '):
            result = 'return ' + expression(text[7:], fields)
        elif re.fullmatch(r'set_dead\("\w+"\)', text):
            result = 'self.' + text
        else:
            match = re.fullmatch(r'(?:var/(?:area/)?|var/)?(\w+)\s*(=|-=|\+=)\s*(.+)', text)
            if not match:
                raise ValueError(f'Unsupported projected statement: {text}')
            name, operator, value = match.groups()
            target = 'self.' + name if name in fields else name
            result = target + ' ' + operator + ' ' + expression(value, fields)
        output.append('    ' * depth + result)
    namespace = dict(
        istype=is_type,
        get_area=lambda obj: getattr(obj, 'area', None),
        findtext=lambda text, sub: sub in text,
        list=lambda *items: items,
        range=lambda radius, plant: plant.nearby,
        locate=lambda path: path,
        min=min,
        prob=lambda chance: chance > 0,
        AREA_OUTSIDE=1,
        map=State(heat_wave=False),
    )
    exec(compile('\n'.join(output), '<production-crop-projection>', 'exec'), namespace)
    return namespace[signature.split('(')[0].split()[-1]], namespace


def water_proc(source=FARM):
    return compile_proc(block(source, '/obj/structure/farming/plant/proc/water_proc()'),
                        'def water_tick(self):', ('loc', 'water', 'max_water', 'winter_hardy'))


def plant(**kwargs):
    area = State(icon_state='snow_storm', climate='temperate')
    p = State(type='/obj/structure/farming/plant/turnip', water=60, max_water=90,
              winter_hardy=True, loc=State(area=area), nearby=[], death=None)
    p.set_dead = lambda kind: setattr(p, 'death', kind)
    for key, value in kwargs.items():
        setattr(p, key, value)
    return p


class Turf:
    def __init__(self, **kwargs):
        self.type = '/turf/floor/dirt/ploughed'
        self.is_plowed = True
        self.density = False
        self.area = State(location=1, is_void_area=False)
        self.roof = False
        self.__dict__.update(kwargs)

    def __contains__(self, item):
        return self.roof and item == '/obj/roof'


class WinterCrops(unittest.TestCase):
    def test_water_hardiness_is_opt_in(self):
        self.assertIn('var/winter_hardy = FALSE', block(FARM, '/obj/structure/farming/plant'))
        self.assertIn('winter_hardy = TRUE', block(FARM, '/obj/structure/farming/plant/turnip'))
        tick, _ = water_proc()
        hardy = plant()
        tick(hardy)
        self.assertIsNone(hardy.death)
        self.assertEqual(hardy.water, 45)
        ordinary = plant(winter_hardy=False, type='/obj/structure/farming/plant/tomato')
        tick(ordinary)
        self.assertEqual(ordinary.death, 'frozen')
        self.assertEqual(ordinary.water, 60)

    def test_hardiness_does_not_remove_other_costs(self):
        tick, ns = water_proc()
        dry = plant(water=15)
        tick(dry)
        self.assertEqual((dry.water, dry.death), (0, 'dry'))
        sand = plant()
        sand.loc.area.icon_state = 'sandstorm'
        tick(sand)
        self.assertEqual(sand.death, 'destroyed')
        ns['map'].heat_wave = True
        hot = plant()
        hot.loc.area.icon_state = 'clear'
        hot.loc.area.climate = 'desert'
        tick(hot)
        self.assertEqual(hot.water, 25)

    def test_existing_rain_irrigation_and_mushrooms(self):
        tick, _ = water_proc()
        rain = plant(water=85)
        rain.loc.area.icon_state = 'rain'
        tick(rain)
        self.assertEqual(rain.water, 90)
        watered = plant(nearby=[State(type='/turf/floor/beach/water', salty=False, flooded=False)])
        tick(watered)
        self.assertEqual(watered.water, 90)
        salty = plant(nearby=[State(type='/turf/floor/beach/water', salty=True, flooded=False)])
        tick(salty)
        self.assertEqual(salty.water, 45)
        for kind in ('mushroom', 'mushroompsy'):
            mushroom = plant(type='/obj/structure/farming/plant/' + kind,
                             winter_hardy=False, water=0, max_water=0)
            tick(mushroom)
            self.assertEqual((mushroom.water, mushroom.death), (0, None))

    def test_omission_controls_detect_changed_production(self):
        old = 'findtext(A.icon_state, "snow_storm") && !winter_hardy'
        self.assertEqual(FARM.count(old), 1)
        tick, _ = water_proc(FARM.replace(old, 'findtext(A.icon_state, "snow_storm")'))
        hardy = plant()
        tick(hardy)
        self.assertEqual(hardy.death, 'frozen', 'Removing hardiness must be detected')
        tick, _ = water_proc(FARM.replace(old, 'findtext(A.icon_state, "snow_storm") && winter_hardy'))
        ordinary = plant(winter_hardy=False)
        tick(ordinary)
        self.assertIsNone(ordinary.death, 'Inverting hardiness must break ordinary-crop parity')
        with self.assertRaises(ValueError):
            water_proc(FARM.replace('water -= 15', 'unreviewed_effect()'))

    def test_outdoor_plot_admission_and_recheck(self):
        check, _ = compile_proc(block(FARM, '/proc/winter_crop_plot_error(turf/T)'),
                                'def plot_error(T):')
        self.assertIsNone(check(Turf()))
        for turf in [Turf(type='/turf/floor/dirt'), Turf(is_plowed=False), Turf(density=True),
                     Turf(roof=True), Turf(area=None), Turf(area=State(location=0, is_void_area=False)),
                     Turf(area=State(location=1, is_void_area=True))]:
            self.assertIsNotNone(check(turf))
        seed = block(FARM, '/obj/item/stack/farming/seeds/turnip/planting_error(turf/T)')
        self.assertIn('return winter_crop_plot_error(T)', seed)
        growth = block(FARM, '/obj/structure/farming/plant/turnip/stageGrowth()')
        self.assertRegex(growth, r'if \(stage < readyStageMin && winter_crop_plot_error\(get_turf\(src\)\)\)\n\t\treturn\n\treturn \.\.\(\)')
        advance, ns = compile_proc(growth, 'def turnip_advance(self):', ('stage', 'readyStageMin'))
        ns['get_turf'] = lambda crop: crop.turf
        ns['winter_crop_plot_error'] = check
        ns['parent'] = lambda crop: setattr(crop, 'stage', crop.stage + 1)
        sheltered = State(stage=6, readyStageMin=7, turf=Turf(roof=True))
        advance(sheltered)
        self.assertEqual(sheltered.stage, 6, 'A roof blocks immature growth')
        sheltered.stage = 7
        for _ in range(4):
            advance(sheltered)
        self.assertEqual(sheltered.stage, 11, 'A roof cannot immortalize a ripe crop')
        sheltered.stage = 6
        sheltered.turf.roof = False
        advance(sheltered)
        self.assertEqual(sheltered.stage, 7, 'Removing shelter permits growth again')

    def test_catalog_bootstrap_and_sustainable_finite_harvest(self):
        for path in ('/obj/item/stack/farming/seeds/turnip', '/obj/structure/farming/plant/turnip'):
            body = block(FARM, path)
            self.assertIn('biomes = list("temperate", "sea", "tundra", "taiga")', body)
            self.assertIn('seasons = list("WINTER", "SPRING", "SUMMER", "FALL")', body)
        wild = (ROOT / 'code/game/objects/structures/wild.dm').read_text()
        seed_list = block(wild, '/obj/structure/wild/proc/generate_seed_list(var/biome)')
        self.assertIn('typesof(/obj/item/stack/farming/seeds)', seed_list)
        self.assertIn('if (!(biome in seed_check.biomes))', seed_list)
        self.assertIn('new seedpath(loc, 2)', block(FARM, '/obj/structure/farming/plant/proc/spawn_seeds()'))
        attack = block(FARM, '/obj/structure/farming/plant/attackby(obj/item/weapon/W as obj, mob/user as mob)')
        self.assertIn('else if (readyHarvest())', attack)
        self.assertIn('spawn_seeds()\n\t\t\tspawn_produce()', attack)
        self.assertIn('qdel(src)', attack)
        floor = (ROOT / 'code/game/turfs/floor_attackby.dm').read_text()
        self.assertIn('C.amount -= 1', floor)
        self.assertIn('TS.spawn_plant(src)', floor)
        self.assertIn('D.soil_nutrition -= nutrition_consumed', FARM)
        self.assertIn('stage > readyStageMax', block(FARM, '/obj/structure/farming/plant/proc/growth()'))
        food = block(GROWN, '/obj/item/weapon/reagent_containers/food/snacks/grown/turnip')
        self.assertIn('nutriment_amt = 2', food)
        self.assertIn('decay = 90*600', food)

    def test_plump_helmet_inherits_real_mushroom_exemptions(self):
        crop = block(FARM, '/obj/structure/farming/plant/plump_helmet')
        self.assertIn('parent_type = /obj/structure/farming/plant/mushroom', crop)
        self.assertNotIn('max_water =', crop)
        self.assertIn('max_water = 0', block(FARM, '/obj/structure/farming/plant/mushroom'))
        tick, _ = water_proc()
        helmet = plant(type='/obj/structure/farming/plant/plump_helmet',
                       winter_hardy=False, water=0, max_water=0)
        self.assertTrue(is_type(helmet, '/obj/structure/farming/plant/mushroom'))
        tick(helmet)
        self.assertEqual((helmet.water, helmet.death), (0, None))
        growth = block(FARM, '/obj/structure/farming/plant/proc/growth()')
        self.assertIn('a.location == 0 && (istype(src, /obj/structure/farming/plant/mushroom)', growth)
        self.assertIn('soil_nutrition_proc()', growth)
        self.assertIn('!istype(D, /turf/floor/dirt/ploughed)', growth)

    def test_plump_spores_use_all_biomes_and_winter_default(self):
        seed = block(FARM, '/obj/item/stack/farming/seeds/plump_helmet')
        self.assertNotIn('biomes =', seed)
        self.assertNotIn('seasons =', seed)
        self.assertNotIn('parent_type =', seed)
        base = block(FARM, '/obj/item/stack/farming/seeds')
        biomes = re.search(r'var/list/biomes = list\(([^\n]+)\)', base)[1]
        seasons = re.search(r'var/list/seasons = list\(([^\n]+)\)', base)[1]
        self.assertEqual(set(re.findall(r'"([^"]+)"', biomes)),
                         {'tundra', 'temperate', 'sea', 'desert', 'jungle', 'savanna', 'taiga', 'semiarid'})
        self.assertIn('"WINTER"', seasons)
        self.assertIn('"Dry Season"', seasons)
        food = block(GROWN, '/obj/item/weapon/reagent_containers/food/snacks/grown/plump_helmet')
        self.assertIn('nutriment_amt = 2', food)
        self.assertIn('decay = 60*600', food)
        # Shared harvest retires the crop, and shared planting debits one spore.
        attack = block(FARM, '/obj/structure/farming/plant/attackby(obj/item/weapon/W as obj, mob/user as mob)')
        self.assertRegex(attack, r'(?s)else if \(readyHarvest\(\)\).*?spawn_seeds\(\).*?spawn_produce\(\).*?qdel\(src\)')
        self.assertNotIn('/obj/structure/farming/plant/plump_helmet/attackby', FARM)
        self.assertIn('new seedpath(loc, 2)', block(FARM, '/obj/structure/farming/plant/proc/spawn_seeds()'))

    def test_plump_half_rate_still_advances_ripe_crops(self):
        body = block(FARM, '/obj/structure/farming/plant/plump_helmet/stageGrowth()')
        meaningful = [line.split('//')[0].strip() for line in body.splitlines() if line.split('//')[0].strip()]
        self.assertEqual(meaningful, ['if (prob(50))', 'return ..()'])
        tick, ns = compile_proc(body, 'def helmet_tick(self):')
        advance, base_ns = compile_proc(block(FARM, '/obj/structure/farming/plant/proc/stageGrowth()'),
                                        'def advance(self):', ('stage', 'plant_nutrition'))
        ns['parent'] = advance
        chances = []
        sequence = iter([False, True] * 10)
        ns['prob'] = lambda chance: chances.append(chance) or next(sequence)
        helmet = State(stage=1, plant_nutrition=100)
        for _ in range(12):
            tick(helmet)
        self.assertEqual(helmet.stage, 7, 'Six successful growth trials reach harvest')
        for _ in range(8):
            tick(helmet)
        self.assertEqual(helmet.stage, 11, 'Four further successes pass ripe stage 10')
        self.assertEqual(chances, [50] * 20)
        # This sequence is deterministic fixture input, not a bounded RNG-time claim.
        ns['prob'] = lambda chance: False
        for _ in range(100):
            tick(helmet)
        self.assertEqual(helmet.stage, 11)
        growth = block(FARM, '/obj/structure/farming/plant/proc/growth()')
        self.assertIn('if (vstatic || stage > readyStageMax)', growth)
        self.assertIn('set_dead()', growth)

    def test_actual_dmis_have_every_referenced_state(self):
        for crop in ('turnip', 'plump_helmet'):
            with self.subTest(crop=crop):
                self.assert_dmi(crop)

    def test_png_checks_reject_corruption(self):
        data = bytearray((ROOT / 'icons/farming/pocket_stronghold_turnip.dmi').read_bytes())
        data[29] ^= 1
        with self.assertRaisesRegex(ValueError, 'CRC'):
            read_rgba_dmi(bytes(data))
        with self.assertRaises(ValueError):
            read_rgba_dmi(b'not a PNG')

    def test_ci_is_offline_and_explicitly_guarded(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        marker = '      - name: Test winter crops and attributed sprite contracts offline'
        step = workflow.split(marker, 1)[1].split('      - name:', 1)[0]
        self.assertIn("needs.changes.outputs.extensive == 'true' || contains(fromJSON(needs.changes.outputs.new_tests), 'tests/winter_crops')", step)
        self.assertIn("python3 -I -S -B -m unittest discover -s tests/winter_crops -p 'test_*.py' -v", step)
        self.assertNotRegex(step, r'DreamMaker|DreamDaemon|--native|pip install')

    def assert_dmi(self, crop):
        path = ROOT / f'icons/farming/pocket_stronghold_{crop}.dmi'
        encoded = path.read_bytes()
        sheet_width, sheet_height, desc, pixels = read_rgba_dmi(encoded)
        expected = json.loads((ROOT / 'icons/farming/pocket_stronghold_turnip.json').read_text())['derived_assets'][path.name]
        self.assertEqual(hashlib.sha256(encoded).hexdigest(), expected['sha256'])
        width = int(re.search(r'width = (\d+)', desc)[1])
        height = int(re.search(r'height = (\d+)', desc)[1])
        self.assertEqual((width, height), (32, 32))
        states = {}
        offset = 0
        for match in re.finditer(r'state = "([^"]*)"(.*?)(?=\nstate =|\Z)', desc, re.S):
            name, body = match.groups()
            dirs = int(re.search(r'dirs = (\d+)', body)[1])
            frames = int(re.search(r'frames = (\d+)', body)[1])
            self.assertNotIn(name, states)
            x = offset % (sheet_width // width) * width
            y = offset // (sheet_width // width) * height
            self.assertLessEqual(x + width, sheet_width)
            self.assertLessEqual(y + height, sheet_height)
            sprite = b''.join(pixels[((y + row) * sheet_width + x) * 4:((y + row) * sheet_width + x + width) * 4] for row in range(height))
            self.assertTrue(any(sprite[3::4]), name)
            self.assertEqual(hashlib.sha256(sprite).hexdigest(), expected['rgba_states'][name])
            states[name] = (dirs, frames)
            offset += dirs * frames
        required = {crop, crop + '-seeds', crop + '-harvest', crop + '-dead'}
        required |= {f'{crop}-grow{i}' for i in range(1, 7)}
        self.assertEqual(set(states), required)
        self.assertTrue(all(value == (1, 1) for value in states.values()))


if __name__ == '__main__':
    unittest.main()
