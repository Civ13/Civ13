"""Explicit offline test list. No native tests or wildcard discovery enter CI."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT))
sys.path.insert(0,str(Path(__file__).resolve().parent))
TEST_FILES=(
    'test_acceptance.py','test_annotations.py','test_cli.py','test_configuration.py',
    'test_dmm_export.py','test_metrics.py','test_port_topology.py','test_resource_proposal.py',
    'test_source_audit.py','test_surface_generator.py','test_validator.py','test_public_cli.py','test_oceanic.py',
)


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--report',type=Path)
    parser.add_argument('--historical-catalog-root',type=Path,required=True)
    parser.add_argument('--intermediate-catalog-root',type=Path,required=True)
    parser.add_argument('--v3-catalog-root',type=Path,required=True);a=parser.parse_args()
    os.environ['CIV13_TEST_HISTORICAL_CATALOG_ROOT']=str(a.historical_catalog_root.resolve())
    os.environ['CIV13_TEST_INTERMEDIATE_CATALOG_ROOT']=str(a.intermediate_catalog_root.resolve())
    os.environ['CIV13_TEST_V3_CATALOG_ROOT']=str(a.v3_catalog_root.resolve())
    suite=unittest.TestSuite()
    for name in TEST_FILES:
        spec=importlib.util.spec_from_file_location('procedural_'+name[:-3],Path(__file__).with_name(name))
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        suite.addTests(unittest.defaultTestLoader.loadTestsFromModule(module))
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    passed=result.wasSuccessful() and result.testsRun>0 and not result.skipped
    report=dict(scope='offline-only',passed=passed,tests=result.testsRun,failures=len(result.failures),errors=len(result.errors),skipped=len(result.skipped),native_launches=0)
    if a.report:a.report.parent.mkdir(parents=True,exist_ok=True);a.report.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report));return 0 if passed else 1


if __name__=='__main__':raise SystemExit(main())
