"""Versioned, bounded offline configuration. Limits are provisional engineering caps.
Acceptance here is configuration consistency only, never runtime/resource admission.
"""
from copy import deepcopy
from .validator import canonical_hash

CONFIG_VERSION="civ13-generation-config/1"
PORT_CONFIG_VERSION="civ13-generation-config/2"
BIOMES={"TEMPERATE","LUSH","STEPPE","ARID","DESERT","ALPINE","COAST","CAVERN"}
ROOT={"schema","profile","preset","seed","dimensions","biome_mix_pct","climate","water",
      "mountains","vegetation","resources","starts"}


def preset(profile="SURFACE",seed="0"):
    if profile not in {"SURFACE","OCEANIC","UNDERGROUND_CAVERN"}:raise ValueError("profile")
    d=dict(schema=CONFIG_VERSION,profile=profile,preset={"SURFACE":"TEMPERATE_REFERENCE",
            "OCEANIC":"ARCHIPELAGO","UNDERGROUND_CAVERN":"CONNECTED_CAVES"}[profile],seed=seed,
           dimensions=dict(width=155,height=225,layers={"SURFACE":2,"UNDERGROUND":1}),
           biome_mix_pct={"TEMPERATE":70,"STEPPE":20,"ARID":10},
           climate=dict(moisture_range=[20,80],temperature_c_range=[0,30]),
           water=dict(coverage_pct=[10,20],river_networks=[1,3],river_width_tiles=[2,5],
                      lake_count=[1,3],lake_area_pct=[3,12],swamp_pct=[0,4],sea_pct=[1,5]),
           mountains=dict(range_count=[0,2],range_min_area=32,range_width_tiles=[3,12]),
           vegetation=dict(suitable_site_density_pct=[10,35]),
           resources=dict(density_per_1000_land_tiles=[10,30]),
           starts=dict(count=18,min_spacing_tiles=8,max_route_tiles=60))
    if profile=="OCEANIC":
        d["biome_mix_pct"]={"COAST":60,"TEMPERATE":40}
        d["water"].update(coverage_pct=[60,85],sea_pct=[55,80],lake_area_pct=[1,3],swamp_pct=[0,2],river_networks=[0,2])
        d["mountains"]["range_count"]=[0,3];d["starts"]["count"]=6
    elif profile=="UNDERGROUND_CAVERN":
        d["biome_mix_pct"]={"CAVERN":100}
        d["climate"].update(moisture_range=[40,80],temperature_c_range=[5,20])
        d["water"].update(coverage_pct=[2,10],sea_pct=[0,0],lake_area_pct=[1,8],swamp_pct=[0,0],river_networks=[0,2])
        d["mountains"]["range_count"]=[0,0];d["starts"]["count"]=8
    return d


def _validate_v1(d):
    errors=[]
    def fail(code,detail):errors.append({"code":code,"detail":detail})
    def require(v,label):
        if not v:raise ValueError(label)
    def exact(v,keys,label):require(type(v) is dict and set(v)==set(keys),label)
    def integer(v,lo,hi):return type(v) is int and lo<=v<=hi
    def interval(v,lo,hi,label):
        require(type(v) is list and len(v)==2 and all(integer(i,lo,hi) for i in v) and v[0]<=v[1],label)
    try:
        exact(d,ROOT,"root keys: invariant switches and unknown controls forbidden")
        require(d["schema"]==CONFIG_VERSION,"schema")
        require(d["profile"] in {"SURFACE","OCEANIC","UNDERGROUND_CAVERN"},"profile")
        require(d["preset"] in {"TEMPERATE_REFERENCE","ARCHIPELAGO","CONNECTED_CAVES","CUSTOM"},"preset")
        expected={"SURFACE":"TEMPERATE_REFERENCE","OCEANIC":"ARCHIPELAGO","UNDERGROUND_CAVERN":"CONNECTED_CAVES"}[d["profile"]]
        require(d["preset"] in {expected,"CUSTOM"},"preset/profile mismatch")
        require(type(d["seed"]) is str and d["seed"].isascii() and 1<=len(d["seed"])<=128,"ASCII seed")
        exact(d["dimensions"],{"width","height","layers"},"dimensions")
        require(all(integer(d["dimensions"][k],32,512) for k in ["width","height"]),"dimensions 32..512")
        require(d["dimensions"]["layers"]=={"SURFACE":2,"UNDERGROUND":1} and
                all(type(v) is int for v in d["dimensions"]["layers"].values()),"classic two-layer mapping")
        mix=d["biome_mix_pct"]
        require(type(mix) is dict and mix and set(mix)<=BIOMES and all(integer(v,0,100) for v in mix.values()) and sum(mix.values())==100,"land-biome percentages sum to 100")
        exact(d["climate"],{"moisture_range","temperature_c_range"},"climate")
        interval(d["climate"]["moisture_range"],0,100,"moisture range")
        interval(d["climate"]["temperature_c_range"],-50,50,"temperature range")
        exact(d["water"],{"coverage_pct","river_networks","river_width_tiles","lake_count","lake_area_pct","swamp_pct","sea_pct"},"water")
        for k in ["coverage_pct","lake_area_pct","swamp_pct","sea_pct"]:interval(d["water"][k],0,95,"water "+k)
        interval(d["water"]["river_networks"],0,8,"river networks")
        interval(d["water"]["river_width_tiles"],1,16,"river width")
        interval(d["water"]["lake_count"],0,12,"lake count")
        exact(d["mountains"],{"range_count","range_min_area","range_width_tiles"},"mountains")
        interval(d["mountains"]["range_count"],0,6,"range count")
        require(integer(d["mountains"]["range_min_area"],3,4096),"range area")
        interval(d["mountains"]["range_width_tiles"],2,32,"range width")
        exact(d["vegetation"],{"suitable_site_density_pct"},"vegetation")
        interval(d["vegetation"]["suitable_site_density_pct"],0,70,"vegetation density")
        exact(d["resources"],{"density_per_1000_land_tiles"},"resources")
        interval(d["resources"]["density_per_1000_land_tiles"],1,100,"resource density")
        exact(d["starts"],{"count","min_spacing_tiles","max_route_tiles"},"starts")
        for k,lo,hi in [("count",1,64),("min_spacing_tiles",3,64),("max_route_tiles",8,256)]:
            require(integer(d["starts"][k],lo,hi),"starts "+k)
    except (ValueError,TypeError,KeyError) as e:
        return [{"code":"CONFIG_SCHEMA","detail":str(e)}]
    w,h=d["dimensions"]["width"],d["dimensions"]["height"]
    water=d["water"];mount=d["mountains"];mix=d["biome_mix_pct"]
    land_max=w*h*(100-water["coverage_pct"][0])/100
    if sum(water[k][0] for k in ["lake_area_pct","swamp_pct","sea_pct"])>water["coverage_pct"][1]:
        fail("CONFIG_WATER_BUDGET","minimum lake+swamp+sea coverage exceeds total water maximum")
    if any(water[k][1]>water["coverage_pct"][1] for k in ["lake_area_pct","swamp_pct","sea_pct"]):
        fail("CONFIG_WATER_BUDGET","water component maximum exceeds total maximum")
    if water["lake_count"][1]==0 and water["lake_area_pct"][1]>0 or water["lake_count"][0]>0 and water["lake_area_pct"][1]==0:
        fail("CONFIG_LAKE_CONFLICT","lake count and area contradict")
    if water["coverage_pct"][1]==0 and (water["river_networks"][1]>0 or water["lake_count"][1]>0):
        fail("CONFIG_WATER_CONFLICT","dry config requests water features")
    if mount["range_count"][0]*mount["range_min_area"]>land_max:
        fail("CONFIG_RANGE_BUDGET","minimum ranges cannot fit even the maximum dry land")
    if water["river_width_tiles"][1]>=min(w,h)//2 or mount["range_width_tiles"][1]>=min(w,h):
        fail("CONFIG_SCALE","requested feature width incompatible with dimensions")
    if d["starts"]["count"]*9>land_max or (d["starts"]["count"]>1 and d["starts"]["min_spacing_tiles"]>w+h-2):
        fail("CONFIG_START_CAPACITY","necessary start-clearance or separation bound cannot fit")
    # These tests reject obvious contradictions; complete packing is checked on generated geometry.
    moisture=d["climate"]["moisture_range"]
    if mix.get("LUSH",0)>0 and moisture[1]<65 or mix.get("DESERT",0)>0 and moisture[0]>30:
        fail("CONFIG_CLIMATE","requested biome has no valid moisture envelope")
    if mix.get("LUSH",0)>0 and mix.get("DESERT",0)>0 and not all(mix.get(k,0)>0 for k in ["TEMPERATE","STEPPE","ARID"]):
        fail("CONFIG_ECOTONE","lush and desert require intermediate land biomes")
    if d["profile"]=="UNDERGROUND_CAVERN":
        if mix!={"CAVERN":100} or mount["range_count"][1]>0 or water["sea_pct"][1]>0:
            fail("CONFIG_PROFILE","caverns require cavern catalog; no surface ranges or sea in this preset family")
    elif mix.get("CAVERN",0)>0:
        fail("CONFIG_PROFILE","surface profiles cannot request cavern land biome")
    if d["profile"]=="OCEANIC" and (water["sea_pct"][0]<50 or water["coverage_pct"][0]<50):
        fail("CONFIG_OCEANIC","oceanic family requires majority-water/sea lower bound")
    return errors


def port_surface_preset(seed="ports-0",width=155,height=225,*,sea_side="S"):
    """Explicit graph family: 2-3 edge inlets -> confluence -> lake -> sea/edge."""
    d=preset(seed=seed);d.update(schema=PORT_CONFIG_VERSION,preset="CUSTOM")
    d["dimensions"].update(width=width,height=height)
    d["water"].update(river_networks=[1,1],lake_count=[1,1],lake_area_pct=[4,7],
                      coverage_pct=[12,26],river_width_tiles=[3,3],sea_pct=[2,4],swamp_pct=[0,4])
    d["starts"]["count"]=6 if width<100 else 18
    def span(n,pct):
        center=n*pct//100;return [center-1,center+1]
    inlet_sides=[s for s in ["W","N","E"] if s!=sea_side]
    d["surface_layout"]={"sea_side":sea_side,"inlets":[{"id":"inlet-"+s.lower(),"side":s,"span":span(width if s in {"N","S"} else height,62 if s in {"W","E"} else 27)} for s in inlet_sides],
                         "outlet":{"id":"outlet","kind":"SEA","side":sea_side,"span":span(width if sea_side in {"N","S"} else height,60)},
                         "junction_pct":[45,67],"lake_pct":[56,39],"climate_axis":[1,1]}
    if sea_side=='N':
        d['surface_layout'].update(junction_pct=[45,33],lake_pct=[56,61],climate_axis=[1,-1])
        for p in d['surface_layout']['inlets']:
            if p['side'] in {'W','E'}:p['span']=span(height,38)
    elif sea_side=='E':d['surface_layout'].update(junction_pct=[36,67],lake_pct=[65,40],climate_axis=[-1,1])
    elif sea_side=='W':d['surface_layout'].update(junction_pct=[67,55],lake_pct=[36,39],climate_axis=[1,-1])
    return d


def _validate_config(d):
    if not isinstance(d,dict) or d.get("schema")!=PORT_CONFIG_VERSION:return _validate_v1(d)
    base=deepcopy(d);layout=base.pop("surface_layout",None);base["schema"]=CONFIG_VERSION
    errors=_validate_v1(base)
    if errors:return errors
    def bad(detail):return [{"code":"CONFIG_PORT_LAYOUT","detail":detail}]
    def exact(v,keys):return type(v) is dict and set(v)==set(keys)
    def ints(v,n,lo,hi):return type(v) is list and len(v)==n and all(type(i) is int and lo<=i<=hi for i in v)
    if d["profile"]!="SURFACE":return bad("config v2 currently supports SURFACE only")
    if not exact(layout,{"sea_side","inlets","outlet","junction_pct","lake_pct","climate_axis"}):return bad("layout keys")
    if layout["sea_side"] not in {"N","S","E","W","NONE"}:return bad("sea side")
    if type(layout["inlets"]) is not list or not 2<=len(layout["inlets"])<=3:return bad("2..3 inlet ports required")
    if not exact(layout["outlet"],{"id","kind","side","span"}) or layout["outlet"]["kind"] not in {"SEA","EDGE"}:return bad("outlet kind/keys")
    if not ints(layout["junction_pct"],2,15,85) or not ints(layout["lake_pct"],2,15,85):return bad("feature positions 15..85 percent")
    if sum(abs(a-b) for a,b in zip(layout["junction_pct"],layout["lake_pct"]))<20:return bad("junction/lake anchors too close")
    if not ints(layout["climate_axis"],2,-4,4) or layout["climate_axis"]==[0,0]:return bad("climate axis must be nonzero integer vector -4..4")
    w,h=d["dimensions"]["width"],d["dimensions"]["height"];ids=set();occupied=set()
    for i,p in enumerate(layout["inlets"]+[layout["outlet"]]):
        if not exact(p,{"id","side","span"} if i<len(layout["inlets"]) else {"id","kind","side","span"}):return bad("port keys")
        if type(p["id"]) is not str or not 1<=len(p["id"])<=40 or p["id"] in ids:return bad("unique short port IDs required")
        ids.add(p["id"])
        if p["side"] not in {"N","S","E","W"}:return bad("port side")
        length=w if p["side"] in {"N","S"} else h
        if not ints(p["span"],2,1,length-2) or not 1<=p["span"][1]-p["span"][0]+1<=16:return bad("port span must be ordered, width 1..16 and exclude corners")
        for offset in range(p["span"][0],p["span"][1]+1):
            key=(p["side"],offset)
            if key in occupied:return bad("overlapping edge-port spans")
            occupied.add(key)
    outlet=layout["outlet"]
    if outlet["kind"]=="SEA":
        if layout["sea_side"]!=outlet["side"] or d["water"]["sea_pct"][0]<=0:return bad("sea outlet requires positive coast on the same side")
        if any(p["side"]==layout["sea_side"] for p in layout["inlets"]):return bad("inlet cannot occupy the solid sea coast side")
    elif layout["sea_side"]!="NONE" or d["water"]["sea_pct"]!=[0,0]:return bad("edge outlet family requires sea NONE and sea_pct [0,0]")
    if d["water"]["river_networks"]!=[1,1] or d["water"]["lake_count"]!=[1,1]:return bad("v2 slice requires one connected network and one through-lake")
    return []


def validate_config(d):
    try:return _validate_config(d)
    except (TypeError,KeyError,ValueError) as e:return [{"code":"CONFIG_SCHEMA","detail":"malformed versioned configuration: "+str(e)}]


def seed_manifest(config,algorithm_version,content_version,profile_version):
    errors=validate_config(config)
    if errors:return {"status":"CONFIG_REJECTED","errors":errors}
    return {"status":"CONFIG_VALIDATED_OFFLINE_ONLY","schema":"civ13-seed-manifest/1",
            "algorithm_version":algorithm_version,"content_version":content_version,"profile_version":profile_version,
            "configuration":deepcopy(config),"configuration_sha256":canonical_hash(config),
            "layer_mapping":deepcopy(config["dimensions"]["layers"]),
            "required_invariants":"SPECIFICATION H1-H8/G1-G5/S1-S4; cannot be disabled",
            "native_resource_admission":"PENDING","generation_result":None}
