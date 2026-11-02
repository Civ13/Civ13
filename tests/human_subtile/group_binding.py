"""Exact immutable source binding for the isolated group-swap observation."""
import hashlib,re,subprocess,time
PARENT='08cbcb35a2c98720f38981289a3194327afdf362'
PARENT_TREE='36d1827b443523a34601cd4bb858b307b2f3c710'
PATHS=frozenset({
 '.github/workflows/wildlife-cardinal-cadence.yml',
 'tests/human_subtile/cloud_npc_controller.py',
 'tests/human_subtile/cloud_npc_job.py',
 'tests/human_subtile/cloud_npc_smoke.py',
 'tests/human_subtile/group_binding.py',
 'tests/human_subtile/group_worker.py',
 'tests/human_subtile/group_evidence.py',
 'tests/human_subtile/test_group_integration.py',
 'tests/human_subtile/test_bump_integration.py',
 'tests/human_subtile/native_group/native-group-probe.dme',
 'tests/human_subtile/native_group/native-group-probe.dm',
 'tests/human_subtile/native_group/validate_receipt.py',
 'tests/human_subtile/native_group/test_validate_receipt.py',
 'tests/human_subtile/native_group/test_source_contract.py',
})
# Independently accepted v2 source bytes, not Windows checkout-normalized content.
INPUTS={
 'native-group-probe.dme':'50add13aa4fa80a7e1dd9c9d8e31cc0991c5eb835a62370b566f4d47a1cd9f76',
 'native-group-probe.dm':'f26244c5248fade2edca68cafa83d8f6249b0bb5ce7f05accf074f9a96afb500',
 'validate_receipt.py':'100e6aadccf3a5ac9fad2383b9f1db8b15e07652e93a72477122e817e5afed18',
 'test_validate_receipt.py':'8f7a39683cd87ac5b2218acf9453dc020ddf71a66420997cc6b861b454613b05',
 'test_source_contract.py':'6bf47d388da9e9790362b0201d5954151f2e097a5ab856eb515c76f16fda5ed3',
}
PREFIX='tests/human_subtile/native_group/'
# Bound runner inputs exclude this binding file itself; external review pins full tree.
RUNNER_INPUTS={
    '.github/workflows/wildlife-cardinal-cadence.yml': '60192d5ff258c8b126852cdbad86093afed51e1f70ed67d203009721690336a5',
    'tests/human_subtile/cloud_npc_controller.py': 'e1da67d9fa2dcad4f95d6215a05f268cac4603f410a492926a1c38d11f70b5a0',
    'tests/human_subtile/cloud_npc_job.py': '4b7b3ea95de0a197f3e5f89227ad6962d07b20e7a82b148efe27581f5cd45dcc',
    'tests/human_subtile/cloud_npc_smoke.py': 'a173aeb1a8cc1872785e7f05c024a18340f93ade5777a3f4f0973e2baa294643',
    'tests/human_subtile/group_worker.py': 'd96772e1f673e50a00185b8afb0a6a6d5d168aca9f9d312e96438ca0b0a64a04',
    'tests/human_subtile/group_evidence.py': '5a7858fecaba0aabe2e6bda3ead628a9125f1eced360268c4e9ed2adac4248a8',
    'tests/human_subtile/test_group_integration.py': 'f70aef4824185e0960e30eb7bae3c3ffaa302537b300bd5c7ab4e1c007cc4758',
    'tests/human_subtile/test_bump_integration.py': 'c40599bee1b510e62655c95c6d545a13f57c279dfcb5a5a9beb848d76ad88cc8',
}

def read(git,args,env=None,deadline=None,timeout=10):
    if deadline is not None:
        remain=deadline-time.monotonic()
        if remain<=0:raise TimeoutError('group binding deadline')
        timeout=min(timeout,remain)
    return subprocess.check_output(git+args,env=env,timeout=timeout)

def validate_head(git,head,env=None,deadline=None):
    if type(head) is not str or re.fullmatch('[0-9a-f]{40}',head) is None:raise ValueError('invalid exact head')
    parents=read(git,['rev-list','--parents','-n','1',head],env,deadline).decode().strip().split()
    if parents != [head,PARENT]:raise ValueError('unexpected parent')
    if read(git,['rev-parse',PARENT+'^{tree}'],env,deadline).decode().strip()!=PARENT_TREE:raise ValueError('unexpected parent tree')
    diff=read(git,['diff','--no-ext-diff','--no-renames','--name-only','-z',PARENT,head,'--'],env,deadline,30).split(b'\0')
    if not diff or diff[-1]!=b'' or any(not x for x in diff[:-1]):raise ValueError('bad delta list')
    paths=[x.decode('utf-8') for x in diff[:-1]]
    if len(paths)!=len(set(paths)) or frozenset(paths)!=PATHS:raise ValueError('unexpected changed path set')
    raw=read(git,['ls-tree','-r','-z',head,'--',*sorted(PATHS)],env,deadline,30)
    rows={}
    for row in raw.split(b'\0'):
        if not row:continue
        meta,path=row.split(b'\t',1);mode,kind,oid=meta.split();name=path.decode('utf-8')
        if name in rows or mode!=b'100644' or kind!=b'blob' or not re.fullmatch(b'[0-9a-f]{40}',oid):raise ValueError('invalid source tree entry')
        rows[name]=oid.decode()
    if frozenset(rows)!=PATHS:raise ValueError('missing tree path')
    for name,digest in INPUTS.items():
        data=read(git,['show',head+':'+PREFIX+name],env,deadline,10)
        if hashlib.sha256(data).hexdigest()!=digest:raise ValueError('accepted fixture bytes differ: '+name)
    for path,digest in RUNNER_INPUTS.items():
        data=read(git,['show',head+':'+path],env,deadline,10)
        if hashlib.sha256(data).hexdigest()!=digest:raise ValueError('reviewed runner bytes differ: '+path)
    tree=read(git,['rev-parse',head+'^{tree}'],env,deadline).decode().strip()
    if re.fullmatch('[0-9a-f]{40}',tree) is None:raise ValueError('invalid tree')
    return tree
