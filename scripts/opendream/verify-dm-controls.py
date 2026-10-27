"""Run actual fixed DM control procedures in a tiny isolated OpenDream world."""
import argparse
import json
from pathlib import Path
import re
import socket
import subprocess
import tempfile
import time


def free_port():
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--server", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    repository = Path(__file__).resolve().parents[2]
    helper = (repository / "code/processes/python.dm").read_text(encoding="utf-8")
    helper = helper[helper.index("/proc/opendream_control_request("):]
    world_source = (repository / "code/world.dm").read_text(encoding="utf-8")
    reboot = world_source[world_source.index("/world/Reboot("):world_source.index("#define COLOR_LIGHT_SEPIA")]
    guard = next(line for line in world_source.splitlines() if "if(!(host[1] in filtering_whitelist))" in line).strip().split(" //")[0]
    with tempfile.TemporaryDirectory(prefix="civ13-od-controls-") as directory:
        root = Path(directory)
        (root / "SQL/opendream-control").mkdir(parents=True)
        fixture = '''
/world
    maxx = 1
    maxy = 1
    maxz = 1
/proc/log_debug(message)
    return
/world/New()
    var/list/results = list()
#ifdef OPENDREAM
    results["opendream_define"] = TRUE
#else
    results["opendream_define"] = FALSE
#endif
    results["missing_supervisor_rejected"] = !opendream_control_request("restart")
    text2file("{}", "SQL/opendream-control/enabled.json")
    results["arbitrary_action_rejected"] = !opendream_control_request("shell")
    results["mapswap_queued"] = opendream_control_request("mapswap", "NOMADS")
    results["duplicate_rejected"] = !opendream_control_request("restart")
    var/list/request = json_decode(file2text("SQL/opendream-control/game-request.json"))
    results["paid_map_id_preserved"] = request["map"] == "NOMADS" && request["action"] == "mapswap"
    results["commit_marker"] = fexists("SQL/opendream-control/game-ready")
    fdel("SQL/opendream-control/game-request.json")
    fdel("SQL/opendream-control/game-ready")
    world.Reboot("isolated test")
    results["world_reboot_marker"] = fexists("SQL/opendream-control/game-ready")
    var/list/filtering_whitelist = list("127.0.0.1")
    var/list/host = list("127.0.0.1")
    var/rejected = FALSE
    GUARD
        rejected = TRUE
    results["default_loopback_whitelist"] = !rejected
    host = list("192.0.2.1")
    rejected = FALSE
    GUARD
        rejected = TRUE
    results["unlisted_host_filtered"] = rejected
    text2file(json_encode(results), "results.json")
'''.replace("GUARD", guard)
        # Only the OPENDREAM branch is needed; native legacy restart references
        # are intentionally excluded from this tiny world, never game sources.
        reboot = reboot[:reboot.index("\t#endif") + len("\t#endif")]
        (root / "probe.dme").write_text(helper + "\n" + reboot + "\n" + fixture, encoding="utf-8")
        with (root / "compile.log").open("wb") as log:
            subprocess.run([str(args.compiler.resolve()), "--version=516.1681", str(root / "probe.dme")],
                           cwd=root, stdout=log, stderr=subprocess.STDOUT, timeout=60, check=True)
        game_port, topic_port = free_port(), free_port()
        while topic_port == game_port:
            topic_port = free_port()
        config = '[net]\nbindto="127.0.0.1"\nport=' + str(game_port)
        config += '\n[status]\nenabled=false\n[hub]\nadvertise=false\n[auth]\nmode=2\n'
        config += '[opendream]\njson_path=' + json.dumps(str(root / "probe.json")) + '\ntopic_port=' + str(topic_port) + '\n'
        (root / "server.toml").write_text(config, encoding="utf-8")
        with (root / "server.log").open("wb") as log:
            process = subprocess.Popen([str(args.server.resolve()), "--config-file", str(root / "server.toml")],
                                       cwd=root, stdout=log, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL)
            try:
                deadline = time.monotonic() + 30
                while not (root / "results.json").exists():
                    if process.poll() is not None or time.monotonic() >= deadline:
                        raise RuntimeError((root / "server.log").read_text(errors="replace")[-3000:])
                    time.sleep(.1)
                results = json.loads((root / "results.json").read_text())
                results["world_reboot_queued"] = json.loads((root / "SQL/opendream-control/game-request.json").read_text())["action"] == "restart"
                args.output.parent.mkdir(parents=True, exist_ok=True)
                args.output.write_text(json.dumps(results, indent=2), encoding="utf-8")
                if not all(results.values()):
                    raise RuntimeError("DM control contract failed: " + str(results))
                print(json.dumps(results))
            finally:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)


if __name__ == "__main__":
    main()


