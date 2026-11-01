"""Offline closure checks; this adapter never implements recovery behavior."""
import importlib.util
from pathlib import Path
import re
import unittest

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
ADAPTER = 'tests/movement_save_chunks/debug_lossy_adapter.dm'
REFUSAL = 'throw EXCEPTION("Debug recovery requires the full-source fixture")'


def module(name):
    spec = importlib.util.spec_from_file_location('debug_adapter_' + name, HERE / (name + '.py'))
    result = importlib.util.module_from_spec(spec)
    import sys
    sys.modules[spec.name] = result
    spec.loader.exec_module(result)
    return result


def verify(text):
    for name in ('bind', 'observe', 'finish_failure', 'finish_success', 'audit', 'is_quarantined', 'encode_list_member'):
        match = re.search(r'(?m)^\tproc/' + name + r'\([^\n]*\)\n\t\t([^\n]+)', text)
        if not match or match.group(1) != REFUSAL:
            raise AssertionError('policy method does not refuse: ' + name)
    for name in ('debug_backup_identity_valid', 'debug_cleanup_owned', 'valid_debug_recovery_audit'):
        match = re.search(r'(?m)^/(?:map_storage/)?proc/' + name + r'\([^\n]*\)\n\t([^\n]+)', text)
        if not match or match.group(1) != REFUSAL:
            raise AssertionError('fixture entry does not refuse: ' + name)
    body = text.split('/proc/save_debug_omits(', 1)[1]
    if ('if(persistence_active_operation && persistence_active_operation.debug_recovery)\n\t\t' + REFUSAL + '\n\treturn FALSE') not in body:
        raise AssertionError('ordinary/no-debug omission gate changed')


class AdapterContracts(unittest.TestCase):
    def test_both_packets_include_identical_explicit_adapter(self):
        for name in ('prepare', 'benchmark'):
            files = module(name).FILES
            self.assertEqual(files.count(ADAPTER), 1)
            self.assertLess(files.index(ADAPTER), files.index('code/modules/persistence/functions.dm'))
            self.assertLess(files.index(ADAPTER), files.index('code/modules/persistence/saving.dm'))

    def test_every_recovery_entry_refuses_and_default_does_not_omit(self):
        text = (ROOT / ADAPTER).read_text(encoding='utf-8')
        verify(text)
        self.assertEqual(text.count(REFUSAL), 11)
        with self.assertRaises(AssertionError): verify(text.replace(REFUSAL, 'return TRUE', 1))
        with self.assertRaises(AssertionError): verify(text.replace('persistence_active_operation.debug_recovery', 'FALSE', 1))
        for name in ('is_quarantined', 'encode_list_member'):
            original = re.search(r'(?m)^\tproc/' + name + r'\([^\n]*\)\n\t\t' + re.escape(REFUSAL), text)
            self.assertIsNotNone(original)
            mutated = text[:original.start()] + original.group().replace(REFUSAL, 'return FALSE') + text[original.end():]
            with self.subTest(name=name), self.assertRaises(AssertionError): verify(mutated)


if __name__ == '__main__': unittest.main()
