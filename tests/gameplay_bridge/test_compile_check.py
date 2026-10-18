"""Compile packet/receipt controls only; no compiler or daemon execution."""
import io
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts/gameplay_bridge"))
from compile_check import compile_dme, prepare, run, verify_log


class CompileCheck(unittest.TestCase):
    def test_ci_compiles_fresh_exact_head_not_generated_workspace(self):
        workflow=(ROOT/".github/workflows/test.yml").read_text(encoding="utf-8")
        step=workflow.split("      - name: Compile disabled gameplay bridge closure without running it\n",1)[1].split("      - name:",1)[0]
        required=(
            'git status --short --untracked-files=no > "$RUNNER_TEMP/gameplay-bridge-source-status.txt"',
            'compile_source="$RUNNER_TEMP/gameplay-bridge-source"',
            'test ! -e "$compile_source"',
            'git worktree add --detach "$compile_source" "$CIV13_EXPECTED_COMMIT"',
            'test "$(git -C "$compile_source" rev-parse HEAD)" = "$CIV13_EXPECTED_COMMIT"',
            'python3 -B "$compile_source/scripts/gameplay_bridge/compile_check.py"',
            '--byond-bin "$GITHUB_WORKSPACE/BYOND/byond/bin"',
            '--expected-commit "$CIV13_EXPECTED_COMMIT"')
        def bound(text): return all(anchor in text for anchor in required)
        self.assertTrue(bound(step))
        self.assertLess(step.index(required[3]),step.index(required[5]))
        for anchor in (required[3],required[4],required[5]):
            self.assertFalse(bound(step.replace(anchor,"omitted",1)))
        self.assertNotIn("git reset",step)

    def test_actual_dme_closure_is_no_map_no_hook_and_same_production_module(self):
        result=compile_dme((ROOT/"civ13.dme").read_text())
        self.assertIn('#define CIV13_GAMEPLAY_BRIDGE\n',result)
        self.assertIn('#include "code/modules/gameplay_bridge/bridge.dm"',result)
        self.assertNotIn('.dmm"',result)
        self.assertNotIn('CIV13_GAMEPLAY_WAIT_GUARDS',result)
        self.assertIn('compile_generated/world.dm',result)
        with self.assertRaisesRegex(ValueError,"anchor drift"):
            compile_dme('missing anchors')

    def test_wrong_head_dirty_tree_and_existing_output_refuse_before_writing(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)/"checkout"; root.mkdir(); out=Path(temp)/"packet"
            with patch("compile_check.git",return_value=b"b"*40+b"\n"):
                with self.assertRaisesRegex(ValueError,"frozen HEAD"): prepare(root,out,"a"*40)
            self.assertFalse(out.exists())
            with patch("compile_check.git",side_effect=[b"a"*40,b" M shared.dm"]):
                with self.assertRaisesRegex(ValueError,"frozen HEAD"): prepare(root,out,"a"*40)
            with self.assertRaisesRegex(ValueError,"outside checkout"): prepare(root,root,"a"*40)

    def test_only_complete_pinned_zero_diagnostic_receipt_passes(self):
        good="DM compiler version 516.1681\nbridge_compile.dmb - 0 errors, 0 warnings\n"
        verify_log(good,0)
        for text,rc in ((good,1),(good.replace("516.1681","516.1680"),0),
                        (good.replace("0 warnings","1 warnings"),0),
                        (good.replace("0 errors","1 errors"),0),("",0)):
            with self.assertRaises(ValueError): verify_log(text,rc)

    def test_compile_preparation_excludes_config_and_rejects_archive_escape(self):
        files={p:(ROOT/p).read_text(encoding="utf-8") for p in ("civ13.dme","code/_helpers/mobs.dm","code/world.dm","code/controllers/mc/globals.dm")}
        files["config/host.txt"]="synthetic-private-config"
        def archive(extra=None):
            stream=io.BytesIO()
            with tarfile.open(fileobj=stream,mode="w") as tar:
                for path,text in files.items():
                    if path.startswith("config/"): continue
                    data=text.encode(); row=tarfile.TarInfo(path); row.size=len(data)
                    tar.addfile(row,io.BytesIO(data))
                if extra:
                    row=tarfile.TarInfo(extra);row.size=1;tar.addfile(row,io.BytesIO(b"x"))
            return stream.getvalue()
        def fake_git(root,*args):
            if args[0]=="rev-parse": return b"a"*40
            if args[0]=="status":
                self.assertIn("--untracked-files=no",args)
                return b""  # CI BYOND/ tooling is untracked and not an input.
            if args[0]=="ls-files": return "\0".join(files).encode()
            if args[0]=="show": return files[args[1].split(":",1)[1]].encode()
            self.assertEqual(args[0],"archive")
            self.assertFalse(any(p.startswith("config/") for p in args))
            return payload
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)/"checkout";root.mkdir();out=Path(temp)/"packet"
            payload=archive()
            with patch("compile_check.git",side_effect=fake_git),patch("compile_check.selected_files",return_value=list(files)):
                source=prepare(root,out,"a"*40)
            self.assertFalse((source/"config").exists())
            self.assertFalse((source/"BYOND").exists())
            self.assertEqual((source/"code/_helpers/mobs.dm").read_text(encoding="utf-8"),files["code/_helpers/mobs.dm"])
            for extra in ("../escape", "config/host.txt"):
                payload=archive(extra);bad=Path(temp)/("bad-"+str(len(extra)))
                with patch("compile_check.git",side_effect=fake_git),patch("compile_check.selected_files",return_value=list(files)):
                    with self.assertRaises(ValueError): prepare(root,bad,"a"*40)
                self.assertFalse(bad.exists())

    def test_runner_invokes_only_compiler_with_finite_timeout(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);source=root/"source";source.mkdir();binary=root/"bin";binary.mkdir()
            (binary/"DreamMaker").write_text("inert test placeholder, never executed")
            class Result: returncode=0
            def compiler(command,**options):
                self.assertEqual(command,[str(binary/"DreamMaker"),"-max_errors","0","bridge_compile.dme"])
                self.assertEqual(options["timeout"],180)
                self.assertEqual(options["cwd"],source)
                options["stdout"].write(b"DM compiler version 516.1681\n0 errors, 0 warnings\n")
                return Result()
            with patch("compile_check.prepare",return_value=source),patch("compile_check.subprocess.run",side_effect=compiler) as calls:
                result=run(root,root,"a"*40,binary)
            self.assertEqual(calls.call_count,1)
            self.assertEqual(result["runtime"],"not_run")


if __name__ == "__main__": unittest.main()
