"""Source guards: wizard gear stays out of persistent worlds (Val, 2026-11-14).

On persistent worlds a wizard's gear must look like ordinary items to everyone;
magic comes from the wizard, not from a unique item type. Any decoration is a
cosmetic change anyone can make to any item. The only exception is a god's
original book. The magic module's own items (wands, robes, potions, brooms,
wand parts, magic swords) belong to the Wizard Boy and fantasy round maps, so
none of them may be mapped onto, crafted on or spawned into persistent worlds.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
MAGIC_DIR = ROOT / 'code/modules/magic'
# Map folders that persistent-world regions load from.
PERSISTENT_MAP_DIRS = ('maps/nomads', 'maps/sea', 'maps/space')
# Files outside the magic module that may create magic gear, and why. Any
# other creation must sit behind a Wizard Boy map check.
ALLOWED_SPAWNERS = {
    'code/modules/1713/jobs/permafrost.dm',  # round map job kit
    'code/game/objects/map_metadata/clash.dm',  # round map reward
    'code/game/objects/map_metadata/wizard_boy.dm',
    'code/modules/1713/moldy_men/moldy_sabotage.dm',  # Wizard Boy event
    'code/game/objects/effects/spawner.dm',  # phosphor beetle mob, not gear
}
PATH_RE = re.compile(r'^(/obj/[A-Za-z0-9_/]+)', re.M)


def defined_paths(files):
    found = set()
    for path in files:
        found.update(PATH_RE.findall(path.read_text(encoding='utf-8', errors='replace')))
    return found


MAGIC_FILES = sorted(MAGIC_DIR.glob('*.dm'))
OTHER_FILES = [p for p in (ROOT / 'code').rglob('*.dm') if MAGIC_DIR not in p.parents]
# Magic-only types: defined in the magic module and nowhere else.
MAGIC_TYPES = defined_paths(MAGIC_FILES) - defined_paths(OTHER_FILES)
MAGIC_ROOTS = (
    '/obj/item/weapon/material/magic',
    '/obj/item/wand_part',
    '/obj/structure/magic',
)


ROOT_RE = re.compile('|'.join(re.escape(r) for r in MAGIC_ROOTS) + r'(?![A-Za-z0-9_])')
TYPE_RE = re.compile('|'.join(re.escape(p) for p in sorted(MAGIC_TYPES, key=len, reverse=True)) + r'(?![A-Za-z0-9_/])')


def mentions_magic_type(text):
    hit = ROOT_RE.search(text) or TYPE_RE.search(text)
    return hit.group(0) if hit else None


class MundaneWizardGear(unittest.TestCase):
    def test_magic_module_defines_gear(self):
        # Sanity: the scan sees the module, so the guards below are not vacuous.
        self.assertIn('/obj/item/weapon/material/magic/wand', MAGIC_TYPES | set(MAGIC_ROOTS))
        self.assertGreater(len(MAGIC_TYPES), 50)

    def test_no_magic_gear_on_persistent_maps(self):
        for folder in PERSISTENT_MAP_DIRS:
            for dmm in sorted((ROOT / folder).rglob('*.dmm')):
                hit = mentions_magic_type(dmm.read_text(encoding='utf-8', errors='replace'))
                self.assertIsNone(hit, f'{dmm.relative_to(ROOT)} places magic gear {hit}')

    def test_no_magic_gear_in_crafting(self):
        for recipe in sorted((ROOT / 'config/crafting').iterdir()):
            if recipe.is_file():
                hit = mentions_magic_type(recipe.read_text(encoding='utf-8', errors='replace'))
                self.assertIsNone(hit, f'{recipe.relative_to(ROOT)} crafts magic gear {hit}')

    def test_magic_recipes_stay_on_wizard_boy(self):
        text = (MAGIC_DIR / 'magic_recipes.dm').read_text()
        self.assertIn('if (!map || map.ID != MAP_WIZARD_BOY)', text)

    def test_no_new_spawn_sources(self):
        for path in OTHER_FILES:
            rel = path.relative_to(ROOT).as_posix()
            if rel in ALLOWED_SPAWNERS:
                continue
            lines = path.read_text(encoding='utf-8', errors='replace').splitlines()
            for i, line in enumerate(lines):
                created = re.search(r'\bnew\s*(/obj/[A-Za-z0-9_/]+)', line)
                if not created or not mentions_magic_type(created.group(1)):
                    continue
                guard = '\n'.join(lines[max(0, i - 3):i + 1])
                self.assertIn('MAP_WIZARD_BOY', guard,
                              f'{rel}:{i + 1} creates magic gear {created.group(1)} outside Wizard Boy; '
                              'persistent-world wizard gear must be an ordinary item')

    def test_gods_book_is_the_only_exception(self):
        book = (ROOT / 'code/modules/divine/divine_book.dm').read_text()
        head = book.split('/obj/item/weapon/book/divine\n', 1)[1].split('\n/', 1)[0]
        # It still looks like any other book; only the original says whose it is.
        self.assertIn('name = "book"', head)
        self.assertIn('title = "book"', head)
        self.assertNotIn('icon_state', head)

    def test_atlas_never_lists_the_gods_book(self):
        # The public Crafting Atlas lists items by type path; a divine path would give it away.
        text = (ROOT / 'scripts/atlas/entities.py').read_text()
        internal = re.search(r"INTERNAL = re.compile\((.*?), re.I\)", text, re.S).group(1)
        pattern = re.compile(''.join(re.findall(r"r'([^']*)'", internal)), re.I)
        self.assertTrue(pattern.search('/obj/item/weapon/book/divine'))
        self.assertNotIn('book/divine', (ROOT / 'UI/crafting-atlas.json').read_text())


if __name__ == '__main__':
    unittest.main()
