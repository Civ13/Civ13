"""Held synthetic encoder proof; never use as evidence of gameplay cadence."""
import json
import re
import time
from pathlib import Path

import acquire
import guard_config
from directx_official_setup import binding, check_setup_sockets, cleanup_diagnostic, require
from verify_portable_tree import verify

ENCODER_PROOF_ENABLED = True
ENCODER_SHA = '8ae725e6b560339faf248371b97e14c9c23f63842a4a89a6349dc88b59503ed9'
PROBE_SHA = '757fe225d0f11079e43f52629ed761d52754aeb9bd66d03418e25858f93699cf'
NAME = 'ffmpeg-n9.0.2-39-g7adfbe40dc-win64-gpl-shared-9.0'
WORK_SECONDS = 30
CLEANUP_SECONDS = 5


def check_output_budget(output, clip, budget):
    budget()
    if clip.exists():
        require(acquire._plain(clip).st_size <= 16 * 1024 ** 2, 'encoder_output_limit')
    for log in output.glob('*.log'):
        require(acquire._plain(log).st_size <= 1024 * 1024, 'encoder_log_limit')


def run(root):
    require(ENCODER_PROOF_ENABLED is True, 'encoder_proof_disabled')
    context = binding()
    root = Path(root).absolute()
    acquire._plain_ancestors(root)
    portable = root / 'portable-ffmpeg'
    manifest = Path(__file__).with_name('ffmpeg-btbn-file-manifest.json')
    output = root / 'encoder-evidence'
    require(not output.exists() and not output.is_symlink(), 'fresh_encoder_output_required')
    output.mkdir()
    ffmpeg, ffprobe = portable / NAME / 'bin' / 'ffmpeg.exe', portable / NAME / 'bin' / 'ffprobe.exe'
    guard_config.BINARIES.update({'ffmpeg.exe': ENCODER_SHA, 'ffprobe.exe': PROBE_SHA})
    clip = output / 'encoder-proof.mp4'
    operations = [
        ('encode', [str(ffmpeg), '-nostdin', '-v', 'error', '-f', 'lavfi', '-i',
                    'testsrc2=size=480x480:rate=20', '-frames:v', '80', '-threads', '1',
                    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-an', '-n', str(clip)]),
        ('probe', [str(ffprobe), '-v', 'error', '-protocol_whitelist', 'file,pipe',
                   '-count_frames', '-select_streams', 'v:0', '-show_entries',
                   'stream=width,height,avg_frame_rate,nb_read_frames:format=duration',
                   '-of', 'json', str(clip)]),
        ('decode', [str(ffmpeg), '-nostdin', '-v', 'error', '-protocol_whitelist', 'file,pipe',
                    '-i', str(clip), '-f', 'null', '-']),
    ]
    result = {'schema': 1, 'binding': context, 'status': 'FAILED', 'synthetic_only': True,
              'gameplay_or_native_cadence_verified': False, 'phases': []}
    started = time.monotonic()
    def budget():
        require(time.monotonic() - started < WORK_SECONDS, 'encoder_work_timeout')
    try:
        for phase, command in operations:
            verify(portable, manifest, budget)
            from windows import Adapter
            adapter = Adapter()
            process = None
            row = {'phase': phase, 'status': 'FAILED'}
            result['phases'].append(row)
            try:
                adapter.preflight(guard_config.LIMITS)
                require(adapter.free() >= 2 * 1024 ** 3, 'encoder_free_memory_limit')
                adapter.open(creation_guard=budget)
                process = adapter.launch(command, Path(command[0]).parent,
                                         output, phase, creation_guard=budget)
                while not adapter.exited(process):
                    budget()
                    require(adapter.accounting().total == 1, 'encoder_child_process_rejected')
                    require(adapter.memory(process.process) <= guard_config.LIMITS['process_private_bytes'],
                            'encoder_memory_limit')
                    check_setup_sockets(adapter, process, row)
                    check_output_budget(output, clip, budget)
                    adapter.pause(0.05)
                check_output_budget(output, clip, budget)
                done = adapter.finish(process)
                require(done['exit_code'] == 0 and done['total_processes'] == 1 and
                        done['active_processes'] == 0, 'encoder_phase_failed')
                row['exit_code'] = done['exit_code']
                row['status'] = 'PASSED'
            finally:
                row['cleanup'] = cleanup_diagnostic(adapter.cleanup(process, CLEANUP_SECONDS))
                require(row['cleanup'].get('all_exited') is True, 'encoder_cleanup_unconfirmed')
        metadata = json.loads(acquire._read(output / 'probe.stdout.log', 1024 * 1024))
        streams = metadata.get('streams') or []
        require(len(streams) == 1 and streams[0].get('width') == 480 and
                streams[0].get('height') == 480 and streams[0].get('avg_frame_rate') == '20/1' and
                streams[0].get('nb_read_frames') == '80', 'encoder_probe_mismatch')
        duration = float(metadata.get('format', {}).get('duration', 0))
        require(3.95 <= duration <= 4.05, 'encoder_duration_mismatch')
        require(acquire._plain(clip).st_size <= 16 * 1024 ** 2, 'encoder_output_limit')
        result['frames'], result['duration_seconds'] = 80, duration
        result['status'] = 'PASSED'
    except Exception as error:
        code = str(error)
        result['error'] = code if re.fullmatch('[a-z_]{1,80}', code) else 'encoder_failed'
        raise
    finally:
        data = (json.dumps(result, indent=2) + '\n').encode()
        require(len(data) <= 16384, 'encoder_receipt_size_limit')
        with (output / 'encoder-proof-receipt.json').open('xb') as stream:
            stream.write(data)
    return result
