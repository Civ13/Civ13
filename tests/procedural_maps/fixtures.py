"""Hand-authored synthetic contract fixtures, not procedural Civ13 maps."""
from copy import deepcopy
import json
from pathlib import Path
from tools.procedural_maps.validator import VERSION


def cell(**changes):
    c=dict(terrain="PLAIN",biome="TEMPERATE",soil="LOAM",elevation_m=0,
           moisture=50,temperature_c=20,water="NONE",salinity="NONE",depth_cm=0,
           body="",blocked=False,tree="NONE",resource="NONE",hazard=False)
    c.update(changes); return c


def base(profile="SURFACE",w=9,h=9):
    return dict(schema=VERSION,seed="fixture-only-0",algorithm_version="fixture/1",
                content_version="synthetic/1",profile_version=profile+"/1",profile=profile,
                active_layer="SURFACE",width=w,height=h,
                layers={"SURFACE":{"native_z":2,"cells":[[cell() for _ in range(w)] for _ in range(h)]}},
                ports=[],rivers=[],lakes=[],starts=[[2,2,"SURFACE"]],portals=[],
                policy=dict(mountain_min_area=3,mountain_max_components=2,max_moisture_step=25,
                            max_temperature_step=10,max_resource_distance=20,max_water_distance=20,
                            ship_radius=0,ocean_ports_min=2,land_components_min=2,start_count=1,
                            river_half_width=1,max_path_uphill_m=0))


def put(d,x,y,layer="SURFACE",**changes):
    d["layers"][layer]["cells"][y][x].update(changes)


def water(d,x,y,kind,body,layer="SURFACE",**changes):
    put(d,x,y,layer,terrain="WATER",water=kind,body=body,
        salinity="SALT" if kind=="SEA" else "FRESH",depth_cm=200,**changes)


def supplies(d,layer="SURFACE",x=2,y=2):
    for dx,res in [(0,"FOOD"),(1,"WOOD"),(2,"STONE")]: put(d,x+dx,y,layer,resource=res)


def surface():
    d=base(); supplies(d)
    for y in range(9): water(d,0,y,"RIVER","r1")
    d["ports"]=[dict(id="north",at=[0,8,"SURFACE"],side="N",role="INLET",body="r1"),
                dict(id="south",at=[0,0,"SURFACE"],side="S",role="OUTLET",body="r1")]
    d["rivers"]=[dict(id="r1",path=[[0,y,"SURFACE"] for y in reversed(range(9))],
                      source=dict(kind="EDGE",target="north"),sink=dict(kind="EDGE",target="south"))]
    for x in [5,6,7]: put(d,x,7,terrain="MOUNTAIN",soil="ROCK",blocked=True)
    put(d,6,5,tree="BROADLEAF")
    return d


def lake_surface(terminal=True):
    d=surface()
    for y in range(4): put(d,0,y,**cell())
    water(d,0,3,"LAKE","l1");water(d,1,3,"LAKE","l1")
    d["rivers"][0]["path"]=[[0,y,"SURFACE"] for y in range(8,3,-1)]
    d["rivers"][0]["sink"]={"kind":"LAKE","target":"l1"}
    d["ports"]=d["ports"][:1]
    d["lakes"]=[dict(id="l1",terminal_basin=terminal,outflow="" if terminal else "r2")]
    if not terminal:
        for y in range(3):water(d,0,y,"RIVER","r2")
        d["rivers"].append(dict(id="r2",path=[[0,y,"SURFACE"] for y in range(2,-1,-1)],
                                source=dict(kind="LAKE",target="l1"),sink=dict(kind="EDGE",target="south")))
        d["ports"].append(dict(id="south",at=[0,0,"SURFACE"],side="S",role="OUTLET",body="r2"))
    return d


def oceanic():
    d=base("OCEANIC",13,11)
    for y in range(11):
        for x in range(13): water(d,x,y,"SEA","ocean")
    # Two genuinely separate land components, each with safe supplies and a fresh lake.
    for x0 in [1,8]:
        for y in range(2,8):
            for x in range(x0,x0+4):put(d,x,y,**cell(terrain="BEACH",biome="COAST"))
        supplies(d,x=x0,y=3)
        water(d,x0+3,6,"LAKE","lake"+str(x0))
        d["lakes"].append(dict(id="lake"+str(x0),terminal_basin=True,outflow=""))
    d["starts"]=[[2,3,"SURFACE"],[9,3,"SURFACE"]];d["policy"]["start_count"]=2
    d["ports"]=[dict(id="west",at=[0,0,"SURFACE"],side="W",role="OCEAN",body="ocean"),
                dict(id="east",at=[12,0,"SURFACE"],side="E",role="OCEAN",body="ocean")]
    return d


def cavern():
    d=base("UNDERGROUND_CAVERN")
    d["active_layer"]="UNDERGROUND"
    d["layers"]["UNDERGROUND"]={"native_z":1,"cells":[[cell(terrain="ROCK",biome="CAVERN",soil="ROCK",blocked=True) for _ in range(9)] for _ in range(9)]}
    for y in range(1,8):
        for x in range(1,8):put(d,x,y,"UNDERGROUND",**cell(terrain="CAVE_FLOOR",biome="CAVERN",soil="ROCK"))
    supplies(d,layer="UNDERGROUND")
    water(d,7,7,"LAKE","springpool",layer="UNDERGROUND")
    d["lakes"]=[dict(id="springpool",terminal_basin=True,outflow="")]
    d["starts"]=[[2,2,"UNDERGROUND"]]
    d["portals"]=[dict(a=[1,1,"UNDERGROUND"],b=[1,1,"SURFACE"])]
    return d


def all_fixtures():
    return {"surface":surface(),"terminal_lake":lake_surface(),"through_lake":lake_surface(False),
            "oceanic":oceanic(),"cavern":cavern()}
