"""Pinned-Civ13 static DMM layout exporter and restricted parse-back validator.
Unsupported runtime semantics live in the mandatory sidecar, never new DM vars.
No native engine is imported, launched, compiled, or evaluated.
"""
import hashlib
import json
import re
from pathlib import Path
from .source_audit import parse_classic
from .validator import validate,canonical_hash
from .repo_source import read_pinned

COMMIT="067478b82c7ad9f1b83759a221e6f22080ba865a"
CATALOG_VERSION="civ13-static-layout/1"
CATALOG={
 "code/game/turfs/floor_types.dm":"3b3c83d2082f4f840a598d0fbb54cb3b3132eee8",
 "code/game/turfs/flooring/flooring_premade.dm":"cf0dcd8da162773fe9c44837b57dc188c339b25e",
 "code/game/objects/structures/wild.dm":"066f593f429133376970ac98fe9928e6e8cdba4d",
 "code/game/objects/structures/rocks.dm":"99aefaf8164df5a551fa89b06b158256e88b0823",
 "code/game/area/caribbean.dm":"7dab770535bb41736648780eac4f1283bc24cb64",
 "code/game/objects/effects/landmarks/normal.dm":"56a17e5ec62c4b8c43c83e9a526e78f2b3307ff9",
 "code/game/objects/map_metadata/nomads/nomads.dm":"7d44d40584567fafcddfeb79056a0a4da24acb08",
 "civ13.dme":"b2bef805c76f6b14ead026cc7756d9d3eb0b2f53",
}
TREES={"BROADLEAF":"/obj/structure/wild/tree/live_tree","PINE":"/obj/structure/wild/tree/live_tree/pine",
       "PALM":"/obj/structure/wild/palm","CACTUS":"/obj/structure/wild/tree/cactus"}


def verify_catalog(catalog_root=None):
    for path,pin in CATALOG.items():
        read_pinned(path,pin,catalog_root)
    # Exact type declarations, not prefix/type-name guesses. DME source includes are also pinned.
    declarations={
      "code/game/turfs/floor_types.dm":["/turf/floor/grass","/turf/floor/beach/sand","/turf/floor/beach/water","/turf/floor/beach/water/deep","/turf/floor/beach/water/shallowsaltwater","/turf/floor/beach/water/deep/saltwater","/turf/floor/beach/water/swamp"],
      "code/game/turfs/flooring/flooring_premade.dm":["/turf/floor/dirt","/turf/floor/dirt/underground"],
      "code/game/objects/structures/wild.dm":list(TREES.values()),
      "code/game/objects/structures/rocks.dm":["/obj/structure/wild/rock/basalt"],
      "code/game/area/caribbean.dm":["/area/caribbean/nomads/forest","/area/caribbean/void/caves"],
      "code/game/objects/effects/landmarks/normal.dm":["/obj/effect/landmark"],
      "code/game/objects/map_metadata/nomads/nomads.dm":["/obj/map_metadata/nomads"],
    }
    for path,types in declarations.items():
        source=read_pinned(path,CATALOG[path],catalog_root).decode("utf-8")
        for typename in types:
            if not re.search(r"^"+re.escape(typename)+r"\s*$",source,re.M):raise ValueError("CATALOG_TYPE_MISSING: "+typename)
    return True


def project(doc):
    errors=validate(doc)
    if errors:raise ValueError("IR_REJECTED: "+json.dumps(errors))
    if doc["profile"] not in {"SURFACE","OCEANIC"} or set(doc["layers"])!={"SURFACE","UNDERGROUND"}:
        raise ValueError("EXPORT_PROFILE: two-plane SURFACE or OCEANIC only")
    starts={tuple(p) for p in doc["starts"]};result={}
    for layer,level in doc["layers"].items():
        z=level["native_z"]
        for y,row in enumerate(level["cells"]):
            for x,c in enumerate(row):
                atoms=[]
                if c["hazard"]:raise ValueError("EXPORT_HAZARD_UNSUPPORTED")
                if c["water"]!="NONE":
                    if c["depth_cm"] not in {30,200}:raise ValueError("EXPORT_DEPTH_UNSUPPORTED")
                    if c["salinity"]=="BRACKISH":raise ValueError("EXPORT_BRACKISH_UNSUPPORTED")
                    base="/turf/floor/beach/water"
                    if c["water"]=="SWAMP":
                        if c["salinity"]!="FRESH" or c["depth_cm"]!=30:raise ValueError("EXPORT_SWAMP_UNSUPPORTED")
                        turf=base+"/swamp"
                    elif c["salinity"]=="SALT":turf=base+("/deep/saltwater" if c["depth_cm"]==200 else "/shallowsaltwater")
                    else:turf=base+("/deep" if c["depth_cm"]==200 else "")
                else:
                    if c["terrain"] in {"MOUNTAIN","ROCK"}:
                        # Native dense basalt plus underground-dirt substrate. Geographic
                        # altitude/range identity remain sidecar metadata, not new DM vars.
                        turf="/turf/floor/dirt/underground";atoms.append("/obj/structure/wild/rock/basalt")
                    elif c["terrain"]=="CAVE_FLOOR":turf="/turf/floor/dirt/underground"
                    elif c["terrain"]=="HILL":turf="/turf/floor/dirt"
                    elif c["terrain"]=="BEACH" or c["soil"]=="SAND":turf="/turf/floor/beach/sand"
                    else:turf="/turf/floor/grass"
                if c["blocked"] and c["terrain"] not in {"MOUNTAIN","ROCK"}:raise ValueError("EXPORT_BLOCKER_UNSUPPORTED")
                if c["tree"]!="NONE":
                    if c["tree"] not in TREES:raise ValueError("EXPORT_SPECIES_UNSUPPORTED")
                    atoms.append(TREES[c["tree"]])
                if (x,y,layer) in starts:atoms.append('/obj/effect/landmark{icon_state = "x3"; name = "JoinLateCiv"}')
                if x==0 and y==0 and layer=="UNDERGROUND":atoms.append("/obj/map_metadata/nomads")
                atoms.extend([turf,"/area/caribbean/nomads/forest" if layer=="SURFACE" else "/area/caribbean/void/caves"])
                result[(x+1,y+1,z)]=",".join(atoms)
    return result


def emit(doc,manifest,catalog_root=None):
    verify_catalog(catalog_root)
    if manifest["generation_result"]["ir_sha256"]!=canonical_hash(doc):raise ValueError("MANIFEST_IR_MISMATCH")
    layout=project(doc);recipes=sorted(set(layout.values()));alphabet="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    def key(n):return "".join(alphabet[(n//52**power)%52] for power in [1,0])
    if len(recipes)>52**2:raise ValueError("DICTIONARY_CAPACITY")
    keys={recipe:key(i) for i,recipe in enumerate(recipes)}
    lines=['// Offline generated layout. Requires pinned Civ13 project/assets. Not runtime acceptance.']
    lines.extend('"'+keys[recipe]+'" = ('+recipe+')' for recipe in recipes)
    for z in [1,2]:
        lines.extend(["",f'(1,1,{z}) = {{"'])
        for y in range(doc["height"],0,-1):lines.append("".join(keys[layout[(x,y,z)]] for x in range(1,doc["width"]+1)))
        lines.append('"}')
    text="\n".join(lines)+"\n"
    sidecar={"schema":"civ13-dmm-sidecar/1","catalog_version":CATALOG_VERSION,"source_commit":COMMIT,
             "dmm_sha256":hashlib.sha256(text.encode()).hexdigest(),"ir_sha256":canonical_hash(doc),
             "manifest":manifest,"semantic_ir":doc,
             "projection_limits":["river/lake/body distinction, biome, elevation, soil/climate and abstract resource labels require this sidecar",
               "mountains and blocked reserve project to dense native basalt on underground dirt; no altitude/biome runtime behavior is added",
               "abstract supplies are sidecar-only and are not emitted as usable native supplies",
               "constructors may randomize appearance/start timers; static layout is not deterministic runtime or gameplay acceptance"]}
    verify_roundtrip(text,sidecar)
    return text,sidecar


def verify_roundtrip(text,sidecar):
    if sidecar["schema"]!="civ13-dmm-sidecar/1" or sidecar["source_commit"]!=COMMIT or sidecar["catalog_version"]!=CATALOG_VERSION:
        raise ValueError("SIDECAR_VERSION")
    if hashlib.sha256(text.encode()).hexdigest()!=sidecar["dmm_sha256"]:raise ValueError("DMM_HASH_MISMATCH")
    doc=sidecar["semantic_ir"]
    if canonical_hash(doc)!=sidecar["ir_sha256"] or sidecar["manifest"]["generation_result"]["ir_sha256"]!=sidecar["ir_sha256"]:
        raise ValueError("IR_HASH_MISMATCH")
    _,parsed,dims=parse_classic(text)
    if sorted(dims)!=[[doc["width"],doc["height"],1],[doc["width"],doc["height"],2]]:raise ValueError("DMM_DIMENSIONS")
    if parsed!=project(doc):raise ValueError("NATIVE_LAYOUT_MISMATCH")
    return {"static_native_layout_equal":True,"ir_plus_sidecar_semantics_equal":True,
            "dmm_alone_full_ir_semantics":False,"native_editor_compiler_runtime":"NOT_RUN",
            "cells_checked":len(parsed),"ir_sha256":sidecar["ir_sha256"]}
