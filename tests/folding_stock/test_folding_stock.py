"""Folding-stock guns share one toggle on /obj/item/weapon/gun/projectile.

original_fold_verb.dm.txt freezes the fold verb that the AKMS, AKS-74 family,
SR-3 and DT-28 each copied. Source checks only; no BYOND runtime.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
FILES = {
    'projectile': ROOT / 'code/modules/projectiles/guns/projectile.dm',
    'smg': ROOT / 'code/modules/1713/weapons/guns/mg/smg.dm',
    'aks': ROOT / 'code/modules/1713/weapons/guns/mg/aks.dm',
    'lmg': ROOT / 'code/modules/1713/weapons/guns/mg/lmg.dm',
}
FOLDING = {
    'smg': ('submachinegun/ak47/akms', 'submachinegun/ak74/aks74', 'submachinegun/srm'),
    'aks': ('submachinegun/ak101',),
    'lmg': ('automatic/dp28/dt28',),
}
VERB = '\tset name = "Toggle Stock"\n\tset category = null\n\tset src in usr\n\ttoggle_folding_stock(usr)\n'


def block(source, header):
    match = re.search(r'(?m)^' + re.escape(header) + r'.*\n((?:\t.*\n|[ \t]*\n)*)', source)
    return match.group(1) if match else None


def errors(sources):
    found = []
    base = sources['projectile']
    helper = block(base, '/obj/item/weapon/gun/projectile/proc/toggle_folding_stock(') or ''
    original = (HERE / 'original_fold_verb.dm.txt').read_text(encoding='utf-8')
    for line in ('folded = FALSE', 'folded = TRUE', 'You extend the stock on \\the [src].',
                 'You collapse the stock on \\the [src].', 'equiptimer = 15', 'equiptimer = 7',
                 'set_stock()', 'update_icon()'):
        if line not in original or line not in helper:
            found.append(f'toggle lost {line}')
    if 'recoil *= 1.5' not in original or 'recoil *= stock_recoil_mult' not in helper:
        found.append('toggle lost the recoil change')
    icon = block(base, '/obj/item/weapon/gun/projectile/update_icon(') or ''
    if 'icon_state = folded ? "[base_icon]_folded" : "[base_icon]"' not in icon:
        found.append('update_icon must draw the folded state')
    for name, types in FOLDING.items():
        source = sources[name]
        for path in types:
            full = '/obj/item/weapon/gun/projectile/' + path
            if block(source, full + '/verb/fold(') != VERB + '\n':
                found.append(f'{path} must use the shared toggle')
            definition = re.search(r'(?m)^' + re.escape(full) + r'\n((?:\t.*\n)*)', source)
            if not definition or '\tfolding_stock = TRUE\n' not in definition.group(1):
                found.append(f'{path} must set folding_stock')
        if 'recoil /= 1.5' in source or 'proc/set_stock(' in source:
            found.append(f'{name} copies the fold toggle again')
    if '\tstock_recoil_mult = 1\n' not in sources['aks']:
        found.append('AK-101 stock must not change recoil')
    return found


class FoldingStock(unittest.TestCase):
    def setUp(self):
        self.sources = {name: path.read_text(encoding='utf-8') for name, path in FILES.items()}

    def test_folding_guns_share_the_toggle(self):
        self.assertEqual(errors(self.sources), [])

    def test_detects_copied_toggle(self):
        changed = dict(self.sources)
        changed['smg'] += '\n/obj/item/weapon/gun/projectile/x/proc/set_stock()\n\treturn\n'
        self.assertTrue(errors(changed))


if __name__ == '__main__':
    unittest.main()
