"""Project whistle persistence selection without running a game server."""
from types import SimpleNamespace as NS
import unittest

from source_adapter import extract, project, read
from test_throw_target import saved_fields

TOOLS = 'code/game/objects/items/weapons/tools.dm'
POLICY = '/obj/item/weapon/whistle/persistence_runtime_var'


def policy(parent=lambda key: False, source=None):
    return project((source or read(TOOLS)).replace('..()', 'parent(key)'),
                   POLICY, 'src, key', {'parent': parent}, True)


class WhistleCooldownPersistence(unittest.TestCase):
    def whistle(self):
        return NS(kinds={'/datum', '/obj', '/obj/item', '/atom/movable'},
                  vars={'name': 'whistle', 'cooldown': True, 'custom': 42},
                  defaults={'name': 'object', 'cooldown': False, 'custom': 0})

    def test_save_during_cooldown_preserves_live_state_but_omits_cooldown(self):
        whistle = self.whistle()
        before = whistle.vars.copy()
        fields = saved_fields(whistle, policy())
        self.assertNotIn('cooldown', fields)
        self.assertIn('custom', fields)
        self.assertEqual(whistle.vars, before)

    def test_legacy_cooldown_is_filtered_before_import(self):
        loading = extract(read('code/modules/persistence/loading.dm'),
                          '/map_storage/proc/load_entry_fields')
        self.assertIn('if(object.persistence_runtime_var(v))', loading)
        self.assertTrue(policy()(self.whistle(), 'cooldown'))
        self.assertFalse(self.whistle().defaults['cooldown'])

    def test_negative_control_and_inherited_filters(self):
        source = read(TOOLS)
        marker = 'key == "cooldown" || '
        self.assertEqual(source.count(marker), 1)
        unguarded = policy(source=source.replace(marker, '', 1))
        self.assertIn('cooldown', saved_fields(self.whistle(), unguarded))
        inherited = policy(lambda key: key == 'appearance')
        self.assertTrue(inherited(self.whistle(), 'appearance'))
        self.assertFalse(inherited(self.whistle(), 'custom'))

    def test_cooldown_mechanism_and_subtypes_remain_present(self):
        source = read(TOOLS)
        attack = extract(source, '/obj/item/weapon/whistle/attack_self')
        self.assertIn('if (!cooldown)', attack)
        self.assertIn('spawn(6 SECONDS)', attack)
        self.assertIn('cooldown = FALSE', attack)
        self.assertIn('/obj/item/weapon/whistle/death', source)
        self.assertIn('/obj/item/weapon/whistle/tin', source)


if __name__ == '__main__':
    unittest.main()
