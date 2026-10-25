"""Strict pure-data native result oracles. No engine, process or network access."""
import json
import re
from pathlib import Path
from prepare import HEAD, TREE, VERSION, MODES

TARGETS = {"overlay-omission": "appearance_present", "melt-omission": "warm_debit_rejects",
           "generation-omission": "stale_after_reaccumulation",
           "reload-generation-omission": "fresh_wait_invalidated_by_reload",
           "reload-sampling": "reload_zero_no_accrual",
           "del-unregister-omission": "replacement_registry_exact"}
FATAL = re.compile(r"SNOW_FATAL|\b(?:FAIL:|BUG:|RUNTIME:|warning:|error:)|runtime error|Runtime in|"
                   r"unexpected runtime|bad ref|bad loc|segmentation|fatal error|out of memory|"
                   r"access violation|infinite loop|##\s*ERROR|cleanup failed", re.I)


def expected_assertions():
    value = json.loads(Path(__file__).with_name("expected-assertions.json").read_text())
    if set(value) != set(MODES):
        raise ValueError("Wrong expected mode inventory")
    for mode, names in value.items():
        if (not isinstance(names, list) or not names or len(names) != len(set(names)) or
                any(not isinstance(name, str) or not re.fullmatch(r"[a-z][a-z0-9_]{1,79}", name)
                    for name in names)):
            raise ValueError("Invalid expected assertion names")
        if mode in TARGETS and TARGETS[mode] not in names:
            raise ValueError("Missing causal target")
    return value


def verify_listener_log(log):
    opened = re.findall(r"World opened on network port (\d+) for address ([^\s]+)\.", log)
    if (len(opened) > 1 or log.count("World opened on network port") != len(opened) or
            any(host != "127.0.0.1" or not 1 <= int(port) <= 65535 for port, host in opened)):
        raise ValueError("Unexpected listener bind")
    if opened:
        close = log.find("World no longer opened to new users.")
        if close < log.find("World opened on network port"):
            raise ValueError("Startup bind lacks closure")


def verify_logs(mode, assertions, log):
    if FATAL.search(log):
        raise ValueError("Native engine diagnostic")
    verify_listener_log(log)
    found = re.findall(r"^SNOW_ASSERT ([a-z][a-z0-9_]+)=([01])\s*$", log, re.M)
    if len(found) != len(assertions) or len({name for name, _ in found}) != len(found):
        raise ValueError("Missing or duplicate assertion logs")
    if {name: int(value) for name, value in found} != assertions:
        raise ValueError("Assertion logs differ from result")
    if log.count("SNOW_ASSERT ") != len(found):
        raise ValueError("Malformed assertion log")
    final = re.findall(r"^SNOW_RESULT ([a-z0-9-]+)\s*$", log, re.M)
    if final != [mode] or log.count("SNOW_RESULT ") != 1:
        raise ValueError("Missing, repeated or unbound completion marker")
    if log.rfind("SNOW_ASSERT ") > log.index("SNOW_RESULT "):
        raise ValueError("Assertion after completion")


def verify_result(mode, result, runtime):
    if mode not in MODES:
        raise ValueError("Unknown mode")
    if not isinstance(result, dict) or set(result) != {"head", "tree", "version", "mode", "checks", "failed", "assertions"}:
        raise ValueError("Unexpected result schema")
    if any(result[key] != expected for key, expected in
           (("head", HEAD), ("tree", TREE), ("version", VERSION), ("mode", mode))):
        raise ValueError("Unbound source/version/mode")
    expected = expected_assertions()[mode]
    values = result["assertions"]
    if not isinstance(values, dict) or set(values) != set(expected):
        raise ValueError("Incomplete or unexpected assertion set")
    if any(type(value) is not int or value not in (0, 1) for value in values.values()):
        raise ValueError("Assertion values must be native integer zero/one")
    if type(result["checks"]) is not int or result["checks"] != len(expected):
        raise ValueError("Incorrect assertion count")
    failed = [name for name in expected if values[name] == 0]
    if type(result["failed"]) is not int or result["failed"] != len(failed):
        raise ValueError("Incorrect failure count")
    required = [] if mode == "baseline" else [TARGETS[mode]]
    if failed != required:
        raise ValueError("Wrong causal failure set: " + repr(failed))
    verify_logs(mode, values, runtime)
    return {"status": "passed" if mode == "baseline" else "causal-control-detected",
            "checks": len(expected), "expected_failures": failed}


def verify_auxiliary(logs):
    for name, content in logs.items():
        if FATAL.search(content):
            raise ValueError("Native diagnostic in " + name)
        verify_listener_log(content)
