"""Post-cleanup Linux encoding using already-installed, hash-pinned FFmpeg.

Not invoked on the Windows capture runner. No downloads or synthetic frames.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time

PINS = {'/usr/bin/ffmpeg':'e8a8d46f5225f3062cec7c07fb145d58ae73c603cb740dcd5bad34bfb54e455a',
        '/usr/bin/ffprobe':'cefc5f81c0b18429cdbf8fa5a89e1e9c759235e10f93f9b329ff1b2fdff26f46'}
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def require(value, message):
    if not value: raise RuntimeError(message)

def validate(root, expected_head):
    root=Path(root)
    def read(name,cap):
        p=root/name
        require(p.is_file() and not p.is_symlink() and p.stat().st_size<=cap,'Invalid '+name)
        return json.loads(p.read_text())
    receipt=read('receipt.json',65536); manifest=read('recording.json',32768)
    require(receipt['head']==expected_head and receipt['status']=='PASS_NATIVE_CIV13_FLAX_A_FRAMES','Scene/head not accepted')
    for name in ('capture.py','run_scene.py','recording.py','encode_local.py','viewport_border.py','receipt_persistence.py'):
        require(receipt['execution_source_sha256'].get(name)==sha(Path(__file__).with_name(name)), 'Executed source does not match reviewed encoder tooling')
    require(receipt['engine']=='516.1688' and receipt['scene_revision']=='9683866a89d2bdc12f8dc7d25444e350583c5483','Source/engine mismatch')
    require(receipt['directx_setup']['status']=='PASSED','Setup failed')
    require({c['role'] for c in receipt['cleanup']}=={'compiler','server','client'},'Cleanup role mismatch')
    for c in receipt['cleanup']+[receipt['directx_setup']['cleanup']]:
        require(c['all_exited'] and not c.get('errors') and not c.get('error_count') and all(c['primitives'].values()),'Cleanup incomplete')
        require(len(c['exits'])==1 and all(c['exits'][0][k] for k in ('wait_signaled','exit_code_read','thread_handle_closed','process_handle_closed')),'Cleanup primitives incomplete')
    require(manifest['status']=='COMPLETE_GUARDED_FRAMES_PENDING_SCENE_AND_CLEANUP' and manifest['target_fps']==4 and manifest['frame_count']==80,'Recording incomplete')
    viewport=root/'filming-viewport.txt'
    require(viewport.is_file() and not viewport.is_symlink() and viewport.stat().st_size<=16384,'Missing/bounded viewport evidence')
    evidence=receipt.get('viewport_evidence',{})
    require(sha(viewport)==evidence.get('sha256'),'Viewport evidence hash mismatch')
    rows=[json.loads(line) for line in viewport.read_text(encoding='utf-8').splitlines() if line]
    require(1<=len(rows)<=96 and len(rows)==evidence.get('rows') and all(isinstance(r,list) and len(r)==17 for r in rows),'Viewport evidence schema mismatch')
    require(rows[0][1]=='client camera ready' and rows[-1][1]=='take complete','Incomplete viewport evidence')
    require(receipt.get('persistence_complete') is True, 'Incomplete receipt persistence')
    from receipt_persistence import EVIDENCE, REQUIRED
    retained=receipt.get('retained_evidence',{})
    require(type(retained) is dict and set(REQUIRED)<=set(retained)<=set(EVIDENCE), 'Required retained evidence missing')
    for name, descriptor in retained.items():
        path=root/name
        require(type(descriptor) is dict and path.is_file() and not path.is_symlink()
                and path.stat().st_size==descriptor.get('bytes')<=EVIDENCE[name]
                and sha(path)==descriptor.get('sha256'), 'Retained evidence hash/size mismatch')
    require(receipt.get('native_checks')==dict(retained_file='filming-checks.txt',**retained['filming-checks.txt']), 'Checks descriptor mismatch')
    require(read('source-receipt.json',65536)==receipt.get('source')
            and read('filming-take.json',65536)==receipt.get('take'), 'Retained scene/source binding mismatch')
    frames=manifest['frames'];require(len(frames)==80,'Frame count mismatch')
    require(manifest.get('border_policy')==dict(strip_pixels=32,pixels_per_strip=15360,reject_at_black_pixels=14592,order=['top','bottom','left','right']),'Border policy missing')
    total=0;identity=None
    for i,f in enumerate(frames):
        require(f['index']==i and f['name']==f'recording-{i:03d}.png','Frame order/name mismatch')
        require(f['width']==f['height']==480 and f['guard_checkpoints']==2,'Frame guard mismatch')
        counts=f.get('border_black_counts')
        require(isinstance(counts,list) and len(counts)==4 and all(type(v) is int and 0<=v<14592 for v in counts),'Frame border evidence missing')
        current=(f['pid'],f['creation_filetime'],f['hwnd'])
        if identity is None:identity=current
        require(current==identity,'Frame owner changed')
        begin,end=f['begin_seconds'],f['end_seconds']
        require(type(begin) in (int,float) and type(end) in (int,float) and i/4-.000001<=begin<=end<=i/4+.200001,'Frame timing mismatch')
        if i: require(end>frames[i-1]['end_seconds'],'Non-increasing capture time')
        p=root/f['name'];require(p.is_file() and not p.is_symlink() and p.stat().st_size==f['bytes']<=1024**2,'Frame size mismatch')
        require(sha(p)==f['sha256'],'Frame hash mismatch');total+=f['bytes']
    require(total<=15*1024**2 and len({f['sha256'] for f in frames})>=2,'Payload/unchanged frames rejected')
    return receipt,manifest

def bounded_run(argv,cwd,seconds,logname):
    import resource
    def limits():
        resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
        resource.setrlimit(resource.RLIMIT_CPU,(25,25))
        resource.setrlimit(resource.RLIMIT_FSIZE,(4*1024**2,4*1024**2))
        resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    log=Path(cwd)/logname;started=time.monotonic()
    with log.open('xb') as stream:
        p=subprocess.Popen(argv,cwd=cwd,stdin=subprocess.DEVNULL,stdout=stream,stderr=stream,
                           env={'PATH':'/usr/bin:/bin','LC_ALL':'C'},start_new_session=True,preexec_fn=limits)
        try:
            while p.poll() is None:
                require(time.monotonic()-started<seconds and log.stat().st_size<=65536,'Encoding time/log cap')
                time.sleep(.02)
            require(p.returncode==0 and log.stat().st_size<=65536,'Encoder/probe failed')
        finally:
            if p.poll() is None: os.killpg(p.pid,signal.SIGKILL)
            p.wait(timeout=5)
    return log.read_text()

def encode(root, output, expected_head):
    root,output=Path(root).resolve(),Path(output).absolute()
    require(os.name=='posix' and not os.environ.get('GITHUB_ACTIONS'),'Local post-run encoding only')
    require(not output.exists() and not output.is_symlink() and not output.with_suffix('.encoding.json').exists() and output.suffix=='.mp4','Fresh MP4 and receipt required')
    for executable,pin in PINS.items():require(sha(executable)==pin,'Installed encoder hash changed; review required')
    receipt,manifest=validate(root,expected_head)
    with tempfile.TemporaryDirectory(prefix='native-bakery-encode-') as temp:
        work=Path(temp);lines=['ffconcat version 1.0']
        for i,f in enumerate(manifest['frames']):
            shutil.copyfile(root/f['name'],work/f['name'])
            require(sha(work/f['name'])==f['sha256'],'Frame changed during copy')
            lines.append("file '"+f['name']+"'")
            if i<79:lines.append('duration %.6f'%(manifest['frames'][i+1]['end_seconds']-f['end_seconds']))
        (work/'frames.ffconcat').write_text('\n'.join(lines)+'\n')
        bounded_run(['/usr/bin/ffmpeg','-nostdin','-hide_banner','-v','error','-n',
            '-protocol_whitelist','file','-f','concat','-safe','1','-threads','1','-i','frames.ffconcat',
            '-map','0:v:0','-an','-sn','-dn','-fps_mode','passthrough','-frames:v','80',
            '-c:v','libx264','-threads','1','-filter_threads','1','-preset','veryfast',
            '-crf','20','-pix_fmt','yuv420p','-map_metadata','-1','-movflags','+faststart','clip.mp4'],work,30,'encoder.log')
        probe=json.loads(bounded_run(['/usr/bin/ffprobe','-v','error','-protocol_whitelist','file',
            '-threads','1','-count_frames','-show_streams','-show_format','-of','json','clip.mp4'],work,10,'probe.json'))
        streams=probe['streams'];require(len(streams)==1,'Unexpected media streams')
        v=streams[0];require(v['codec_name']=='h264' and v['width']==v['height']==480 and int(v['nb_read_frames'])==80,'Encoded frame mismatch')
        require(19.5<=float(probe['format']['duration'])<=20.5,'Encoded duration mismatch')
        clip=work/'clip.mp4';require(0<clip.stat().st_size<=4*1024**2,'MP4 cap')
        with output.open('xb') as stream:stream.write(clip.read_bytes())
        report=dict(status='ENCODED_FROM_VERIFIED_NATIVE_FRAMES',head=expected_head,
            input_manifest_sha256=sha(root/'recording.json'),mp4_sha256=sha(output),
            frames=80,width=480,height=480,actual_duration=probe['format']['duration'],
            encoding=PINS,timing='Actual capture end-time deltas; concat timestamps quantized by PNG demuxer; no interpolation or duplicated frames',
            caption='Chapter 1 of 3: supplied harvested flax is bound and begins freshwater retting. One of three ten-second stages completes; the worker pauses the unfinished soak. Later chapters use independent genuinely produced batches with waiting omitted. All chapters receive readable stage captions and disclosed reading holds before delivery.')
        with output.with_suffix('.encoding.json').open('x') as stream:json.dump(report,stream,indent=2)
        return report

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('root');parser.add_argument('output');parser.add_argument('--expected-head',required=True)
    args=parser.parse_args();print(json.dumps(encode(args.root,args.output,args.expected_head),indent=2))
