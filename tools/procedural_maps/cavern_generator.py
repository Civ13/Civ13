"""Original dependency-free UNDERGROUND_CAVERN backend for offline IR, never DM/game output.

Noise-grown chambers joined by a minimum spanning set of winding tunnels, fresh
spring pools cut into the rock beside chambers, isolated fungus pillars, paired
surface exits, and reserved survival routes. The surface plane is open placeholder
ground so every exit lands on a safe tile; it is not a generated surface map.
"""
from __future__ import annotations
from collections import Counter
from copy import deepcopy
import heapq
import json
from .configuration import validate_config,seed_manifest
from .surface_generator import Rejection,ground,neighbors,distances
from .validator import VERSION,stable_u64,canonical_hash,validate

ALGORITHM_VERSION="cavern-offline/0.1.0"
CONTENT_VERSION="abstract-survival-catalog/1"
PROFILE_VERSION="UNDERGROUND_CAVERN-offline/1"
CHAMBER_AREA=900 # one chamber per this many map tiles
MIN_CHAMBERS=4
MAX_CHAMBERS=40


def rock(**changes):
    return ground(terrain="ROCK",biome="CAVERN",soil="ROCK",blocked=True,elevation_m=-40,**changes)


def _generate(config,traversal):
    problems=validate_config(config)
    if problems:raise Rejection("CONFIG_REJECTED",json.dumps(problems,sort_keys=True))
    if config["profile"]!="UNDERGROUND_CAVERN":raise Rejection("BACKEND_PROFILE","only UNDERGROUND_CAVERN is implemented here")
    if config["schema"]!="civ13-generation-config/1":raise Rejection("BACKEND_SCHEMA","caverns use the version 1 configuration")
    water_cfg=config["water"]
    if water_cfg["river_networks"][0]>0:raise Rejection("BACKEND_RIVERS","underground rivers are not implemented; set river_networks minimum to 0")
    if water_cfg["swamp_pct"][0]>0:raise Rejection("BACKEND_WATER","cavern backend makes no wetlands")
    if traversal not in {"forward","reverse"}:raise ValueError("traversal")
    cfg_hash=canonical_hash(config);seed=config["seed"]
    def draw(stage,x=0,y=0,slot=0):
        return stable_u64(seed,ALGORITHM_VERSION,CONTENT_VERSION,PROFILE_VERSION+":"+cfg_hash,stage,"UNDERGROUND",x,y,slot)
    def choose(stage,bounds,slot=0):
        span=bounds[1]-bounds[0]+1;limit=2**64-(2**64%span)
        for retry in range(32):
            value=draw(stage+"-choice",slot=slot*32+retry)
            if value<limit:return bounds[0]+value%span
        raise Rejection("RANDOM_REJECTION_BOUND","integer sampling exhausted 32 draws")
    lattice={}
    def field(stage,x,y,scale):
        # Same bilinear fixed-point lattice noise as the surface backend.
        gx,tx=divmod(x,scale);gy,ty=divmod(y,scale)
        def node(xx,yy):
            key=(stage,xx,yy)
            if key not in lattice:lattice[key]=draw(stage,xx,yy)%1024
            return lattice[key]
        a=node(gx,gy);b=node(gx+1,gy);c=node(gx,gy+1);d=node(gx+1,gy+1)
        return ((a*(scale-tx)+b*tx)*(scale-ty)+(c*(scale-tx)+d*tx)*ty)//(scale*scale)
    w,h=config["dimensions"]["width"],config["dimensions"]["height"]
    area=w*h
    points=[(x,y) for y in range(h) for x in range(w)]
    iteration=points if traversal=="forward" else list(reversed(points))
    moist_lo,moist_hi=config["climate"]["moisture_range"];temp_lo,temp_hi=config["climate"]["temperature_c_range"]
    surface_moisture=max(moist_lo,min(moist_hi,55));surface_temp=(temp_lo+temp_hi)//2
    grid=[[None for _ in range(w)] for _ in range(h)]
    surface=[[None for _ in range(w)] for _ in range(h)]
    scale=max(8,min(w,h)//6)
    for x,y in iteration:
        # Smooth fields keep neighbour climate steps far below validator limits.
        moisture=moist_lo+field("cave-moisture",x,y,scale)*(moist_hi-moist_lo)//1023
        temperature=temp_lo+field("cave-temperature",x,y,scale)*(temp_hi-temp_lo)//1023
        grid[y][x]=rock(moisture=moisture,temperature_c=temperature)
        surface[y][x]=ground(moisture=surface_moisture,temperature_c=surface_temp)
    def at(p):return grid[p[1]][p[0]]
    interior={(x,y) for x,y in points if 2<=x<w-2 and 2<=y<h-2}
    if len(interior)<area//2:raise Rejection("CAVERN_SCALE","map too small for chambers")
    # Chambers: spread centres on a jittered lattice, then grow noise-shaped blobs.
    chamber_count=max(MIN_CHAMBERS,min(MAX_CHAMBERS,area//CHAMBER_AREA))
    columns=max(1,round((chamber_count*w/h)**0.5));rows=(chamber_count+columns-1)//columns
    centres=[]
    for i in range(chamber_count):
        col,row=i%columns,i//columns
        x0,x1=col*w//columns,(col+1)*w//columns-1;y0,y1=row*h//rows,(row+1)*h//rows-1
        mx=max(3,(x1-x0)//4);my=max(3,(y1-y0)//4)
        cx=max(x0+mx,min(x1-mx,x0+mx+draw("chamber-x",i)%max(1,x1-x0-2*mx+1)))
        cy=max(y0+my,min(y1-my,y0+my+draw("chamber-y",i)%max(1,y1-y0-2*my+1)))
        cx=max(3,min(w-4,cx));cy=max(3,min(h-4,cy))
        centres.append((cx,cy))
    chambers=[];floor=set()
    for i,centre in enumerate(centres):
        cell_area=(w//columns)*(h//rows)
        target=max(12,cell_area*(18+draw("chamber-size",i)%17)//100)
        frontier=[(0,centre)];seen={centre};body=set()
        def cost(p):
            dx,dy=p[0]-centre[0],p[1]-centre[1]
            return (dx*dx+dy*dy)*4+field("chamber-shape-"+str(i),p[0],p[1],max(3,min(w,h)//12))//4
        while frontier and len(body)<target:
            _,p=heapq.heappop(frontier);body.add(p)
            for q in neighbors(p,w,h):
                if q in interior and q not in seen:seen.add(q);heapq.heappush(frontier,(cost(q),q))
        chambers.append(body);floor|=body
    # Tunnels: Prim's minimum spanning tree over chamber centres, plus one loop,
    # each carved as a noise-weighted shortest path through the interior.
    def tunnel(a,b,stage):
        heap=[(0,a)];best={a:0};parent={}
        noise=max(3,min(w,h)//10)
        while heap:
            total,p=heapq.heappop(heap)
            if total!=best[p]:continue
            if p==b:break
            for q in neighbors(p,w,h):
                if q not in interior:continue
                step=total+(20 if q in floor else 100)+field(stage,q[0],q[1],noise)//8
                if step<best.get(q,10**30):best[q]=step;parent[q]=p;heapq.heappush(heap,(step,q))
        if b not in best:raise Rejection("TUNNEL_ROUTE","interior cannot join two chambers")
        path=[b]
        while path[-1]!=a:path.append(parent[path[-1]])
        return path
    joined={0};edges=[]
    while len(joined)<len(centres):
        a,b=min(((i,j) for i in joined for j in range(len(centres)) if j not in joined),
                key=lambda e:(abs(centres[e[0]][0]-centres[e[1]][0])+abs(centres[e[0]][1]-centres[e[1]][1]),e))
        edges.append((a,b));joined.add(b)
    if len(centres)>2:
        extra=min(((i,j) for i in range(len(centres)) for j in range(i+1,len(centres)) if (i,j) not in edges and (j,i) not in edges),
                  key=lambda e:(abs(centres[e[0]][0]-centres[e[1]][0])+abs(centres[e[0]][1]-centres[e[1]][1]),e))
        edges.append(extra)
    tunnel_records=[]
    for n,(a,b) in enumerate(edges):
        path=tunnel(centres[a],centres[b],"tunnel-"+str(n))
        wide=draw("tunnel-width",n)%2
        for p in path:
            floor.add(p)
            if wide:
                for q in neighbors(p,w,h):
                    if q in interior and draw("tunnel-widen",*q)%3==0:floor.add(q)
        tunnel_records.append(dict(chambers=[a,b],length=len(path)))
    for p in floor:at(p).update(terrain="CAVE_FLOOR",blocked=False)
    # Spring pools grow into solid rock beside chambers, so they never cut the floor.
    lake_count=choose("lake-count",water_cfg["lake_count"])
    lo=max(water_cfg["lake_area_pct"][0],water_cfg["coverage_pct"][0])
    hi=min(water_cfg["lake_area_pct"][1],water_cfg["coverage_pct"][1])
    if lake_count==0 or hi<lo:raise Rejection("WATER_BUDGET","caverns need at least one spring pool inside the water intervals")
    lake_pct=choose("lake-coverage",[lo,hi])
    lake_cells=max(lake_count,(area*lake_pct+99)//100)
    if lake_cells*100>hi*area:lake_cells=area*hi//100
    lakes=[];lake_sets=[];wet=set()
    ranked=sorted(range(len(chambers)),key=lambda i:(draw("lake-chamber",i),i))
    def keep_clear(q):
        # Pools stay in solid rock, apart from each other, off the map edge.
        return q in interior and q not in floor and q not in wet and not any(t in wet for t in neighbors(q,w,h))
    def grow_pool(i,start,target):
        frontier=[(0,start)];seen={start};body=set()
        def lake_cost(p):
            dx,dy=p[0]-start[0],p[1]-start[1]
            return (dx*dx+dy*dy)*3+field("lake-shape-"+str(i),p[0],p[1],max(3,min(w,h)//12))//8
        while frontier and len(body)<target:
            _,p=heapq.heappop(frontier)
            if not keep_clear(p):continue
            body.add(p)
            for q in neighbors(p,w,h):
                if q not in seen and q not in floor:seen.add(q);heapq.heappush(frontier,(lake_cost(q),q))
        return body
    for i in range(lake_count):
        target=lake_cells//lake_count+(i<lake_cells%lake_count)
        # Bounded deterministic search: up to 8 chambers, 4 rock seeds each.
        body=set()
        for k in range(min(8,len(ranked))):
            chamber=chambers[ranked[(i+k)%len(ranked)]]
            seeds=sorted({q for p in chamber for q in neighbors(p,w,h) if keep_clear(q)},key=lambda q:(draw("lake-seed-"+str(i),*q),q))
            for start in seeds[:4]:
                body=grow_pool(i,start,target)
                if len(body)==target:break
            if len(body)==target:break
        if len(body)!=target:raise Rejection("LAKE_PACKING","bounded pool growth exhausted")
        lid="pool-"+str(i)
        for p in body:
            at(p).update(terrain="WATER",water="LAKE",salinity="FRESH",body=lid,depth_cm=200,soil="SILT",blocked=False)
        wet|=body;lake_sets.append(body)
        lakes.append(dict(id=lid,terminal_basin=True,outflow=""))
    walk=set(floor)
    banks={p for p in walk if any(q in wet for q in neighbors(p,w,h))}
    if not banks:raise Rejection("CAVERN_WATER","no floor tile touches a spring pool")
    water_distance,water_parent=distances(banks,walk,w,h)
    max_route=config["starts"]["max_route_tiles"]
    reserved=set();route_records=[]
    # Exits: about one chamber in four gets a surface exit, at the open tile nearest its centre.
    portals=[];exits=[]
    exit_target=max(2,len(chambers)//4)
    for i in sorted(range(len(chambers)),key=lambda i:(draw("exit-chamber",i),i)):
        if len(exits)>=exit_target:break
        chamber=chambers[i]
        open_tiles=[p for p in chamber if all(q in walk for q in neighbors(p,w,h))]
        if not open_tiles:continue
        cx,cy=centres[i]
        p=min(open_tiles,key=lambda p:(abs(p[0]-cx)+abs(p[1]-cy),draw("exit-rank",*p),p))
        exits.append(p);reserved.add(p)
    for p in sorted(exits):portals.append(dict(a=[p[0],p[1],"UNDERGROUND"],b=[p[0],p[1],"SURFACE"]))
    if not exits:raise Rejection("CAVERN_EXIT","no chamber has room for a surface exit")
    candidates={p for p in walk if water_distance.get(p,area)<=max_route and p not in reserved and all(q in walk for q in neighbors(p,w,h))}
    starts=[];spacing=config["starts"]["min_spacing_tiles"]
    for i in range(config["starts"]["count"]):
        if not candidates:raise Rejection("START_PACKING","could not place requested separated safe starts")
        p=max(candidates,key=lambda p:(min((abs(p[0]-s[0])+abs(p[1]-s[1]) for s in starts),default=0),draw("start-rank",*p),p))
        starts.append(p)
        candidates={q for q in candidates if abs(q[0]-p[0])+abs(q[1]-p[1])>=spacing}
        path=[p]
        while path[-1] not in banks:path.append(water_parent[path[-1]])
        reserved.update(path)
        supply_distance,supply_parent=distances([p],walk,w,h)
        choices=sorted([q for q,d in supply_distance.items() if 1<=d<=min(4,max_route) and at(q)["resource"]=="NONE" and q not in exits],
                       key=lambda q:(supply_distance[q],draw("supply-rank",*q),q))
        if len(choices)<3:raise Rejection("START_SUPPLIES","no clear sites for abstract supplies")
        resource_routes={}
        for kind,q in zip(["FOOD","WOOD","STONE"],choices[:3]):
            at(q)["resource"]=kind;route=[q]
            while route[-1]!=p:route.append(supply_parent[route[-1]])
            reserved.update(route);resource_routes[kind]=[list(t) for t in reversed(route)]
        exit_distance=min(supply_distance[e] for e in exits)
        route_records.append(dict(start=list(p),freshwater_bank_route=[list(t) for t in path],resource_routes=resource_routes,nearest_exit_tiles=exit_distance))
    resource_density=choose("resource-density",config["resources"]["density_per_1000_land_tiles"])
    extra_count=len(walk)*resource_density//1000
    extra=sorted([p for p in walk if at(p)["resource"]=="NONE" and p not in reserved],key=lambda p:(draw("extra-resources",*p),p))[:extra_count]
    for p in extra:at(p)["resource"]=["FOOD","WOOD","STONE"][draw("resource-kind",*p)%3];reserved.add(p)
    # Fungus pillars sit only where all eight neighbours are open floor and no other
    # pillar touches them, so the floor stays one 4-connected region.
    def ring(p):
        x,y=p
        return [(x+dx,y+dy) for dx in (-1,0,1) for dy in (-1,0,1) if (dx or dy)]
    eligible=[]
    for p in iteration:
        if p not in walk or p in reserved or at(p)["moisture"]<40:continue
        if all(q in walk for q in ring(p)):eligible.append(p)
    density=choose("vegetation-density",config["vegetation"]["suitable_site_density_pct"])
    eligible.sort(key=lambda p:(field("fungus-clusters",*p,max(4,min(w,h)//10))*1024+draw("fungus-fine",*p)%1024,p))
    budget=len(eligible)*density//100;fungus=set()
    for p in eligible:
        if len(fungus)>=budget:break
        if any(q in fungus for q in ring(p)):continue
        fungus.add(p);at(p)["tree"]="FUNGUS"
    doc=dict(schema=VERSION,seed=seed,algorithm_version=ALGORITHM_VERSION,content_version=CONTENT_VERSION,
             profile_version=PROFILE_VERSION,profile="UNDERGROUND_CAVERN",active_layer="UNDERGROUND",width=w,height=h,
             layers={"SURFACE":{"native_z":2,"cells":surface},"UNDERGROUND":{"native_z":1,"cells":grid}},
             ports=[],rivers=[],lakes=lakes,starts=[[x,y,"UNDERGROUND"] for x,y in starts],portals=portals,
             policy=dict(mountain_min_area=config["mountains"]["range_min_area"],mountain_max_components=1,
                         max_moisture_step=25,max_temperature_step=10,max_resource_distance=max_route,max_water_distance=max_route,
                         ship_radius=0,ocean_ports_min=1,land_components_min=1,start_count=len(starts),
                         river_half_width=0,max_path_uphill_m=0))
    reasons=validate(doc)
    counts=Counter(c["water"] for row in grid for c in row);total_water=area-counts["NONE"]
    if not water_cfg["coverage_pct"][0]*area<=total_water*100<=water_cfg["coverage_pct"][1]*area:
        reasons.append(dict(code="CONFIG_REALIZED_WATER",detail="realized water coverage outside requested interval"))
    if counts["LAKE"]*100+100<water_cfg["lake_area_pct"][0]*area or counts["LAKE"]*100>water_cfg["lake_area_pct"][1]*area+100:
        reasons.append(dict(code="CONFIG_REALIZED_COMPONENT",detail="LAKE area outside requested interval"))
    if reasons:raise Rejection("INVARIANT_REJECTED",json.dumps(reasons,sort_keys=True))
    manifests=seed_manifest(config,ALGORITHM_VERSION,CONTENT_VERSION,PROFILE_VERSION)
    manifests.update(status="GENERATED_VALID_OFFLINE_IR",generation_result={"ir_sha256":canonical_hash(doc),"validation_errors":[],"native_acceptance":"NOT_RUN"},
                     generated_topology=dict(chambers=len(chambers),tunnels=len(edges),pools=lake_count,exits=len(portals)),
                     chamber_centres=[list(c) for c in centres],tunnels=tunnel_records,
                     abstract_routes=route_records,reserved_route_cells=[list(p) for p in sorted(reserved)],
                     realized_water_cells=dict(sorted(counts.items())),floor_cells=len(floor),eligible_fungus_sites=len(eligible),
                     selected_vegetation_density_pct=density,fungus_pillars=len(fungus),
                     surface_layer="OPEN_PLACEHOLDER_GROUND",reference_matching="NOT_EVALUATED")
    return doc,manifests


def generate(config,*,traversal="forward"):
    """One bounded candidate, no retries or repair; caller logs rejection explicitly."""
    try:
        doc,manifest=_generate(deepcopy(config),traversal)
        return {"status":"GENERATED_VALID_OFFLINE_IR","document":doc,"manifest":manifest,"reasons":[]}
    except Rejection as e:
        return {"status":"REJECTED_OFFLINE_CANDIDATE","document":None,"manifest":None,
                "reasons":[{"code":e.code,"detail":e.detail}],"configuration_sha256":canonical_hash(config)}
