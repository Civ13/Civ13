import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from fixtures import surface


class CLITests(unittest.TestCase):
    def invoke(self,text):
        with tempfile.TemporaryDirectory(prefix="civ13-offline-validator-") as tmp:
            p=Path(tmp)/"input.json";p.write_text(text,encoding="utf-8")
            r=subprocess.run([sys.executable,"-m", "tools.procedural_maps", "validate",str(p)],capture_output=True,text=True,timeout=10)
            return r.returncode,json.loads(r.stdout)
    def test_positive_exit_and_scope(self):
        code,r=self.invoke(json.dumps(surface()))
        self.assertEqual(0,code);self.assertEqual("offline-ir-only",r["scope"])
    def test_invariant_negative_exit(self):
        d=surface();d["ports"]=[];code,r=self.invoke(json.dumps(d))
        self.assertEqual(1,code);self.assertFalse(r["accepted"])
        self.assertIn("RIVER_ENDPOINT",{x["code"] for x in r["errors"]})
    def test_duplicate_key_input_failure(self):
        code,r=self.invoke('{"schema":"one","schema":"two"}')
        self.assertEqual(2,code);self.assertIn("duplicate JSON key",r["errors"][0]["detail"])
    def test_nonfinite_input_failure(self):
        code,r=self.invoke('{"seed":NaN}')
        self.assertEqual(2,code);self.assertFalse(r["accepted"])


if __name__=="__main__":unittest.main(verbosity=2)
