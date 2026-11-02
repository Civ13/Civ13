"""Acquire pinned installer as data on a disposable hosted Windows runner.

Never execute the installer. Exact bytes are checked before bounded 7-Zip data
extraction. The complete extracted bin file manifest binds compiler/daemon/client.
"""
import argparse,json,os,subprocess,time,urllib.request
from pathlib import Path
from protocol import digest,require
ROOT=Path(__file__).resolve().parents[2]

def acquire(out, pin):
    require(os.environ.get('RUNNER_ENVIRONMENT')=='github-hosted' and os.environ.get('RUNNER_OS')=='Windows','Hosted Windows data preparation only')
    out=Path(out).resolve();out.mkdir(parents=True,exist_ok=False)
    require(pin['version']=='516.1688','Review pin advance')
    installer=out/'byond-pinned.exe';request=urllib.request.Request(pin['url'],headers={'User-Agent':'Civ13-native-fixture-preparation'})
    began=time.monotonic()
    with urllib.request.urlopen(request,timeout=30) as response,installer.open('wb') as stream:
        total=0
        while True:
            require(time.monotonic()-began<120,'Installer acquisition deadline')
            chunk=response.read(1024*1024)
            if not chunk:break
            total+=len(chunk);require(total<=pin['bytes'],'Installer byte ceiling');stream.write(chunk)
    require(total==pin['bytes'] and digest(installer.read_bytes())==pin['sha256'],'Pinned installer digest/size')
    extracted=out/'extracted';extracted.mkdir()
    # Bounded contents of one already hash-checked known installer; no installation.
    result=subprocess.run([r'C:\Program Files\7-Zip\7z.exe','x',str(installer),'-o'+str(extracted),'-y'],capture_output=True,timeout=90)
    (out/'extract.log').write_bytes(result.stdout+result.stderr);require(result.returncode==0,'Pinned installer data extraction failed')
    candidates=[p for p in extracted.rglob('*') if p.is_file() and p.name.lower()=='dd.exe'];require(len(candidates)==1,'Unique extracted bin directory')
    binary=candidates[0].parent;files={}
    for p in binary.rglob('*'):
        require(not p.is_symlink() and not (getattr(p.lstat(),'st_file_attributes',0)&0x400),'Toolchain reparse point')
        if p.is_file():files[p.relative_to(binary).as_posix()]=dict(bytes=p.stat().st_size,sha256=digest(p.read_bytes()))
    require(sum(x['bytes'] for x in files.values())<=128*1024**2 and len(files)<=256,'Extracted toolchain ceiling')
    hashes={}
    for name in ('dm.exe','dd.exe','dreamseeker.exe'):
        matches=[p for p in binary.iterdir() if p.name.lower()==name];require(len(matches)==1,'Missing unique native binary '+name);hashes[name]=digest(matches[0].read_bytes())
    known=json.loads((ROOT/'tests/tree_refresh_native/toolchain-contract.json').read_text())
    require(all(hashes[k]==known[k] for k in ('dm.exe','dd.exe')),'Existing canonical installed binary allowlist drift')
    manifest=dict(version=pin['version'],installer_sha256=pin['sha256'],installer_bytes=pin['bytes'],files=files,binary_hashes=hashes,integrity_scope=pin['integritySource'])
    (out/'toolchain.json').write_text(json.dumps(manifest,sort_keys=True,indent=2)+'\n');(out/'bin-path.txt').write_text(str(binary));return manifest

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args();print(json.dumps(acquire(a.output,json.loads((ROOT/'tools/byond/version.json').read_text()))))
