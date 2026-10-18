"""Prepare frozen private test packets. NEVER start BYOND, clients or services.

Only Git read commands and local file writes occur. Actual execution requires
the core native lease and parent approval, after vehicle/sender priority.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess

from wait_overlay import unguarded_source

PROFILES = ("compile_stock", "compile_disabled", "compile_enabled", "headless", "baseline",
            "disabled", "no_hook", "omit_entry", "omit_wake", "omit_final", "reacquire")
GUARDS = {
    "omit_entry": "\t\tif (!gameplay_lease.claim_gather_wait(user, target))\n\t\t\treturn FALSE\n",
    "omit_wake": "\t\tif (gameplay_lease && !gameplay_lease.valid())\n\t\t\t. = FALSE\n\t\t\tbreak\n",
    "omit_final": "\tif (gameplay_lease && !gameplay_lease.valid())\n\t\t. = FALSE\n",
}
NATIVE = "tests/gameplay_bridge/native/"
UNUSED_RESOURCE_MACROS = ("CUSTOM_ITEM_OBJ", "CUSTOM_ITEM_MOB", "CUSTOM_ITEM_SYNTH")


def profile_contract(name):
    if name not in PROFILES:
        raise ValueError("unknown profile")
    return {"expected": "compile_only" if name.startswith("compile_") else ("assertion_failure" if name.startswith("omit_") or name == "reacquire" else "pass"),
            "dme": "source/"+name+".dme", "runtime_cwd": "runtime/"+name,
            "compile_seconds": 180, "runtime_seconds": 90, "world_tick_ceiling": 800,
            "dimensions": [1,1,1] if name.startswith("compile_") else [9,9,1]}


def git(root, *args):
    return subprocess.check_output(["git", *args], cwd=root, timeout=30)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def without_comments(source):
    """Preserve quoted text/newlines while excluding DM line/block comments."""
    output, i, quote, depth = [], 0, None, 0
    while i < len(source):
        pair, char = source[i:i+2], source[i]
        if depth:
            if pair == "/*":
                depth += 1; i += 2
            elif pair == "*/":
                depth -= 1; i += 2
            else:
                output.append("\n" if char == "\n" else " "); i += 1
        elif quote:
            output.append(char); i += 1
            if char == "\\" and i < len(source):
                output.append(source[i]); i += 1
            elif char == quote:
                quote = None
        elif pair == "/*":
            depth = 1; i += 2
        elif pair == "//":
            end = source.find("\n",i)
            i = len(source) if end < 0 else end
        else:
            output.append(char); i += 1
            if char in ("'", '"'):
                quote = char
    return "".join(output)


def resource_literals(source):
    """Single-quoted resources outside text/comments, including interpolation."""
    modes, result, i = [["code",0]], [], 0
    while i < len(source):
        mode = modes[-1][0]
        char, pair = source[i], source[i:i+2]
        if mode in ("text","longtext"):
            if char == "\\":
                i += 2
            elif mode == "longtext" and pair == '"}':
                modes.pop(); i += 2
            elif mode == "text" and char == '"':
                modes.pop(); i += 1
            elif char == "[":
                modes.append(["expression",1]); i += 1
            else:
                i += 1
        elif pair == "//":
            end = source.find("\n",i)
            i = len(source) if end < 0 else end
        elif pair == "/*":
            depth, i = 1, i+2
            while i < len(source) and depth:
                if source[i:i+2] == "/*": depth += 1; i += 2
                elif source[i:i+2] == "*/": depth -= 1; i += 2
                else: i += 1
        elif pair == '{"':
            modes.append(["longtext",0]); i += 2
        elif char == '"':
            modes.append(["text",0]); i += 1
        elif char == "'":
            begin, i = i+1, i+1
            while i < len(source) and source[i] != "'":
                i += 2 if source[i] == "\\" else 1
            if i >= len(source):
                raise ValueError("unclosed DM resource literal")
            result.append(source[begin:i]); i += 1
        else:
            if mode == "expression":
                if char == "[": modes[-1][1] += 1
                elif char == "]":
                    modes[-1][1] -= 1
                    if not modes[-1][1]: modes.pop()
            i += 1
    return result


def isolated_startup(world, globals_source):
    marker = "/world/New()"
    if world.count(marker) != 1 or world.count("/datum/global_init/New()\n") != 1:
        raise ValueError("world startup drift")
    world = world.replace(marker, "/world/proc/unused_gameplay_packet_startup()", 1)
    start = world.index("/world/proc/unused_gameplay_packet_startup()")
    next_proc = re.search(r"\n/[^/\n]",world[start:])
    end = start + next_proc.start() if next_proc else len(world)
    tail = world[start:end]
    # A renamed proc cannot contain the original New's parent call.
    if len(re.findall(r"^\t\.\.\(\)$", tail, re.M)) != 1:
        raise ValueError("world parent drift")
    tail = re.sub(r"^\t\.\.\(\)$", "", tail, count=1, flags=re.M)
    world = world[:start] + tail + world[end:]
    world = world.replace("/datum/global_init/New()\n", "/datum/global_init/New()\n\treturn\n", 1)
    marker = "/datum/controller/global_vars/New()\n"
    if globals_source.count(marker) != 1:
        raise ValueError("global startup drift")
    return world, globals_source.replace(marker, marker + "\tGLOB = src\n\treturn\n", 1)


def helper_variant(source, profile):
    # Reconstructing exactly rejects drift before producing any control.
    baseline = unguarded_source(source)
    if profile in ("baseline", "no_hook"):
        return baseline
    if profile in GUARDS:
        marker = GUARDS[profile]
        if source.count(marker) != 1:
            raise ValueError("guard anchor drift")
        return source.replace(marker, "", 1)
    if profile == "reacquire":
        marker = "\t\tsleep(0.1)\n"
        begin, end = source.index("/proc/do_after("), source.index("//Returns a list of all mobs", source.index("/proc/do_after("))
        body = source[begin:end]
        if body.count(marker) != 1:
            raise ValueError("sleep anchor drift")
        body = body.replace(marker, marker + "#ifdef CIV13_GAMEPLAY_BRIDGE\n\t\tgameplay_lease = gameplay_context\n#endif\n", 1)
        return source[:begin] + body + source[end:]
    return source


def selected_files(root, tracked):
    """Production source, static assets, exact runtime dictionaries; no server config."""
    by_case = {}
    for path in tracked:
        by_case.setdefault(path.casefold(),[]).append(path)
    def canonical(path):
        if path in tracked:
            return path
        matches = by_case.get(path.casefold(),[])
        if len(matches) == 1:
            return matches[0] # Packet is explicitly Windows; retain tracked case.
        raise ValueError("untracked/missing or case-ambiguous file: " + path)
    selected = {p for p in tracked if p.startswith(("code/", "icons/", "sound/", "UI/", "interface/", "scripts/gameplay_bridge/", NATIVE,
                                                    "config/names/", "config/crafting/"))}
    selected |= {p for p in ("civ13.dme", "rust_g.dll") if p in tracked}
    # Stock defines mention absent optional Baystation custom art, but no source
    # expands those macros. Verify that fact; do not invent replacement assets.
    for p in selected:
        if p.endswith(".dm"):
            usage = "\n".join(line for line in without_comments((root/p).read_text(encoding="utf-8-sig")).splitlines() if not line.lstrip().startswith("#"))
            if any(re.search(r"\b"+macro+r"\b",usage) for macro in UNUSED_RESOURCE_MACROS):
                raise ValueError("optional resource macro now expanded; resolve real asset: " + p)
    # Scan only included sources; excluded legacy code can mention absent assets.
    pending = ["civ13.dme", "code/modules/gameplay_bridge/bridge.dm",
               NATIVE + "compile_probe.dm", NATIVE + "headless_probe.dm", NATIVE + "client_assertions.dm"]
    visited = set()
    while pending:
        p = pending.pop()
        if p in visited:
            continue
        if p not in tracked:
            raise ValueError("missing source include: " + p)
        visited.add(p)
        selected.add(p)
        source = (root / p).read_text(encoding="utf-8-sig")
        for value in re.findall(r'^\s*#include\s+"([^"\n]+)"', without_comments(source), re.M):
            value = PurePosixPath(value.replace("\\", "/")).as_posix()
            if value.endswith(".dmm"):
                continue
            relative = (PurePosixPath(p).parent / value).as_posix()
            candidate = relative if relative.casefold() in by_case else value
            candidate = canonical(candidate)
            if candidate.endswith((".dm", ".dme")):
                pending.append(candidate)
            selected.add(candidate)
        resource_source = re.sub(r'^\s*#define (?:' + "|".join(UNUSED_RESOURCE_MACROS) + r')\b[^\n]*', "",source,flags=re.M)
        for value in resource_literals(resource_source):
            if not re.fullmatch(r"[^\n]+\.(?:dmi|png|jpg|gif|ogg|wav|mid|ttf|otf|bmp|ico)",value,re.I):
                continue
            value = PurePosixPath(value.replace("\\", "/")).as_posix()
            selected.add(canonical(value))
    if "rust_g.dll" not in selected or not any(p.startswith("config/names/") for p in selected):
        raise ValueError("required Windows runtime assets absent")
    return sorted(selected)


def prepare(root, output, expected_commit):
    root, output = root.resolve(), output.resolve()
    if output.exists() or output == root or root in output.parents:
        raise ValueError("use a fresh output directory outside the checkout")
    head = git(root, "rev-parse", "HEAD").decode().strip()
    if head != expected_commit or git(root, "status", "--porcelain", "--untracked-files=all").strip():
        raise ValueError("exact clean frozen HEAD required")
    # Historical ambient/craft probes are deliberately not reusable for typed
    # gather. Keep their source for review, never emit executable stale packets.
    raise ValueError("typed gather native fixture not reconciled; preparation disabled")



def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--expected-commit", required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    manifest = prepare(root, args.output, args.expected_commit)
    print(json.dumps({"commit": manifest["commit"], "state": manifest["state"], "files": len(manifest["sha256"]), "output": str(args.output.resolve())}))


if __name__ == "__main__":
    main()
