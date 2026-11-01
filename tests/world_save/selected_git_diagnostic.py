"""Bounded, nonsecret Git diagnostics before the selected-toolchain source test."""
from __future__ import annotations

import json
import os
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
LIMIT_SECONDS = 20
REFS = {
    "f05659dd5d117302b7ab494ad6e226f2b3f50ab1": (
        ".github/workflows/test.yml", "tests/world_save/run-durable-world.py",
        "tests/world_save/run-cross-level.py", "tests/world_save/run-sleep-transfer.py",
        "tests/world_save/run-dimension-bootstrap.py", "tests/world_save/run-reader-contract.py",
        "tests/world_save/partial_save_inspector/inspect-partial-save.py"),
    "d0ffbfb2335eb735756b998f3f2ff617c28f144b": (
        "code/modules/organs/wound.dm", "code/modules/persistence/loading.dm"),
    "eedc9862fcb7b2b7c3617c6972965fafa650e51a": (
        ".github/workflows/test.yml", "tests/world_save/run-cross-level.py"),
}
ENV_FLAGS = ("GIT_DIR", "GIT_WORK_TREE", "GIT_COMMON_DIR", "GIT_OBJECT_DIRECTORY",
             "GIT_ALTERNATE_OBJECT_DIRECTORIES", "GIT_REPLACE_REF_BASE",
             "GIT_NO_REPLACE_OBJECTS", "GIT_CONFIG_GLOBAL", "GIT_CONFIG_SYSTEM",
             "GIT_CONFIG_COUNT", "GIT_CONFIG_PARAMETERS", "GIT_SHALLOW_FILE",
             "GIT_NO_LAZY_FETCH")
INVOCATION_ORDER = (
    "test_sleep_transfer_sources.py", "test_cross_level_sources.py",
    "test_round_start_announcement.py", "test_irrigation_fixture_dependencies.py",
    "partial_save_inspector/test_inspector.py", "test_round_metadata_toolchain.py",
    "test_selected_git_diagnostic.py", "selected_git_diagnostic.py",
    "test_selected_toolchains.py")
HEX40 = re.compile(r"^[0-9a-f]{40}$")
REPLACE = re.compile(r"^refs/replace/([0-9a-f]{40}) ([0-9a-f]{40})$")


def reason(stderr):
    # Never copy Git stderr: it can contain URLs or private configuration.
    lower = stderr.lower()
    if "not a git repository" in lower: return "not_repository"
    if "invalid object name" in lower: return "invalid_object"
    if "bad object" in lower: return "bad_object"
    if "exists on disk, but not in" in lower: return "path_not_in_commit"
    if "needed a single revision" in lower: return "unresolved_revision"
    return "other_or_empty"


def collect(run=subprocess.run, monotonic=time.monotonic, environ=None):
    env = dict(os.environ if environ is None else environ)
    flags = {name: name in env for name in ENV_FLAGS}
    # Diagnostics must not trigger a partial clone's lazy network fetch.
    # This applies only to these child Git invocations, not the tested command.
    env["GIT_NO_LAZY_FETCH"] = "1"
    end = monotonic() + LIMIT_SECONDS
    incomplete = False

    def git(*args, discard=False):
        nonlocal incomplete
        remaining = end - monotonic()
        if remaining <= 0:
            incomplete = True
            return {"status": "deadline"}
        try:
            proc = run(["git", *args], cwd=ROOT, env=env, timeout=min(2, remaining),
                       stdout=subprocess.DEVNULL if discard else subprocess.PIPE,
                       stderr=subprocess.PIPE, text=True)
        except subprocess.TimeoutExpired:
            incomplete = True
            return {"status": "timeout"}
        except OSError:
            incomplete = True
            return {"status": "unavailable"}
        result = {"status": "exited", "exit": proc.returncode}
        if proc.returncode: result["reason"] = reason(proc.stderr or "")
        if not discard: result["_stdout"] = proc.stdout or ""
        return result

    def value(args, pattern):
        row = git(*args)
        output = row.pop("_stdout", "").strip()
        if row.get("exit") == 0 and pattern.fullmatch(output):
            row["value"] = output
        return row

    # Paths are requested explicitly; configuration and remote values are never emitted.
    def path_value(*args):
        row = git(*args)
        output = row.pop("_stdout", "").strip()
        if row.get("exit") == 0 and 0 < len(output) <= 4096 and "\n" not in output and "\r" not in output:
            row["value"] = output
        return row

    git_dir = path_value("rev-parse", "--absolute-git-dir")
    worktree = path_value("rev-parse", "--show-toplevel")
    head = value(("rev-parse", "--verify", "HEAD^{commit}"), HEX40)
    shallow = value(("rev-parse", "--is-shallow-repository"), re.compile(r"^(true|false)$"))
    config = git("config", "--local", "--get", "extensions.partialClone")
    config.pop("_stdout", None)  # A configured remote name may be private.
    partial = {**config, "configured": config.get("exit") == 0 if config.get("status") == "exited" else None}
    replace = git("for-each-ref", "--count=17", "--format=%(refname) %(objectname)", "refs/replace/")
    lines = replace.pop("_stdout", "").splitlines()
    pairs = [REPLACE.fullmatch(line) for line in lines]
    if replace.get("exit") == 0 and all(pairs):
        replace["refs"] = [{"original": m.group(1), "replacement": m.group(2)} for m in pairs[:16]]
        replace["truncated"] = len(pairs) > 16

    refs = {}
    for ref, paths in REFS.items():
        commit = value(("rev-parse", "--verify", ref + "^{commit}"), HEX40)
        tree = value(("rev-parse", "--verify", ref + "^{tree}"), HEX40)
        raw_tree = value(("--no-replace-objects", "rev-parse", "--verify", ref + "^{tree}"), HEX40)
        entries = {}
        for path in paths:
            target = ref + ":" + path
            entries[path] = {
                "exists": git("cat-file", "-e", target, discard=True),
                "blob": value(("rev-parse", "--verify", target), HEX40),
                "unreplaced_blob": value(("--no-replace-objects", "rev-parse", "--verify", target), HEX40),
                "show": git("show", target, discard=True),
            }
        refs[ref] = {"commit": commit, "tree": tree, "unreplaced_tree": raw_tree, "paths": entries}

    return {
        "schema": 1,
        "complete": not incomplete,
        "cwd": str(Path.cwd().resolve()),
        "fixture_root": str(ROOT),
        "invocation_order_expected": list(INVOCATION_ORDER),
        "env_overrides_present_only": flags,
        "diagnostic_children_disable_lazy_fetch": True,
        "git_dir": git_dir,
        "worktree": worktree,
        "head": head,
        "shallow": shallow,
        "partial_clone": partial,
        "replace_refs": replace,
        "historical": refs,
    }


def main():
    try:
        result = collect()
        status = 0 if result["complete"] else 1
    except Exception:
        # Diagnostic failure must not replace or suppress the following source test.
        result = {"schema": 1, "diagnostic_error": "collection_failed"}
        status = 1
    print("SELECTED_GIT_DIAGNOSTIC=" + json.dumps(result, sort_keys=True, separators=(",", ":")))
    return status


if __name__ == "__main__":
    raise SystemExit(main())
