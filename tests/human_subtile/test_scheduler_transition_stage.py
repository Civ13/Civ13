"""Exact native-call instrumentation tests; no runtime or game launch."""
import importlib.util
import hashlib
import tempfile
from pathlib import Path
import unittest

HERE=Path(__file__).resolve().parent; ROOT=HERE.parents[1]
spec=importlib.util.spec_from_file_location('transition_stage',HERE/'scheduler_transition_stage.py')
stage=importlib.util.module_from_spec(spec);spec.loader.exec_module(stage)

def source_map(): return {p:(ROOT/p).read_text(encoding='utf-8') for p in (stage.ANIMAL,stage.AI,stage.CAT)}

class StageContract(unittest.TestCase):
    def setUp(self): self.sources=source_map()
    def test_exact_call_sites_and_reversibility(self):
        before=dict(self.sources);after=stage.instrument(self.sources)
        self.assertEqual(self.sources,before)
        for path,old,new in reversed((stage.CLIENT_GATE,)+stage.REPLACEMENTS):
            self.assertEqual(after[path].count(new),1)
            after[path]=after[path].replace(new,old,1)
        self.assertEqual(after,before)
    def test_missing_and_duplicate_preimages_fail_before_output(self):
        for path,old,_ in stage.REPLACEMENTS:
            for replacement in ('',old+old):
                bad=dict(self.sources);bad[path]=bad[path].replace(old,replacement,1)
                with self.subTest(path=path,duplicate=bool(replacement)),self.assertRaises(ValueError):stage.instrument(bad)
    def test_misindented_or_already_instrumented_source_is_rejected(self):
        for path,before,_ in stage.REPLACEMENTS:
            bad=dict(self.sources);bad[path]=bad[path].replace(before,'\t'+before,1)
            with self.subTest(path=path),self.assertRaises(ValueError):stage.instrument(bad)
        with self.assertRaises(ValueError):stage.instrument(stage.instrument(self.sources))
    def test_headless_gate_only_admits_selected_unanchored_npc(self):
        import re
        from types import SimpleNamespace
        staged=stage.instrument(self.sources)[stage.AI]
        def expression(source):
            lines=[line.strip() for line in source.splitlines() if line.startswith('\tif (client || anchored ||')]
            self.assertEqual(len(lines),1)
            expr=lines[0][4:-1].replace('&&',' and ').replace('||',' or ')
            return re.sub(r'!(?!=)',' not ',expr).strip()
        old=expression(self.sources[stage.AI]); new=expression(staged)
        actor=object(); other=object()
        for present in (0,1):
            for client in (False,True):
                for anchored in (False,True):
                    for subject in (actor,other):
                        env={'client':client,'anchored':anchored,'clients':SimpleNamespace(len=present),
                             'src':subject,'fixture_scheduler_test_subjects':[actor]}
                        before=bool(eval(old,{'__builtins__':{}},env));after=bool(eval(new,{'__builtins__':{}},env))
                        expected=client or anchored or (present==0 and subject is other)
                        with self.subTest(present=present,client=client,anchored=anchored,selected=subject is actor):
                            self.assertEqual(after,expected)
                            if present==0 and subject is actor and not client and not anchored:self.assertTrue(before)
                            else:self.assertEqual(before,after)
    def test_gate_preimage_missing_or_duplicate_fails_closed(self):
        path,before,_=stage.CLIENT_GATE
        for replacement in ('',before+before):
            bad=dict(self.sources);bad[path]=bad[path].replace(before,replacement,1)
            with self.subTest(duplicate=bool(replacement)),self.assertRaises(ValueError):stage.instrument(bad)
    def test_probe_receipt_preimages_and_missing_negative(self):
        source=(ROOT/stage.PROBE).read_text(encoding='utf-8')
        result=stage.adapt_probe(source)
        self.assertIn('fixture_scheduler_transition_main()',result)
        self.assertIn('"transition_partial" = fixture_transition_events',result)
        for before,_ in stage.PROBE_REPLACEMENTS:
            with self.subTest(before=before),self.assertRaises(ValueError):
                stage.adapt_probe(source.replace(before,'',1))
    def test_prepare_only_exact_overlays_and_hashes(self):
        class Current:
            def adapt(self,out,manifest,path,before,after):
                p=out/'stage'/path;source=p.read_text(encoding='utf-8')
                if source.count(before)!=1:raise ValueError('preimage')
                p.write_text(source.replace(before,after,1),encoding='utf-8',newline='\n')
        with tempfile.TemporaryDirectory() as temp:
            out=Path(temp); staged=out/'stage';staged.mkdir()
            for rel in (stage.ANIMAL,stage.AI,stage.CAT,stage.PROBE,stage.FIXTURE):
                dest=staged/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes((ROOT/rel).read_bytes())
            dme=staged/'human_subtile.dme';dme.write_text('// fixture\n',encoding='utf-8')
            manifest={'dme':'stage/human_subtile.dme','stage_files':{}}
            stage.adapt(out,manifest,Current())
            self.assertFalse(manifest['native_executed']);self.assertEqual(manifest['transition_scope'],stage.SCOPE)
            self.assertIn(stage.CLIENT_GATE[2],(staged/stage.AI).read_text(encoding='utf-8'))
            self.assertEqual(dme.read_text(encoding='utf-8').count('scheduler_core_draft.dm'),1)
            for rel in (stage.ANIMAL,stage.AI,stage.CAT,stage.PROBE,'human_subtile.dme'):
                raw=(staged/rel).read_bytes();self.assertEqual(manifest['stage_files'][rel],{'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()})
            with self.assertRaises(ValueError):stage.adapt(out,manifest,Current())
    def test_source_inventory_is_exact(self):
        bad=dict(self.sources);bad['extra']=''
        with self.assertRaises(ValueError):stage.instrument(bad)
    def test_dispatch_markers_follow_actual_call(self):
        instrumented=stage.instrument(self.sources)
        for path,before,after in stage.REPLACEMENTS:
            self.assertIn(after,instrumented[path])
            original=''.join(line for line in after.splitlines(keepends=True) if 'fixture_transition_' not in line)
            self.assertEqual(original,before,'every original line and indentation must remain exact')
            lines=after.splitlines()
            for i,line in enumerate(lines):
                if 'fixture_transition_' in line:
                    self.assertGreater(i,0)
                    self.assertEqual(len(line)-len(line.lstrip('\t')),len(lines[i-1])-len(lines[i-1].lstrip('\t')))

if __name__=='__main__':unittest.main()
