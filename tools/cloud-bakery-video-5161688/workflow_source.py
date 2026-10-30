"""Read the exact committed workflow on CI; use the local reference offline."""
import os, re, subprocess
from pathlib import Path

def workflow_text():
    if os.environ.get('GITHUB_ACTIONS') != 'true':
        return (Path(__file__).parent/'workflow.reference.txt').read_text(encoding='utf-8')
    workspace=os.environ.get('GITHUB_WORKSPACE',''); sha=os.environ.get('GITHUB_SHA','')
    if not Path(workspace).is_absolute() or not re.fullmatch('[0-9a-f]{40}',sha):
        raise ValueError('invalid workflow checkout identity')
    head=subprocess.check_output(['git','-C',workspace,'rev-parse','HEAD'],timeout=10).decode('ascii').strip()
    if head!=sha: raise ValueError('workflow checkout head mismatch')
    data=subprocess.check_output(['git','-C',workspace,'show',sha+':.github/workflows/cloud-bakery-video-5161688.yml'],timeout=10)
    if len(data)>131072: raise ValueError('workflow size limit')
    return data.decode('utf-8')
