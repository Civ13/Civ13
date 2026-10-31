"""Stage exact tracked source for a separately selected, bounded compile only.

This module never launches BYOND. It streams a Git archive and verifies every
regular member against the exact Git blob before the worker invokes DreamMaker.
"""
import hashlib
import os
from pathlib import Path, PurePosixPath
import signal
import subprocess
import tarfile

MAX_FILES=8000
MAX_BYTES=1024**3
MAX_MEMBER=256*1024**2


def require(ok,message):
    if not ok: raise RuntimeError(message)


def tree_inventory(raw):
    require(len(raw)<=16*1024**2,'Git inventory bound')
    expected={};total=0
    for row in raw.split(b'\0'):
        if not row: continue
        meta,path=row.split(b'\t',1);mode,kind,oid,size=meta.split()
        name=path.decode('utf-8'); parts=PurePosixPath(name)
        require(mode in (b'100644',b'100755') and kind==b'blob' and len(oid)==40 and all(c in b'0123456789abcdef' for c in oid) and size.isdigit() and
                not parts.is_absolute() and '..' not in parts.parts and '\\' not in name and name not in expected,
                'Unsupported Git member')
        length=int(size);require(0 <= length <= MAX_MEMBER,'Git member size bound')
        total+=length;require(total<=MAX_BYTES and len(expected)<MAX_FILES,'Git source budget')
        expected[name]={'git_blob':oid.decode('ascii'),'bytes':length,'mode':mode.decode('ascii')}
    require('civ13.dme' in expected,'Missing production DME')
    return expected,total


def extract_exact(stream, stage, expected):
    require(stage.is_dir() and not any(stage.iterdir()),'Production stage must be fresh')
    seen={}
    with tarfile.open(fileobj=stream,mode='r|') as archive:
        for item in archive:
            if item.isdir(): continue
            name=item.name; path=PurePosixPath(name)
            require(item.isfile() and not path.is_absolute() and '..' not in path.parts and '\\' not in name and
                    name in expected and name not in seen and item.size==expected[name]['bytes'], 'Unexpected archive member')
            target=stage.joinpath(*path.parts)
            require(target.resolve().is_relative_to(stage.resolve()),'Production path escapes stage')
            target.parent.mkdir(parents=True,exist_ok=True)
            source=archive.extractfile(item); git=hashlib.sha1(('blob '+str(item.size)+'\0').encode()); digest=hashlib.sha256();remaining=item.size
            with target.open('xb') as dest:
                while remaining:
                    data=source.read(min(1024**2,remaining));require(data,'Truncated Git member')
                    dest.write(data);git.update(data);digest.update(data);remaining-=len(data)
            require(git.hexdigest()==expected[name]['git_blob'],'Git blob mismatch: '+name)
            seen[name]={'bytes':item.size,'sha256':digest.hexdigest(),'git_blob':git.hexdigest()}
    require(set(seen)==set(expected),'Missing tracked source member')
    return seen


def prepare(root, out, head):
    require(not out.exists(),'Production output must be fresh')
    observed=subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],timeout=10).decode().strip()
    require(observed==head and len(head)==40,'Production head mismatch')
    raw=subprocess.check_output(['git','-C',str(root),'ls-tree','-r','-l','-z',head],timeout=30)
    expected,total=tree_inventory(raw)
    out.mkdir();stage=out/'stage';stage.mkdir()
    child=subprocess.Popen(['git','-C',str(root),'archive','--format=tar',head],stdout=subprocess.PIPE,
                           stderr=subprocess.DEVNULL,start_new_session=True)
    try:
        seen=extract_exact(child.stdout,stage,expected)
        require(child.wait(timeout=10)==0,'Git archive failed')
    finally:
        if child.poll() is None:
            os.killpg(child.pid,signal.SIGKILL);child.wait(timeout=3)
        child.stdout.close()
    tree=subprocess.check_output(['git','-C',str(root),'rev-parse',head+'^{tree}'],timeout=10).decode().strip()
    return {'head':head,'tree':tree,'files':seen,'bytes':total,'dme':'civ13.dme','source_unmodified':True}


def verify_source(stage, manifest):
    for name, expected in manifest['files'].items():
        path=stage.joinpath(*PurePosixPath(name).parts)
        require(path.is_file() and path.stat().st_size==expected['bytes'],'Production source missing or changed: '+name)
        with path.open('rb') as stream:
            digest=hashlib.file_digest(stream,'sha256').hexdigest()
        require(digest==expected['sha256'],'Production source changed: '+name)
