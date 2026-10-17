"""Exercise production shell dispatch and TTS with counted offline adapters."""
import argparse
import json
import re
import subprocess
import tempfile
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--byond-bin", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--negative-control", choices=("tts", "dispatch"))
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    args.output.mkdir(parents=True, exist_ok=True)
    chat = (repo / "code/game/mob/living/chat_overlay.dm").read_text(encoding="utf-8")
    tts = chat[chat.index("/mob/proc/play_tts("):chat.index("/////AMAZON AWS")]
    python = (repo / "code/processes/python.dm").read_text(encoding="utf-8")
    dispatch = python[python.index("/process/python/proc/execute("):python.index("/process/python/proc/getScriptDir()")]
    if args.negative_control == "tts":
        marker = "\t#ifdef OPENDREAM\n\t// OpenDream has no shell-backed speech generator. Avoid a job per listener.\n\treturn\n\t#else\n"
        if marker not in tts:
            raise RuntimeError("TTS control marker changed")
        tts = tts.replace(marker, "", 1).replace("\t#endif\n", "", 1)
    if args.negative_control == "dispatch":
        marker = '\treturn FALSE\n\t#else\n'
        if marker not in dispatch:
            raise RuntimeError("Dispatch control marker changed")
        dispatch = dispatch.replace(marker, '\t#else\n', 1)
        # Let the old shell path execute in the OpenDream fixture.
        dispatch = dispatch.replace("\t#else\n", "\t#endif\n", 1)
        dispatch = dispatch[:dispatch.rindex("\t#endif")] + dispatch[dispatch.rindex("\t#endif") + len("\t#endif"):]
    tts = tts.replace("!client", "!fixture_client").replace("src && client", "src && fixture_client")
    tts = tts.replace("shell(", "compat_shell(").replace("fexists(", "compat_fexists(")
    dispatch = dispatch.replace("shell(", "compat_shell(")
    probe = (Path(__file__).with_name("probe.dm")).read_text(encoding="utf-8")
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip()
    results = []
    modes = ("opendream",) if args.negative_control else ("native", "opendream")
    for mode in modes:
        with tempfile.TemporaryDirectory(prefix="civ13-shell-") as temporary:
            root = Path(temporary)
            fixture = ("#define OPENDREAM\n" if mode == "opendream" else "") + "\n" + tts + dispatch + probe
            (root / "probe.dme").write_text(fixture, encoding="utf-8")
            (args.output / (mode + "-probe.dme")).write_text(fixture, encoding="utf-8")
            compiler = args.byond_bin / ("dm.exe" if (args.byond_bin / "dm.exe").exists() else "DreamMaker")
            daemon = args.byond_bin / ("dd.exe" if (args.byond_bin / "dd.exe").exists() else "DreamDaemon")
            build = subprocess.run([str(compiler.resolve()), "-max_errors", "0", "probe.dme"],
                                   cwd=root, capture_output=True, text=True, timeout=30)
            build_log = build.stdout + build.stderr
            (args.output / (mode + "-compile.log")).write_text(build_log, encoding="utf-8")
            if build.returncode or "516.1681" not in build_log or "0 errors, 0 warnings" not in build_log:
                raise RuntimeError(build_log)
            runtime = subprocess.run([str(daemon.resolve()), "probe.dmb", "-invisible", "-trusted", "-close", "-log", "runtime.log"],
                                     cwd=root, capture_output=True, text=True, timeout=15)
            log = (root / "runtime.log").read_text(encoding="utf-8", errors="replace")
            log += runtime.stdout + runtime.stderr
            (args.output / (mode + "-runtime.log")).write_text(log, encoding="utf-8")
            if runtime.returncode or re.search(r"runtime error:|Bad ref|DM runtime", log, re.I) or log.count("DONE shell compatibility") != 1:
                raise RuntimeError(log)
            failures = re.findall(r"^FAIL (.+)$", log, re.M)
            expected = {
                "tts": ["OpenDream makes no shell calls", "OpenDream creates no speech jobs", "OpenDream makes no generated audio lookup"],
                "dispatch": ["unsupported script rejected", "OpenDream makes no shell calls"],
            }.get(args.negative_control, [])
            if failures != expected or (not failures and log.count("PASS shell compatibility") != 1):
                raise RuntimeError(log)
            results.append({"mode": mode, "expected_failures": failures, "status": "passed"})
    receipt = {"head_sha": commit, "negative_control": args.negative_control, "checks": results,
               "scope": "Pinned native compiler executes both preprocessing branches with external-effect adapters; not an OpenDream engine or live-game test."}
    (args.output / "result.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    print(json.dumps(receipt))


if __name__ == "__main__":
    main()
