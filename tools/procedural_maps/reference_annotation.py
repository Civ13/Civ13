"""Static, source-informed hydrology annotation candidate; no DM evaluation.

Exact type components/edge contacts are observations. Width-derived lake/channel
labels are proposals with explicit uncertainty and need human/source review.
"""
from __future__ import annotations
import hashlib
import json
import re
import sys
from collections import Counter, deque
from pathlib import Path

from .repo_source import read_pinned
from .source_audit import parse_classic

PIN="b2ec0cc75ae77fc6ee163840ced4d5aa57f14cc7"
COMMIT="067478b82c7ad9f1b83759a221e6f22080ba865a"
FRESH={"/turf/floor/beach/water","/turf/floor/beach/water/deep"}
SALT={"/turf/floor/beach/water/shallowsaltwater","/turf/floor/beach/water/deep/saltwater"}
SWAMP={"/turf/floor/beach/water/swamp"}
W,H=155,225


def near(p):
    x,y=p
    return [(xx,yy) for xx,yy in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)] if 1<=xx<=W and 1<=yy<=H]


def components(points):
    remain=set(points);out=[]
    while remain:
        seed=min(remain);remain.remove(seed);seen={seed};todo=[seed]
        while todo:
            for q in near(todo.pop()):
                if q in remain:remain.remove(q);seen.add(q);todo.append(q)
        out.append(seen)
    return sorted(out,key=lambda c:(-len(c),min(c)))


def intervals(values):
    values=sorted(set(values));out=[]
    for n in values:
        if out and n==out[-1][1]+1:out[-1][1]=n
        else:out.append([n,n])
    return out


def runs(points):
    by_y={}
    for x,y in points:by_y.setdefault(y,[]).append(x)
    return [[y,a,b] for y,xs in sorted(by_y.items()) for a,b in intervals(xs)]


def summary(points):
    return dict(area=len(points),bbox_native=[min(x for x,y in points),min(y for x,y in points),max(x for x,y in points),max(y for x,y in points)],
                centroid_native=[sum(x for x,y in points)/len(points),sum(y for x,y in points)/len(points)],
                edge_contacts_native={"W":intervals(y for x,y in points if x==1),"E":intervals(y for x,y in points if x==W),
                                      "S":intervals(x for x,y in points if y==1),"N":intervals(x for x,y in points if y==H)},
                row_runs_y_x1_x2_native=runs(points))


def build(catalog_root=None):
    read_pinned("code/game/turfs/floor_types.dm","3b3c83d2082f4f840a598d0fbb54cb3b3132eee8",catalog_root)
    raw=read_pinned("maps/nomads/nomads.dmm",PIN,catalog_root)
    actual=hashlib.sha1(b"blob "+str(len(raw)).encode()+b"\0"+raw).hexdigest()
    if actual!=PIN:raise ValueError("source map pin mismatch")
    _,cells,dims=parse_classic(raw.decode("utf-8"))
    typed={};turfs={}
    for (x,y,z),atoms in cells.items():
        if z!=2:continue
        types=re.findall(r'(?:^|,)\s*(/turf/[^,{)\s]+)',atoms)
        if len(types)!=1:raise ValueError("expected exactly one source turf")
        t=types[0];turfs[(x,y)]=t
        if t in FRESH:typed[(x,y)]="FRESHWATER_TYPE"
        elif t in SALT:typed[(x,y)]="SALTWATER_TYPE"
        elif t in SWAMP:typed[(x,y)]="SWAMP_FRESH_TYPE"
        elif t.startswith("/turf/floor/beach/water"):raise ValueError("unclassified source water type "+t)
    classes={k:{p for p,v in typed.items() if v==k} for k in sorted(set(typed.values()))}
    class_components={};membership={}
    for kind,points in classes.items():
        class_components[kind]=[]
        for i,comp in enumerate(components(points),1):
            ident=kind.lower()+"_"+str(i)
            for p in comp:membership[p]=ident
            class_components[kind].append(dict(id=ident,classification_status="EXACT_SOURCE_TYPE_COMPONENT",**summary(comp)))
    allwater=components(typed)
    interfaces={}
    for p,kind in typed.items():
        for q in near(p):
            if q in typed and p<q and typed[q]!=kind:
                key=" / ".join(sorted([membership[p],membership[q]]))
                interfaces.setdefault(key,[]).append([list(p),list(q)])
    fresh=classes["FRESHWATER_TYPE"]
    # Bank distance in fresh raster only. Grid exterior counts as bank for this
    # width proposal, preventing broad boundary contacts from receiving infinite width.
    dist={p:1 for p in fresh if len(near(p))<4 or any(q not in fresh for q in near(p))}
    todo=deque(dist)
    while todo:
        p=todo.popleft()
        for q in near(p):
            if q in fresh and q not in dist:dist[q]=dist[p]+1;todo.append(q)
    cores={p for p,v in dist.items() if v>=5}
    core_components=components(cores)
    candidate_cores=[]
    for i,c in enumerate(core_components,1):
        candidate_cores.append(dict(id="broad_freshwater_core_"+str(i),classification="POSSIBLE_LAKE_CORE",
                                    status="MORPHOLOGY_PROPOSAL_NOT_AUTHORED_BODY_ID",threshold_bank_distance_tiles=5,
                                    uncertainty="A broad freshwater core can also be a wide channel or mouth. A reviewer must decide its lake shoreline and inflow/outflow cuts.",
                                    **summary(c)))
    major_fresh=components(fresh)[0]
    major_core=core_components[0]
    # Each path below proves only raster connectivity from an observed contact
    # to the broad-core proposal. It is not an inferred authored centerline/flow.
    parent={p:None for p in major_core};queue=deque(sorted(major_core))
    while queue:
        p=queue.popleft()
        for q in sorted(near(p)):
            if q in major_fresh and q not in parent:parent[q]=p;queue.append(q)
    observed=[]
    contacts=summary(major_fresh)["edge_contacts_native"]
    for side,spans in contacts.items():
        for i,(a,b) in enumerate(spans,1):
            middle=(a+b)//2
            p={"W":(1,middle),"E":(W,middle),"S":(middle,1),"N":(middle,H)}[side]
            observed.append(dict(id="edge_"+side.lower()+"_"+str(i),kind="OBSERVED_EDGE_INTERVAL",
                                 side=side,interval_native=[a,b],representative_native=list(p),flow_direction="UNRESOLVED"))
    salt_contact=sorted({p for p in major_fresh if any(q in classes["SALTWATER_TYPE"] for q in near(p))})
    if salt_contact:
        observed.append(dict(id="fresh_salt_interface",kind="OBSERVED_FRESH_SALT_INTERFACE",
                             contact_cells_native=[list(p) for p in salt_contact],representative_native=list(salt_contact[len(salt_contact)//2]),
                             flow_direction="UNRESOLVED; candidate sea outlet requires hydrologic review"))
    routes=[];uses=Counter()
    for contact in observed:
        p=tuple(contact["representative_native"]);path=[p]
        while parent[p] is not None:p=parent[p];path.append(p)
        uses.update(path)
        routes.append(dict(contact_id=contact["id"],status="RASTER_CONNECTIVITY_WITNESS_NOT_FLOW_OR_CENTERLINE",
                           path_length_edges=len(path)-1,path_native=[list(p) for p in path],
                           destination="broad_freshwater_core_1"))
    shared={p for p,n in uses.items() if n>=2 and p not in major_core}
    junctions=[dict(id="shared_route_region_"+str(i),status="POSSIBLE_CONFLUENCE_REGION_NOT_AUTHORED_JUNCTION",**summary(c))
               for i,c in enumerate(components(shared),1)]
    return dict(schema="civ13-reference-hydrology-annotation/1",status="AGENT_PROPOSAL_NOT_HUMAN_APPROVED",
                source=dict(repository="Civ13/Civ13",commit=COMMIT,path="maps/nomads/nomads.dmm",git_blob=PIN),
                dimensions=[W,H,2],active_native_z=2,coordinates="native 1-based southwest origin; row runs [y,x1,x2], inclusive",
                method="Exact DMM turf identities and cardinal components. No image colors are used.",
                class_counts=dict(Counter(typed.values())),components=class_components,
                all_water_components=[dict(id="all_water_"+str(i),**summary(c)) for i,c in enumerate(allwater,1)],
                interclass_interfaces_native=interfaces,
                freshwater_bank_distance_histogram=dict(sorted(Counter(dist.values()).items())),
                possible_lake_cores=candidate_cores,
                main_network_contact_candidates=observed,
                contact_to_broad_core_routes=routes,
                possible_confluence_regions=junctions,
                proposed_semantics=dict(sea="Saltwater-type components touching south edge are candidate sea/coast bodies; not proven navigable.",
                                        rivers="Narrow fresh paths linking map-edge contacts and broad freshwater body are candidate channels; exact centerlines, direction, ports and body IDs require review.",
                                        lakes="Broad freshwater core is a candidate lake interior; exact lake raster and outlets are not encoded as authored body IDs in this source.",
                                        swamp="Swamp source subtype is explicit; it is not inferred from vegetation colors."),
                unresolved=["No source river/lake body IDs or flow directions in these turf names.",
                            "Edge contacts are observed raster intervals, not verified designed inlet/outlet ports.",
                            "No elevation or hydraulic head is inferred from dirt colors, tile types or native z.",
                            "No drinking safety, vessel clearance, tree obstruction, resource access or start reachability is established.",
                            "Source may violate the new generator invariants; annotations must preserve that discrepancy.",
                            "Generated-map similarity verdict remains unavailable until required semantic annotations and tolerances are reviewed."])
