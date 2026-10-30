"""Compare all 225 authored DMM cells with the original checked-in map."""
import hashlib
from pathlib import Path
import re
import unittest

HERE=Path(__file__).resolve().parent


def parse(path):
    raw=path.read_text(encoding='utf-8-sig')
    defs={}
    for match in re.finditer(r'^"([^"\n]+)"\s*=\s*\(',raw,re.M):
        pos=match.end();start=pos;depth=1;quote=None;escape=False
        while depth:
            ch=raw[pos];pos+=1
            if escape:escape=False;continue
            if quote:
                if ch=='\\':escape=True
                elif ch==quote:quote=None
                continue
            if ch in ('"',"'"):quote=ch
            elif ch=='(':depth+=1
            elif ch==')':depth-=1
        defs[match[1]]=raw[start:pos-1]
    size={len(k) for k in defs}
    if len(size)!=1:raise ValueError('Invalid DMM keys')
    size=size.pop();grid={}
    for match in re.finditer(r'^\((\d+),(\d+),(\d+)\)\s*=\s*\{"\s*\n(.*?)\n"\}',raw,re.M|re.S):
        x0,y0,z=map(int,match.group(1,2,3));rows=match[4].splitlines()
        for i,row in enumerate(rows):
            if len(row)%size:raise ValueError('Invalid DMM row')
            for j in range(len(row)//size):
                key=row[j*size:(j+1)*size]
                if key not in defs:raise ValueError('Missing DMM definition')
                coord=x0+j,y0+len(rows)-1-i,z
                if coord in grid:raise ValueError('Overlapping DMM blocks')
                grid[coord]=defs[key]
    return grid


class AuthoredMap(unittest.TestCase):
    def test_every_cell_and_direction_reproduces_original(self):
        original=HERE/'authored-little-creek.dmm'
        crop=HERE/'changed-source/filming/bakery.dmm'
        self.assertEqual(hashlib.sha256(original.read_bytes()).hexdigest(),'7d67c4bc869859bcfdaf549a7922497517cd573556731d43365570bf85961dd5')
        before,after=parse(original),parse(crop)
        self.assertEqual(len(after),7200)
        for x in range(1,97):
            for y in range(90,165):
                self.assertEqual(before[x,y,2],after[x,y-89,1],(x,y))
        for x,y in [(85,6),(74,58)]:
            self.assertIn('/obj/structure/simple_door/key_door/anyone/wood',after[x,y,1])
        for x in range(80,88):
            self.assertNotIn('/turf/wall',after[x,54,1],x)
            self.assertNotIn('/obj/structure/',after[x,54,1],x)


if __name__=='__main__':unittest.main()
