"""Source-projected cache contracts; these checks do not execute BYOND."""
import unittest
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[2] / 'code/game/turfs/floor_icon.dm'
PROC = '/turf/floor/proc/get_flooring_overlay'
OLD_ENTRY = '\tif (!flooring_cache[cache_key])'
NEW_ENTRY = (
    '\tvar/cached_overlay = flooring_cache[cache_key]\n'
    '\tif (cached_overlay)\n'
    '\t\treturn cached_overlay'
)
MISS = (
    'var/icon/use_icon = edge_icon ? edge_icon : flooring.icon\n'
    'var/image/I = image(icon = use_icon, icon_state = icon_base, dir = icon_dir)\n'
    'I.layer = layer\n'
    'flooring_cache[cache_key] = I\n'
    'return flooring_cache[cache_key]'
)


def project_cache_contract(source):
    """Extract and validate the supported cache paths from the actual DM source."""
    body = source.split(PROC, 1)[1].split('\n/', 1)[0]
    body = body.split('\n', 1)[1].strip('\n')
    if body.startswith(NEW_ENTRY + '\n'):
        miss = body[len(NEW_ENTRY) + 1:]
        expected = '\n'.join('\t' + line for line in MISS.splitlines())
    elif body.startswith(OLD_ENTRY + '\n'):
        miss = body[len(OLD_ENTRY) + 1:]
        lines = MISS.splitlines()
        expected = '\n'.join('\t\t' + line for line in lines[:-1])
        expected += '\n\t' + lines[-1]
    else:
        raise ValueError('cache hit behavior changed')
    if miss != expected:
        raise ValueError('cache miss behavior changed')
    return True


def simulate_contract(cache, key, icon_base, icon_dir, edge_icon, floor_icon, layer):
    """Model only the tested missing, null, zero, and truthy-object cases."""
    value = cache.get(key)
    if value is not None and value != 0:
        return value
    value = {'icon': edge_icon if edge_icon else floor_icon,
             'state': icon_base, 'dir': icon_dir, 'layer': layer}
    cache[key] = value
    return cache[key]


class FloorOverlayCache(unittest.TestCase):
    def test_projection_retains_the_original_hit_and_miss_contracts(self):
        source = SOURCE.read_text(encoding='utf-8')
        self.assertIn(NEW_ENTRY, source)
        previous = source.replace(NEW_ENTRY, OLD_ENTRY, 1)
        previous = previous.replace(
            '\n\tvar/icon/use_icon', '\n\t\tvar/icon/use_icon', 1
        ).replace(
            '\n\tvar/image/I = image', '\n\t\tvar/image/I = image', 1
        ).replace('\n\tI.layer = layer', '\n\t\tI.layer = layer', 1).replace(
            '\n\tflooring_cache[cache_key] = I',
            '\n\t\tflooring_cache[cache_key] = I', 1
        )
        self.assertTrue(project_cache_contract(previous))
        self.assertTrue(project_cache_contract(source))

    def test_hits_preserve_identity_and_first_writer_inputs(self):
        source = SOURCE.read_text(encoding='utf-8')
        self.assertTrue(project_cache_contract(source))
        cache = {}
        first = simulate_contract(cache, 'edge', 'grass_edges', 1, None, 'grass.dmi', 2)
        later = simulate_contract(cache, 'edge', 'sand_edges', 8, 'sand.dmi', 'other.dmi', 5)
        self.assertIs(first, later)
        self.assertEqual(first, {'icon': 'grass.dmi', 'state': 'grass_edges', 'dir': 1, 'layer': 2})

    def test_missing_and_falsey_entries_create_and_store_one_overlay(self):
        self.assertTrue(project_cache_contract(SOURCE.read_text(encoding='utf-8')))
        for initial in (None, 0):
            with self.subTest(initial=initial):
                cache = {'edge': initial}
                overlay = simulate_contract(cache, 'edge', 'sand_edges', 4, 'sand.dmi', 'floor.dmi', 3)
                self.assertIs(cache['edge'], overlay)
                self.assertEqual(overlay, {'icon': 'sand.dmi', 'state': 'sand_edges', 'dir': 4, 'layer': 3})
        cache = {}
        overlay = simulate_contract(cache, 'edge', 'grass_edges', 1, None, 'grass.dmi', 2)
        self.assertIs(cache['edge'], overlay)

    def test_negative_controls_reject_changed_hit_and_miss_paths(self):
        source = SOURCE.read_text(encoding='utf-8')
        variants = (
            source.replace('if (cached_overlay)', 'if (!cached_overlay)', 1),
            source.replace('return cached_overlay', 'return image()', 1),
            source.replace('I.layer = layer', 'I.layer = 0', 1),
            source.replace('\n\tI.layer = layer', '\n\t\tI.layer = layer', 1),
        )
        for variant in variants:
            with self.subTest(variant=variants.index(variant)), self.assertRaises(ValueError):
                project_cache_contract(variant)


if __name__ == '__main__':
    unittest.main()