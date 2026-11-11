"""Offline tests for the native save-to-map exporter (tools/save_to_map/export.py).

They need no BYOND: stream levels are written by the real stream helper (host
C compiler) and decoded by savestream_reader; projection, metadata and DME
staging run on synthetic records. tests/save_to_map/run_native.py covers the
native reader and the full-game compile.
"""
from __future__ import annotations

import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "save_to_map"))
sys.path.insert(0, str(ROOT / "tests" / "savestream"))
import export  # noqa: E402
from core import CoreError  # noqa: E402
from savestream_reader import StreamError, StreamFile, TypePath  # noqa: E402

CATALOG = {"/turf/floor/wood", "/turf/floor/grass", "/turf/sky/building", "/obj/structure/bed/chair",
           "/obj/structure/closet", "/obj/covers/wood", "/area/caribbean/nomads", "/area/caribbean/roofed",
           "/obj/structure/vehicleparts/frame"}


def meta(spawns=None, zones=None):
    return {"generation": "g", "dims": [2, 1, 1], "map_type": None,
            "zones": zones or {"a": "/area/caribbean/nomads", "b": "/area/caribbean/roofed"},
            "spawns": spawns if spawns is not None else {"latejoin": {"JoinLateCiv": [{"x": 2, "y": 1, "z": 1}]}},
            "elevation": None}


def level(entries, cells, header=None):
    return [{"z": 1, "header": header or {"format": 3}, "cells": cells, "entries": entries}]


def turf(ref, path, content=(), fields=(), num=None):
    return {"ref": ref, "type": path, "content": list(content), "fields": list(fields), "num": num or {}}


class StreamReaderTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        try:
            from helper_client import Helper, Path_, build_helper, record
        except ImportError as error:  # pragma: no cover - repository layout
            raise unittest.SkipTest(str(error))
        cls.tmp = Path(tempfile.mkdtemp(prefix="save-to-map-stream-"))
        try:
            exe = build_helper(cls.tmp)
        except (RuntimeError, OSError) as error:
            raise unittest.SkipTest(f"stream helper unavailable: {error}")
        cls.path = cls.tmp / "1.stream.sav"
        values = {
            "/generation": "round-v2:abc",
            "/entries/0/1/type": Path_("/turf/floor/wood"),
            "/entries/0/1/content": ["2&3"],
            "/entries/0/1/icon_state": "wood2",
            "/entries/0/2/type": Path_("/obj/structure/bed/chair"),
            "/entries/0/2/dir": 4,
            "/entries/0/2/pixel_x": {"kind": "value", "value": -6},
            "/entries/0/2/name": 'Private "name" [x]',
            "/entries/0/3/type": Path_("/mob/living/human"),
            "/entries/1/513/type": Path_("/obj/covers/wood"),
        }
        helper = Helper(exe, "write", cls.path)
        assert helper.request("W", "".join(record(p, v) for p, v in values.items())) == b"OK"
        summary = json.loads(helper.request("F", "force"))
        helper.close()
        assert summary["published"], summary

    def test_reads_values_and_listing(self):
        stream = StreamFile(self.path)
        self.assertEqual(stream.get("/generation"), "round-v2:abc")
        self.assertIsInstance(stream.get("/entries/0/1/type"), TypePath)
        self.assertEqual(stream.children("/entries/0/1"), ["content", "icon_state", "type"])
        self.assertEqual(stream.children("/entries"), ["0", "1"])
        self.assertFalse(stream.has("/entries/0/9/type"))
        with self.assertRaises(KeyError):
            stream.get("/missing")

    def test_entry_projection_matches_native_reader_shape(self):
        entries = export.StreamEntries(self.path)
        self.assertEqual(entries.get(1)["content"], [2, 3])
        chair = entries.get(2)
        self.assertEqual(chair["type"], "/obj/structure/bed/chair")
        self.assertEqual(chair["num"], {"dir": 4.0, "pixel_x": -6.0})
        self.assertEqual(sorted(chair["fields"]), ["dir", "name", "pixel_x"])
        self.assertNotIn("Private", json.dumps(chair))
        self.assertEqual(entries.get(513)["type"], "/obj/covers/wood")

    def test_truncated_stream_is_refused(self):
        broken = self.tmp / "broken.stream.sav"
        broken.write_bytes(self.path.read_bytes()[:-5])
        with self.assertRaises(StreamError):
            StreamFile(broken)


class ProjectionTest(unittest.TestCase):
    def setUp(self):
        self.profile = export.load_profile()

    def project(self, entries, cells, data=None, preview=False, header=None):
        return export.project(level(entries, cells, header), data or meta(), self.profile, CATALOG, preview)

    def test_static_objects_kept_and_runtime_state_left_out(self):
        entries = {
            1: turf(1, "/turf/floor/wood", [2, 3, 4, 5], ["icon_state"]),
            2: turf(2, "/obj/structure/bed/chair", fields=["dir", "name"], num={"dir": 4}),
            3: turf(3, "/mob/living/human", fields=["ckey"]),
            4: turf(4, "/obj/structure/closet", [9], ["dir"], {"dir": 3}),
            5: turf(5, "/obj/structure/vehicleparts/frame"),
            6: turf(6, "/turf/floor/grass"),
        }
        cells = {(1, 1): {"ref": 1, "zone": "b"}, (2, 1): {"ref": 6, "zone": "a"}}
        grid, report, status = self.project(entries, cells)
        self.assertEqual(status, "complete")
        self.assertEqual(grid[1, 1, 1], "(/obj/structure/bed/chair{dir = 4},/obj/structure/closet,{metadata},/turf/floor/wood,/area/caribbean/roofed)")
        self.assertEqual(grid[2, 1, 1], '(/obj/effect/landmark{name = "JoinLateCiv"},/turf/floor/grass,/area/caribbean/nomads)')
        counts = report.counts
        self.assertEqual((counts["retained_objects"], counts["excluded_objects"], counts["excluded_entity_roots"]), (2, 1, 1))
        self.assertEqual(counts["excluded_content_roots"], 1)
        rendered = json.dumps(report.render(status))
        self.assertIn("saved_field:name", rendered)
        self.assertNotIn("ckey\"", rendered.replace("saved_field:ckey", ""))

    def test_unknown_static_type_rejects_unless_preview(self):
        entries = {1: turf(1, "/turf/floor/wood", [2]), 2: turf(2, "/obj/structure/not_in_source"), 3: turf(3, "/turf/floor/wood")}
        cells = {(1, 1): {"ref": 1, "zone": "a"}, (2, 1): {"ref": 3, "zone": "a"}}
        report = export.Report()
        with self.assertRaisesRegex(CoreError, "unsupported_static"):
            export.project(level(entries, cells), meta(), self.profile, CATALOG, False, report)
        # The rejection names the type so the operator can fix it.
        self.assertEqual(report.groups["unsupported_static", "type:/obj/structure/not_in_source"], 1)
        self.assertEqual(report.counts["saved_objects"], 1)
        _, report, status = self.project(entries, cells, preview=True)
        self.assertEqual(status, "incomplete_preview")
        entries[2] = turf(2, "/obj/structure/" + "x" * 300)
        _, report, _ = self.project(entries, cells, preview=True)
        self.assertEqual(report.groups["unsupported_static", "unknown_static_type"], 1)

    def test_unknown_terrain_and_missing_topology_reject(self):
        entries = {1: turf(1, "/turf/unknown"), 2: turf(2, "/turf/floor/wood")}
        with self.assertRaisesRegex(CoreError, "unsupported_terrain"):
            self.project(entries, {(1, 1): {"ref": 1, "zone": "a"}, (2, 1): {"ref": 2, "zone": "a"}})
        entries[1] = turf(1, "/turf/floor/wood")
        with self.assertRaisesRegex(CoreError, "topology_unavailable_in_save"):
            self.project(entries, {(1, 1): {"ref": 1, "zone": None}, (2, 1): {"ref": 2, "zone": "a"}})

    def test_sparse_baseline_and_missing_spawn(self):
        entries = {1: turf(1, "/turf/floor/wood")}
        header = {"format": 3, "sparse_turf": "/turf/sky/building", "sparse_zone": "a"}
        grid, report, _ = self.project(entries, {(1, 1): {"ref": 1, "zone": "b"}}, header=header)
        self.assertTrue(grid[2, 1, 1].endswith("/turf/sky/building,/area/caribbean/nomads)"))
        self.assertEqual(report.counts["sparse_baseline_cells"], 1)
        with self.assertRaisesRegex(CoreError, "missing_spawn"):
            self.project(entries, {(1, 1): {"ref": 1, "zone": "b"}}, data=meta(spawns={}), header=header)
        with self.assertRaisesRegex(CoreError, "incomplete_grid"):
            self.project(entries, {(1, 1): {"ref": 1, "zone": "b"}})

    def test_spawn_names_are_validated(self):
        spawns = {"latejoin": {"JoinLateCiv": [{"x": 2, "y": 1, "z": 1}], 'x"]': [{"x": 1, "y": 1, "z": 1}]},
                  "start": [{"x": 1, "y": 1, "z": 1}]}
        entries = {1: turf(1, "/turf/floor/wood"), 2: turf(2, "/turf/floor/wood")}
        grid, _, _ = self.project(entries, {(1, 1): {"ref": 1, "zone": "a"}, (2, 1): {"ref": 2, "zone": "a"}}, data=meta(spawns))
        self.assertIn('/obj/effect/landmark{name = "start"}', grid[1, 1, 1])
        self.assertNotIn('x\\"', grid[1, 1, 1])


class OutputTest(unittest.TestCase):
    def test_dmm_render_orders_rows_and_palette(self):
        grid = {(1, 1, 1): "(/turf/floor/wood,/area/caribbean/nomads)", (2, 1, 1): "({metadata},/turf/floor/grass,/area/caribbean/nomads)",
                (1, 2, 1): "(/turf/floor/wood,/area/caribbean/nomads)", (2, 2, 1): "(/turf/floor/wood,/area/caribbean/nomads)"}
        text = export.render_dmm((2, 2, 1), grid, "/obj/map_metadata/export_x").decode()
        self.assertEqual(text, '"a" = (/turf/floor/wood,/area/caribbean/nomads)\n'
                               '"b" = (/obj/map_metadata/export_x,/turf/floor/grass,/area/caribbean/nomads)\n'
                               '\n(1,1,1) = {"\naa\nab\n"}\n')

    def test_metadata_is_literal_and_carries_elevation(self):
        data = meta()
        data["dims"] = [10, 10, 1]
        data["elevation"] = {"version": 1, "maxx": 10, "maxy": 10, "maxz": 1, "default_metres": 12.5,
                             "regions": [{"x1": 1, "x2": 3, "y1": 1, "y2": 3, "z": 1, "metres": 40}]}
        type_path, map_id, source = export.metadata_source("river", 'Title "[x]"', export.load_profile(), data, None)
        text = source.decode()
        self.assertEqual((type_path, map_id), ("/obj/map_metadata/export_river", "EXPORT_RIVER"))
        self.assertIn('title = "Title \\"\\[x\\]\\""', text)
        self.assertIn("elevation_default_metres = 12.5", text)
        self.assertIn('"metres" = 40', text)
        self.assertIn("if (J.type == /datum/job/civilian/civnomad)", text)
        data["elevation"]["maxx"] = 11
        self.assertNotIn("elevation", export.metadata_source("river", "T", export.load_profile(), data, None)[2].decode())

    def test_staged_dme_replaces_only_the_selected_map(self):
        source = (ROOT / "civ13.dme").read_text(encoding="utf-8")
        staged = export.staged_dme(source, ".save-export-x/positive.dmm", ".save-export-x/export_a.dm")
        start = staged.index(export.BEGIN)
        block = staged[start:staged.index(export.END)]
        self.assertEqual(block.count(".dmm"), 1)
        self.assertIn('#include ".save-export-x\\positive.dmm"', block)
        metadata = staged.index('#include ".save-export-x\\export_a.dm"')
        self.assertLess(staged.rindex("map_metadata\\", 0, metadata), metadata)
        self.assertEqual(staged.replace(block, "").count(".dmm"), source.replace(source[source.index(export.BEGIN):source.index(export.END)], "").count(".dmm"))

    def test_missing_type_control_changes_one_turf(self):
        dmm = '"a" = (/obj/x,/turf/floor/wood,/area/a)\n"b" = (/turf/floor/grass,/area/a)\n'
        mutated = export.missing_type_control(dmm)
        self.assertEqual(mutated.count(export.MISSING_TYPE), 1)
        self.assertIn("/turf/floor/grass", mutated)

    def test_source_catalog_includes_nested_declarations(self):
        catalog = export.source_types()
        # religions.dm declares altars without a leading slash (seen on a real Gaia save).
        for path in ("/turf/floor/wood", "/obj/structure/bed/chair", "/area/caribbean/nomads", "/obj/map_metadata",
                     "/obj/structure/altar/wood", "/obj/structure/altar/stone/material/obsidian"):
            self.assertIn(path, catalog)
        self.assertNotIn("/obj/structure/not_in_source", catalog)

    def test_profile_excludes_vehicles_and_economy(self):
        profile = export.load_profile()
        self.assertFalse(export.object_admitted("/obj/structure/vehicleparts/frame", profile))
        self.assertFalse(export.object_admitted("/obj/structure/money_printer", profile))
        self.assertFalse(export.object_admitted("/obj/item/stack/rods", profile))
        self.assertTrue(export.object_admitted("/obj/structure/bed/chair", profile))
        self.assertTrue(export.object_admitted("/obj/roof/wood", profile))


if __name__ == "__main__":
    unittest.main()
