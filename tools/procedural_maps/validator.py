"""Pure offline acceptance prototype. No game import, network, writes, or generator."""
from __future__ import annotations

import argparse
import hashlib
import json
from collections import deque
from pathlib import Path

VERSION = "civ13-geography-ir/1"
PORT_VERSION = "civ13-geography-ir/2"
PROFILES = {"SURFACE", "OCEANIC", "UNDERGROUND_CAVERN"}
TERRAINS = {"PLAIN", "HILL", "MOUNTAIN", "BEACH", "CAVE_FLOOR", "ROCK", "WATER"}
BIOMES = {"TEMPERATE", "LUSH", "STEPPE", "ARID", "DESERT", "ALPINE", "CAVERN", "COAST"}
SOILS = {"LOAM", "SAND", "ROCK", "SILT", "NONE"}
WATERS = {"NONE", "RIVER", "LAKE", "SEA", "SWAMP"}
SALINITIES = {"NONE", "FRESH", "BRACKISH", "SALT"}
SPECIES = {"NONE", "BROADLEAF", "PINE", "PALM", "CACTUS", "FUNGUS"}
ECOTONES = {frozenset(e) for e in [
    ("LUSH", "TEMPERATE"), ("LUSH", "COAST"), ("TEMPERATE", "STEPPE"),
    ("STEPPE", "ARID"), ("ARID", "DESERT"), ("TEMPERATE", "ALPINE"),
    ("STEPPE", "ALPINE"), ("TEMPERATE", "COAST"), ("ARID", "COAST"),
    ("DESERT", "COAST"), ("ALPINE", "COAST"), ("STEPPE", "COAST")
]}
CELL_KEYS = {"terrain", "biome", "soil", "elevation_m", "moisture", "temperature_c",
             "water", "salinity", "depth_cm", "body", "blocked", "tree", "resource", "hazard"}
ROOT_KEYS = {"schema", "seed", "algorithm_version", "content_version", "profile_version",
             "profile", "active_layer", "width", "height", "layers", "ports", "rivers",
             "lakes", "starts", "portals", "policy"}
POLICY_KEYS = {"mountain_min_area", "mountain_max_components", "max_moisture_step",
               "max_temperature_step", "max_resource_distance", "max_water_distance",
               "ship_radius", "ocean_ports_min", "land_components_min", "start_count",
               "river_half_width", "max_path_uphill_m"}


def stable_u64(seed: str, algorithm: str, content: str, profile: str,
               stage: str, layer: str, x: int, y: int, slot: int = 0) -> int:
    """Coordinate-stable draw; JSON array framing prevents concatenation collisions."""
    payload = json.dumps([seed, algorithm, content, profile, stage, layer, x, y, slot],
                         ensure_ascii=True, separators=(",", ":")).encode("ascii")
    return int.from_bytes(hashlib.sha256(payload).digest()[:8], "big")


def canonical_hash(document: dict) -> str:
    return hashlib.sha256(json.dumps(document, sort_keys=True, separators=(",", ":"),
                                     allow_nan=False).encode()).hexdigest()


def validate(d: object) -> list[dict]:
    """Reject malformed documents before graph traversal. Never mutate input."""
    errors: list[dict] = []

    def err(code, detail, at=None):
        errors.append({"code": code, "detail": detail, **({"at": list(at)} if at else {})})

    def require(ok, label):
        if not ok:
            raise ValueError(label)

    def integer(v, lo, hi):
        return type(v) is int and lo <= v <= hi

    def exact(v, keys, label):
        require(type(v) is dict and set(v) == set(keys), label)

    try:
        v2=type(d) is dict and d.get("schema")==PORT_VERSION
        exact(d, ROOT_KEYS|({"junctions"} if v2 else set()), "root keys")
        require(d["schema"] in {VERSION,PORT_VERSION} and d["profile"] in PROFILES, "schema/profile")
        for k in ("seed", "algorithm_version", "content_version", "profile_version"):
            require(type(d[k]) is str and 0 < len(d[k]) <= 128, k)
        require(d["seed"].isascii(), "seed must be ASCII")
        require(integer(d["width"], 3, 512) and integer(d["height"], 3, 512), "dimensions")
        w, h = d["width"], d["height"]
        require(type(d["layers"]) is dict and 1 <= len(d["layers"]) <= 4, "layers")
        require(d["active_layer"] in d["layers"], "active_layer")
        native_z = set()
        for name, layer in d["layers"].items():
            require(type(name) is str and name in {"SURFACE", "UNDERGROUND"}, "logical layer")
            exact(layer, {"native_z", "cells"}, "layer keys")
            z = layer["native_z"]
            require(integer(z, 1, 16) and z not in native_z, "native_z unique")
            native_z.add(z)
            require(z == {"SURFACE": 2, "UNDERGROUND": 1}[name], "Nomads layer mapping")
            require(type(layer["cells"]) is list and len(layer["cells"]) == h, "grid height")
            for row in layer["cells"]:
                require(type(row) is list and len(row) == w, "grid width")
                for c in row:
                    exact(c, CELL_KEYS, "cell keys")
                    for key, values in [("terrain", TERRAINS), ("biome", BIOMES), ("soil", SOILS),
                                        ("water", WATERS), ("salinity", SALINITIES), ("tree", SPECIES)]:
                        require(type(c[key]) is str and c[key] in values, key)
                    for key, lo, hi in [("elevation_m", -12000, 12000), ("moisture", 0, 100),
                                        ("temperature_c", -100, 100), ("depth_cm", 0, 100000)]:
                        require(integer(c[key], lo, hi), key)
                    require(type(c["body"]) is str and len(c["body"]) <= 64, "body")
                    require(type(c["resource"]) is str and c["resource"] in {"NONE", "FOOD", "WOOD", "STONE"}, "resource")
                    require(type(c["blocked"]) is bool and type(c["hazard"]) is bool, "bool flags")
        for name in ("ports", "rivers", "lakes", "starts", "portals"):
            require(type(d[name]) is list and len(d[name]) <= 2048, name)
        def coord(p):
            require(type(p) is list and len(p) == 3, "coordinate [x,y,layer]")
            require(integer(p[0], 0, w-1) and integer(p[1], 0, h-1) and
                    type(p[2]) is str and p[2] in d["layers"], "coordinate bounds")
        ids = set()
        for r in d["rivers"]:
            exact(r, {"id", "path", "source", "sink"}, "river keys")
            require(type(r["id"]) is str and r["id"] and r["id"] not in ids, "river id")
            ids.add(r["id"])
            require(type(r["path"]) is list and 2 <= len(r["path"]) <= w*h, "river path")
            for p in r["path"]: coord(p)
            for k in ("source", "sink"):
                exact(r[k], {"kind", "target"}, "terminal keys")
                require(r[k]["kind"] in ({"EDGE", "LAKE", "SEA","JUNCTION"} if v2 else {"EDGE", "LAKE", "SEA", "RIVER"}) and
                        type(r[k]["target"]) is str, "terminal kind/target")
        ids = set()
        for lake in d["lakes"]:
            exact(lake, {"id", "terminal_basin", "outflow"}, "lake keys")
            require(type(lake["id"]) is str and lake["id"] and lake["id"] not in ids, "lake id")
            ids.add(lake["id"])
            require(type(lake["terminal_basin"]) is bool and type(lake["outflow"]) is str, "lake outlet")
        for p in d["ports"]:
            exact(p, {"id", "at", "side", "role", "body"}|({"span"} if v2 else set()), "port keys")
            coord(p["at"])
            require(type(p["id"]) is str and p["id"] and type(p["body"]) is str, "port id/body")
            require(p["side"] in {"N", "S", "E", "W"} and p["role"] in {"INLET", "OUTLET", "OCEAN"}, "port side/role")
            if v2:
                length=w if p["side"] in {"N","S"} else h
                require(type(p["span"]) is list and len(p["span"])==2 and all(integer(i,0,length-1) for i in p["span"]) and p["span"][0]<=p["span"][1],"port span")
        if v2:
            require(type(d["junctions"]) is list and len(d["junctions"])<=64,"junction list")
            seen=set()
            for j in d["junctions"]:
                exact(j,{"id","at","incoming","outgoing","footprint"},"junction keys");coord(j["at"])
                require(type(j["id"]) is str and j["id"] and j["id"] not in seen,"junction id");seen.add(j["id"])
                require(type(j["incoming"]) is list and 2<=len(j["incoming"])<=8 and all(type(s) is str for s in j["incoming"]) and len(set(j["incoming"]))==len(j["incoming"]),"junction incoming")
                require(type(j["outgoing"]) is str and type(j["footprint"]) is list and 1<=len(j["footprint"])<=1024,"junction outgoing/footprint")
                for p in j["footprint"]:coord(p)
        for p in d["starts"]: coord(p)
        for p in d["portals"]:
            exact(p, {"a", "b"}, "portal keys")
            coord(p["a"]); coord(p["b"])
        exact(d["policy"], POLICY_KEYS, "policy keys")
        for k, v in d["policy"].items():
            require(integer(v, 0, 100000), "integer policy " + k)
        require(d["policy"]["ship_radius"] <= 4, "ship radius")
        require(d["policy"]["start_count"] > 0, "start_count")
        require(d["policy"]["mountain_min_area"] >= 2 and
                d["policy"]["mountain_max_components"] >= 1, "mountain policy")
        require(d["policy"]["land_components_min"] >= 1 and
                d["policy"]["ocean_ports_min"] >= 1, "ocean policy")
    except (ValueError, TypeError, KeyError) as e:
        return [{"code": "SCHEMA", "detail": str(e)}]

    policy = d["policy"]
    cells = {(x, y, layer): c for layer, level in d["layers"].items()
             for y, row in enumerate(level["cells"]) for x, c in enumerate(row)}
    active = {p for p in cells if p[2] == d["active_layer"]}
    def near(p):
        x,y,l = p
        return [(xx,yy,l) for xx,yy in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]
                if 0 <= xx < w and 0 <= yy < h]
    def components(points):
        remain = set(points); result = []
        while remain:
            seed = min(remain); seen = {seed}; todo = [seed]; remain.remove(seed)
            while todo:
                for q in near(todo.pop()):
                    if q in remain: remain.remove(q); seen.add(q); todo.append(q)
            result.append(seen)
        return result
    def walkable(c):
        return not (c["blocked"] or c["hazard"] or c["tree"] != "NONE" or
                    c["water"] != "NONE" or c["terrain"] in {"ROCK", "MOUNTAIN"})
    def connected_distances(start, allowed, links=None):
        distances = {start: 0}; queue = deque([start])
        while queue:
            p = queue.popleft()
            for q in near(p) + (links or {}).get(p, []):
                if q in allowed and q not in distances:
                    distances[q] = distances[p]+1; queue.append(q)
        return distances

    for p,c in cells.items():
        wet = c["water"] != "NONE"
        if wet != (c["terrain"] == "WATER") or (wet and (c["depth_cm"] <= 0 or not c["body"])) or (
            not wet and (c["depth_cm"] != 0 or c["salinity"] != "NONE" or c["body"])):
            err("WATER_TYPE", "water/terrain/depth/body mismatch", p)
        if wet and (c["salinity"] == "NONE" or (c["water"] in {"RIVER", "LAKE"} and c["salinity"] != "FRESH") or
                    (c["water"] == "SEA" and c["salinity"] != "SALT")):
            err("SALINITY", "fresh river/lake; salt sea; explicit swamp salinity", p)
        if c["water"] == "SWAMP" and (c["soil"] not in {"SILT", "LOAM"} or c["moisture"] < 70):
            err("SWAMP_SITE", "wetland requires saturated suitable substrate", p)
        tree = c["tree"]
        allowed = {
            "BROADLEAF": c["soil"] == "LOAM" and 35 <= c["moisture"] <= 90 and -5 <= c["temperature_c"] <= 35 and c["elevation_m"] <= 2000,
            "PINE": c["soil"] in {"LOAM", "SAND"} and 20 <= c["moisture"] <= 80 and -20 <= c["temperature_c"] <= 25 and c["elevation_m"] <= 3000,
            "PALM": c["soil"] in {"SAND", "LOAM"} and 20 <= c["moisture"] <= 85 and 18 <= c["temperature_c"] <= 45 and c["elevation_m"] <= 1000,
            "CACTUS": c["soil"] == "SAND" and c["moisture"] <= 30 and c["temperature_c"] >= 10,
            "FUNGUS": c["terrain"] == "CAVE_FLOOR" and c["moisture"] >= 40,
            "NONE": True,
        }[tree]
        if tree != "NONE" and (wet or c["blocked"] or c["hazard"] or c["terrain"] in {"ROCK", "MOUNTAIN"} or not allowed):
            err("VEGETATION_SITE", "species habitat or placement invalid", p)
        if c["biome"] == "DESERT" and c["moisture"] > 30 or c["biome"] == "LUSH" and c["moisture"] < 65:
            err("CLIMATE_SITE", "desert/lush moisture envelope", p)
        for q in near(p):
            if q < p: continue
            other = cells[q]
            if c["water"] == other["water"] == "NONE":
                if c["biome"] != other["biome"] and frozenset((c["biome"],other["biome"])) not in ECOTONES:
                    err("ECOTONE", "forbidden biome adjacency", p)
                if abs(c["moisture"]-other["moisture"]) > policy["max_moisture_step"] or abs(c["temperature_c"]-other["temperature_c"]) > policy["max_temperature_step"]:
                    err("CLIMATE_GRADIENT", "climate discontinuity", p)

    mountains = components({p for p in active if cells[p]["terrain"] == "MOUNTAIN"})
    if len(mountains) > policy["mountain_max_components"] or any(len(c) < policy["mountain_min_area"] for c in mountains):
        err("MOUNTAIN_RANGE", "fragmented or undersized mountain component")

    ports = {p["id"]: p for p in d["ports"]}
    if len(ports) != len(d["ports"]) or len({tuple(p["at"]) for p in d["ports"]}) != len(ports):
        err("PORT_DUPLICATE", "duplicate id or coordinate")
    for port in d["ports"]:
        p = tuple(port["at"]); x,y,_ = p; c = cells[p]
        if not {"W":x==0,"E":x==w-1,"S":y==0,"N":y==h-1}[port["side"]]:
            err("PORT_EDGE", "port must occupy declared edge", p)
        expected = "SEA" if port["role"] == "OCEAN" else "RIVER"
        if c["water"] != expected or c["body"] != port["body"]:
            err("PORT_WATER", "port body/type mismatch", p)
    rivers = {r["id"]: r for r in d["rivers"]}
    lakes = {l["id"]: l for l in d["lakes"]}
    junctions={j["id"]:j for j in d.get("junctions",[])}
    river_points = {}
    used_ports = set()
    for rid,r in rivers.items():
        path = [tuple(p) for p in r["path"]]
        footprint = {p for p,c in cells.items() if c["water"] == "RIVER" and c["body"] == rid}
        river_points[rid] = footprint
        if not footprint or len(components(footprint)) != 1 or len(set(path)) != len(path):
            err("RIVER_RASTER", "empty/disconnected footprint or repeated path", path[0])
        if any(p not in footprint for p in path) or any(b not in near(a) for a,b in zip(path,path[1:])):
            err("RIVER_PATH", "path must be continuous in its raster body", path[0])
        if any(cells[b]["elevation_m"] > cells[a]["elevation_m"] + policy["max_path_uphill_m"] for a,b in zip(path,path[1:])):
            err("RIVER_UPHILL", "flow violates drainage height", path[0])
        # Multi-source distance from path enforces bounded raster width without O(area*path).
        distance = {p:0 for p in path if p in footprint}; queue = deque(distance)
        while queue:
            p = queue.popleft()
            for q in near(p):
                if q in footprint and q not in distance: distance[q]=distance[p]+1; queue.append(q)
        if any(distance.get(p, w*h) > policy["river_half_width"] for p in footprint):
            err("RIVER_WIDTH", "unexplained river raster beyond channel path", path[0])
        for k,p in [("source",path[0]),("sink",path[-1])]:
            terminal = r[k]; kind,target = terminal["kind"],terminal["target"]
            if kind == "EDGE":
                port = ports.get(target)
                expected_role = "INLET" if k == "source" else "OUTLET"
                if not port or tuple(port["at"]) != p or port["body"] != rid or port["role"] != expected_role:
                    err("RIVER_ENDPOINT", "edge endpoint lacks matching directional port", p)
                else: used_ports.add(target)
            elif kind=="JUNCTION":
                j=junctions.get(target)
                zone={tuple(q) for q in j["footprint"]} if j else set()
                if not j or (k=="source" and (rid!=j["outgoing"] or p not in zone)) or (k=="sink" and (rid not in j["incoming"] or not zone.intersection(near(p)))):
                    err("RIVER_ENDPOINT","junction endpoint does not match its graph/raster zone",p)
            elif kind in {"LAKE", "SEA", "RIVER"}:
                if not any(cells[q]["water"] == kind and cells[q]["body"] == target for q in near(p)) or (kind=="RIVER" and (target not in rivers or target==rid)) or (kind=="LAKE" and target not in lakes):
                    err("RIVER_ENDPOINT", "terminal does not contact declared body", p)
                if k == "source" and kind not in {"LAKE", "EDGE"}:
                    err("RIVER_SOURCE", "v1 sources are edge inlets or declared lake outlets", p)
    for p,c in cells.items():
        if c["water"] == "RIVER" and c["body"] not in rivers: err("RIVER_UNDECLARED", "raster has no river graph", p)
        if c["water"] == "LAKE" and c["body"] not in lakes: err("LAKE_UNDECLARED", "raster has no lake declaration", p)
    for lake in lakes.values():
        points = {p for p,c in cells.items() if c["water"] == "LAKE" and c["body"] == lake["id"]}
        if len(components(points)) != 1: err("LAKE_RASTER", "lake must have one connected body")
        outflows = [r["id"] for r in rivers.values() if r["source"] == {"kind":"LAKE","target":lake["id"]}]
        if lake["terminal_basin"]:
            if lake["outflow"] or outflows: err("LAKE_OUTLET", "terminal basin cannot have outflow")
        elif not lake["outflow"] or outflows != [lake["outflow"]]:
            err("LAKE_OUTLET", "through lake requires exactly its declared outlet")
    for port in d["ports"]:
        if port["role"] != "OCEAN" and port["id"] not in used_ports: err("PORT_UNUSED", "river port is not a graph terminal")
    # Directed graph includes river->lake->outlet; all paths must drain to sea/edge/declared basin.
    def trace(rid, visiting):
        while rid in rivers and rid not in visiting:
            visiting.add(rid)
            sink=rivers[rid]["sink"]
            if sink["kind"] in {"EDGE","SEA"}:return True
            if sink["kind"]=="RIVER":rid=sink["target"];continue
            if sink["kind"]=="JUNCTION":
                j=junctions.get(sink["target"])
                if not j:return False
                rid=j["outgoing"];continue
            lake=lakes.get(sink["target"])
            if not lake:return False
            if lake["terminal_basin"]:return True
            rid=lake["outflow"]
        return False
    adjacency = {rid:set() for rid in rivers}
    for rid,r in rivers.items():
        for terminal in [r["source"],r["sink"]]:
            if terminal["kind"] == "RIVER" and terminal["target"] in rivers:
                adjacency[rid].add(terminal["target"]); adjacency[terminal["target"]].add(rid)
            if terminal["kind"]=="JUNCTION" and terminal["target"] in junctions:
                j=junctions[terminal["target"]]
                for other in j["incoming"]+[j["outgoing"]]:
                    if other in rivers and other!=rid:adjacency[rid].add(other);adjacency[other].add(rid)
            if terminal["kind"] == "LAKE":
                for other,rr in rivers.items():
                    if other != rid and terminal["target"] in [t["target"] for t in [rr["source"],rr["sink"]] if t["kind"]=="LAKE"]:
                        adjacency[rid].add(other)
    for rid in rivers:
        seen={rid}; todo=[rid]
        while todo:
            for other in adjacency[todo.pop()]:
                if other not in seen: seen.add(other); todo.append(other)
        if not any(rivers[r][k]["kind"]=="EDGE" for r in seen for k in ["source","sink"]):
            err("RIVER_NO_EDGE", "river network requires explicit map edge port")
        if not trace(rid,set()): err("RIVER_CYCLE", "drainage has cycle or missing outlet")

    walk = {p for p,c in cells.items() if walkable(c)}
    links = {}
    for portal in d["portals"]:
        a,b = tuple(portal["a"]),tuple(portal["b"])
        if a[2]==b[2] or a not in walk or b not in walk:
            err("PORTAL", "entrance/exit must pair safe cells on distinct layers", a)
        else:
            links.setdefault(a,[]).append(b); links.setdefault(b,[]).append(a)
    starts=[tuple(p) for p in d["starts"]]
    if len(starts)!=policy["start_count"] or len(set(starts))!=len(starts): err("START_COUNT", "start count/uniqueness")
    for p in starts:
        if p not in walk or p not in active:
            err("START_SAFE", "start must be clear safe active-layer land", p); continue
        distances=connected_distances(p, walk, links)
        for resource in ("FOOD","WOOD","STONE"):
            if not any(cells[q]["resource"]==resource and dist<=policy["max_resource_distance"] for q,dist in distances.items()):
                err("START_RESOURCE", "no safe bounded route to "+resource, p)
        if not any(dist<=policy["max_water_distance"] and any(cells[t]["water"] in {"LAKE","RIVER"} and cells[t]["salinity"]=="FRESH" and not cells[t]["hazard"] for t in near(q)) for q,dist in distances.items()):
            err("START_WATER", "no bounded safe route to fresh-water bank", p)

    if d["profile"] in {"SURFACE","OCEANIC"} and d["active_layer"] != "SURFACE": err("PROFILE_LAYER", "surface profiles use SURFACE/native z2")
    if d["profile"] == "OCEANIC":
        land={p for p in active if cells[p]["water"]=="NONE"}
        if len(components(land)) < policy["land_components_min"]: err("ISLANDS", "too few land components")
        sea={p for p in active if cells[p]["water"]=="SEA" and not cells[p]["blocked"] and not cells[p]["hazard"] and cells[p]["depth_cm"]>=200}
        radius=policy["ship_radius"]
        nav={p for p in sea if all((p[0]+dx,p[1]+dy,p[2]) in sea for dx in range(-radius,radius+1) for dy in range(-radius,radius+1))}
        ocean_ports=[tuple(p["at"]) for p in d["ports"] if p["role"]=="OCEAN"]
        if len(ocean_ports)<policy["ocean_ports_min"]: err("OCEAN_PORTS", "missing ocean edge ports")
        if not nav or len(components(nav))!=1 or len(components(sea))!=1:
            err("OCEAN_NAVIGATION", "deep sea and ship-clear core must be connected")
        core_distance={p:0 for p in nav};queue=deque(core_distance)
        while queue:
            q=queue.popleft()
            for t in near(q):
                if t in sea and t not in core_distance:
                    core_distance[t]=core_distance[q]+1;queue.append(t)
        # Edge ports may be on boundary; their inward clearance must touch the eroded core.
        for port in ocean_ports:
            if core_distance.get(port,w*h)>radius+1:
                err("OCEAN_PORT_ROUTE", "port cannot reach ship-clear water", port)
        for p in starts:
            if p in walk:
                reach=connected_distances(p,walk,links)
                shores={q for q in reach if q in active and any(t in sea for t in near(q))}
                if not shores or not any(core_distance.get(t,w*h)<=radius for q in shores for t in near(q)):
                    err("START_COAST", "start has no land route to navigable coast", p)
    if d["profile"] == "UNDERGROUND_CAVERN":
        if d["active_layer"] != "UNDERGROUND": err("PROFILE_LAYER", "caverns use UNDERGROUND/native z1")
        floors={p for p in active if cells[p]["terrain"]=="CAVE_FLOOR" and p in walk}
        if not floors or len(components(floors))!=1: err("CAVERN_CONNECTIVITY", "all usable chambers/passages must connect")
        valid_exits={a for a in links if a in active}
        if not valid_exits: err("CAVERN_EXIT", "paired safe entrance/exit required")
        for p in starts:
            if p in walk and not valid_exits.intersection(connected_distances(p,walk,links)):
                err("CAVERN_EXIT_ROUTE", "start cannot reach a valid exit", p)
    if v2:
        from .ports_validation import validate_port_geometry
        errors.extend(validate_port_geometry(d))
    return sorted(errors,key=lambda e:(e["code"],str(e.get("at",[])),e["detail"]))


def dry_run_patch(base: dict, changes: list[dict], expected_generation: str, actual_generation: str) -> dict:
    """Future-adapter preflight example. Returns a plan; never applies changes."""
    if expected_generation != actual_generation:
        return {"accepted":False,"reason":"GENERATION_CONFLICT","plan":[]}
    seen=set(); plan=[]
    for change in changes:
        key=change["at"]
        if key in seen or key not in base or base[key]["owner"]!="GENERATOR" or base[key]["revision"]!=change["expected_revision"]:
            return {"accepted":False,"reason":"EDIT_CONFLICT","plan":[]}
        seen.add(key); plan.append(dict(change))
    return {"accepted":True,"reason":"OFFLINE_PLAN_ONLY","plan":plan}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("document",type=Path)
    args=parser.parse_args()
    try:
        if args.document.stat().st_size>64*1024*1024: raise ValueError("document exceeds prototype 64 MiB limit")
        def pairs(items):
            result={}
            for k,v in items:
                if k in result: raise ValueError("duplicate JSON key: "+k)
                result[k]=v
            return result
        d=json.loads(args.document.read_text(encoding="utf-8"),object_pairs_hook=pairs,
                     parse_constant=lambda x: (_ for _ in ()).throw(ValueError("nonfinite JSON")))
        errors=validate(d)
        print(json.dumps({"accepted":not errors,"scope":"offline-ir-only","errors":errors},indent=2))
        return 1 if errors else 0
    except (OSError,ValueError,RecursionError) as e:
        print(json.dumps({"accepted":False,"scope":"offline-ir-only","errors":[{"code":"INPUT","detail":str(e)}]}))
        return 2


if __name__=="__main__":
    raise SystemExit(main())
