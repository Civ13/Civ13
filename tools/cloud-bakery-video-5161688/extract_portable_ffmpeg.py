"""Verify and unpack pinned FFmpeg data to a fresh task directory; never execute."""
import hashlib,json,stat,zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parent
PINS=ROOT/'package-pins.json'
MANIFEST=ROOT/'ffmpeg-btbn-file-manifest.json'
MANIFEST_SHA='e563f015220d49397a1f80651ef165faca4616d84a6bfa3656f21bf7ddfe7b0e'

def extract(archive,destination,allowed_root,pin,manifest,manifest_sha,check_budget=None):
    check_budget = check_budget or (lambda: None)
    archive=Path(archive).absolute();destination=Path(destination).absolute();allowed_root=Path(allowed_root).absolute()
    if destination.parent!=allowed_root:raise ValueError('destination_outside_task_root')
    for ancestor in (allowed_root,*allowed_root.parents):
        info=ancestor.lstat()
        if ancestor.is_symlink() or getattr(info,'st_file_attributes',0)&0x400 or not ancestor.is_dir():raise ValueError('unsafe_task_ancestor')
    if destination.exists() or destination.is_symlink():raise ValueError('fresh_destination_required')
    if hashlib.sha256(Path(manifest).read_bytes()).hexdigest()!=manifest_sha:raise ValueError('manifest_identity')
    rows=json.loads(Path(manifest).read_text(encoding='utf-8'))
    if type(rows) is not list or len(rows)!=224:raise ValueError('manifest_count')
    expected={r['name']:(r['bytes'],r['sha256']) for r in rows}
    if len(expected)!=len(rows):raise ValueError('manifest_duplicate')
    h=hashlib.sha256()
    with archive.open('rb') as f:
        while True:
            check_budget()
            block=f.read(1024*1024)
            if not block:break
            h.update(block)
    if archive.stat().st_size!=pin['archive_bytes'] or h.hexdigest()!=pin['archive_sha256']:raise ValueError('archive_identity')
    with zipfile.ZipFile(archive) as z:
        infos=z.infolist();seen=set();members={}
        if len(infos)>512 or sum(i.file_size for i in infos)>300*1024**2:raise ValueError('archive_bounds')
        for i in infos:
            check_budget()
            parts=i.filename.rstrip('/').split('/')
            reserved={'CON','PRN','AUX','NUL',*(f'COM{n}' for n in range(1,10)),*(f'LPT{n}' for n in range(1,10))}
            if not all(p and p not in ('.','..') and p.isascii() and '\\' not in p and ':' not in p and not p.endswith(('.', ' ')) and p.split('.')[0].upper() not in reserved for p in parts):raise ValueError('unsafe_member')
            key=i.filename.casefold()
            if key in seen or stat.S_ISLNK((i.external_attr>>16)&0xffff):raise ValueError('duplicate_or_link')
            seen.add(key)
            if i.file_size>128*1024**2 or (i.file_size and (not i.compress_size or i.file_size>500*i.compress_size)):raise ValueError('member_bounds')
            if not i.is_dir():members[i.filename]=i
        if set(members)!=set(expected):raise ValueError('manifest_membership')
        destination.mkdir(parents=False)
        for name,i in members.items():
            check_budget()
            target=destination.joinpath(*name.split('/'))
            target.parent.mkdir(parents=True,exist_ok=True)
            digest=hashlib.sha256();count=0
            with z.open(i) as src,target.open('xb') as out:
                while True:
                    check_budget()
                    block=src.read(1024*1024)
                    if not block:break
                    count+=len(block)
                    if count>expected[name][0]:raise ValueError('member_changed_size')
                    digest.update(block);out.write(block)
            if (count,digest.hexdigest())!=expected[name]:raise ValueError('member_identity')
    return {'members':len(expected),'unpacked_bytes':sum(x[0] for x in expected.values()),'archive_sha256':h.hexdigest(),'executed':False,'runtime_verified':False}

if __name__=='__main__':
    import sys
    pin=json.loads(PINS.read_text(encoding='utf-8'))['ffmpeg']
    print(json.dumps(extract(sys.argv[1],sys.argv[2],sys.argv[3],pin,MANIFEST,MANIFEST_SHA),indent=2))
