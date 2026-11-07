"""Offline source checks for the 2026-11-07 gameplay audit fixes (see run.py)."""
import importlib.util
from pathlib import Path
import unittest

_spec = importlib.util.spec_from_file_location('gameplay_audit_run', Path(__file__).with_name('run.py'))
audit = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(audit)


class GameplayAuditSourceTest(unittest.TestCase):
    def test_fixes_present(self):
        self.assertEqual(audit.source_checks(), [])

    def test_ethanol_removal_spends_every_alcohol(self):
        holder = audit.block(audit.read('code/modules/reagents/Chemistry-Holder.dm'),
                             '/datum/reagents/proc/remove_reagent(')
        ethanol = holder[holder.index('if (id == "ethanol")'):holder.index('for (var/datum/reagent/current in reagent_list)\n\t\tif (current.id == id)')]
        self.assertIn('istype(current, /datum/reagent/ethanol)', ethanol)
        self.assertIn('remaining -= used', ethanol)
        self.assertNotIn('\n\t\t\treturn TRUE\n\n', ethanol)


if __name__ == '__main__':
    unittest.main()
