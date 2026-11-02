"""Offline regression controls for the single enabled-owner adapter."""
import copy
import importlib.util
from pathlib import Path
import unittest

HERE=Path(__file__).resolve().parent
def module(name):
    spec=importlib.util.spec_from_file_location(name,HERE/(name+'.py'))
    value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value);return value

stage=module('scheduler_hostile_stage')
contract=module('scheduler_hostile_contract')
fixture_test=module('test_scheduler_hostile_contract')


class HostileStage(unittest.TestCase):
    def test_probe_preserves_partial_receipt_and_changes_scope(self):
        original=('\t\t\thuman_subtile_fixture_headless()\n'
                  '"checks" = human_subtile_fixture_checks,\n'
                  '"scope" = "actual human/codec; headless authority adapter"\n')
        result=stage.adapted_probe(original)
        self.assertIn('fixture_scheduler_hostile_main()',result)
        self.assertIn('"transition_partial" = fixture_transition_events',result)
        self.assertIn('"scope" = "'+stage.SCOPE+'"',result)
        self.assertNotIn('fixture_scheduler_transition_main()',result)
        for old in ('human_subtile_fixture_headless()', '"checks" = human_subtile_fixture_checks,',
                    '"scope" = "actual human/codec; headless authority adapter"'):
            with self.subTest(old=old),self.assertRaises(ValueError):
                stage.adapted_probe(original.replace(old,'',1))

    def test_dme_includes_one_fixture_after_real_scheduler(self):
        original='#include "tests\\human_subtile\\scheduler_core_draft.dm"\n'
        result=stage.adapted_dme(original)
        self.assertEqual(result.count('scheduler_hostile_draft.dm'),1)
        self.assertGreater(result.index('scheduler_hostile_draft.dm'),
                           result.index('scheduler_core_draft.dm'))
        with self.assertRaises(ValueError):stage.adapted_dme(result)
        with self.assertRaises(ValueError):stage.adapted_dme('')

    def test_receipt_binds_partial_trace_and_exact_single_case(self):
        row=fixture_test.good();head='a'*40
        receipt=dict(head=head,error=None,port=0,byond_version=516,byond_build=1688,
                     scope=contract.SCOPE,transition_checks=42,transition_phase='quiet',
                     transition_rows=[row],transition_partial=copy.deepcopy(row['events']))
        self.assertTrue(contract.validate_receipt(receipt,head)['positive_contact'])
        for mutate in ('scope','phase','checks','missing','duplicate','partial','head'):
            broken=copy.deepcopy(receipt)
            if mutate=='scope':broken['scope']='fallback'
            if mutate=='phase':broken['transition_phase']='replacement'
            if mutate=='checks':broken['transition_checks']=0
            if mutate=='missing':broken['transition_rows']=[]
            if mutate=='duplicate':broken['transition_rows'].append(copy.deepcopy(row))
            if mutate=='partial':broken['transition_partial'][-1]['sx']=7
            if mutate=='head':broken['head']='b'*40
            with self.subTest(mutate=mutate),self.assertRaises(ValueError):
                contract.validate_receipt(broken,head)


if __name__=='__main__':unittest.main()