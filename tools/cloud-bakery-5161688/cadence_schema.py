"""V2 deferred native samples: configuration/timing/fact schema, not scene acceptance.

No capture APIs, subprocesses, downloads or dependencies. A validated manifest is
still pending final source, scene, persistence, workflow and owned cleanup proof.
"""
import hashlib
import math
from pathlib import Path
import re
import struct
import zlib

STATUS = 'VALIDATED_PENDING_SCENE_CLEANUP'
WIDTH = HEIGHT = 480
RAW_FRAME_BYTES = 691200
MAX_RAW_BYTES = 13824000
REJECTION_TIMING = 'Native safety immediate per sample; all-frame content validation deferred <=one-second acquisition plus <=0.5s configuration handshake; no acceptance before scene/cleanup/terminal proof'
CHECKPOINTS = ['immediately_before_bitblt', 'immediately_after_bitblt']
NATIVE_CLEANUP = 'owned GDI/input handles released; thread DPI restored'
HEX64 = re.compile(r'[0-9a-f]{64}\Z')


def require(ok, message):
    if not ok:
        raise ValueError(message)


def finite(value):
    return type(value) in (int,float) and math.isfinite(value)


def integer(value, low, high):
    return type(value) is int and low <= value <= high


def validate_config(config):
    require(type(config) is dict and set(config)=={'world_fps','client_fps','world_tick_lag','client_tick_lag','effective_fps','same_admitted_client'}, 'Cadence configuration schema')
    require(config['same_admitted_client'] is True, 'Cadence client binding missing')
    for key in ('world_fps','client_fps','world_tick_lag','client_tick_lag','effective_fps'):
        require(finite(config[key]), 'Nonfinite cadence configuration')
    world,client=config['world_fps'],config['client_fps']
    require(1 <= world <= 120 and 0 <= client <= 120, 'Cadence configuration bounds')
    effective=client if client else world
    require(1 <= effective <= 120 and math.isclose(config['effective_fps'],effective,rel_tol=1e-9,abs_tol=1e-9), 'Effective fps does not match inherited/explicit configuration')
    require(math.isclose(config['world_tick_lag'],10/world,rel_tol=1e-6,abs_tol=1e-6), 'World fps/tick_lag mismatch')
    require((client==0 and config['client_tick_lag']==0) or (client>0 and math.isclose(config['client_tick_lag'],10/client,rel_tol=1e-6,abs_tol=1e-6)), 'Client fps/tick_lag mismatch')
    return effective


def validate_owner(owner):
    require(type(owner) is dict and set(owner)=={'pid','creation_filetime','hwnd'}, 'Owner schema')
    for key in ('pid','creation_filetime','hwnd'):
        require(integer(owner[key],1,2**64-1), 'Invalid owner identity')


def validate_pixel_facts(f):
    keys={'pixel_count','nonzero_pixel_count','channel_min','channel_max','entirely_black','flat_rgb','distinct_rgb_capped_at_256','quantized_color_count','channel_range','middle_pixel_fraction','dominant_quantized_fraction','adjacent_quantized_changes','semantic_appearance_verified'}
    require(type(f) is dict and set(f)==keys, 'Pixel facts schema')
    require(type(f['pixel_count']) is int and f['pixel_count']==230400, 'Pixel coverage mismatch')
    require(integer(f['nonzero_pixel_count'],2304,230400), 'Insufficient nonzero pixels')
    require(f['entirely_black'] is False and f['flat_rgb'] is False and f['semantic_appearance_verified'] is False, 'Invalid pixel acceptance facts')
    require(integer(f['channel_min'],0,255) and integer(f['channel_max'],0,255), 'Channel range schema')
    require(integer(f['channel_range'],32,255) and f['channel_range']==f['channel_max']-f['channel_min'], 'Channel diversity failed')
    require(integer(f['distinct_rgb_capped_at_256'],16,256) and integer(f['quantized_color_count'],8,4096), 'Color diversity failed')
    require(integer(f['adjacent_quantized_changes'],1152,230399), 'Pixel transitions failed')
    require(finite(f['middle_pixel_fraction']) and .01<=f['middle_pixel_fraction']<=1, 'Middle pixels failed')
    require(finite(f['dominant_quantized_fraction']) and 0<f['dominant_quantized_fraction']<=.98, 'Dominant color failed')


def validate_border_facts(f):
    fixed={'schema':1,'width':480,'height':480,'border_pixels':32,'pixels_per_strip':15360,'reject_at_black_pixels':14592}
    counts=('top_black_pixels','bottom_black_pixels','left_black_pixels','right_black_pixels')
    require(type(f) is dict and set(f)==set(fixed)|set(counts)|{'accepted'}, 'Border schema')
    require(all(type(f[k]) is int and f[k]==v for k,v in fixed.items()), 'Border fixed contract mismatch')
    require(f['accepted'] is True and all(integer(f[k],0,14591) for k in counts), 'Border rejection')


def validate_png_header(data):
    require(len(data)>=45 and data[:8]==b'\x89PNG\r\n\x1a\n' and data[8:16]==b'\0\0\0\rIHDR', 'PNG header missing')
    require(struct.unpack('>IIBBBBB',data[16:29])==(480,480,8,2,0,0,0), 'PNG dimensions/RGB8 format mismatch')
    require(struct.unpack('>I',data[29:33])[0]==zlib.crc32(data[12:29])&0xffffffff, 'PNG IHDR checksum')


def validate_manifest(manifest, root=None, expected_count=None):
    require(type(manifest) is dict, 'Manifest object required')
    required={'schema','status','fps_config','cadence_samples','owner','width','height','frame_count','raw_buffer_bytes','deferred_validation','rejected','frames','rejection_timing','configured_cadence_only','rendered_presentation_rate_measured','acquisition_end_seconds','total_frame_bytes','raw_buffers_released','validation_begin_seconds'}
    require(set(manifest)==required, 'Manifest v2 fields mismatch')
    require(type(manifest['schema']) is int and manifest['schema']==2 and manifest['status']==STATUS, 'Manifest not fully validated pending scene/cleanup')
    require(manifest['rejection_timing']==REJECTION_TIMING and manifest['configured_cadence_only'] is True and manifest['rendered_presentation_rate_measured'] is False and manifest['raw_buffers_released'] is True, 'Deferred limitations/release evidence missing')
    require(manifest['deferred_validation'] is True and manifest['rejected'] is False, 'Deferred batch rejected or unvalidated')
    require(type(manifest['width']) is int and type(manifest['height']) is int and manifest['width']==manifest['height']==480, 'Exact dimensions required')
    fps=validate_config(manifest['fps_config']);validate_owner(manifest['owner'])
    n=manifest['frame_count']
    require(integer(n,1,min(20,math.floor(fps))), 'Frame count/batch duration bound')
    if expected_count is not None:
        require(type(expected_count) is int and n==expected_count, 'Reviewed frame count mismatch')
    require(type(manifest['raw_buffer_bytes']) is int and manifest['raw_buffer_bytes']==n*RAW_FRAME_BYTES<=MAX_RAW_BYTES, 'Raw buffer bound/accounting mismatch')
    samples=manifest['cadence_samples']
    require(type(samples) is list and len(samples)==3, 'Three cadence samples required')
    for phase,sample in zip(('admission','burst_start','burst_end'),samples):
        require(type(sample) is dict and set(sample)=={'phase','config','owner'} and sample['phase']==phase, 'Cadence sample schema/order')
        validate_config(sample['config']);validate_owner(sample['owner'])
        require(sample['config']==manifest['fps_config'] and sample['owner']==manifest['owner'], 'Cadence configuration/identity changed')
    frames=manifest['frames'];require(type(frames) is list and len(frames)==n, 'Frames incomplete')
    total=0;previous_end=None;first_due=None
    for i,f in enumerate(frames):
        keys={'index','name','sha256','bytes','begin_seconds','end_seconds','due_seconds','width','height','pid','creation_filetime','hwnd','pixel_diagnostics','viewport_border','checkpoints','native_cleanup'}
        require(type(f) is dict and set(f)==keys, 'Frame schema')
        require(type(f['index']) is int and f['index']==i and f['name']==f'cadence-{i:03d}.png', 'Frame sequence/name')
        require(type(f['sha256']) is str and HEX64.fullmatch(f['sha256']), 'PNG hash schema')
        require(integer(f['bytes'],45,1048576), 'PNG byte bound')
        owner={k:f[k] for k in ('pid','creation_filetime','hwnd')}
        validate_owner(owner);require(owner==manifest['owner'], 'Frame owner changed')
        require(type(f['width']) is int and type(f['height']) is int and f['width']==f['height']==480, 'Frame dimensions mismatch')
        require(f['checkpoints']==CHECKPOINTS and f['native_cleanup']==NATIVE_CLEANUP, 'Native safety/cleanup checkpoint evidence missing')
        begin,end,due=(f[k] for k in ('begin_seconds','end_seconds','due_seconds'))
        require(all(finite(t) and t>=0 for t in (begin,end,due)), 'Invalid frame timestamps')
        if first_due is None:
            require(due==0, 'First scheduled sample must be relative burst zero')
            first_due=due
        require(math.isclose(due-first_due,i/fps,rel_tol=0,abs_tol=1e-9), 'Due schedule mismatch')
        require(due<=begin<=end and end-due<1/fps, 'Acquisition cadence missed')
        require(previous_end is None or begin>=previous_end and end>previous_end, 'Non-monotonic/overlapping acquisition')
        previous_end=end
        validate_pixel_facts(f['pixel_diagnostics']);validate_border_facts(f['viewport_border'])
        if root is not None:
            path=Path(root)/f['name']
            require(path.is_file() and not path.is_symlink() and path.stat().st_size==f['bytes'], 'PNG file missing/size changed')
            data=path.read_bytes();require(len(data)==f['bytes'] and hashlib.sha256(data).hexdigest()==f['sha256'], 'PNG hash changed')
            validate_png_header(data)
        total+=f['bytes']
    require(finite(manifest['acquisition_end_seconds']) and previous_end<=manifest['acquisition_end_seconds']<=1, 'Acquisition end bound')
    require(finite(manifest['validation_begin_seconds']) and manifest['acquisition_end_seconds']<=manifest['validation_begin_seconds']<=1.5, 'Deferred validation start/handshake bound')
    require(type(manifest['total_frame_bytes']) is int and manifest['total_frame_bytes']==total, 'Total PNG byte accounting mismatch')
    require(previous_end-first_due<=1 and total<=15*1024**2, 'Batch duration/payload bound')
    return manifest
