"""Original dependency-free SURFACE backend for offline IR, never DM/game output.

Variable coast, connected flood-grown lakes, edge/lake/sea river grammar,
noise-weighted ridge paths, smooth climatic bands, and reserved survival routes.
No reference image or source map is loaded by generation.
"""
from __future__ import annotations
from collections import Counter,deque
from copy import deepcopy
import heapq
import json
from pathlib import Path
from .configuration import validate_config,seed_manifest
from .validator import VERSION,PORT_VERSION,stable_u64,canonical_hash,validate

ALGORITHM_VERSION="surface-offline/0.1.0"
PORTS_ALGORITHM_VERSION="surface-offline/0.2.0"
CONTENT_VERSION="abstract-survival-catalog/1"
PROFILE_VERSION="SURFACE-offline/1"
CHAIN=["LUSH","TEMPERATE","STEPPE","ARID","DESERT"]


class Rejection(Exception):
    def __init__(self,code,detail):self.code=code;self.detail=detail;super().__init__(detail)


def ground(**changes):
    d=dict(terrain="PLAIN",biome="TEMPERATE",soil="LOAM",elevation_m=0,moisture=50,
           temperature_c=20,water="NONE",salinity="NONE",depth_cm=0,body="",blocked=False,
           tree="NONE",resource="NONE",hazard=False)
    d.update(changes);return d


def neighbors(p,w,h):
    x,y=p
    return [(xx,yy) for xx,yy in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)] if 0<=xx<w and 0<=yy<h]


def distances(sources,allowed,w,h):
    dist={p:0 for p in sorted(sources)};parent={};queue=deque(sorted(sources))
    while queue:
        p=queue.popleft()
        for q in neighbors(p,w,h):
            if q in allowed and q not in dist:
                dist[q]=dist[p]+1;parent[q]=p;queue.append(q)
    return dist,parent


def _generate(config,traversal):
    problems=validate_config(config)
    if problems:raise Rejection("CONFIG_REJECTED",json.dumps(problems,sort_keys=True))
    if config["profile"]!="SURFACE":raise Rejection("BACKEND_PROFILE","only SURFACE is implemented")
    mix={k:v for k,v in config["biome_mix_pct"].items() if v}
    if set(mix)-set(CHAIN):raise Rejection("BACKEND_BIOMES","v0.1 supports the lush-to-desert surface chain only")
    indices=[i for i,b in enumerate(CHAIN) if b in mix]
    if indices!=list(range(min(indices),max(indices)+1)):
        raise Rejection("BACKEND_ECOTONE","requested bands must be a contiguous climatic sequence")
    if traversal not in {"forward","reverse"}:raise ValueError("traversal")
    is_ports=config['schema']=='civ13-generation-config/2'
    algorithm=PORTS_ALGORITHM_VERSION if is_ports else ALGORITHM_VERSION
    profile_version='SURFACE-offline/2' if is_ports else PROFILE_VERSION
    cfg_hash=canonical_hash(config);seed=config["seed"]
    def draw(stage,x=0,y=0,slot=0):
        return stable_u64(seed,algorithm,CONTENT_VERSION,profile_version+":"+cfg_hash,stage,"SURFACE",x,y,slot)
    def choose(stage,bounds,slot=0):
        span=bounds[1]-bounds[0]+1;limit=2**64-(2**64%span)
        for retry in range(32):
            value=draw(stage+"-choice",slot=slot*32+retry)
            if value<limit:return bounds[0]+value%span
        raise Rejection("RANDOM_REJECTION_BOUND","integer sampling exhausted 32 draws")
    lattice={}
    def field(stage,x,y,scale):
        # Bilinear fixed-point integer lattice noise; no platform float arithmetic.
        gx,tx=divmod(x,scale);gy,ty=divmod(y,scale)
        def node(xx,yy):
            key=(stage,xx,yy)
            if key not in lattice:lattice[key]=draw(stage,xx,yy)%1024
            return lattice[key]
        a=node(gx,gy);b=node(gx+1,gy);c=node(gx,gy+1);d=node(gx+1,gy+1)
        return ((a*(scale-tx)+b*tx)*(scale-ty)+(c*(scale-tx)+d*tx)*ty)//(scale*scale)
    w,h=config["dimensions"]["width"],config["dimensions"]["height"]
    points=[(x,y) for y in range(h) for x in range(w)]
    iteration=points if traversal=="forward" else list(reversed(points))
    grid=[[None for _ in range(w)] for _ in range(h)]
    underground=[[None for _ in range(w)] for _ in range(h)]
    for x,y in iteration:
        grid[y][x]=ground()
        underground[y][x]=ground(terrain="ROCK",biome="CAVERN",soil="ROCK",blocked=True)
    def at(p):return grid[p[1]][p[0]]
    def wet(p,kind,body):
        c=at(p);c.update(terrain="WATER",water=kind,salinity="SALT" if kind=="SEA" else "FRESH",
                       body=body,depth_cm=200 if kind in {"LAKE","SEA"} else 30,soil="SILT",elevation_m=0,
                       tree="NONE",resource="NONE",blocked=False)
    area=w*h;water_cfg=config["water"]
    ridge_paths=[];reserved=set();route_records=[];junctions=[];route_stats=[]
    if is_ports:
        from .hydrology_ports import build,HydroReject
        try:hydro=build(config,draw,choose,field,points,at,wet)
        except HydroReject as e:raise Rejection(e.code,e.detail) from e
        sea=hydro['sea'];lakes=hydro['lakes'];lake_sets=hydro['lake_sets'];rivers=hydro['rivers'];ports=hydro['ports']
        max_width=hydro['max_width'];net_count=hydro['net_count'];lake_count=hydro['lake_count']
        junctions=hydro['junctions'];route_stats=hydro['route_stats']
    else:
        sea_pct=choose("sea-coverage",water_cfg["sea_pct"])
        sea_count=area*sea_pct//100
        if sea_pct and sea_count<w:
            sea_count=w
            if sea_count*100>water_cfg["sea_pct"][1]*area:
                raise Rejection("COAST_SCALE","positive sea budget cannot fit a connected south coast at this size")
        sea=set()
        if sea_count:
            sea_order=sorted(points,key=lambda p:(p[1]*1024+field("coast",p[0],0,max(4,w//6))//2,p))
            sea=set(sea_order[:sea_count])
            for p in sea:wet(p,"SEA","sea-south")
        sea_top=max((y for x,y in sea),default=-1)
        net_count=choose("river-networks",water_cfg["river_networks"])
        lake_count=choose("lake-count",water_cfg["lake_count"])
        # Coupled topology sampling is explicit, recorded, and within requested intervals.
        if lake_count and net_count>lake_count:
            net_count=max(water_cfg["river_networks"][0],min(net_count,lake_count))
            if net_count>lake_count:raise Rejection("TOPOLOGY_BUDGET","network minimum exceeds available lake count in this backend")
        widths=[choose("channel-width",water_cfg["river_width_tiles"],i) for i in range(net_count)]
        # Reserve a conservative channel budget before selecting lake size. Coupled draws
        # stay inside the user's intervals; impossible selections reject without repair.
        while net_count>water_cfg["river_networks"][0] and (sum(v+1 for v in widths)*h*100//area+sea_pct+water_cfg["lake_area_pct"][0]+water_cfg["swamp_pct"][0]>water_cfg["coverage_pct"][1]):
            net_count-=1;widths.pop()
        slots=max(lake_count,net_count,1)
        if w//slots<8:raise Rejection("FEATURE_PACKING","too many independent water lanes for this width")
        lake_cap=water_cfg["coverage_pct"][1]-sea_pct-water_cfg["swamp_pct"][0]-(sum(v+1 for v in widths)*h*100+area-1)//area
        lake_upper=min(water_cfg["lake_area_pct"][1],lake_cap)
        if lake_upper<water_cfg["lake_area_pct"][0]:raise Rejection("WATER_BUDGET","minimum lakes and conservative channel budget exceed total water maximum")
        lake_pct=choose("lake-coverage",[water_cfg["lake_area_pct"][0],lake_upper])
        lake_cells=area*lake_pct//100
        if lake_count==0 and lake_cells:raise Rejection("LAKE_BUDGET","no lakes selected but positive area selected")
        lakes=[];lake_sets=[];rivers=[];ports=[];ridge_paths=[];reserved=set();route_records=[]
        for i in range(lake_count):
            xlo=i*w//slots+2;xhi=(i+1)*w//slots-3
            target=lake_cells//lake_count+(i<lake_cells%lake_count)
            cy=max(sea_top+6,min(h-7,h*(40+draw("lake-y",i)%25)//100))
            cx=(xlo+xhi)//2+(int(draw("lake-x",i)%5)-2)
            cx=max(xlo,min(xhi,cx));center=(cx,cy)
            eligible={(x,y) for x in range(xlo,xhi+1) for y in range(sea_top+4,h-4)}
            if target<1 or target>len(eligible):raise Rejection("LAKE_PACKING","lake cannot fit its lane and requested area")
            frontier=[];seen={center};body=set()
            def lake_cost(p):
                dx,dy=p[0]-cx,p[1]-cy
                return dx*dx*7+dy*dy*3+field("lake-shape-"+str(i),p[0],p[1],max(3,min(w,h)//10))//12
            heapq.heappush(frontier,(lake_cost(center),center))
            while frontier and len(body)<target:
                _,p=heapq.heappop(frontier);body.add(p)
                for q in neighbors(p,w,h):
                    if q in eligible and q not in seen:
                        seen.add(q);heapq.heappush(frontier,(lake_cost(q),q))
            if len(body)!=target:raise Rejection("LAKE_PACKING","bounded connected lake growth exhausted")
            lake_sets.append(body)
            for p in body:wet(p,"LAKE","lake-"+str(i))
            lakes.append(dict(id="lake-"+str(i),terminal_basin=i>=net_count,outflow="river-"+str(i)+"-out" if i<net_count else ""))
        def channel(rid,path,source,sink,width):
            if len(path)<2:raise Rejection("CHANNEL_SCALE","river segment too short")
            offsets=range(-(width//2),width-width//2)
            footprint={(x+dx,y) for x,y in path for dx in offsets if 0<=x+dx<w}
            for p in footprint:
                if at(p)["water"]!="NONE":raise Rejection("CHANNEL_COLLISION","river width overlaps existing water outside its terminal")
            for p in footprint:wet(p,"RIVER",rid)
            rivers.append(dict(id=rid,path=[[x,y,"SURFACE"] for x,y in path],source=source,sink=sink))
        def make_path(start,end,xlo,xhi,stage):
            x,y=start;ex,ey=end;path=[start]
            if y<ey:raise Rejection("DRAINAGE_ORDER","river endpoint above its source")
            for row in range(y,ey-1,-1):
                remaining=row-ey
                preferred=xlo+field(stage,0,row,max(4,h//8))*(xhi-xlo)//1023
                desired=ex if remaining<=3 else preferred
                # Bounded meander; converge deterministically at the endpoint.
                step=ex if remaining<=1 else max(x-1,min(x+1,desired))
                step=max(xlo,min(xhi,step))
                while x!=step:
                    x+=1 if x<step else -1
                    if (x,row)!=path[-1]:path.append((x,row))
                if row>ey:path.append((x,row-1))
            while x!=ex:
                x+=1 if x<ex else -1;path.append((x,ey))
            return path
        max_width=0
        for i in range(net_count):
            width=widths[i];max_width=max(max_width,width)
            left=i*w//slots+width//2+1;right=(i+1)*w//slots-(width-width//2)-2
            if right<left:raise Rejection("CHANNEL_PACKING","river width cannot fit allocated lane")
            inlet_x=left+draw("inlet-x",i)%(right-left+1)
            if i<len(lake_sets):
                body=lake_sets[i]
                top=min(body,key=lambda p:(-p[1],abs(p[0]-inlet_x),p[0]))
                bottom=min(body,key=lambda p:(p[1],abs(p[0]-inlet_x),p[0]))
                left=min(left,top[0],bottom[0]);right=max(right,top[0],bottom[0])
                path=make_path((inlet_x,h-1),(top[0],top[1]+1),left,right,"inlet-curve-"+str(i))
                rid="river-"+str(i)+"-in";pid="port-"+str(i)+"-north"
                channel(rid,path,dict(kind="EDGE",target=pid),dict(kind="LAKE",target="lake-"+str(i)),width)
                ports.append(dict(id=pid,at=[inlet_x,h-1,"SURFACE"],side="N",role="INLET",body=rid))
                source=(bottom[0],bottom[1]-1);source_terminal=dict(kind="LAKE",target="lake-"+str(i))
            else:
                source=(inlet_x,h-1);pid="port-"+str(i)+"-north"
                source_terminal=dict(kind="EDGE",target=pid)
            outlet_x=left+draw("outlet-x",i)%(right-left+1)
            if sea:
                heights={x:max((y for xx,y in sea if xx==x),default=-1) for x in range(left,right+1)}
                highest=max(heights.values())
                outlet_x=min([x for x,v in heights.items() if v==highest],key=lambda x:(abs(x-outlet_x),x))
            sea_y=max((y for x,y in sea if x==outlet_x),default=-1)
            endpoint=(outlet_x,sea_y+1 if sea else 0)
            path=make_path(source,endpoint,left,right,"outlet-curve-"+str(i))
            rid="river-"+str(i)+"-out"
            sink=dict(kind="SEA",target="sea-south") if sea else dict(kind="EDGE",target="port-"+str(i)+"-south")
            channel(rid,path,source_terminal,sink,width)
            if i>=len(lake_sets):ports.append(dict(id=pid,at=[inlet_x,h-1,"SURFACE"],side="N",role="INLET",body=rid))
            if not sea:ports.append(dict(id=sink["target"],at=[outlet_x,0,"SURFACE"],side="S",role="OUTLET",body=rid))
    # Optional saturated floodplain patches grow only from water-adjacent dry soil.
    swamp_pct=choose("swamp-coverage",water_cfg["swamp_pct"])
    swamp_target=area*swamp_pct//100
    existing_water=sum(at(p)["water"]!="NONE" for p in points)
    minimum_needed=max(0,(area*water_cfg["coverage_pct"][0]+99)//100-existing_water)
    swamp_target=max(swamp_target,minimum_needed)
    maximum_allowed=area*water_cfg["coverage_pct"][1]//100-existing_water
    swamp_target=min(swamp_target,maximum_allowed)
    if swamp_target*100<water_cfg["swamp_pct"][0]*area or swamp_target*100>water_cfg["swamp_pct"][1]*area:
        raise Rejection("WATER_BUDGET","wetland interval cannot satisfy the realized whole-map water budget")
    dry={p for p in points if at(p)["water"]=="NONE"}
    front=[];queued=set()
    for p in sorted(dry):
        if any(at(q)["water"] in {"LAKE","RIVER"} for q in neighbors(p,w,h)):
            heapq.heappush(front,(draw("swamp-priority",*p),p));queued.add(p)
    swamp=set()
    while front and len(swamp)<swamp_target:
        _,p=heapq.heappop(front);swamp.add(p)
        for q in neighbors(p,w,h):
            if q in dry and q not in queued:
                queued.add(q);heapq.heappush(front,(draw("swamp-priority",*q),q))
    if len(swamp)!=swamp_target:raise Rejection("SWAMP_PACKING","wetland growth exhausted")
    for p in swamp:wet(p,"SWAMP","wetlands");at(p).update(moisture=80,soil="SILT")
    dry={p for p in points if at(p)["water"]=="NONE"}
    # Connected ridge skeletons use shortest paths on an eroded dry mask.
    range_count=choose("range-count",config["mountains"]["range_count"])
    mountains=set()
    for i in range(range_count):
        width=choose("range-width",config["mountains"]["range_width_tiles"],i);radius=max(1,width//2)
        forbidden={p for p in points if p not in dry or p in mountains}
        distance,_=distances(forbidden,set(points),w,h)
        safe={p for p in dry if distance.get(p,area)>radius+2 and radius<p[0]<w-radius-1 and radius<p[1]<h-radius-1}
        if len(safe)<config["mountains"]["range_min_area"]:raise Rejection("RANGE_PACKING","insufficient connected dry clearance for range")
        start=max(safe,key=lambda p:(draw("ridge-start-"+str(i),*p),p))
        reach,parent=distances([start],safe,w,h)
        desired=max(4,min(w,h)//3)
        end=min(reach,key=lambda p:(abs(reach[p]-desired),-draw("ridge-end-"+str(i),*p),p))
        # A seed-dependent weighted Dijkstra path gives original varied ridge geometry.
        heap=[(0,start)];cost={start:0};parents={}
        while heap:
            total,p=heapq.heappop(heap)
            if total!=cost[p]:continue
            if p==end:break
            for q in neighbors(p,w,h):
                if q not in safe:continue
                proposal=total+100+field("ridge-cost-"+str(i),*q,max(3,min(w,h)//9))//16
                if proposal<cost.get(q,10**30):cost[q]=proposal;parents[q]=p;heapq.heappush(heap,(proposal,q))
        path=[end]
        while path[-1]!=start:path.append(parents[path[-1]])
        ridge_paths.append([list(p) for p in path])
        expansion,_=distances(path,dry,w,h)
        component={p for p,v in expansion.items() if v<=radius}
        if len(component)<config["mountains"]["range_min_area"]:raise Rejection("RANGE_AREA","generated range below mandatory area")
        if any(q in mountains for p in component for q in [p]+neighbors(p,w,h)):
            raise Rejection("RANGE_COLLISION","distinct requested ranges touch")
        mountains|=component
        for p in component:at(p).update(terrain="MOUNTAIN",blocked=True,soil="ROCK",elevation_m=400+(radius-expansion[p])*120)
    foothills,_=distances(mountains,dry,w,h)
    for p,d in foothills.items():
        if 1<=d<=2:at(p).update(terrain="HILL",soil="ROCK",elevation_m=(3-d)*100)
    # Quantile climatic bands follow a continuous coordinate field, never image pixels.
    if is_ports:
        ax,ay=config['surface_layout']['climate_axis']
        ordered=sorted(dry,key=lambda p:(1024*(p[0]*ax+p[1]*ay)+field('climate-warp-2d',*p,max(5,min(w,h)//4))*max(1,min(w,h)//4),p))
    else:
        ordered=sorted(dry,key=lambda p:(p[0]*1024+field("climate-warp",0,p[1],max(5,h//6))*max(1,w//10),p))
    boundaries=[];running=0;bands=[b for b in CHAIN if b in mix]
    for b in bands:
        count=len(ordered)*mix[b]//100;boundaries.append((b,count));running+=count
    boundaries[-1]=(boundaries[-1][0],boundaries[-1][1]+len(ordered)-running)
    climate_moist={"LUSH":75,"TEMPERATE":55,"STEPPE":40,"ARID":25,"DESERT":15}
    moist_lo,moist_hi=config["climate"]["moisture_range"];temp_lo,temp_hi=config["climate"]["temperature_c_range"]
    cursor=0
    for b,count in boundaries:
        for p in ordered[cursor:cursor+count]:
            moisture=max(moist_lo,min(moist_hi,climate_moist[b]))
            c=at(p);c.update(biome=b,moisture=moisture,temperature_c=temp_lo+(temp_hi-temp_lo)*p[1]//max(1,h-1))
            if c["terrain"]=="PLAIN":c["soil"]="SAND" if b in {"ARID","DESERT"} else "LOAM"
        cursor+=count
    # Coastal sand is substrate only; retain climate biome to avoid inventing desert.
    for p in sorted(dry):
        if at(p)["terrain"]=="PLAIN" and any(q in sea for q in neighbors(p,w,h)):
            at(p).update(terrain="BEACH",soil="SAND")
    walk={p for p in dry if at(p)["terrain"]!="MOUNTAIN"}
    banks={p for p in walk if any(at(q)["water"] in {"LAKE","RIVER"} for q in neighbors(p,w,h))}
    water_distance,water_parent=distances(banks,walk,w,h)
    max_route=config["starts"]["max_route_tiles"]
    candidates={p for p in walk if water_distance.get(p,area)<=max_route and all(q in walk for q in neighbors(p,w,h))}
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
        choices=sorted([q for q,d in supply_distance.items() if 1<=d<=min(4,max_route) and at(q)["resource"]=="NONE"],key=lambda q:(supply_distance[q],draw("supply-rank",*q),q))
        if len(choices)<3:raise Rejection("START_SUPPLIES","no clear sites for abstract supplies")
        resource_routes={}
        for kind,q in zip(["FOOD","WOOD","STONE"],choices[:3]):
            at(q)["resource"]=kind;route=[q]
            while route[-1]!=p:route.append(supply_parent[route[-1]])
            reserved.update(route);resource_routes[kind]=[list(t) for t in reversed(route)]
        route_records.append(dict(start=list(p),freshwater_bank_route=[list(t) for t in path],resource_routes=resource_routes))
    # Extra abstract resources and habitat-eligible dense vegetation are coordinate stable.
    resource_density=choose("resource-density",config["resources"]["density_per_1000_land_tiles"])
    extra_count=len(dry)*resource_density//1000
    extra=sorted([p for p in walk if at(p)["resource"]=="NONE" and p not in reserved],key=lambda p:(draw("extra-resources",*p),p))[:extra_count]
    for p in extra:at(p)["resource"]=["FOOD","WOOD","STONE"][draw("resource-kind",*p)%3];reserved.add(p)
    eligible=[]
    for p in iteration:
        c=at(p)
        if p in reserved or c["water"]!="NONE" or c["blocked"] or c["resource"]!="NONE":continue
        species="NONE"
        if c["soil"]=="LOAM" and 35<=c["moisture"]<=90 and -5<=c["temperature_c"]<=35:species="BROADLEAF"
        elif c["soil"] in {"LOAM","SAND"} and 20<=c["moisture"]<=80 and -20<=c["temperature_c"]<=25:species="PINE"
        elif c["soil"]=="SAND" and c["moisture"]<=30 and c["temperature_c"]>=10:species="CACTUS"
        if species!="NONE":eligible.append((p,species))
    density=choose("vegetation-density",config["vegetation"]["suitable_site_density_pct"])
    eligible.sort(key=lambda item:(field("forest-clusters",*item[0],max(4,min(w,h)//10))*1024+draw("tree-fine",*item[0])%1024,item[0]))
    for p,species in eligible[:len(eligible)*density//100]:at(p)["tree"]=species
    doc=dict(schema=PORT_VERSION if is_ports else VERSION,seed=seed,algorithm_version=algorithm,content_version=CONTENT_VERSION,
             profile_version=profile_version,profile="SURFACE",active_layer="SURFACE",width=w,height=h,
             layers={"SURFACE":{"native_z":2,"cells":grid},"UNDERGROUND":{"native_z":1,"cells":underground}},
             ports=ports,rivers=rivers,lakes=lakes,starts=[[x,y,"SURFACE"] for x,y in starts],portals=[],
             policy=dict(mountain_min_area=config["mountains"]["range_min_area"],mountain_max_components=max(1,config["mountains"]["range_count"][1]),
                         max_moisture_step=25,max_temperature_step=10,max_resource_distance=max_route,max_water_distance=max_route,
                         ship_radius=0,ocean_ports_min=2,land_components_min=1,start_count=len(starts),
                         river_half_width=max_width,max_path_uphill_m=0))
    if is_ports:doc['junctions']=junctions
    reasons=validate(doc)
    counts=Counter(c["water"] for row in grid for c in row);total_water=area-counts["NONE"]
    if not water_cfg["coverage_pct"][0]*area<=total_water*100<=water_cfg["coverage_pct"][1]*area:
        reasons.append(dict(code="CONFIG_REALIZED_WATER",detail="realized water coverage outside requested interval"))
    for kind,key in [("SEA","sea_pct"),("SWAMP","swamp_pct"),("LAKE","lake_area_pct")]:
        # Whole-cell quantization permits less than one cell of boundary error.
        if counts[kind]*100+100<water_cfg[key][0]*area or counts[kind]*100>water_cfg[key][1]*area+100:
            reasons.append(dict(code="CONFIG_REALIZED_COMPONENT",detail=kind+" area outside requested interval"))
    if reasons:raise Rejection("INVARIANT_REJECTED",json.dumps(reasons,sort_keys=True))
    manifests=seed_manifest(config,algorithm,CONTENT_VERSION,profile_version)
    manifests.update(status="GENERATED_VALID_OFFLINE_IR",generation_result={"ir_sha256":canonical_hash(doc),"validation_errors":[],"native_acceptance":"NOT_RUN"},
                     generated_topology=dict(networks=net_count,lakes=lake_count,ranges=range_count,channel_width_max=max_width),
                     abstract_routes=route_records,ridge_skeletons=ridge_paths,reserved_route_cells=[list(p) for p in sorted(reserved)],
                     realized_water_cells=dict(sorted(counts.items())),eligible_vegetation_sites=len(eligible),selected_vegetation_density_pct=density,
                     cave_layer="UNGENERATED_BLOCKED_RESERVE",reference_matching="NOT_EVALUATED")
    if is_ports:manifests['graph_to_raster']={'junctions':deepcopy(junctions),'port_spans':deepcopy(ports),'bounded_route_stats':route_stats}
    return doc,manifests


def generate(config,*,traversal="forward"):
    """One bounded candidate, no retries or repair; caller logs rejection explicitly."""
    try:
        doc,manifest=_generate(deepcopy(config),traversal)
        return {"status":"GENERATED_VALID_OFFLINE_IR","document":doc,"manifest":manifest,"reasons":[]}
    except Rejection as e:
        return {"status":"REJECTED_OFFLINE_CANDIDATE","document":None,"manifest":None,
                "reasons":[{"code":e.code,"detail":e.detail}],"configuration_sha256":canonical_hash(config)}
