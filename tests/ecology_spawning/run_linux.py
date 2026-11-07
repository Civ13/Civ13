"""Linux port of tests/resource_extraction/run.ps1 for one probe.

Usage: python3 tests/ecology_spawning/run_linux.py . tests/ecology_spawning/probe.dm
       python3 tests/ecology_spawning/run_linux.py . tests/ecology_spawning/perf_probe.dm 900
Needs the pinned BYOND from scripts/cloud_byond_setup.sh in ~/byond-<version>.
"""
import os, re, shutil, subprocess, sys, tempfile, uuid, json
repo = os.path.abspath(sys.argv[1]); probe = sys.argv[2]; timeout = int(sys.argv[3]) if len(sys.argv) > 3 else 120
pin = json.load(open(os.path.join(repo, 'tools/byond/version.json')))['version']
binp = os.path.expanduser('~/byond-' + pin + '/byond/bin')
env = dict(os.environ, LD_LIBRARY_PATH=binp + ':' + os.environ.get('LD_LIBRARY_PATH', ''), BYOND_SYSTEM=os.path.dirname(binp), PATH=binp + ':' + os.environ['PATH'])
prefix = '.resource_probe_' + uuid.uuid4().hex
tmp = tempfile.mkdtemp(prefix='civ13-eco-')
os.chdir(repo)
commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
created = []
def w(name, text):
    open(name, 'w', newline='\n').write(text); created.append(name)
try:
    world = open('code/world.dm').read().replace('/world/New()', '/world/proc/unused_resource_startup()')
    off = world.index('/world/proc/unused_resource_startup()')
    m = re.compile(r'(?m)^\t\.\.\(\)\r?$').search(world, off)
    world = world[:m.start()] + world[m.end():]
    world = world.replace('/datum/global_init/New()', '/datum/global_init/New()\n\treturn')
    w(prefix + '_world.dm', world)
    g = open('code/controllers/mc/globals.dm').read().replace('/datum/controller/global_vars/New()', '/datum/controller/global_vars/New()\n\tGLOB = src\n\treturn')
    w(prefix + '_globals.dm', g)
    src = open('civ13.dme').read().replace('code\\world.dm', prefix + '_world.dm').replace('code\\controllers\\mc\\globals.dm', prefix + '_globals.dm')
    src = re.sub(r'(?m)^#include ".*\.dmm"\s*$', '', src)
    w(prefix + '.dme', src + '\n#include "' + probe + '"\n')
    b = subprocess.run(['DreamMaker', '-max_errors', '0', prefix + '.dme'], env=env, capture_output=True, text=True)
    out = b.stdout + b.stderr
    if '0 errors, 0 warnings' not in out:
        print(out[-4000:]); sys.exit('compile failed')
    for ext in ('.dmb', '.rsc'):
        shutil.copy(prefix + ext, os.path.join(tmp, 'probe' + ext)); created.append(prefix + ext)
    shutil.copytree('config', os.path.join(tmp, 'config'))
    r = subprocess.run(['DreamDaemon', 'probe.dmb', '0', '-invisible', '-close', '-trusted', '-params', 'tested_commit=' + commit, '-log', 'runtime.log'], cwd=tmp, env=env, timeout=timeout)
    print(open(os.path.join(tmp, 'runtime.log')).read())
    res = json.load(open(os.path.join(tmp, 'result.json')))
    print(json.dumps(res))
    sys.exit(0 if res.get('failures') == 0 and not res.get('runtime_error') else 1)
finally:
    for f in created + [prefix + '.int', prefix + '.dyn.rsc', prefix + '.lk']:
        if os.path.exists(f): os.remove(f)
    print('evidence:', tmp)
