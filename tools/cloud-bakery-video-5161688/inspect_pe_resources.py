"""Parse bounded PE resources without loading or executing the inspected binary."""
import hashlib,json,re,struct,sys
from pathlib import Path

def resources(p):
 data=p.read_bytes();u16=lambda n:struct.unpack_from('<H',data,n)[0];u32=lambda n:struct.unpack_from('<I',data,n)[0]
 assert data[:2]==b'MZ';pe=u32(0x3c);assert data[pe:pe+4]==b'PE\0\0';n=u16(pe+6);opt=pe+24;optsize=u16(pe+20);assert u16(opt)==0x10b and n<=32
 secs=[]
 for i in range(n):
  at=opt+optsize+40*i;secs.append((u32(at+12),u32(at+16),u32(at+20)))
 def offset(rva,size=1):
  for va,rawsize,raw in secs:
   if va<=rva and rva+size<=va+rawsize and raw+rva-va+size<=len(data):return raw+rva-va
  raise ValueError('unbacked_resource')
 rva,size=u32(opt+96+16),u32(opt+100+16);base=offset(rva,size);assert 0<size<=8*1024**2
 def rname(x):
  if not (x&0x80000000):return str(x)
  pos=base+(x&0x7fffffff);length=u16(pos);assert length<=128 and pos+2+2*length<=base+size
  return data[pos+2:pos+2+2*length].decode('utf-16le')
 rows=[];vis=set()
 def walk(rel,parts,depth):
  assert depth<=3 and rel not in vis;vis.add(rel);pos=base+rel;assert base<=pos and pos+16<=base+size
  count=u16(pos+12)+u16(pos+14);assert count<=4096 and pos+16+8*count<=base+size
  for i in range(count):
   key,target=struct.unpack_from('<II',data,pos+16+8*i);name=rname(key)
   if target&0x80000000:walk(target&0x7fffffff,parts+[name],depth+1)
   else:
    entry=base+target;assert entry+16<=base+size;data_rva,length=struct.unpack_from('<II',data,entry);assert length<=4*1024**2
    at=offset(data_rva,length);raw=data[at:at+length];rows.append((parts+[name],raw))
 walk(0,[],0)
 return rows

if __name__=='__main__':
 path=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(exist_ok=False)
 results=[]
 for parts,raw in resources(path):
  pathstr='/'.join(parts);text=''
  for encoding in ('utf-8','utf-16le'):
   text+=' '+raw[:200000].decode(encoding,errors='ignore').lower()
  interesting=any(x in text for x in ('{\\rtf','license agreement','licence agreement','end-user license','software license terms'))
  row={'resource':pathstr,'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'interesting':interesting}
  if interesting:
   name='resource-'+re.sub('[^A-Za-z0-9_-]','_',pathstr)+'.bin';(out/name).write_bytes(raw);row['local_file']=name
  results.append(row)
 (out/'inventory.json').write_text(json.dumps(results,indent=2)+'\n',encoding='utf-8')
 print(json.dumps([r for r in results if r['interesting']],indent=2));print('resource_count',len(results))
