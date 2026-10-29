from tools.procedural_maps.repo_source import read_pinned
import hashlib
import json
import os
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]


class ResourceProposalTests(unittest.TestCase):
    def test_frozen_identity(self):
        b=(ROOT/'tools/procedural_maps/catalog/native-resources-v0.1.json').read_bytes()
        self.assertEqual('3271ab65af695acc984e97953cf9a0082af1a866d6f5440ec00d699a2770d743',hashlib.sha256(b).hexdigest())
    def test_exact_source_evidence(self):
        d=json.loads((ROOT/'tools/procedural_maps/catalog/native-resources-v0.1.json').read_text())
        for entry in d['entries']:
            for evidence in entry['evidence']:
                b=read_pinned(evidence['path'], evidence['git_blob'],os.environ['CIV13_TEST_HISTORICAL_CATALOG_ROOT'])
                self.assertEqual(evidence['git_blob'],hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest())
                lines=b.decode().splitlines();self.assertEqual(evidence['anchor'],lines[evidence['line']-1])
                section=[]
                for line in lines[evidence['line']-1:]:
                    if section and line.startswith('/'):break
                    section.append(line)
                for fragment in evidence['required_source_fragments']:self.assertIn(fragment,'\n'.join(section))
    def test_current_source_preserves_each_frozen_evidence_section(self):
        from tools.procedural_maps.dmm_export import verify_catalog
        from tools.procedural_maps.repo_source import read_source
        self.assertTrue(verify_catalog())
        d=json.loads((ROOT/'tools/procedural_maps/catalog/native-resources-v0.1.json').read_text())
        for entry in d['entries']:
            for evidence in entry['evidence']:
                path=evidence['path'];old=read_pinned(path,evidence['git_blob'],os.environ['CIV13_TEST_HISTORICAL_CATALOG_ROOT']).decode().splitlines()
                new=read_source(path).decode().splitlines()
                def section(lines):
                    start=lines.index(evidence['anchor']);out=[]
                    for line in lines[start:]:
                        if out and line.startswith('/'):break
                        out.append(line)
                    return out
                self.assertEqual(section(old),section(new),evidence['anchor'])
    def test_no_native_resource_admission(self):
        d=json.loads((ROOT/'tools/procedural_maps/catalog/native-resources-v0.1.json').read_text())
        self.assertFalse(d['automatic_abstract_to_native_mapping']);self.assertFalse(d['native_interactions_implemented'])
        self.assertTrue(all(not e['native_placement_admitted'] and e['unresolved'] for e in d['entries']))
        food=next(e for e in d['entries'] if e['abstract']=='FOOD')
        self.assertIn('not yet a verified common-human food source',food['interaction'])


if __name__=='__main__':unittest.main(verbosity=2)
