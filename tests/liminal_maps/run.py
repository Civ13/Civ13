"""Bounded explicit indoor tests only. No native engines or asset loading."""
import argparse
import json
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT));sys.path.insert(0,str(Path(__file__).parent))
from test_topology import IndoorTests


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,required=True);a=p.parse_args()
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(IndoorTests))
    proof=dict(scope='small-authored-indoor-topology-only',passed=result.wasSuccessful() and result.testsRun>0 and not result.skipped,
               tests=result.testsRun,failures=len(result.failures),errors=len(result.errors),skipped=len(result.skipped),native_launches=0,assets_copied=0)
    a.report.parent.mkdir(parents=True,exist_ok=True);a.report.write_text(json.dumps(proof,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(proof));raise SystemExit(0 if proof['passed'] else 1)
