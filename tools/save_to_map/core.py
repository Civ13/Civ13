"""Synthetic static-source export core. Never reads BYOND saves or runs a game."""
from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import dataclass
import hashlib
import json
import math
import os
from pathlib import Path
import stat
import sys

BASELINE = "fa363b8a01ed7d936c10a6303ce1be4c26d82ab0"
POLICY = "static-map-v0"
PROFILE = "synthetic-static-v0"
FLOOR = "/turf/floor/wood"
WALL = "/turf/wall/iron"
CHAIR = "/obj/structure/bed/chair"
LANDMARK = "/obj/effect/landmark"
AREA = "/area/caribbean/dark"
SPAWN = "JoinLateCivilian"
DEFAULTS = "synthetic_constructor_defaults"
EXCLUDED_FIELDS = {
    "name": "user_text_field", "desc": "user_text_field",
    "key": "identity_field", "ckey": "identity_field", "client": "identity_field",
    "keycode": "credential_field", "custom_code": "credential_field",
    "password": "credential_field", "token": "credential_field",
    "original_target": "runtime_field", "appearance": "runtime_field",
    "light": "runtime_field", "light_sources": "runtime_field",
}


class CoreError(ValueError):
    """Only fixed internal reason codes may cross the reporting boundary."""


@dataclass(frozen=True)
class Limits:
    input_bytes: int = 1_048_576
    output_bytes: int = 2_097_152
    cells: int = 4096
    levels: int = 8
    objects: int = 4096
    per_cell: int = 32
    fields: int = 64
    nodes: int = 65536
    depth: int = 16
    text_bytes: int = 256
    report_groups: int = 64


def require(condition, code="invalid_input"):
    if not condition:
        raise CoreError(code)


def checked_limits(limits):
    maximum = Limits()
    for key, value in vars(limits).items():
        require(type(value) is int and 0 < value <= getattr(maximum, key), "invalid_limits")
    require(limits.output_bytes >= 512, "invalid_limits")


def check_tree(value, limits):
    """Bound the whole input, including skipped payloads; never interpret them."""
    count = 0
    active = set()

    def visit(item, depth):
        nonlocal count
        count += 1
        require(count <= limits.nodes and depth <= limits.depth, "limit_exceeded")
        if type(item) in (dict, list):
            require(id(item) not in active, "cyclic_input")
            active.add(id(item))
            if type(item) is dict:
                require(len(item) <= limits.fields, "limit_exceeded")
                for key, child in item.items():
                    require(type(key) is str and len(key.encode("utf-8")) <= 96, "invalid_input")
                    visit(child, depth + 1)
            else:
                for child in item:
                    visit(child, depth + 1)
            active.remove(id(item))
        elif type(item) is str:
            require(len(item.encode("utf-8")) <= limits.text_bytes, "limit_exceeded")
        elif type(item) in (int, float):
            require(math.isfinite(item) and abs(item) <= 1e12, "invalid_number")
        else:
            require(item is None or type(item) is bool, "invalid_input")

    visit(value, 0)


def keys(value, required, optional=()):
    require(type(value) is dict and set(required) <= value.keys()
            and value.keys() <= set(required) | set(optional))


def json_bytes(value):
    return (json.dumps(value, sort_keys=True, indent=2, ensure_ascii=True, allow_nan=False) + "\n").encode()


def dm_literal(value):
    """Encode data as a DM literal, never an expression; native compatibility unrun."""
    if value is None:
        return "null"
    if type(value) is int:
        require(abs(value) <= 1e12, "invalid_literal")
        return str(value)
    require(type(value) is str and len(value.encode("utf-8")) <= 256, "invalid_literal")
    # Escape backslash first, then interpolation/control syntax. DM has no \r.
    require(all(ord(char) >= 32 or char in "\n\t" for char in value), "invalid_literal")
    require(all(ord(char) != 127 and not 0xD800 <= ord(char) <= 0xDFFF for char in value), "invalid_literal")
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    escaped = escaped.replace("[", "\\[").replace("]", "\\]")
    escaped = escaped.replace("\n", "\\n").replace("\t", "\\t")
    return '"' + escaped + '"'


class Dispositions:
    def __init__(self, limits):
        self.groups = Counter()
        self.counts = Counter()
        self.limits = limits

    def add(self, reason, category, count=1):
        self.groups[reason, category] += count

    def field(self, name):
        self.counts["excluded_fields"] += 1
        self.add("excluded_by_policy", EXCLUDED_FIELDS[name])

    def report(self, status):
        groups = sorted(self.groups.items())
        visible = groups[:self.limits.report_groups]
        return {
            "schema_version": 1, "scope": "synthetic_static_source_core",
            "policy_id": POLICY, "profile_id": PROFILE, "status": status, "ready": False,
            "geometry_status": {"static_source_only": "complete", "incomplete_preview": "incomplete"}.get(status, "rejected"),
            "playability_status": "unverified_proposed_profile", "compile_status": "not_run",
            "native_round_trip": "not_run", "topology_provenance": "synthetic_only",
            "privacy_validation": "allowlist_projection_only_no_real_data",
            "counters": dict(sorted(self.counts.items())),
            "counter_scope": "examined_projection_before_acceptance",
            "uninspected_descendant_count": None if self.counts["uninspected_subtrees"] else 0,
            "groups": [{"reason": reason, "category": category, "count": count}
                       for (reason, category), count in visible],
            "details_truncated": len(groups) > len(visible),
            "overflow_group_count": len(groups) - len(visible),
            "overflow_dispositions": sum(count for _, count in groups[len(visible):]),
            "next_actions": ["review_companion_profile", "verify_native_source_compatibility"],
        }


def fields(record, allowed, dispositions):
    """Unknown semantics make the static record unsupported, not a silent reset."""
    values = record.get("vars", {})
    require(type(values) is dict)
    unsupported = False
    for name in values:
        if name in allowed:
            continue
        if name in EXCLUDED_FIELDS:
            dispositions.field(name)
        else:
            dispositions.counts["unsupported_fields"] += 1
            dispositions.add("unsupported_static", "unknown_field")
            unsupported = True
    return values, unsupported


def atom_text(type_path, values):
    # All callers pass an exact catalog type and only prevalidated variable names.
    require(type_path in (FLOOR, WALL, CHAIR, LANDMARK, AREA), "invalid_literal")
    if not values:
        return type_path
    require(values.keys() <= {"dir", "pixel_x", "pixel_y", "name"}, "invalid_literal")
    return type_path + "{" + "; ".join(key + " = " + dm_literal(values[key]) for key in sorted(values)) + "}"


def project(data, dispositions, limits, preview):
    keys(data, {"schema_version", "kind", "profile_id", "provenance", "dimensions", "cells"})
    require(type(data["schema_version"]) is int and data["schema_version"] == 1)
    require(data["kind"] == "synthetic_static_source" and data["profile_id"] == PROFILE, "unsupported_input_kind")
    require(data["provenance"] == {"kind": "synthetic_authored_fixture", "source_commit": BASELINE,
                                   "topology": "synthetic_complete"}, "unsupported_provenance")
    dims = data["dimensions"]
    require(type(dims) is list and len(dims) == 3 and all(type(v) is int and v > 0 for v in dims))
    maxx, maxy, maxz = dims
    require(maxx * maxy * maxz <= limits.cells and maxz <= limits.levels, "limit_exceeded")
    require(type(data["cells"]) is list and len(data["cells"]) == maxx * maxy * maxz, "incomplete_grid")
    grid = {}
    objects_seen = 0
    spawns = 0
    for cell in data["cells"]:
        keys(cell, {"x", "y", "z", "turf", "area", "objects"})
        coord = tuple(cell[axis] for axis in ("x", "y", "z"))
        require(all(type(v) is int and 1 <= v <= bound for v, bound in zip(coord, dims)), "invalid_coordinate")
        require(coord not in grid, "duplicate_cell")
        turf = cell["turf"]
        keys(turf, {"type", "defaults"}, {"vars"})
        require(turf["type"] in (FLOOR, WALL), "unsupported_terrain")
        require(turf["defaults"] == DEFAULTS, "unproven_defaults")
        _, unsupported = fields(turf, set(), dispositions)
        require(not unsupported, "unsupported_terrain_field")
        require(cell["area"] == AREA, "unsupported_topology")
        require(type(cell["objects"]) is list and len(cell["objects"]) <= limits.per_cell, "limit_exceeded")
        atoms = []
        structure_here = False
        spawn_here = False
        for record in cell["objects"]:
            objects_seen += 1
            require(objects_seen <= limits.objects, "limit_exceeded")
            require(type(record) is dict and type(record.get("type")) is str)
            path = record["type"]
            if path.startswith(("/mob/", "/client/")) or path in ("/mob", "/client"):
                dispositions.counts["excluded_entity_roots"] += 1
                dispositions.counts["uninspected_subtrees"] += 1
                dispositions.add("excluded_by_policy", "player_or_npc_and_contents")
                continue
            if path not in (CHAIR, LANDMARK):
                dispositions.counts["unsupported_objects"] += 1
                dispositions.counts["uninspected_subtrees"] += 1
                dispositions.add("unsupported_static", "unknown_static_type")
                continue
            keys(record, {"type", "defaults"}, {"vars", "contents"})
            require(record["defaults"] == DEFAULTS, "unproven_defaults")
            allowed = {"dir", "pixel_x", "pixel_y"} if path == CHAIR else {"name"}
            values, unsupported = fields(record, allowed, dispositions)
            contents = record.get("contents", [])
            require(type(contents) is list)
            if contents:
                dispositions.counts["excluded_content_roots"] += 1
                dispositions.counts["uninspected_subtrees"] += 1
                dispositions.add("excluded_by_policy", "nested_contents")
            admitted = {name: value for name, value in values.items() if name in allowed}
            if path == CHAIR:
                for name, value in admitted.items():
                    require(type(value) is int and (value in (1, 2, 4, 8) if name == "dir" else -32 <= value <= 32), "invalid_property")
            else:
                require(admitted == {"name": SPAWN}, "invalid_spawn")
                require(not contents, "invalid_spawn")
            if unsupported:
                dispositions.counts["unsupported_objects"] += 1
                continue
            if path == CHAIR:
                structure_here = True
            else:
                spawn_here = True
                spawns += 1
            dispositions.counts["retained_objects"] += 1
            dispositions.counts["retained_fields"] += len(admitted)
            atoms.append(atom_text(path, admitted))
        require(not spawn_here or (turf["type"] == FLOOR and not structure_here), "blocked_spawn")
        atoms.extend((turf["type"], AREA))
        grid[coord] = "(" + ",".join(atoms) + ")"
        dispositions.counts["retained_cells"] += 1
    require(spawns > 0, "missing_spawn")
    has_loss = dispositions.counts["unsupported_objects"] > 0
    if has_loss and not preview:
        raise CoreError("unsupported_static")
    return dims, grid, "incomplete_preview" if has_loss else "static_source_only"


def render_dmm(dims, grid, limit):
    models = sorted(set(grid.values()))
    width = 2
    while 26 ** width < len(models):
        width += 1

    def key(number):
        chars = []
        for _ in range(width):
            chars.append(chr(97 + number % 26))
            number //= 26
        return "".join(reversed(chars))

    palette = {model: key(i) for i, model in enumerate(models)}
    parts = []
    size = 0

    def append(text):
        nonlocal size
        encoded = text.encode("utf-8")
        size += len(encoded)
        require(size <= limit, "limit_exceeded")
        parts.append(encoded)

    for model in models:
        append('"' + palette[model] + '" = ' + model + "\n")
    maxx, maxy, maxz = dims
    for z in range(1, maxz + 1):
        append('\n(1,1,' + str(z) + ') = {"\n')
        for y in range(maxy, 0, -1):
            append("".join(palette[grid[x, y, z]] for x in range(1, maxx + 1)) + "\n")
        append('"}\n')
    return b"".join(parts)


def build(data, *, preview=False, limits=Limits()):
    """Pure in-memory conversion of bounded synthetic canonical data."""
    try:
        checked_limits(limits)
    except CoreError:
        report = {"schema_version": 1, "status": "rejected", "ready": False, "reason": "invalid_limits"}
        return {"report.json": json_bytes(report)}, report
    dispositions = Dispositions(limits)
    output = {}
    try:
        checked_limits(limits)
        check_tree(data, limits)
        dims, grid, status = project(data, dispositions, limits, preview)
        output["geometry.dmm"] = render_dmm(dims, grid, limits.output_bytes)
    except CoreError as error:
        status = "rejected"
        dispositions.add("invalid_input" if str(error) not in {"unsupported_static", "unsupported_topology", "unsupported_terrain", "unsupported_terrain_field", "unproven_defaults", "unsupported_provenance", "limit_exceeded"} else str(error), "static_projection")
        output.clear()
    except (RecursionError, OverflowError, UnicodeError, TypeError):
        status = "rejected"
        dispositions.add("invalid_input", "static_projection")
        output.clear()
    report = dispositions.report(status)
    output["report.json"] = json_bytes(report)
    output["report.txt"] = ("Synthetic static-source core: " + status + "\nPlayable: unverified\nCompilation: not run\n"
                            + "".join(row["reason"] + ": " + row["category"] + " (" + str(row["count"]) + ")\n" for row in report["groups"])).encode()
    output["manifest.json"] = json_bytes({
        "schema_version": 1, "source_commit": BASELINE, "policy_id": POLICY, "profile_id": PROFILE,
        "scope": "synthetic_static_source_core", "ready": False, "status": status,
        "companion_metadata": "not_generated_proposed_profile_only",
        "asset_dependency": "matching_Civ13_source_and_assets",
        "files": {name: hashlib.sha256(value).hexdigest() for name, value in sorted(output.items())},
    })
    # Reports are also bounded; retain only a fixed redacted failure if necessary.
    if sum(map(len, output.values())) + len(core_receipt(output)) > limits.output_bytes:
        report = {"schema_version": 1, "status": "rejected", "ready": False,
                  "reason": "limit_exceeded", "scope": "synthetic_static_source_core"}
        output = {"report.json": json_bytes(report)}
    return output, report


def core_receipt(output):
    return json_bytes({"scope": "synthetic_static_source_core", "ready": False,
                       "manifest_sha256": hashlib.sha256(output.get("manifest.json", b"")).hexdigest()})


def checked_path(path):
    """Refuse links/reparse points in all existing path components, without following them."""
    path = Path(os.path.abspath(path))
    for component in (*reversed(path.parents), path):
        try:
            info = component.lstat()
        except FileNotFoundError:
            continue
        require(not stat.S_ISLNK(info.st_mode) and not getattr(info, "st_file_attributes", 0) & 0x400, "unsafe_path")
    return path


def read_input(path, limits=Limits()):
    checked_limits(limits)
    path = checked_path(path)
    require(path.suffix.lower() == ".json", "unsupported_input_kind")
    fd = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0))
    with os.fdopen(fd, "rb") as stream:
        before = os.fstat(stream.fileno())
        require(stat.S_ISREG(before.st_mode) and before.st_nlink == 1, "unsafe_path")
        require(0 < before.st_size <= limits.input_bytes, "limit_exceeded")
        raw = stream.read(limits.input_bytes + 1)
        after = os.fstat(stream.fileno())
        require((before.st_size, before.st_mtime_ns, before.st_ino) == (after.st_size, after.st_mtime_ns, after.st_ino), "unstable_input")
        require(len(raw) <= limits.input_bytes, "limit_exceeded")

    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, "duplicate_key")
            result[key] = value
        return result

    def constant(_):
        raise CoreError("invalid_number")

    try:
        data = json.loads(raw.decode("utf-8"), object_pairs_hook=pairs, parse_constant=constant)
        check_tree(data, limits)
        return data
    except (UnicodeError, json.JSONDecodeError, RecursionError, OverflowError, ValueError) as error:
        if isinstance(error, CoreError):
            raise
        raise CoreError("invalid_json") from None


def exclusive_write(path, content, *, created=None):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0), 0o600)
    if created is not None:
        created.add(path.name)
    with os.fdopen(fd, "wb") as stream:
        info = os.fstat(stream.fileno())
        require(stat.S_ISREG(info.st_mode) and info.st_nlink == 1, "unsafe_path")
        stream.write(content)
        stream.flush()
        os.fsync(stream.fileno())


def write_package(target, output, report):
    """Create a fresh private directory; incomplete writes are retained without a receipt."""
    target = checked_path(target)
    require(target.parent.is_dir(), "invalid_output_parent")
    try:
        target.mkdir(mode=0o700, exist_ok=False)
    except FileExistsError:
        raise CoreError("output_exists") from None
    created = set()
    try:
        for name, content in sorted(output.items()):
            require(name in {"geometry.dmm", "report.json", "report.txt", "manifest.json"}, "invalid_output_name")
            exclusive_write(target / name, content, created=created)
            require((target / name).read_bytes() == content, "output_verification_failed")
        if report["status"] == "static_source_only":
            # This receipt confirms the offline core only. It never means playable.
            try:
                exclusive_write(target / "CORE_COMPLETE.json", core_receipt(output), created=created)
            except (OSError, CoreError):
                # Remove only our newly created receipt, never other package files.
                # If that fails, the outcome must remain explicitly uncertain.
                if "CORE_COMPLETE.json" in created:
                    try:
                        (target / "CORE_COMPLETE.json").unlink(missing_ok=True)
                    except OSError:
                        raise CoreError("package_write_uncertain") from None
                raise
    except (OSError, CoreError) as error:
        # Retain partial package files for inspection; never retry automatically.
        if isinstance(error, CoreError) and str(error) == "package_write_uncertain":
            raise
        raise CoreError("package_write_failed") from None


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True, help="Synthetic canonical JSON only")
    parser.add_argument("--output", type=Path, required=True, help="New nonexisting package directory")
    parser.add_argument("--preview", action="store_true", help="Allow explicitly incomplete static-object previews")
    args = parser.parse_args(argv)
    try:
        input_path = checked_path(args.input)
        output_path = checked_path(args.output)
        require(input_path != output_path and output_path not in input_path.parents, "input_output_overlap")
        data = read_input(input_path)
        output, report = build(data, preview=args.preview)
        write_package(output_path, output, report)
        print(json.dumps({"status": report["status"], "ready": False}, sort_keys=True))
        return 0 if report["status"] == "static_source_only" else 1
    except (CoreError, OSError) as error:
        reason = "package_write_uncertain" if isinstance(error, CoreError) and str(error) == "package_write_uncertain" else "input_or_package_rejected"
        print(json.dumps({"status": "rejected", "reason": reason, "ready": False}, sort_keys=True), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
