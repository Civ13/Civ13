"""Offline adapter for the small DM subset used by water_proc/get_temp.

Executes translated production statements, with explicit synthetic spatial/type
adapters. This is not a DM compiler, native range oracle or gameplay evidence.
Unknown statements fail Python compilation rather than silently being skipped.
"""
import math
from pathlib import Path
import re
import subprocess
from types import SimpleNamespace as Record

BASE = "9db2b2f42a5fbbb0bdd49d50a2672da6111a7709"
ROOT = Path(__file__).resolve().parents[2]


def baseline(path):
    return subprocess.check_output(
        ["git", "show", f"{BASE}:{path}"], cwd=ROOT, text=True, encoding="utf-8")


def procedure(source, signature):
    start = source.index(signature)
    end = re.search(r"\n/[^/*]", source[start + len(signature):])
    stop = start + len(signature) + end.start() if end else len(source)
    return source[start:stop].rstrip() + "\n"


def expression(value):
    # Quoted text is opaque to the operator/type-path adapters.
    pieces = re.split(r'("[^"\n]*")', value)
    for i in range(0, len(pieces), 2):
        part = pieces[i].replace("&&", " and ").replace("||", " or ")
        part = re.sub(r"!(?!=)", "not ", part)
        part = re.sub(r"(?<![\w])/(?:\w+/)*\w+", lambda m: repr(m[0]), part)
        pieces[i] = part
    return "".join(pieces)


def compile_proc(source, *, water=False):
    output = ["def probe():"]
    if water:
        output.append("    global water")
    switches = set()
    for raw in source.splitlines()[1:]:
        line = raw.split("//", 1)[0].rstrip()
        if not line.strip():
            continue
        depth = len(line) - len(line.lstrip("\t"))
        if depth == 0:
            raise AssertionError(f"Unsupported indentation: {line!r}")
        text = line.strip()
        switches = {d for d in switches if d < depth}
        if text.startswith("switch ("):
            switches.add(depth)
            translated = "match " + expression(text[8:-1]) + ":"
        elif text.startswith("if ("):
            condition = expression(text[4:-1])
            translated = (f"case _case if _case == ({condition}):"
                          if depth - 1 in switches else f"if {condition}:")
        elif text.startswith("else if ("):
            translated = "elif " + expression(text[9:-1]) + ":"
        elif text == "else":
            translated = "else:"
        elif text.startswith("for ("):
            match = re.fullmatch(r"for \(var(.+)/([A-Za-z_]+) in range\((.+)\)\)", text)
            if not match:
                raise AssertionError(f"Unsupported loop: {text}")
            kind, name, args = match.groups()
            translated = f"for {name} in typed_range({kind!r}, {expression(args)}):"
        else:
            translated = re.sub(r"^var/(?:\w+/)*(\w+)", r"\1", text)
            translated = expression(translated)
        output.append("    " * depth + translated)
    namespace = {}
    exec(compile("\n".join(output), "<translated-production-DM>", "exec"), namespace)
    return namespace["probe"].__code__


def entity(kind, *, x=0, y=0, z=1, **values):
    return Record(kind=kind, x=x, y=y, z=z, **values)


def istype(obj, kind):
    return obj is not None and (obj.kind == kind or obj.kind.startswith(kind + "/"))


def execute(code, objects=(), **state):
    counts = {"range_calls": 0, "synthetic_candidates": 0, "typed_visits": 0}

    def typed_range(kind, radius, center):
        counts["range_calls"] += 1
        # Materialize the synthetic range once, as the production range() call does.
        nearby = [obj for obj in objects if obj.z == center.z and
                  max(abs(obj.x - center.x), abs(obj.y - center.y)) <= radius]
        counts["synthetic_candidates"] += len(nearby)
        for obj in nearby:
            if istype(obj, kind):
                counts["typed_visits"] += 1
                yield obj

    def set_dead(reason):
        state["stage"] = 11
        state["death"] = reason

    namespace = dict(state, typed_range=typed_range, istype=istype,
                     get_area=lambda obj: state.get("area"),
                     findtext=lambda text, needle: needle.lower() in text.lower(),
                     set_dead=set_dead, list=lambda *args: args, round=math.floor,
                     TRUE=True, FALSE=False, null=None,
                     AREA_INSIDE=1, MAP_ANTARCTICA="antarctica",
                     WEATHER_NONE=0, WEATHER_WET=1, WEATHER_EXTREME=2)
    from types import FunctionType
    result = FunctionType(code, namespace)()
    return result, namespace.get("water"), state.get("stage"), state.get("death"), counts
