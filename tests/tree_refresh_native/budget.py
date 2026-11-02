"""Bounded live metadata census of generated fixture diagnostics.

No file contents are read during measurement. A full bounded scandir census runs
at most twice a second, excluding immutable inputs and declared resource files.
The scan's own duration/counts are retained; this is sampled, not a disk quota.
"""
import json,os,stat,time
from pathlib import Path
from protocol import LIMITS,require

class EvidenceBudget:
    def __init__(self,stage,output,input_files,binary=None,binary_files=None,now=time.monotonic):
        self.output=Path(output);self.now=now;self.last=-1e30;self.records=0;self.stream_bytes=0
        self.state_cap=LIMITS['evidence_bytes'];self.artifact_cap=1024**3;self.generated={}
        self.roots=[('stage',Path(stage),input_files),('output',self.output,{})]
        if binary is not None:self.roots.append(('bin',Path(binary),binary_files or {}))
        self.last_row=None
    def record(self,row):
        raw=(json.dumps(row,separators=(',',':'))+'\n').encode()
        require(self.records<400 and len(raw)<=16384 and self.stream_bytes+len(raw)<=1024**2,'Evidence census stream bound')
        with (self.output/'evidence-budget.jsonl').open('ab') as f:require(f.write(raw)==len(raw),'Evidence census append failed')
        self.records+=1;self.stream_bytes+=len(raw);self.last_row=row
    def check(self,force=False):
        if not force and self.now()-self.last<.5:return
        began=self.now();self.last=began;row=dict(entries=0,files=0,state_bytes=0,artifact_bytes=0,paths=[]);generated={}
        try:
            for label,root,baseline in self.roots:
                pending=[(root,0)]
                while pending:
                    directory,depth=pending.pop();require(depth<=16,'Evidence census directory depth')
                    with os.scandir(directory) as entries:
                        for entry in entries:
                            row['entries']+=1;require(row['entries']<=8192,'Evidence census entry bound')
                            info=entry.stat(follow_symlinks=False)
                            require(not stat.S_ISLNK(info.st_mode) and not (getattr(info,'st_file_attributes',0)&0x400),'Evidence census reparse point')
                            path=Path(entry.path);rel=path.relative_to(root).as_posix()
                            if entry.is_dir(follow_symlinks=False):pending.append((path,depth+1));continue
                            require(entry.is_file(follow_symlinks=False),'Nonregular generated evidence')
                            if rel in baseline:
                                require(info.st_size==baseline[rel]['bytes'],'Immutable input size changed: '+label+'/'+rel);continue
                            row['files']+=1;require(row['files']<=1024,'Generated evidence file-count bound')
                            # Exact compiled artifacts, plus owned-profile BYOND
                            # resource caches, have a separate aggregate ceiling.
                            resource=(label=='stage' and rel in ('tree_refresh.dmb','tree_refresh.rsc')) or (label=='output' and 'environment' in path.relative_to(root).parts and path.suffix.lower() in ('.dmb','.rsc'))
                            if resource:row['artifact_bytes']+=info.st_size;continue
                            key=label+'/'+rel;generated[key]=path;row['state_bytes']+=info.st_size
                            if len(row['paths'])<32:row['paths'].append(dict(path=key,bytes=info.st_size))
            self.generated=generated
            require(row['state_bytes']<=self.state_cap,'All generated native diagnostics/state exceed 16 MiB')
            require(row['artifact_bytes']<=self.artifact_cap,'Compiled/profile resources exceed 1 GiB')
            row['scan_ms']=(self.now()-began)*1000
            appended_bytes=len((json.dumps(row,separators=(',',':'))+'\n').encode())
            require(row['state_bytes']+appended_bytes<=self.state_cap,'Evidence census append exceeds combined state cap')
        except BaseException as error:
            self.generated.update(generated);row['error']=str(error);row['scan_ms']=(self.now()-began)*1000;self.record(row);raise
        self.record(row)
