"""Bounded genuine sampling; never synthesize/repeat a missed frame."""
import hashlib
import json
import math
import time
from pathlib import Path
from capture import capture_owned

COUNT, FPS, SIZE = 80, 4, (480, 480)
MAX_LATE = 0.20
MAX_FRAME_BYTES = 1024 * 1024
MAX_FRAME_TOTAL = 15 * 1024 * 1024

def record_frames(adapter, process, output, title, watch, start_sequence,
                  capture=capture_owned, clock=time.monotonic, sleep=time.sleep):
    output = Path(output)
    manifest = output / 'recording.json'
    if manifest.exists() or any(output.glob('recording-*.png')):
        raise RuntimeError('Fresh recording destinations required')
    result = dict(schema=1, status='FAILED_DIAGNOSTIC_ONLY', target_fps=FPS,
                  frame_count=COUNT, playback_seconds=COUNT/FPS,
                  scope='Genuine sampled guest-camera frames; staged actors; no ordinary-player acceptance',
                  frames=[])
    total = 0
    identity = None
    started = clock()
    try:
        for index in range(COUNT):
            due = started + index/FPS
            while clock() < due:
                watch()
                sleep(min(0.02, max(0, due-clock())))
            watch()
            begin = clock()
            result['last_attempt_timing'] = dict(index=index, due_seconds=round(due-started,6),
                begin_seconds=round(begin-started,6), begin_lateness_seconds=round(begin-due,6))
            if begin - due > MAX_LATE:
                raise RuntimeError('Recording cadence missed; no frame duplication')
            name = f'recording-{index:03d}.png'
            c = capture(adapter, process, output/name, title, SIZE)
            end = clock()
            result['last_attempt_timing'].update(end_seconds=round(end-started,6),
                capture_call_seconds=round(end-begin,6), end_lateness_seconds=round(end-due,6))
            stage = c.get('stage_seconds')
            keys = ('native_guards_and_readback','pixel_diagnostics','png_encoding','png_write_fsync')
            if (isinstance(stage,dict) and set(stage)==set(keys)
                    and all(type(stage[k]) in (int,float) and math.isfinite(stage[k]) and 0<=stage[k]<=180 for k in keys)):
                result['last_attempt_timing']['capture_stage_seconds'] = {k:round(stage[k],6) for k in keys}
            watch()
            if end - due > MAX_LATE:
                raise RuntimeError('Recording capture too slow; no frame duplication')
            current = (c['identity']['pid'], c['identity']['creation_filetime'], c['window']['hwnd'])
            if identity is None:
                identity = current
            if (current != identity or c['status'] != 'captured'
                    or (c['width'], c['height']) != SIZE
                    or c['window']['client_rect'] != [0, 0, 480, 480]
                    or c['checkpoints'] != ['immediately_before_bitblt', 'immediately_after_bitblt']):
                raise RuntimeError('Recording identity/guard evidence mismatch')
            path = output/name
            size = path.stat().st_size
            total += size
            if size > MAX_FRAME_BYTES or total > MAX_FRAME_TOTAL:
                path.unlink()
                total -= size
                raise RuntimeError('Recording byte cap exceeded')
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            if digest != c['png_sha256'] or size != c['png_bytes']:
                raise RuntimeError('Recording frame seal mismatch')
            result['frames'].append(dict(index=index, name=name, sha256=digest, bytes=size,
                begin_seconds=round(begin-started,6), end_seconds=round(end-started,6),
                pid=current[0], creation_filetime=current[1], hwnd=current[2],
                guard_checkpoints=2, width=480, height=480))
            if index == 0:
                start_sequence()
        if len({f['sha256'] for f in result['frames']}) < 2:
            raise RuntimeError('Recording contains no observed change')
        result['status'] = 'COMPLETE_GUARDED_FRAMES_PENDING_SCENE_AND_CLEANUP'
        return dict(status=result['status'], frames=COUNT, target_fps=FPS,
                    playback_seconds=COUNT/FPS, total_frame_bytes=total,
                    manifest='recording.json')
    except BaseException as error:
        result['error'] = str(error)[:256]
        raise
    finally:
        result['total_frame_bytes'] = total
        raw = json.dumps(result, indent=2).encode()
        if len(raw) > 32768:
            raise RuntimeError('Recording manifest cap exceeded')
        with manifest.open('xb') as stream:
            stream.write(raw)
