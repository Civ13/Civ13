"""Owned setup child. Import is inert; CLI requires explicit roots and deadline.

No function in this module is executed by the offline tests with real effects.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import subprocess
import sys
import tarfile
import time
import urllib.request

ENGINE='09f63000bab228a4bc792f3a2211e2d60a07de14'
TREE='210207129ce01fce6daf87f3a3c8f48085184db6'
ROBUST='af2a7d0406b410c4d960f0f4b34513651c6dc742'
GAME='f5620b232b4fa159930b3b393c9794c05d4fb7b1'
SDK_URL='https://builds.dotnet.microsoft.com/dotnet/Sdk/10.0.401/dotnet-sdk-10.0.401-linux-x64.tar.gz'
SDK_SHA512='51c8b999af9e8dd9998c9edc5944e19a90788862068acd38694e098889054ce8c23d4f0c5cccfa16bf187d044562359e5ee69a9f8ad0bbe913ba90311fbce25b'


def need(ok,message):
    if not ok: raise ValueError(message)


def canonical(value): return json.dumps(value,sort_keys=True,separators=(',',':')).encode()


def path_name(name):
    p=PurePosixPath(name)
    need(name and not p.is_absolute() and '..' not in p.parts and '\\' not in name,'unsafe archive/source path')
    return str(p)


def guarded_command(argv,cwd,check,deadline):
    """No slow caller prep between the final check and actual Popen init."""
    proc=subprocess.Popen.__new__(subprocess.Popen)
    check()
    subprocess.Popen.__init__(proc,argv,cwd=cwd,stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE,shell=False,close_fds=True)
    check()
    out,err=proc.communicate(timeout=max(.001,deadline-time.monotonic()))
    check()
    return proc.returncode,out,err


def extract(tar, destination, check):
    """No extractall, links, devices, duplicate files or mode propagation."""
    count=0; total=0
    for member in tar:
        check(); name=path_name(member.name)
        need(len(PurePosixPath(name).parts)<=16,'SDK depth')
        target=destination/name
        if member.isdir():
            check(); target.mkdir(parents=True,exist_ok=True); continue
        need(member.isfile() and 0<=member.size<=128*1024**2,'SDK nonregular/oversize member')
        count+=1; total+=member.size
        need(count<=10000 and total<=8*1024**3,'SDK extraction bound')
        check(); target.parent.mkdir(parents=True,exist_ok=True)
        check()
        with target.open('xb') as out, tar.extractfile(member) as inp:
            remaining=member.size
            while remaining:
                check(); raw=inp.read(min(1024**2,remaining)); check()
                need(raw,'truncated SDK'); check(); out.write(raw); remaining-=len(raw)
        check(); target.chmod(0o700 if member.mode & 0o111 else 0o600)


def main(argv=None):
    parser=argparse.ArgumentParser()
    parser.add_argument('--root',required=True)
    parser.add_argument('--deadline',required=True,type=float)
    parser.add_argument('--expires',required=True,type=float)
    args=parser.parse_args(argv)
    root=Path(args.root)
    command_rows=[]
    def check(): need(time.monotonic()<args.deadline and time.time()<args.expires,'setup deadline/expiry')
    def cmd(argv,cwd):
        check()
        # No shell, no inherited credential helper or interactive prompts.
        code,out,err=guarded_command(argv,cwd,check,args.deadline)
        check(); need(len(out)+len(err)<=1024**2,'setup command output bound')
        row={'argv':argv,'cwd':str(cwd),'exit':code,
             'stdout_hex':out.hex(),'stderr_hex':err.hex()}
        need(len(command_rows)<1000,'setup command count bound')
        raw=canonical(row); name='command-'+str(len(command_rows))+'.json'
        check()
        with (root/'receipts'/name).open('xb') as out:
            out.write(raw); out.flush(); check(); os.fsync(out.fileno())
        command_rows.append({'path':name,'sha256':hashlib.sha256(raw).hexdigest()})
        check(); need(code==0,'setup command exit '+str(code)+': '+repr(argv))
        return out
    def git(cwd,*argv): return cmd(['/usr/bin/git','-c','credential.helper=','-c','core.hooksPath=/dev/null',*argv],cwd)
    def export(repo,prefix,destination,rows,proof):
        check(); head=git(repo,'rev-parse','HEAD').decode().strip()
        proof.append({'path':prefix,'head':head,'tree':git(repo,'rev-parse','HEAD^{tree}').decode().strip()})
        for record in git(repo,'ls-tree','-rz','HEAD').split(b'\0'):
            if not record: continue
            check(); meta,rawname=record.split(b'\t',1); mode,kind,oid=meta.decode().split()
            name=path_name(rawname.decode()); rel=path_name(prefix+name)
            if kind=='commit':
                child=repo/name
                need(git(child,'rev-parse','HEAD').decode().strip()==oid,'nested gitlink differs')
                export(child,rel+'/',destination,rows,proof); continue
            need(kind=='blob' and mode in ('100644','100755'),'linked/nonregular source')
            raw=(repo/name).read_bytes(); check()
            # Git hashes content including its blob header; authenticate exported bytes.
            need(hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==oid,
                 'tracked source differs')
            target=destination/rel; check(); target.parent.mkdir(parents=True,exist_ok=True)
            check(); target.write_bytes(raw); check()
            rows[rel]=hashlib.sha256(raw).hexdigest()
    check(); engine=root/'engine-checkout'; game=root/'game-checkout'
    for url,head,target in [('https://github.com/valzargaming/OpenDream.git',ENGINE,engine),
                            ('https://github.com/Civ13/Civ13.git',GAME,game)]:
        check(); target.mkdir()
        git(target,'init','-q'); git(target,'remote','add','origin',url)
        git(target,'fetch','--depth=1','origin',head); git(target,'checkout','--detach',head)
        need(git(target,'rev-parse','HEAD').decode().strip()==head,'wrong source head')
    need(git(engine,'rev-parse','HEAD^{tree}').decode().strip()==TREE,'wrong engine tree')
    git(engine,'-c','protocol.file.allow=never','submodule','update','--init','--recursive','--depth=1')
    need(git(engine/'RobustToolbox','rev-parse','HEAD').decode().strip()==ROBUST,'wrong Robust')
    source=root/'source'; check(); source.mkdir(); source_rows={}; proof=[]
    export(engine,'',source,source_rows,proof)
    before=dict(source_rows)
    # Apply only the authenticated patch in the Git checkout, then copy exactly its
    # changed regular paths over the clean, Git-authenticated recursive export.
    cmd([sys.executable,'-B','tools/civ13-provenance/prepare-robust.py'],engine)
    changed=git(engine/'RobustToolbox','diff','--name-only','-z','HEAD').split(b'\0')
    for rawname in changed:
        if not rawname: continue
        check(); name=path_name(rawname.decode()); rel='RobustToolbox/'+name
        need(rel in before,'transform adds undeclared source')
        raw=(engine/rel).read_bytes(); check(); (source/rel).write_bytes(raw); check()
        source_rows[rel]=hashlib.sha256(raw).hexdigest()
    patch=(source/'tools/civ13-provenance/robust-auth.patch').read_bytes()
    # Isolate the source global.json resolver from every other installed SDK.
    # SDK10.0.401 is still selected by latestFeature when no other SDK exists here.
    from run import INPUTS
    game_inputs={}
    for name,want in INPUTS.items():
        check(); raw=git(game,'show',GAME+':'+name)
        need(hashlib.sha256(raw).hexdigest()==want,'production input differs')
        game_inputs[name]=raw.hex()
    archive=root/'sdk.tar.gz'; digest=hashlib.sha512(); size=0
    check()
    with urllib.request.urlopen(SDK_URL,timeout=1) as response:
        need(response.geturl()==SDK_URL,'SDK redirect differs')
        check()
        with archive.open('xb') as out:
            while True:
                check(); raw=response.read(1024**2); check()
                if not raw: break
                size+=len(raw); need(size<=512*1024**2,'SDK archive bound')
                digest.update(raw); check(); out.write(raw)
    need(digest.hexdigest()==SDK_SHA512,'SDK official checksum differs')
    check(); sdk=root/'sdk'; sdk.mkdir()
    with tarfile.open(archive,mode='r|gz') as tar: extract(tar,sdk,check)
    sdk_rows={}
    for path in sorted(sdk.rglob('*')):
        check()
        if path.is_dir(): continue
        need(path.is_file() and not path.is_symlink(),'SDK unexpected link')
        sdk_rows[path.relative_to(sdk).as_posix()]=hashlib.sha256(path.read_bytes()).hexdigest(); check()
    result={'engine':ENGINE,'tree':TREE,'robust':ROBUST,'game':GAME,'git_proof':proof,
            'clean_source_files':before,'source_files':source_rows,
            'robust_transform_sha256':hashlib.sha256(patch).hexdigest(),
            'sdk_files':sdk_rows,'sdk_url':SDK_URL,'sdk_sha512':SDK_SHA512,
            'inputs':game_inputs,'commands':command_rows}
    check()
    with (root/'preparation.json').open('xb') as out:
        out.write(canonical(result)); out.flush(); check(); os.fsync(out.fileno())
    check()


if __name__=='__main__': main()
