import copy
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
import zlib
import cadence_schema as s


def png():
    def chunk(kind, data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    # Synthetic schema fixture, never claimed engine output.
    raw=(b'\0'+bytes(range(240))*6)*480
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',480,480,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b'')


def valid(n=20, fps=20):
    data=png();owner={'pid':44,'creation_filetime':12345678,'hwnd':888}
    cfg={'world_fps':20,'world_tick_lag':.5,'client_fps':0 if fps==20 else fps,'client_tick_lag':0 if fps==20 else 10/fps,'effective_fps':fps,'same_admitted_client':True}
    pixels={'pixel_count':230400,'nonzero_pixel_count':230400,'channel_min':0,'channel_max':239,'entirely_black':False,'flat_rgb':False,'distinct_rgb_capped_at_256':80,'quantized_color_count':42,'channel_range':239,'middle_pixel_fraction':.9,'dominant_quantized_fraction':.1,'adjacent_quantized_changes':10000,'semantic_appearance_verified':False}
    border={'schema':1,'width':480,'height':480,'border_pixels':32,'pixels_per_strip':15360,'reject_at_black_pixels':14592,'top_black_pixels':0,'bottom_black_pixels':0,'left_black_pixels':0,'right_black_pixels':0,'accepted':True}
    frames=[{'index':i,'name':f'cadence-{i:03d}.png','width':480,'height':480,**owner,'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data),'begin_seconds':i/fps,'end_seconds':i/fps+.001,'due_seconds':i/fps,'pixel_diagnostics':dict(pixels),'viewport_border':dict(border),'checkpoints':list(s.CHECKPOINTS),'native_cleanup':s.NATIVE_CLEANUP} for i in range(n)]
    return {'schema':2,'status':s.STATUS,'fps_config':cfg,'cadence_samples':[{'phase':phase,'config':dict(cfg),'owner':dict(owner)} for phase in ('admission','burst_start','burst_end')],'owner':owner,'width':480,'height':480,'frame_count':n,'raw_buffer_bytes':n*691200,'deferred_validation':True,'rejected':False,'frames':frames,'rejection_timing':s.REJECTION_TIMING,'configured_cadence_only':True,'rendered_presentation_rate_measured':False,'acquisition_end_seconds':frames[-1]['end_seconds'],'total_frame_bytes':sum(f['bytes'] for f in frames),'raw_buffers_released':True,'validation_begin_seconds':frames[-1]['end_seconds']}


class SchemaTests(unittest.TestCase):
    def test_inherited_and_explicit_config(self):
        for n,fps in ((20,20),(20,60),(10,10),(1,1)):
            self.assertEqual(s.validate_manifest(valid(n,fps))['frame_count'],n)
    def test_raw_cap_count_dimensions(self):
        for change in ({'raw_buffer_bytes':13824001},{'frame_count':21},{'width':481},{'height':True},{'schema':True},{'deferred_validation':False},{'rejected':True},{'status':'PASS'}):
            m=valid();m.update(change)
            with self.assertRaises(ValueError):s.validate_manifest(m)
    def test_late_early_nan_and_nonmonotonic(self):
        for key,value in (('end_seconds',.05),('begin_seconds',-.001),('end_seconds',float('nan')),('due_seconds',float('inf'))):
            m=valid();m['frames'][0][key]=value
            with self.assertRaises(ValueError):s.validate_manifest(m)
        m=valid();m['frames'][1]['due_seconds']+=.001
        with self.assertRaises(ValueError):s.validate_manifest(m)
    def test_cadence_change_and_binding(self):
        for cfg in ({'same_admitted_client':False},{'client_fps':60},{'world_tick_lag':1},{'client_tick_lag':.1},{'effective_fps':True}):
            m=valid();m['fps_config'].update(cfg)
            with self.assertRaises(ValueError):s.validate_manifest(m)
        m=valid();m['cadence_samples'][-1]['owner']['pid']+=1
        with self.assertRaises(ValueError):s.validate_manifest(m)
    def test_frame_owner_checkpoint_cleanup_and_path(self):
        for change in ({'pid':45},{'checkpoints':s.CHECKPOINTS[:1]},{'native_cleanup':'unknown'},{'name':'../cadence-000.png'},{'bytes':True}):
            m=valid();m['frames'][0].update(change)
            with self.assertRaises(ValueError):s.validate_manifest(m)
    def test_all_pixel_and_border_results_required(self):
        for key,value in (('flat_rgb',True),('channel_range',31),('middle_pixel_fraction',.009),('dominant_quantized_fraction',.981),('adjacent_quantized_changes',1151),('semantic_appearance_verified',True)):
            m=valid();m['frames'][0]['pixel_diagnostics'][key]=value
            with self.assertRaises(ValueError):s.validate_manifest(m)
        for key,value in (('top_black_pixels',14592),('accepted',False),('width',True)):
            m=valid();m['frames'][0]['viewport_border'][key]=value
            with self.assertRaises(ValueError):s.validate_manifest(m)
    def test_file_hash_header_and_count(self):
        with tempfile.TemporaryDirectory() as tmp:
            m=valid(2);root=Path(tmp)
            for f in m['frames']:(root/f['name']).write_bytes(png())
            s.validate_manifest(m,root,2)
            with self.assertRaises(ValueError):s.validate_manifest(m,root,3)
            (root/m['frames'][1]['name']).write_bytes(b'wrong')
            with self.assertRaises(ValueError):s.validate_manifest(m,root,2)
    def test_real_producer_three_frames_fake_acquisition_actual_validation(self):
        from test_deferred_recording import Deferred
        helper=Deferred();self.addCleanup(helper.doCleanups)
        go,root,events,refs=helper.setup_run(real=True,fps=3)
        manifest=go()
        s.validate_manifest(manifest,root,3)
        self.assertEqual(json.loads((root/'cadence-recording.json').read_text()),manifest)
        self.assertTrue(all('rgb' not in c for c in refs))
        self.assertEqual([e[0] for e in events],['acquire']*3+['validate']*3)
    def test_deferral_and_released_buffers_required(self):
        for change in ({'validation_begin_seconds':1.500001},{'acquisition_end_seconds':1.01},{'raw_buffers_released':False},{'rendered_presentation_rate_measured':True},{'total_frame_bytes':1}):
            m=valid();m.update(change)
            with self.assertRaises(ValueError):s.validate_manifest(m)
    def test_no_metadata_claim_is_full_png_decode(self):
        # Validator binds full file hash and IHDR, not semantic gameplay/PNG pixels.
        data=bytearray(png());data[20:24]=struct.pack('>I',479)
        with self.assertRaises(ValueError):s.validate_png_header(bytes(data))

if __name__=='__main__':unittest.main()
