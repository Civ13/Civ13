"""Offline activation identity checks. Does not publish, run or modify anything."""
import argparse
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent

def check(root=HERE, seal=None):
    root = Path(root)
    a = json.loads((root / 'activation.json').read_text(encoding='utf-8'))
    def require(ok, message):
        if not ok:
            raise ValueError(message)
    require(set(a) == {'schema', 'branch', 'message', 'sole_parent', 'run_attempt'}, 'Activation schema fields')
    require(a['schema'] == 1 and a['run_attempt'] == 1, 'Initial attempt only')
    require(a['sole_parent'] == '3f3dd47f614f4659031a793dc590346f5e4de3e6', 'Fixed reviewed parent')
    require(isinstance(a['branch'], str) and re.fullmatch(r'ci/cloud-tanning-5161688-viewport-v[0-9]+-20261025', a['branch']), 'Branch format')
    require(isinstance(a['message'], str) and re.fullmatch(r'ci: one-shot tanning viewport correction v[0-9]+ \(2026-10-25\)', a['message']), 'Message format')
    require(re.search(r'-v([0-9]+)-', a['branch'])[1] == re.search(r' v([0-9]+) ', a['message'])[1], 'Branch/message version')
    ref = 'refs/heads/' + a['branch']
    workflow = (root.parents[1] / '.github/workflows/cloud-bakery-5161688.yml').read_text(encoding='utf-8')
    require(re.findall(r'branches: \[([^\]]+)\]', workflow) == [a['branch']], 'Workflow push branch')
    require(re.findall(r"github.event.head_commit.message == '([^']+)'", workflow) == [a['message']], 'Workflow commit message')
    require(re.findall(r'github.run_attempt == ([0-9]+)', workflow) == ['1'], 'Workflow attempt')
    require(re.findall(r"\$base = '([^']+)'", workflow) == [a['sole_parent']], 'Workflow parent')
    scene = (root / 'run_scene.py').read_text(encoding='utf-8')
    require(re.findall(r"os.environ.get\('GITHUB_REF'\) == '([^']+)'", scene) == [ref], 'Scene activation ref')
    setup = (root / 'directx_setup.py').read_text(encoding='utf-8')
    require(re.findall(r"^BRANCH = '([^']+)'", setup, re.M) == [ref], 'DirectX activation ref')
    contract = json.loads((root / 'tree-source-contract.json').read_text(encoding='utf-8'))
    require(contract['activation_only_guard']['new_branch'] == ref, 'Source-contract activation ref')
    readme = (root / 'README.md').read_text(encoding='utf-8')
    require(re.findall(r'^Branch `([^`]+)`\.', readme, re.M) == [a['branch']], 'README branch')
    require(re.findall(r'^Exact message `([^`]+)`\.', readme, re.M) == [a['message']], 'README message')
    require(re.findall(r'^Sole parent([0-9a-f]+)\.', readme, re.M) == [a['sole_parent']], 'README parent')
    require(re.findall(r'^Attempt([0-9]+) only,', readme, re.M) == ['1'], 'README attempt')
    if seal is not None:
        s = json.loads(Path(seal).read_text(encoding='utf-8'))
        require(s['proposed_branch'] == a['branch'], 'Seal branch')
        require(s['proposed_message'] == a['message'], 'Seal message')
        require(s['initial_sole_parent'] == a['sole_parent'], 'Seal parent')
        require(s['run_attempt'] == a['run_attempt'], 'Seal attempt')
    return a

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--seal', type=Path)
    args = parser.parse_args()
    print(json.dumps(check(seal=args.seal), sort_keys=True))
