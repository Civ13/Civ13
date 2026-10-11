"""Validate required compiled sprite defaults against real DMI frames."""
import json,re,struct,zlib
from pathlib import Path

def dmi(path):
    data=path.read_bytes(); assert data[:8]==b'\x89PNG\r\n\x1a\n'
    offset=8; description=None
    while offset<len(data):
        size,kind=struct.unpack('>I4s',data[offset:offset+8]); chunk=data[offset+8:offset+8+size];offset+=size+12
        if kind==b'zTXt' and chunk.startswith(b'Description\0\0'):
            description=zlib.decompress(chunk[len(b'Description\0\0'):]).decode()
    if description is None: raise ValueError(f'Missing DMI description: {path}')
    w=int(re.search(r'\bwidth\s*=\s*(\d+)',description)[1]);h=int(re.search(r'\bheight\s*=\s*(\d+)',description)[1])
    states={};first=0
    for part in re.split(r'^state\s*=\s*',description,flags=re.M)[1:]:
        name=re.match(r'"(.*)"',part)[1]
        dirs=int(re.search(r'\bdirs\s*=\s*(\d+)',part)[1]);frames=int(re.search(r'\bframes\s*=\s*(\d+)',part)[1])
        if dirs not in (1,4,8) or frames<1:raise ValueError('Invalid DMI frame layout')
        states[name]=(first,dirs,frames);first+=dirs*frames
    return w,h,states

def validate(root, rows):
    from PIL import Image
    required=json.loads((root/'tests/sprites/required-types.json').read_text())
    by_type={r['type']:r for r in rows}; previews=[]
    for t in required:
        r=by_type[t]
        if not r['valid']:raise ValueError(f'Unresolved compiled sprite: {t}')
        path=root/r['icon']; w,h,states=dmi(path)
        first,dirs,frames=states[r['state']]
        sheet=Image.open(path).convert('RGBA');cols=sheet.width//w
        for n in range(first,first+dirs*frames):
            frame=sheet.crop(((n%cols)*w,(n//cols)*h,(n%cols+1)*w,(n//cols+1)*h))
            if frame.getbbox() is None:raise ValueError(f'Transparent sprite frame: {t}, {n}')
        previews.append((r['state'],sheet.crop(((first%cols)*w,(first//cols)*h,(first%cols+1)*w,(first//cols+1)*h))))
    print(f'PASS: {len(required)} required inherited defaults, DMI directions/frames and nonempty pixels')
    return previews

if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('inventory',type=Path);args=parser.parse_args()
    validate(Path(__file__).resolve().parents[2],json.loads(args.inventory.read_text()))
