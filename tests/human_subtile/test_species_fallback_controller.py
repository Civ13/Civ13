"""Offline source, selector and synthetic archive controls; no BYOND execution."""
import copy
import base64
import lzma
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile
from types import SimpleNamespace
import time
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, HERE / filename)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


binding = load("species_binding_test", "species_fallback_binding.py")
evidence = load("species_evidence_test", "species_fallback_evidence.py")
controller = load("species_controller_test", "cloud_npc_controller.py")
fixture = load("species_fixture_test", "test_species_fallback_fixture.py")
stage = load("species_stage_test", "species_fallback_stage.py")
contract = load("species_contract_test", "species_fallback_contract.py")
HEAD = "a" * 40


def rec(data):
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def archive(files):
    output = io.BytesIO()
    with tarfile.open(fileobj=output, mode="w") as tar:
        for name, raw in files:
            item = tarfile.TarInfo(name)
            item.size = len(raw)
            tar.addfile(item, io.BytesIO(raw))
    return output.getvalue()


def synthetic():
    sources = {name: (ROOT / name).read_bytes() for name in binding.PINNED}
    probe = sources["tests/human_subtile/probe.dm"].decode()
    probe = probe.replace("\t\t\thuman_subtile_fixture_headless()", "\t\t\tspecies_fallback_main()")
    probe = probe.replace('"checks" = human_subtile_fixture_checks,',
        '"checks" = human_subtile_fixture_checks, "species_checks" = species_fallback_checks, '
        '"species_rows" = species_fallback_rows, "species_case" = species_fallback_case, '
        '"species_partial" = species_fallback_events,')
    probe = probe.replace('"scope" = "actual human/codec; headless authority adapter"',
                          '"scope" = "' + stage.SCOPE + '"')
    import re
    dme = re.sub(r'^#include ".*\.dmm"\s*$', "", sources["civ13.dme"].decode(), flags=re.M)
    dme += '\n#include "tests\\human_subtile\\mining.dm"\n#include "tests\\human_subtile\\probe.dm"\n'
    dme += '\n#include "tests\\human_subtile\\species_fallback_fixture.dm"\n'
    expected = {name: raw for name, raw in sources.items()
                if name not in ("civ13.dme", "tests/human_subtile/probe.dm")}
    expected["tests/human_subtile/probe.dm"] = probe.encode()
    expected["human_subtile.dme"] = dme.encode()
    manifest = {"head": HEAD, "species_scope": stage.SCOPE, "native_executed": False,
                "stage_files": {name: rec(raw) for name, raw in expected.items()},
                "original_git_files": {name: rec(raw) for name, raw in sources.items()}}
    resource = {"bytes": 12, "mode": 0o600, "sha256": "a" * 64}
    states = {"species": {"before": resource, "after": resource, "changed": False, "integrity_verified": True}}
    receipt = fixture.sample()
    receipt["head"] = HEAD
    raw_receipt = json.dumps(receipt).encode()
    phase = lambda seconds, limit: {"returncode": 0, "timed_out": False,
                                    "oversized_log": False, "deadline": limit, "seconds": seconds}
    status = {"head": HEAD, "suite": "species05", "phase": "complete", "outcome": "passed",
              "fixture_dme_only": True, "resource_copies_independent": True, "runtime_resources": states}
    summary = {"head": HEAD, "suite": "species05", "tick": 0.5, "fixture_dme_only": True,
        "observation_complete": True, "parity_established": False, "scope": stage.SCOPE,
        "limits": {"compile_seconds": 90, "daemon_seconds": 60, "setup_seconds": 60,
                   "work_seconds": 490, "whole_seconds": 600}, "compile": phase(3,90),
        "artifacts": {"human_subtile.rsc": resource}, "resource_states": states,
        "result": {"daemon": phase(4,60), "receipt_sha256": hashlib.sha256(raw_receipt).hexdigest()},
        "observation": contract.validate(receipt, HEAD), "child_elapsed": 7,
        "setup_seconds": 1, "comparison_elapsed": 8}
    payload = {"harness-status.json": json.dumps(status).encode(),
               "smoke-summary.json": json.dumps(summary).encode(),
               "npc-smoke/cloud-manifest.json": json.dumps(manifest).encode(),
               "npc-smoke/stage/compile-stdout.log": b"ok", "npc-smoke/stage/compile-stderr.log": b"",
               "npc-smoke/runtime/receipt.json": raw_receipt, "npc-smoke/runtime/result.txt": b"PASS\n",
               "npc-smoke/runtime/port-closed.txt": b"closed\n", "npc-smoke/runtime/runtime.log": b"",
               "npc-smoke/runtime/daemon-stdout.log": b"", "npc-smoke/runtime/daemon-stderr.log": b""}
    payload.update({f"abi/abi-{i}-{part}.log": b"" for i in range(6) for part in ("stdout","stderr")})
    return sources, payload


def validate(payload, sources):
    class Legacy:
        @staticmethod
        def validate_compile(log, expected):
            if log != "ok" or expected != "human_subtile.dmb":
                raise ValueError("compile log")
    class NPC:
        class current:
            legacy = Legacy()
    modules = {"species_fallback_binding": binding, "species_fallback_stage": stage,
               "species_fallback_contract": contract, "run-npc": NPC}
    def git(args, **kwargs):
        return sources[args[-1].split(":", 1)[1]]
    with patch.object(evidence, "module", side_effect=modules.__getitem__), \
         patch.object(binding, "validate_source", return_value=True), \
         patch.object(evidence.subprocess, "check_output", side_effect=git):
        return evidence.validate(archive(list(payload.items())), HEAD, "species05", ["git"], None, time.monotonic()+10)


class HostContracts(unittest.TestCase):
    def test_synthetic_complete_package(self):
        sources, files = synthetic()
        self.assertEqual(len(files), 23)
        self.assertIsNone(validate(files, sources))

    def test_rejects_incomplete_unexpected_and_unsafe_packages(self):
        sources, files = synthetic()
        for mutation in ("missing", "extra", "traversal"):
            altered = dict(files)
            if mutation == "missing": altered.pop("npc-smoke/runtime/receipt.json")
            elif mutation == "extra": altered["extra"] = b"x"
            else: altered["../escape"] = b"x"
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                validate(altered, sources)

    def test_rejects_changed_inputs_and_invalid_receipt(self):
        sources, files = synthetic()
        changed = dict(sources)
        changed["tests/human_subtile/species_fallback_fixture.dm"] += b"changed"
        with self.assertRaises(ValueError): validate(files, changed)
        altered = dict(files)
        receipt = json.loads(altered["npc-smoke/runtime/receipt.json"])
        receipt["species_rows"][0]["events"][-1]["wild"] = 1
        raw = json.dumps(receipt).encode()
        altered["npc-smoke/runtime/receipt.json"] = raw
        summary = json.loads(altered["smoke-summary.json"])
        summary["result"]["receipt_sha256"] = hashlib.sha256(raw).hexdigest()
        altered["smoke-summary.json"] = json.dumps(summary).encode()
        with self.assertRaises(ValueError): validate(altered, sources)

    def test_rejects_duplicate_or_excess_archive_members(self):
        _, files = synthetic()
        raw = archive(list(files.items()) + [("harness-status.json", b"{}")])
        identity = {"bytes":len(raw), "sha256":hashlib.sha256(raw).hexdigest()}
        with self.assertRaises(RuntimeError): controller.validate_package(raw, identity, "species05")

    def test_rejects_missing_isolation_and_failed_daemon(self):
        sources, files = synthetic()
        altered = dict(files)
        status = json.loads(altered["harness-status.json"])
        status["resource_copies_independent"] = False
        altered["harness-status.json"] = json.dumps(status).encode()
        with self.assertRaises(ValueError): validate(altered, sources)
        altered = dict(files)
        summary = json.loads(altered["smoke-summary.json"])
        summary["result"]["daemon"]["timed_out"] = True
        altered["smoke-summary.json"] = json.dumps(summary).encode()
        with self.assertRaises(ValueError): validate(altered, sources)

    def test_source_binding_refuses_bad_delta_and_bad_blobs(self):
        def perform(delta, bad=False):
            def output(args, **kwargs):
                if "diff" in args:
                    return b"".join(x.encode()+b"\0" for x in delta)
                if args[-1].endswith("^{tree}"): return (binding.BASE_TREE+"\n").encode()
                path = args[-1].split(":",1)[1]
                return (("0"*40 if bad else binding.PINNED[path])+"\n").encode()
            with patch.object(binding.subprocess, "check_output", side_effect=output), \
                 patch.object(binding.subprocess, "run", return_value=subprocess.CompletedProcess([],0)):
                return binding.validate_source(["git"], None, HEAD, time.monotonic()+3)
        self.assertTrue(perform(binding.ALLOWED_DELTA))
        for paths, bad in ((set(binding.ALLOWED_DELTA)-{next(iter(binding.ALLOWED_DELTA))}, False),
                           (set(binding.ALLOWED_DELTA)|{"unexpected.dm"}, False),
                           (binding.ALLOWED_DELTA, True)):
            with self.assertRaises(ValueError): perform(paths, bad)

    def test_expired_source_deadline_refuses_before_subprocess(self):
        with patch.object(binding.subprocess,"check_output") as called:
            with self.assertRaisesRegex(ValueError,"deadline"):
                binding.validate_source(["git"],None,HEAD,time.monotonic()-1)
            called.assert_not_called()

    def test_reviewed_selectors_and_explicit_execute(self):
        for name in ("cloud_npc_controller.py", "cloud_npc_job.py", "cloud_npc_smoke.py"):
            text = (HERE/name).read_text()
            self.assertIn("choices=('species05','transition05')", text)
        text = (HERE/"cloud_npc_job.py").read_text()
        self.assertIn("require(args.execute", text)
        workflow = (ROOT/".github/workflows/wildlife-cardinal-cadence.yml").read_text()
        self.assertIn("suite: [transition05]", workflow)
        self.assertIn('test "$(git rev-parse HEAD^{tree})" = "$EXPECTED_TREE"', workflow)


class IsolationContracts(unittest.TestCase):
    def test_container_restrictions_and_deadline(self):
        with self.assertRaises(RuntimeError):
            controller.create_args("name","owner",HEAD,Path("/source"),Path("/bin"),Path("/zip"),"1001:1001","species05")
        args=controller.create_args("name","owner",HEAD,Path("/source"),Path("/bin"),Path("/zip"),
                                    "1001:1001","species05",123.0)
        for flag, value in (("--network","none"),("--pids-limit","64"),("--memory","3g"),
                            ("--memory-swap","3g"),("--cpus","2"),("--work-deadline","123.0")):
            self.assertEqual(args[args.index(flag)+1],value)
        self.assertIn("--read-only",args)
        self.assertNotIn("--privileged",args)
        self.assertEqual(args.count("--mount"),3)

    def test_rejects_trailing_and_oversized_compressed_evidence(self):
        for raw, extra in ((b"x"*(controller.MAX_PACKAGE+1),b""),(b"valid",b"trailing")):
            compressed=lzma.compress(raw,format=lzma.FORMAT_XZ,preset=6)+extra
            log=b"HARNESS_EVIDENCE_PART 1/1 "+base64.b64encode(compressed)+b"\n"
            marker={"package":{"parts":1,"compressed_bytes":len(compressed),"complete":True,"compression":"xz",
                               "bytes":len(raw),"sha256":hashlib.sha256(raw).hexdigest()}}
            with self.subTest(extra=bool(extra)), self.assertRaises((RuntimeError,lzma.LZMAError)):
                controller.package_from_logs(log,marker,"species05")

    def test_owned_cleanup_and_foreign_owner_protection(self):
        cid="c"*64; owner="b"*32; name="civ13-wildlife-"+owner
        def info(running=True, identity=owner):
            return {"Id":cid,"Name":"/"+name,"Config":{"Labels":{"scope":controller.SCOPE,"owner":identity,"head":HEAD}},
                "State":{"Status":"running" if running else "exited","Running":running,
                         "Pid":321 if running else 0,"ExitCode":137,"OOMKilled":False,"Error":""}}
        class Docker:
            def __init__(self, identity=owner):
                self.state=info(identity=identity); self.calls=[]
            def call(self,args,timeout=10,maximum=None,optional=False):
                self.calls.append(args)
                if args[0]=="inspect":
                    return (1,b"",b"not found") if self.state is None else (0,json.dumps([self.state]).encode(),b"")
                if args[0]=="kill": self.state=info(False)
                elif args[0]=="rm": self.state=None
                elif args[:2]==["container","ls"]: return 0,(cid.encode() if self.state else b""),b""
                return 0,b"",b""
        docker=Docker()
        self.assertTrue(controller.retire(docker,cid,name,owner,HEAD)["absent"])
        self.assertEqual([call[0] for call in docker.calls],["inspect","kill","wait","inspect","rm","container"])
        docker=Docker("foreign")
        with self.assertRaises(RuntimeError): controller.retire(docker,cid,name,owner,HEAD)
        self.assertEqual([call[0] for call in docker.calls],["inspect"])


class WorkerContracts(unittest.TestCase):
    def run_worker(self, fail):
        worker = load("species_worker_test", "species_fallback_worker.py")
        checkpoint = []
        launches = []
        class FakeShared:
            HERE = HERE
            ROOT = ROOT
            @staticmethod
            def require(value, reason):
                if not value: raise RuntimeError(reason)
            @staticmethod
            def load_module(name, path):
                return {"species_fallback_stage": fake_stage, "species_fallback_contract": contract,
                        "species_fallback_binding": fake_binding}[name]
            @staticmethod
            def checkpoint(phase, **fields):
                checkpoint.append((phase, fields))
            @staticmethod
            def file_hash(path):
                return hashlib.sha256(path.read_bytes()).hexdigest()
            @staticmethod
            def run_owned_phase(legacy, group, command, cwd, name, deadline):
                launches.append(("compile", deadline))
                (cwd/"compile-stdout.log").write_text("ok")
                (cwd/"compile-stderr.log").write_text("")
                return {"returncode":0,"timed_out":False,"oversized_log":False,"deadline":deadline,"seconds":0}
            @staticmethod
            def prepare_linked_runtime(out, source, dme, name):
                work = out/name
                work.mkdir()
                dmb = work/"human_subtile.dmb"
                dmb.write_bytes(b"compiled")
                dmb.with_suffix(".rsc").write_bytes(b"resource")
                return work, dmb, {"human_subtile.rsc":{"bytes":8,"sha256":"a"*64,"mode":0o600}}
            @staticmethod
            def run_checked_runtime(legacy, group, command, work, dme, peer, artifacts, expected, label, states, timeout):
                launches.append(("daemon", timeout))
                if fail: raise RuntimeError("synthetic daemon failure")
                item=artifacts["human_subtile.rsc"]
                states[label]={"before":item,"after":item,"changed":False,"integrity_verified":True}
                (work/"port-closed.txt").write_bytes(b"closed\n")
                (work/"result.txt").write_bytes(b"PASS\n")
                row=fixture.sample()
                row["head"]=HEAD
                (work/"receipt.json").write_text(json.dumps(row))
                return {"returncode":0,"timed_out":False,"oversized_log":False,"deadline":timeout,"seconds":0}
        class FakeNPC:
            current = object()
            @staticmethod
            def prepare_source(root, out):
                (out/"stage").mkdir(parents=True)
                (out/"stage/human_subtile.dme").write_text("source")
                return {"head":HEAD,"dme":"stage/human_subtile.dme","stage_files":{}}
        class FakeStage:
            SCOPE = stage.SCOPE
            @staticmethod
            def adapt(out, manifest, current):
                raw=(out/"stage/human_subtile.dme").read_bytes()
                manifest["stage_files"]["human_subtile.dme"]=rec(raw)
        fake_stage=FakeStage()
        fake_binding=SimpleNamespace(validate_source=lambda *args: True)
        fake_runtime=SimpleNamespace(verify_linux=lambda *args: None)
        fake_legacy=SimpleNamespace(validate_compile=lambda *args: None, inspect_logs=lambda *args: None)
        args=SimpleNamespace(suite="species05",head=HEAD,work_deadline=time.monotonic()+1000)
        with tempfile.TemporaryDirectory() as tmp:
            scratch=Path(tmp)
            if fail:
                with self.assertRaisesRegex(RuntimeError,"synthetic daemon failure"):
                    worker.run(FakeShared,args,scratch,Path(tmp),Path(tmp),"group",{}, {}, {},
                               time.monotonic(),FakeNPC,fake_runtime,fake_legacy)
                self.assertFalse((scratch/"smoke-summary.json").exists())
                self.assertFalse(any(phase=="complete" for phase, _ in checkpoint))
            else:
                worker.run(FakeShared,args,scratch,Path(tmp),Path(tmp),"group",{}, {}, {},
                           time.monotonic(),FakeNPC,fake_runtime,fake_legacy)
                summary=json.loads((scratch/"smoke-summary.json").read_text())
                self.assertEqual(summary["observation"]["cases"],list(contract.CASES))
                self.assertEqual(checkpoint[-1][0],"complete")
        self.assertEqual(launches,[("compile",90),("daemon",60)])

    def test_worker_refuses_insufficient_budget_before_launch(self):
        worker=load("species_worker_budget","species_fallback_worker.py")
        class Shared:
            HERE=HERE
            ROOT=ROOT
            @staticmethod
            def require(value, reason):
                if not value: raise RuntimeError(reason)
            @staticmethod
            def load_module(name,path):
                return {"species_fallback_stage":stage,"species_fallback_contract":contract,
                        "species_fallback_binding":binding}[name]
        with self.assertRaisesRegex(RuntimeError,"deadline"):
            worker.run(Shared,SimpleNamespace(suite="species05",head=HEAD,work_deadline=time.monotonic()+1),
                       Path("."),Path("."),Path("."),None,{}, {}, {},time.monotonic(),None,None,None)

    def test_worker_uses_one_bounded_compile_and_one_daemon(self):
        self.run_worker(False)

    def test_worker_failure_does_not_create_success_receipt(self):
        self.run_worker(True)


if __name__ == "__main__":
    unittest.main()