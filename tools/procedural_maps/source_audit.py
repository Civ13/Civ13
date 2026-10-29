"""Restricted static DMM audit for the pinned classic Nomads map; no DM evaluation."""
import hashlib
import json
import re
import struct
from collections import Counter
from pathlib import Path
from .repo_source import read_pinned



def parse_classic(text):
    definitions=dict(re.findall(r'^"([A-Za-z]+)" = \((.*)\)\s*$',text,re.M))
    if not definitions:raise ValueError("no definitions")
    sizes={len(k) for k in definitions}
    if len(sizes)!=1:raise ValueError("mixed tile-key lengths")
    keylen=sizes.pop(); cells={}; dims=[]
    for raw_z,grid in re.findall(r'^\(1,1,(\d+)\) = \{"\r?\n(.*?)\r?\n"\}',text,re.M|re.S):
        rows=grid.splitlines();widths={len(row)//keylen for row in rows}
        if len(widths)!=1 or any(len(row)%keylen for row in rows):raise ValueError("ragged grid")
        width=widths.pop();height=len(rows);z=int(raw_z);dims.append([width,height,z])
        for j,row in enumerate(rows):
            for x in range(width):
                key=row[x*keylen:(x+1)*keylen]
                if key not in definitions:raise ValueError("unknown key")
                p=(x+1,height-j,z)
                if p in cells:raise ValueError("overlapping block")
                cells[p]=definitions[key]
    if len(dims)!=2 or {z for w,h,z in dims}!={1,2}:raise ValueError("expected two classic blocks")
    if len({(w,h) for w,h,z in dims})!=1:raise ValueError("unequal layer sizes")
    return definitions,cells,dims


def audit(catalog_root=None,reference_image=None):
    raw=read_pinned("maps/nomads/nomads.dmm","b2ec0cc75ae77fc6ee163840ced4d5aa57f14cc7",catalog_root)
    definitions,cells,dims=parse_classic(raw.decode("utf-8"))
    by_z={}
    for z in [1,2]:
        counts=Counter();spawn=[];areas=Counter();ladder=[]
        for p,atoms in cells.items():
            if p[2]!=z:continue
            turfs=re.findall(r'(?:^|,)\s*(/turf/[^,{)\s]+)',atoms)
            if len(turfs)!=1:raise ValueError("not exactly one turf")
            counts[turfs[0]]+=1
            for a in re.findall(r'(?:^|,)\s*(/area/[^,{)\s]+)',atoms):areas[a]+=1
            if re.search(r'name\s*=\s*"JoinLateCiv"',atoms):spawn.append(list(p))
            if "/obj/structure/multiz/ladder" in atoms:ladder.append(list(p))
        by_z[str(z)]={"cells":sum(counts.values()),"turf_counts":dict(sorted(counts.items())),
                      "area_counts":dict(sorted(areas.items())),"joinlateciv_count":len(spawn),
                      "joinlateciv_coordinates_native":spawn,"ladder_coordinates_native":ladder}
    reference={"status":"NOT_SUPPLIED","expected_sha256":"7965d467827150fa32fec8bb86cdf88ebe24b143cd0a2adadd5e47d747939226",
               "expected_git_blob":"ff99de1bd91db6125eec71878dbf97d9e28176cd"}
    if reference_image is not None:
        png=Path(reference_image).read_bytes()
        if png[:8]!=b'\x89PNG\r\n\x1a\n':raise ValueError("PNG signature")
        width,height=struct.unpack(">II",png[16:24]);image_sha=hashlib.sha256(png).hexdigest()
        image_blob=hashlib.sha1(b"blob "+str(len(png)).encode()+b"\0"+png).hexdigest()
        if image_sha!=reference['expected_sha256'] or image_blob!=reference['expected_git_blob'] or (width,height)!=(1240,1800):
            raise ValueError("REFERENCE_IMAGE_MISMATCH")
        reference.update(status="BYTE_IDENTITY_VERIFIED_ONLY",width=width,height=height,sha256=image_sha,git_blob=image_blob)
    assert sorted(dims)==[[155,225,1],[155,225,2]]
    assert by_z["2"]["joinlateciv_count"]==18 and by_z["1"]["joinlateciv_count"]==0
    return {"scope":"static source and image identity; no gameplay, hydrology annotation, or render equality",
            "civ13_commit":"067478b82c7ad9f1b83759a221e6f22080ba865a",
            "map_git_blob":"b2ec0cc75ae77fc6ee163840ced4d5aa57f14cc7",
            "dimensions_by_z":sorted(dims),"tile_key_count":len(definitions),"levels":by_z,
            "reference":reference,
            "layer_inference":"z1 has cave areas/underground turfs; z2 has Nomads forest areas and all 18 JoinLateCiv markers. Source supports underground z1/surface z2."}


if __name__=="__main__":print(json.dumps(audit(),indent=2))
