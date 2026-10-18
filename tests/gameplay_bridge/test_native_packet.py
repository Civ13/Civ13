"""Preparation/result-validator tests only. No BYOND, client, socket or model."""
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts/gameplay_bridge"))
from prepare_native import GUARDS, NATIVE, PROFILES, helper_variant, isolated_startup, prepare, profile_contract, resource_literals, selected_files
from wait_overlay import guarded_source
from check_native_packet import CONTROL_FAILURE, ORDINARY, inside, verify_prepared, verify_result


class NativePacketTests(unittest.TestCase):
    def test_helper_controls_preserve_source_and_omit_only_requested_guard(self):
        # Pure in-memory transform on public source; NOT native integration.
        current = (ROOT / "code/_helpers/mobs.dm").read_text(encoding="utf-8")
        source = current
        self.assertEqual(helper_variant(source,"headless"),source)
        self.assertEqual(helper_variant(source,"baseline"),helper_variant(source,"no_hook"))
        for profile, block in GUARDS.items():
            self.assertEqual(helper_variant(source,profile),source.replace(block,"",1))
        self.assertEqual(helper_variant(source,"reacquire").count("gameplay_lease = gameplay_context"),2)
        self.assertEqual((ROOT / "code/_helpers/mobs.dm").read_text(encoding="utf-8"),current)

    def test_startup_isolation_uses_fail_closed_drift_anchors(self):
        w = (ROOT / "code/world.dm").read_text(encoding="utf-8")
        g = (ROOT / "code/controllers/mc/globals.dm").read_text(encoding="utf-8")
        world, globals_source = isolated_startup(w,g)
        self.assertIn("/world/proc/unused_gameplay_packet_startup()",world)
        self.assertIn("/datum/global_init/New()\n\treturn\n",world)
        self.assertIn("/datum/controller/global_vars/New()\n\tGLOB = src\n\treturn\n",globals_source)
        with self.assertRaises(ValueError):
            isolated_startup(w.replace("/world/New()","/world/New(changed)"),g)

    def test_existing_or_checkout_output_is_refused_before_git(self):
        with patch("prepare_native.git") as tool:
            for output in (ROOT, ROOT / "new-packet"):
                with self.assertRaises(ValueError):
                    prepare(ROOT,output,"test")
            tool.assert_not_called()

    def test_dirty_or_mismatched_commit_never_writes_packet(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / "packet"
            with patch("prepare_native.git",side_effect=[b"actual\n"]):
                with self.assertRaisesRegex(ValueError,"clean frozen"):
                    prepare(ROOT,output,"expected")
            with patch("prepare_native.git",side_effect=[b"expected\n",b" M dirty\n"]):
                with self.assertRaisesRegex(ValueError,"clean frozen"):
                    prepare(ROOT,output,"expected")
            self.assertFalse(output.exists())

    def test_stale_ambient_native_packet_refuses_even_clean_current_head(self):
        with tempfile.TemporaryDirectory() as temp:
            output=Path(temp)/"packet"
            with patch("prepare_native.git",side_effect=[b"expected",b""]):
                with self.assertRaisesRegex(ValueError,"typed gather native fixture not reconciled"):
                    prepare(ROOT,output,"expected")
            self.assertFalse(output.exists())

    def test_only_static_assets_and_required_runtime_config_are_selected(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            paths={"civ13.dme":"#include \"code/a.dm\"\n", "code/a.dm":"var/i = 'extra/public.png'\n", "code/modules/gameplay_bridge/bridge.dm":"", "extra/public.png":"pixels", "rust_g.dll":"fixture dll", "config/names/first.txt":"name", "config/crafting/recipes.txt":"recipe", "config/host.txt":"PRIVATE", "data/gameplay-bridge.json":"PRIVATE"}
            paths.update({NATIVE+p:"" for p in ("compile_probe.dm","headless_probe.dm","client_assertions.dm")})
            for p,data in paths.items():
                target=root/p;target.parent.mkdir(parents=True,exist_ok=True);target.write_text(data)
            selected=selected_files(root,set(paths))
            self.assertIn("extra/public.png",selected)
            self.assertIn("config/names/first.txt",selected)
            self.assertNotIn("config/host.txt",selected)
            self.assertNotIn("data/gameplay-bridge.json",selected)

    def test_path_escape_and_tampered_packet_are_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp).resolve()
            for rel in ("../secret","/secret","x\\secret"):
                with self.assertRaises(ValueError): inside(root,rel)
            file=root/"source.dm";file.write_text("source")
            manifest={"commit":"c","state":"prepared_not_executed","native_lease":None,"profiles":[{"name":p,"status":"not_run",**profile_contract(p)} for p in PROFILES],"sha256":{"source.dm":hashlib.sha256(file.read_bytes()).hexdigest()}}
            (root/"manifest.json").write_text(json.dumps(manifest))
            verify_prepared(root,"c")
            for mutation in (manifest["profiles"][:-1], manifest["profiles"][:-1]+[manifest["profiles"][0]], [{**p,"expected":"compile_only"} if p["name"] == "headless" else p for p in manifest["profiles"]]):
                bad=copy.deepcopy(manifest);bad["profiles"]=mutation
                (root/"manifest.json").write_text(json.dumps(bad))
                with self.assertRaises(ValueError):verify_prepared(root,"c")
            (root/"manifest.json").write_text(json.dumps(manifest))
            file.write_text("tampered")
            with self.assertRaisesRegex(ValueError,"hash mismatch"): verify_prepared(root,"c")

    def test_negative_control_requires_exact_failure_not_runtime_or_generic_failure(self):
        for profile,label in CONTROL_FAILURE.items():
            prefix=ORDINARY | {"enabled_implementation_marker"}
            if profile != "omit_entry":prefix |= {"entry_revoke_immediate"}
            if profile in ("omit_wake","reacquire"):prefix |= {"zero_delay_final_revoke","old_lease_initially_valid"}
            result={"commit":"c","profile":profile,"byond_version":516,"byond_build":1681,"dimensions":[9,9,1],"port":0,"runtime_error":False,"positive_client_acceptance":False,"passed":False,"failed_assertion":label,"checks":[{"assertion":a,"passed":True,"tick":0} for a in prefix]+[{"assertion":label,"passed":False,"tick":1}]}
            verify_result(result,profile,"c")
            truncated=copy.deepcopy(result);truncated["checks"]=truncated["checks"][-1:]
            with self.assertRaises(ValueError):verify_result(truncated,profile,"c")
            for key,value in (("runtime_error",True),("failed_assertion","unrelated"),("passed",True)):
                mutation=copy.deepcopy(result);mutation[key]=value
                with self.assertRaises(ValueError): verify_result(mutation,profile,"c")

    def test_resource_scanner_excludes_comments_and_nested_html_text(self):
        source = '''// reference 'missing/comment.dmi'
var/icon = 'icons/real.dmi'
var/text = "[thing ? "<img src='fake.png'>" : ""] [icon('icons/embedded.dmi')]"
var/html = {"<script language="javascript">window.location="byond://";</script><img src='fake.png'> [icon('icons/long.dmi')]"}
/* outer /* 'missing/nested.dmi' */ done */
'''
        self.assertEqual(resource_literals(source),["icons/real.dmi","icons/embedded.dmi","icons/long.dmi"])

    def test_empty_partial_or_false_client_acceptance_cannot_pass(self):
        result={"commit":"c","profile":"disabled","byond_version":516,"byond_build":1681,"dimensions":[9,9,1],"port":0,"runtime_error":False,"positive_client_acceptance":False,"passed":True,"failed_assertion":"","checks":[]}
        with self.assertRaises(ValueError):verify_result(result,"disabled","c")
        result["checks"]=[{"assertion":a,"passed":True,"tick":1} for a in ORDINARY | {"disabled_marker_absent"}]
        verify_result(result,"disabled","c")
        result["positive_client_acceptance"]=True
        with self.assertRaises(ValueError):verify_result(result,"disabled","c")

    def test_client_packet_is_honest_about_execution_and_automation_gaps(self):
        plan=json.loads((ROOT / NATIVE / "client_scenarios.json").read_text())
        self.assertEqual(plan["status"],"prepared_not_run")
        self.assertEqual(plan["session_limits"]["inference_requests"],0)
        self.assertTrue(plan["not_implemented_by_packet"])
        source=(ROOT / NATIVE / "client_assertions.dm").read_text()
        for case in plan["cases"]:
            self.assertIn("/proc/"+case["routine"].split("(")[0]+"(",source)
        self.assertNotIn("/world/New",source)
        self.assertNotIn("/client/New",source)
        self.assertIn("compile_stock",PROFILES)


if __name__ == "__main__":
    unittest.main()
