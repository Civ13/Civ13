"""Export a completed Civ13 world save to a new source map package.

    python3 tools/save_to_map/export.py --save-dir <copied map_saves> \
        --export-id riverside --title "Riverside" --output <new dir> \
        --byond-bin <BYOND bin> [--compile] [--preview]

Pipeline (docs/save-to-map-export.md): admit and copy a completed generation,
read every level with the standalone native reader (extract/extract.dme) or,
for stream levels, the stream file decoder, project the static built world
through tools/save_to_map/native_profile.json, then write a DMM, a companion
map metadata declaration, a manifest and a redacted report. --compile stages a
disposable root-local DME with the export as its only map and compiles it with
a missing-type control. Nothing here loads a save into the game, edits the
production DME or touches a server.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
from core import CoreError, checked_path, dm_literal, exclusive_write, json_bytes, require  # noqa: E402
from savestream_reader import Opaque, StreamError, StreamFile, TypePath  # noqa: E402

SCHEMA = 1
TYPE_ROOT = re.compile(r"^(?:atom|area|turf|obj|mob|datum|client|image)(?:/|\s|\(|$)")
TYPE_PATH = re.compile(r"^(/[A-Za-z_][A-Za-z0-9_]*)+$")
IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]{0,63}$")
EXPORT_ID = re.compile(r"^[a-z][a-z0-9_]{1,39}$")
SPAWN_NAME = re.compile(r"^[A-Za-z0-9_ -]{1,64}$")
LEVEL_FILE = re.compile(r"^(\d{1,2})(?:\.part(\d{1,6})|\.stream)?\.sav$")
GENERATION_FILES = ("map.txt", "round.json", "save_complete.txt")
MAX_INPUT_FILE = 2 << 30
MAX_CELLS = 4_000_000
REPORT_GROUPS = 512
ALPHABET = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"


def load_profile(path=HERE / "native_profile.json"):
    profile = json.loads(Path(path).read_text(encoding="utf-8"))
    require(profile.get("profile_id") == "native-static-v1", "invalid_profile")
    return profile


# ---------- source catalog ----------

def source_types(root=ROOT):
    """Type paths declared in the DM source: top-level paths and tab-nested children."""
    types = set()
    for folder in ("code", "maps"):
        for path in (root / folder).rglob("*.dm"):
            stack = []
            for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
                stripped = line.strip()
                if not stripped or stripped.startswith("//"):
                    continue
                depth = len(line) - len(line.lstrip("\t"))
                del stack[depth:]
                match = re.match(r"^(/?[A-Za-z_][A-Za-z0-9_/]*)\s*(?://.*)?$", stripped)
                if depth == 0:
                    stack = []
                    # DM also accepts top-level type paths without the leading slash.
                    if TYPE_ROOT.match(line):
                        line = "/" + line
                        stripped = "/" + stripped
                    if line.startswith("/"):
                        head = re.match(r"^(/[A-Za-z_][A-Za-z0-9_/]*?)(?:/(?:proc|verb|var)\b|\(|\s|$)", line)
                        if head:
                            types.add(head.group(1).rstrip("/"))
                            if re.fullmatch(r"/[A-Za-z_][A-Za-z0-9_/]*\s*(//.*)?", stripped):
                                stack = [head.group(1).rstrip("/")]
                    continue
                if match and stack and len(stack) == depth and "=" not in stripped:
                    name = match.group(1)
                    if name.split("/")[0] in ("var", "proc", "verb", "tmp", "global", "static", "const"):
                        continue
                    child = stack[-1] + "/" + name.strip("/")
                    types.add(child)
                    stack.append(child)
    # Every parent of a declared type exists.
    for path in list(types):
        parts = path.split("/")
        for end in range(2, len(parts)):
            types.add("/".join(parts[:end]))
    return types


# ---------- admission ----------

def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def inventory(save_dir):
    """Regular, unlinked generation files only; anything else is refused."""
    save_dir = checked_path(save_dir)
    require(save_dir.is_dir(), "missing_save_dir")
    files = {}
    for entry in sorted(os.scandir(save_dir), key=lambda item: item.name):
        info = entry.stat(follow_symlinks=False)
        if entry.name in GENERATION_FILES or LEVEL_FILE.match(entry.name):
            require(stat.S_ISREG(info.st_mode) and not stat.S_ISLNK(info.st_mode), "unsafe_input")
            require(info.st_size <= MAX_INPUT_FILE, "limit_exceeded")
            files[entry.name] = (info.st_size, sha256(entry.path))
    for name in GENERATION_FILES:
        require(name in files, "incomplete_generation")
    return save_dir, files


def stage_copy(save_dir, files, staging):
    level = staging / "level"
    level.mkdir()
    for name, (size, digest) in files.items():
        with open(save_dir / name, "rb") as source, open(level / name, "xb") as target:
            shutil.copyfileobj(source, target, 1 << 20)
        require(sha256(level / name) == digest and (level / name).stat().st_size == size, "unstable_input")
    return level


def round_metadata(level):
    """Only structural keys are read from round state; the rest is never retained."""
    state = json.loads((level / "round.json").read_text(encoding="utf-8"))
    require(type(state) is dict, "invalid_round_state")
    generation = (level / "save_complete.txt").read_text(encoding="utf-8").strip()
    require(state.get("generation") == generation and generation, "generation_mismatch")
    dims = [state.get(key) for key in ("maxx", "maxy", "maxz")]
    require(all(type(v) is int and v > 0 for v in dims), "invalid_dimensions")
    require(dims[0] * dims[1] * dims[2] <= MAX_CELLS and dims[2] <= 32, "limit_exceeded")
    world = state.get("world_state")
    topology = world.get("topology") if type(world) is dict else None
    require(type(topology) is dict and type(topology.get("zones")) is list, "topology_unavailable_in_save")
    zones = {}
    for row in topology["zones"]:
        require(type(row) is dict and type(row.get("id")) is str and type(row.get("type")) is str, "invalid_topology")
        require(TYPE_PATH.match(row["type"]) and row["type"].startswith("/area/"), "invalid_topology")
        require(row["id"] not in zones, "invalid_topology")
        zones[row["id"]] = row["type"]
    spawns = topology.get("spawns") if type(topology.get("spawns")) is dict else {}
    elevation = state.get("elevation")
    map_type = world.get("map_type") if type(world.get("map_type")) is str else None
    return {"generation": generation, "dims": dims, "zones": zones, "spawns": spawns,
            "elevation": elevation, "map_type": map_type}


# ---------- native extraction ----------

def compile_extractor(byond_bin, staging):
    work = staging / "reader"
    work.mkdir()
    for name in ("extract.dme", "extract.dm"):
        shutil.copyfile(HERE / "extract" / name, work / name)
    compiler = byond_bin / ("dm.exe" if os.name == "nt" else "DreamMaker")
    build = subprocess.run([str(compiler), "-max_errors", "0", "extract.dme"], cwd=work,
                           capture_output=True, text=True, timeout=300)
    log = build.stdout + build.stderr
    require(build.returncode == 0 and "0 errors, 0 warnings" in log and (work / "extract.dmb").is_file(), "reader_build_failed")
    return work


def run_reader(byond_bin, work, level, z, read_entries, timeout):
    """One isolated Dream Daemon per level; it reads only the disposable copy."""
    out = work / f"level{z}.jsonl"
    index = os.path.relpath(level / f"{z}.sav", work).replace(os.sep, "/")
    daemon = byond_bin / ("dd.exe" if os.name == "nt" else "DreamDaemon")
    params = f"index={index}&z={z}&out={out.name}&entries={1 if read_entries else 0}"
    subprocess.run([str(daemon), "extract.dmb", "0", "-ip", "127.0.0.1", "-trusted", "-invisible",
                    "-nowebclient", "-close", "-params", params],
                   cwd=work, capture_output=True, text=True, timeout=timeout)
    require(out.is_file(), "reader_failed")
    rows = [json.loads(line) for line in out.read_text(encoding="utf-8").splitlines() if line.strip()]
    require(rows and rows[-1].get("kind") == "end", "reader_failed")
    require(all(row.get("kind") in ("header", "cell", "entry", "end") for row in rows), "reader_failed")
    return rows


def params_refs(chunk):
    require(type(chunk) is str and len(chunk) <= 32000, "invalid_content")
    refs = []
    for part in re.split(r"[&;]", chunk):
        if not part:
            continue
        require(part.isdigit() and int(part) > 0, "invalid_content")
        refs.append(int(part))
    return refs


def scalar(value):
    if type(value) is list and len(value) == 2 and value[0] == ("kind", "value") and value[1][0] == "value":
        return value[1][1]
    return value


class StreamEntries:
    """Entry records of a format-5 level, projected exactly like the native reader's."""

    def __init__(self, path):
        self.file = StreamFile(path)

    def get(self, ref):
        base = f"/entries/{(ref - 1) // 512}/{ref}"
        names = self.file.children(base)
        require("type" in names, "missing_entry")
        type_value = self.file.get(base + "/type")
        numbers = {}
        for field in ("dir", "pixel_x", "pixel_y"):
            if field in names:
                value = scalar(self.file.get(base + "/" + field))
                if type(value) is float:
                    numbers[field] = value
        content = []
        if "content" in names:
            value = self.file.get(base + "/content")
            chunks = [value] if type(value) is str else value if type(value) is list else []
            for item in chunks:
                chunk = item if type(item) is str else item[0] if type(item) is tuple and len(item) == 1 else None
                content += params_refs(chunk)
        return {"ref": ref, "type": str(type_value) if isinstance(type_value, TypePath) else None,
                "fields": [name for name in names if name not in ("type", "content")],
                "num": numbers, "content": content}


def read_levels(level, byond_bin, meta, timeout=3600):
    staging = level.parent
    work = compile_extractor(byond_bin, staging)
    maxx, maxy, maxz = meta["dims"]
    levels = []
    for z in range(1, maxz + 1):
        require((level / f"{z}.sav").is_file(), "missing_level")
        rows = run_reader(byond_bin, work, level, z, True, timeout)
        header = rows[0]
        require(header.get("kind") == "header" and header.get("format") in (3, 4, 5), "unsupported_save_version")
        require(header.get("generation") == meta["generation"], "generation_mismatch")
        require([header.get("maxx"), header.get("maxy"), header.get("maxz")] == [maxx, maxy, maxz], "invalid_dimensions")
        cells = {}
        entries = {}
        for row in rows[1:-1]:
            if row["kind"] == "cell":
                coord = (row["x"], row["y"])
                require(type(row["x"]) is int and type(row["y"]) is int and coord not in cells, "duplicate_cell")
                cells[coord] = row
            elif row["kind"] == "entry":
                entries.setdefault(row["ref"], row)
        source = entries
        if header["format"] == 5:
            stream = level / f"{z}.stream.sav"
            require(stream.is_file(), "missing_stream")
            require(header.get("stream_file") == stream.name, "invalid_stream")
            try:
                source = StreamEntries(stream)
                require(source.file.get("/generation") == meta["generation"], "generation_mismatch")
            except (StreamError, KeyError, UnicodeError):
                raise CoreError("invalid_stream") from None
        levels.append({"z": z, "header": header, "cells": cells, "entries": source})
    return levels


def entry(source, ref):
    if isinstance(source, StreamEntries):
        try:
            return source.get(ref)
        except (StreamError, KeyError, UnicodeError):
            raise CoreError("invalid_stream") from None
    record = source.get(ref)
    require(record is not None, "missing_entry")
    return record


# ---------- projection ----------

class Report:
    def __init__(self):
        self.groups = Counter()
        self.counts = Counter()

    def add(self, reason, category, count=1):
        self.groups[reason, category] += count

    def render(self, status, compile_status="not_run"):
        groups = sorted(self.groups.items())
        visible = groups[:REPORT_GROUPS]
        return {
            "schema_version": SCHEMA, "scope": "native_save_static_export", "profile_id": "native-static-v1",
            "status": status, "ready": False,
            "geometry_status": {"complete": "complete", "incomplete_preview": "incomplete"}.get(status, "rejected"),
            "playability_status": "unverified_new_round", "compile_status": compile_status,
            "privacy_validation": "allowlist_projection_no_saved_text",
            "counters": dict(sorted(self.counts.items())),
            "groups": [{"reason": r, "category": c, "count": n} for (r, c), n in visible],
            "details_truncated": len(groups) > len(visible),
        }


def object_admitted(path, profile):
    if not any(path.startswith(root) for root in profile["object_roots"]):
        return False
    return not any(path.startswith(prefix) for prefix in profile["excluded_object_prefixes"])


def admitted_fields(record, profile, report, catalog_label):
    values = {}
    for name in record.get("fields", []):
        if name not in profile["fields"]:
            report.counts["reset_fields"] += 1
            report.add("reset_to_default", "saved_field:" + name if IDENT.match(str(name)) else "unknown_field")
            continue
        numbers = record.get("num")
        value = numbers.get(name) if type(numbers) is dict else None
        rule = profile["fields"][name]
        number = int(value) if type(value) in (int, float) and math.isfinite(value) and value == int(value) else None
        valid = number is not None and (number in rule["values"] if rule["kind"] == "integer_enum"
                                        else rule["minimum"] <= number <= rule["maximum"])
        if not valid:
            report.counts["reset_fields"] += 1
            report.add("reset_to_default", "invalid_placement_value")
            continue
        values[name] = number
        report.counts["retained_fields"] += 1
    return values


def atom_text(path, values):
    require(TYPE_PATH.match(path), "invalid_literal")
    if not values:
        return path
    require(all(IDENT.match(name) for name in values), "invalid_literal")
    return path + "{" + "; ".join(name + " = " + dm_literal(values[name]) for name in sorted(values)) + "}"


def spawn_markers(meta, profile, report):
    """Spawn landmarks from the saved spawn registry, by coordinate."""
    markers = {}
    spawns = meta["spawns"]

    def place(name, rows, category):
        if type(rows) is not list:
            return
        for row in rows:
            if type(row) is not dict or not all(type(row.get(axis)) is int for axis in ("x", "y", "z")):
                report.add("invalid_input", "spawn_row")
                continue
            if not SPAWN_NAME.match(name):
                report.add("excluded_by_policy", "unsafe_spawn_name")
                continue
            coord = (row["x"], row["y"], row["z"])
            markers.setdefault(coord, []).append(name)
            report.counts["spawn_markers"] += 1
            report.add("restored_from_save", category)

    latejoin = spawns.get("latejoin")
    if type(latejoin) is dict:
        for name in sorted(latejoin):
            place(name, latejoin[name], "latejoin_spawn")
    place("start", spawns.get("start"), "lobby_start")
    place("JoinLate", spawns.get("join"), "join_spawn")
    place("supplydrop", spawns.get("supply"), "supply_drop")
    return markers


def plain_cells(header, total):
    """A level's plain templates and its per-cell template numbers (0 for none)."""
    templates = header.get("plain_templates")
    if templates is None:
        return [], None
    runs = header.get("plain_runs")
    require(type(templates) is list and 1 <= len(templates) <= 255 and all(type(t) is dict for t in templates), "invalid_plain_cells")
    require(type(runs) is list and runs and len(runs) % 2 == 0, "invalid_plain_cells")
    cells = []
    for number, length in zip(runs[::2], runs[1::2]):
        require(type(number) in (int, float) and type(length) in (int, float), "invalid_plain_cells")
        require(number == int(number) and 0 <= number <= len(templates), "invalid_plain_cells")
        require(length == int(length) and length >= 1 and len(cells) + length <= total, "invalid_plain_cells")
        cells += [int(number)] * int(length)
    require(len(cells) == total, "invalid_plain_cells")
    return templates, cells


def project(levels, meta, profile, catalog, preview, report=None):
    report = report if report is not None else Report()
    maxx, maxy, maxz = meta["dims"]
    zones = meta["zones"]
    grid = {}
    unsupported = 0
    markers = spawn_markers(meta, profile, report)
    for level in levels:
        z = level["z"]
        header = level["header"]
        sparse_turf = header.get("sparse_turf")
        sparse_zone = header.get("sparse_zone")
        templates, plain = plain_cells(header, maxx * maxy)
        for y in range(1, maxy + 1):
            for x in range(1, maxx + 1):
                cell = level["cells"].get((x, y))
                atoms = []
                number = plain[(y - 1) * maxx + x - 1] if cell is None and plain else 0
                template = templates[number - 1] if number else None
                if template is not None:
                    turf_path, zone = template.get("type"), template.get("zone")
                    require(type(turf_path) is str and TYPE_PATH.match(turf_path), "invalid_turf")
                    if not (turf_path.startswith(tuple(profile["turf_roots"])) and turf_path in catalog):
                        raise CoreError("unsupported_terrain")
                    turf_path = atom_text(turf_path, admitted_fields(template, profile, report, "turf"))
                    report.counts["plain_cells"] += 1
                elif cell is None:
                    require(type(sparse_turf) is str and sparse_zone in zones, "incomplete_grid")
                    require(TYPE_PATH.match(sparse_turf) and sparse_turf in catalog, "unsupported_terrain")
                    turf_path, zone = sparse_turf, sparse_zone
                    report.counts["sparse_baseline_cells"] += 1
                else:
                    record = entry(level["entries"], cell["ref"])
                    turf_path = record.get("type")
                    zone = cell.get("zone")
                    require(type(turf_path) is str and TYPE_PATH.match(turf_path), "invalid_turf")
                    turf_values = {}
                    if turf_path.startswith(tuple(profile["turf_roots"])) and turf_path in catalog:
                        turf_values = admitted_fields(record, profile, report, "turf")
                    for child_ref in record.get("content", []):
                        child = entry(level["entries"], child_ref)
                        path = child.get("type")
                        report.counts["saved_objects"] += 1
                        if type(path) is not str or not TYPE_PATH.match(path):
                            report.counts["unsupported_objects"] += 1
                            report.add("unsupported_static", "unknown_static_type")
                            unsupported += 1
                            continue
                        if path.startswith(("/mob/", "/mob")):
                            report.counts["excluded_entity_roots"] += 1
                            report.add("excluded_by_policy", "player_or_npc_and_contents")
                            continue
                        if not object_admitted(path, profile):
                            report.counts["excluded_objects"] += 1
                            report.add("excluded_by_policy", path.split("/")[2] if path.count("/") >= 2 else "object")
                            continue
                        if path not in catalog:
                            # A well-formed type path missing from this checkout's source:
                            # name it, so the operator can add it to the profile or source.
                            report.counts["unsupported_objects"] += 1
                            report.add("unsupported_static", "type:" + path if len(path) <= 200 else "unknown_static_type")
                            unsupported += 1
                            continue
                        if child.get("content"):
                            report.counts["excluded_content_roots"] += 1
                            report.add("excluded_by_policy", "nested_contents")
                        atoms.append(atom_text(path, admitted_fields(child, profile, report, "object")))
                        report.counts["retained_objects"] += 1
                    if not (turf_path.startswith(tuple(profile["turf_roots"])) and turf_path in catalog):
                        raise CoreError("unsupported_terrain")
                    turf_path = atom_text(turf_path, turf_values)
                require(type(zone) is str and zone in zones, "topology_unavailable_in_save")
                area = zones[zone]
                require(area in catalog, "unsupported_topology")
                for name in markers.get((x, y, z), []):
                    atoms.append(atom_text("/obj/effect/landmark", {"name": name}))
                if (x, y, z) == (1, 1, 1):
                    atoms.append("{metadata}")
                atoms.extend((turf_path, area))
                grid[x, y, z] = "(" + ",".join(atoms) + ")"
                report.counts["retained_cells"] += 1
    report.counts["areas"] = len({model.rsplit(",", 1)[1] for model in grid.values()})
    required = profile["required_spawn_group"]
    if not any(required in names for names in markers.values()):
        report.add("playability_blocked", "missing_required_spawn")
        if not preview:
            raise CoreError("missing_spawn")
    if unsupported and not preview:
        raise CoreError("unsupported_static")
    return grid, report, "incomplete_preview" if unsupported or not markers else "complete"


def render_dmm(dims, grid, metadata_type):
    models = sorted(set(grid.values()))
    width = 1
    while len(ALPHABET) ** width < len(models):
        width += 1

    def key(number):
        chars = []
        for _ in range(width):
            chars.append(ALPHABET[number % len(ALPHABET)])
            number //= len(ALPHABET)
        return "".join(reversed(chars))

    palette = {model: key(i) for i, model in enumerate(models)}
    lines = ['"' + palette[model] + '" = ' + model.replace("{metadata}", metadata_type) for model in models]
    maxx, maxy, maxz = dims
    for z in range(1, maxz + 1):
        lines.append("")
        lines.append("(1,1," + str(z) + ') = {"')
        for y in range(maxy, 0, -1):
            lines.append("".join(palette[grid[x, y, z]] for x in range(1, maxx + 1)))
        lines.append('"}')
    return ("\n".join(lines) + "\n").encode("utf-8")


# ---------- companion metadata ----------

def elevation_lines(elevation, dims):
    if type(elevation) is not dict or elevation.get("version") != 1:
        return []
    if [elevation.get("maxx"), elevation.get("maxy"), elevation.get("maxz")] != list(dims):
        return []
    default = elevation.get("default_metres")
    regions = elevation.get("regions")
    if type(default) not in (int, float) or not math.isfinite(default) or type(regions) is not list or len(regions) > 256:
        return []
    rows = []
    for row in regions:
        keys = ("x1", "x2", "y1", "y2", "z", "metres")
        if type(row) is not dict or set(row) != set(keys) or not all(type(row[k]) in (int, float) and math.isfinite(row[k]) for k in keys):
            return []
        rows.append("list(" + ", ".join(f'"{k}" = {format_number(row[k])}' for k in keys) + ")")
    lines = [f"\televation_default_metres = {format_number(default)}"]
    if rows:
        lines.append("\televation_regions = list(" + ", ".join(rows) + ")")
    return lines


def format_number(value):
    return str(int(value)) if value == int(value) else repr(float(value))


def terrain_height_file(map_type, root=ROOT):
    """The source map's terrain height file, when its metadata declares one."""
    if not map_type or not TYPE_PATH.match(map_type):
        return None
    for path in (root / "code/game/objects/map_metadata").rglob("*.dm"):
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        for number, line in enumerate(lines):
            if line.rstrip() != map_type:
                continue
            for body in lines[number + 1:]:
                if body and not body.startswith(("\t", " ")):
                    break
                match = re.match(r'^\s+terrain_height_file\s*=\s*"([A-Za-z0-9_./-]+\.txt)"\s*$', body)
                if match and (root / match.group(1)).is_file():
                    return match.group(1)
    return None


def metadata_source(export_id, title, profile, meta, height_file):
    type_path = "/obj/map_metadata/export_" + export_id
    map_id = "EXPORT_" + export_id.upper()
    round_profile = profile["round"]
    lines = [
        "// Generated by tools/save_to_map/export.py (profile native-static-v1). A fresh",
        "// nomads-style round on a world exported from a save; nothing else is restored.",
        type_path,
        f"\tID = {dm_literal(map_id)}",
        f"\ttitle = {dm_literal(title)}",
        f"\tdescription = {dm_literal('A settlement built by players in an earlier world, now a new beginning.')}",
        '\tlobby_icon = ""',
        '\tno_winner = "The round is proceeding normally."',
        "\tcaribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)",
        "\trespawn_delay = 6000",
        "\tfaction1 = CIVILIAN",
        '\tavailablefactions = list("Nomad")',
        "\tfaction_distribution_coeffs = list(CIVILIAN = 1)",
        "\tfaction_organization = list(CIVILIAN)",
        "\troundend_condition_sides = list(list(CIVILIAN) = /area/caribbean/british)",
        '\tage = "5000 B.C."',
        f"\tcivilizations = {1 if round_profile['civilizations'] else 0}",
        f"\tnomads = {1 if round_profile['nomads'] else 0}",
        f"\toverride_mapgen = {1 if round_profile['override_mapgen'] else 0}",
        "\tforce_mapgen = 0",
        f"\tpersistence = {1 if round_profile['persistence'] else 0}",
        "\thas_hunger = 1",
        "\tresearch_active = 1",
        '\tgamemode = "Classic (Stone Age Start)"',
        '\tbattle_name = "a new beginning"',
        f"\tmission_start_message = {dm_literal('<big>A new round begins in a world built by players before you.</big>')}",
    ]
    lines += elevation_lines(meta["elevation"], meta["dims"])
    if height_file:
        lines.append(f"\tterrain_height_file = {dm_literal(height_file)}")
    lines += [
        "",
        f"{type_path}/job_enabled_specialcheck(var/datum/job/J)",
        f"\tif (J.type == {round_profile['job']})",
        "\t\treturn TRUE",
        "\treturn ..()",
        "",
    ]
    return type_path, map_id, "\n".join(lines).encode("utf-8")


# ---------- compile check ----------

BEGIN, END = "// BEGIN_SELECTED_MAP", "// END_SELECTED_MAP"
METADATA_INCLUDE = re.compile(r'^#include "code\\game\\objects\\map_metadata\\[^"\n]+\.dm"\s*$', re.MULTILINE)
MISSING_TYPE = "/turf/save_export_missing_type_control"


def staged_dme(source, dmm, metadata):
    require(source.count(BEGIN) == 1 and source.count(END) == 1, "dme_markers")
    start, end = source.index(BEGIN), source.index(END)
    source = source[:start] + BEGIN + '\n#include "' + dmm.replace("/", "\\") + '"\n' + source[end:]
    last = list(METADATA_INCLUDE.finditer(source))
    require(last, "dme_markers")
    cut = last[-1].end()
    return source[:cut] + '\n#include "' + metadata.replace("/", "\\") + '"' + source[cut:]


def missing_type_control(dmm_text):
    mutated, count = re.subn(r"(\(.*?,)(/turf/[\w/]+)", r"\1" + MISSING_TYPE, dmm_text, count=1)
    require(count == 1 and MISSING_TYPE not in dmm_text, "control_failed")
    return mutated


def compile_summary(log):
    found = re.findall(r" - (\d+) errors?, (\d+) warnings?", log)
    return tuple(map(int, found[-1])) if found else None


def compile_check(package, export_id, byond_bin, root=ROOT):
    """Compile the export as the only map in a disposable root-local DME, plus a negative control."""
    compiler = byond_bin / ("dm.exe" if os.name == "nt" else "DreamMaker")
    source = (root / "civ13.dme").read_text(encoding="utf-8")
    results = {}
    with tempfile.TemporaryDirectory(prefix=".save-export-", dir=root) as work:
        work = Path(work)
        metadata = work / f"export_{export_id}.dm"
        shutil.copyfile(package / "metadata" / f"export_{export_id}.dm", metadata)
        dmm_text = (package / "map" / f"{export_id}.dmm").read_text(encoding="utf-8")
        for name, text in (("positive", dmm_text), ("missing-type", missing_type_control(dmm_text))):
            dmm = work / f"{name}.dmm"
            dmm.write_text(text, encoding="utf-8")
            dme = root / f"{work.name}-{name}.dme"
            try:
                dme.write_text(staged_dme(source, dmm.relative_to(root).as_posix(),
                                          metadata.relative_to(root).as_posix()), encoding="utf-8")
                build = subprocess.run([str(compiler), "-max_errors", "0", dme.name], cwd=root,
                                       capture_output=True, text=True, timeout=1800)
                log = build.stdout + build.stderr
                summary = compile_summary(log)
                if name == "positive":
                    passed = build.returncode == 0 and summary == (0, 0) and dme.with_suffix(".dmb").is_file()
                else:
                    passed = summary is not None and summary[0] > 0 and MISSING_TYPE in log
                results[name] = {"accepted": passed, "errors": summary[0] if summary else None,
                                 "warnings": summary[1] if summary else None}
                if not passed:
                    results[name]["diagnostics"] = [line for line in log.splitlines() if re.search(r":(error|warning):", line)][:20]
            finally:
                for suffix in (".dme", ".dmb", ".rsc", ".int", ".lk", ".dyn.rsc"):
                    dme.with_suffix(suffix).unlink(missing_ok=True)
    version = re.search(r"DM compiler version (\d+\.\d+)", log)
    results["compiler_version"] = version.group(1) if version else None
    results["passed"] = all(results[name]["accepted"] for name in ("positive", "missing-type"))
    return results


# ---------- package ----------

def git_head(root=ROOT):
    try:
        return subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
    except (OSError, subprocess.CalledProcessError):
        return None


def integration_text(export_id, metadata_type):
    return f"""Integrating export {export_id}

1. Copy map/{export_id}.dmm to maps/exports/{export_id}.dmm and
   metadata/export_{export_id}.dm to code/game/objects/map_metadata/exports/.
2. In civ13.dme, include code\\game\\objects\\map_metadata\\exports\\export_{export_id}.dm
   after the other map_metadata includes. To play it, select maps\\exports\\{export_id}.dmm
   as the map in the BEGIN_SELECTED_MAP block (scripts/mapswap.py does this on servers).
3. Compile with zero errors and warnings, then start a fresh round with no
   map_saves/ present. The world starts as {metadata_type}; players join as Nomads.

Nothing from the old round's players, inventories, research or timers is
carried over. See report.txt for what was reset or left out.
"""


def report_text(export_id, rendered):
    text = [f"Save-to-map export {export_id}: {rendered['status']}", f"Compilation: {rendered['compile_status']}",
            "Playable: unverified until a fresh round is started", ""]
    text += [f"{name}: {value}" for name, value in rendered["counters"].items()]
    text += [""] + [f"{row['reason']}: {row['category']} ({row['count']})" for row in rendered["groups"]]
    return ("\n".join(text) + "\n").encode()


def build_package(save_dir, export_id, title, output, byond_bin, *, preview=False, compile=False, timeout=3600):
    require(EXPORT_ID.match(export_id or ""), "invalid_export_id")
    require(type(title) is str and 0 < len(title) <= 64 and all(ch.isprintable() for ch in title), "invalid_title")
    output = checked_path(output)
    require(output.parent.is_dir() and not output.exists(), "output_exists")
    save_dir, files = inventory(save_dir)
    require(output != save_dir and save_dir not in output.parents and output not in save_dir.parents, "input_output_overlap")
    profile = load_profile()
    catalog = source_types()
    with tempfile.TemporaryDirectory(prefix="save-export-") as staging:
        staging = Path(staging)
        level = stage_copy(save_dir, files, staging)
        meta = round_metadata(level)
        levels = read_levels(level, byond_bin, meta, timeout)
        status = "rejected"
        report = Report()
        try:
            grid, report, status = project(levels, meta, profile, catalog, preview, report)
        except CoreError as error:
            # Keep the counts gathered so far: they say what to fix.
            report.add("rejected", str(error))
            grid = None
    _, after = inventory(save_dir)
    require(after == files, "input_changed_during_export")
    output.mkdir(mode=0o700)
    if grid is None:
        rendered = report.render("rejected")
        exclusive_write(output / "report.json", json_bytes(rendered))
        exclusive_write(output / "report.txt", report_text(export_id, rendered))
        return rendered
    height_file = terrain_height_file(meta["map_type"])
    metadata_type, map_id, metadata = metadata_source(export_id, title, profile, meta, height_file)
    dmm = render_dmm(meta["dims"], grid, metadata_type)
    (output / "map").mkdir()
    (output / "metadata").mkdir()
    exclusive_write(output / "map" / f"{export_id}.dmm", dmm)
    exclusive_write(output / "metadata" / f"export_{export_id}.dm", metadata)
    exclusive_write(output / "INTEGRATION.txt", integration_text(export_id, metadata_type).encode())
    compile_status = "not_run"
    if compile:
        results = compile_check(output, export_id, byond_bin)
        exclusive_write(output / "compile.json", json_bytes(results))
        compile_status = "passed" if results["passed"] else "failed"
    rendered = report.render(status, compile_status)
    rendered["counters"]["terrain_height_file"] = 1 if height_file else 0
    exclusive_write(output / "report.json", json_bytes(rendered))
    exclusive_write(output / "report.txt", report_text(export_id, rendered))
    manifest = {
        "schema_version": SCHEMA, "profile_id": "native-static-v1", "source_commit": git_head(),
        "export_id": export_id, "map_id": map_id, "metadata_type": metadata_type,
        "dimensions": meta["dims"], "status": status, "compile_status": compile_status, "ready": False,
        "save_formats": sorted({level["header"]["format"] for level in levels}),
        "files": {path.relative_to(output).as_posix(): sha256(path) for path in sorted(output.rglob("*")) if path.is_file()},
    }
    exclusive_write(output / "manifest.json", json_bytes(manifest))
    return rendered


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--save-dir", type=Path, required=True, help="A copy of a completed map_saves/ generation")
    parser.add_argument("--export-id", required=True, help="Lowercase id, e.g. riverside")
    parser.add_argument("--title", required=True)
    parser.add_argument("--output", type=Path, required=True, help="New package directory (must not exist)")
    parser.add_argument("--byond-bin", type=Path, required=True)
    parser.add_argument("--compile", action="store_true", help="Compile the export against this checkout")
    parser.add_argument("--preview", action="store_true", help="Omit unsupported objects instead of rejecting")
    parser.add_argument("--timeout", type=int, default=3600, help="Seconds per level read")
    args = parser.parse_args(argv)
    try:
        report = build_package(args.save_dir, args.export_id, args.title, args.output, args.byond_bin.resolve(),
                               preview=args.preview, compile=args.compile, timeout=args.timeout)
    except (CoreError, OSError, subprocess.TimeoutExpired, json.JSONDecodeError, UnicodeError) as error:
        reason = str(error) if isinstance(error, CoreError) else type(error).__name__
        print(json.dumps({"status": "rejected", "reason": reason}), file=sys.stderr)
        return 2
    if report["status"] == "rejected":
        reasons = [row["category"] for row in report["groups"] if row["reason"] == "rejected"]
        unsupported = [row["category"][5:] for row in report["groups"] if row["category"].startswith("type:")]
        print(json.dumps({"status": "rejected", "reason": reasons[0] if reasons else "rejected",
                          "unsupported_types": unsupported[:20]}), file=sys.stderr)
        return 2
    print(json.dumps({"status": report["status"], "compile_status": report["compile_status"]}))
    ok = report["status"] == "complete" and report["compile_status"] in ("passed", "not_run")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
