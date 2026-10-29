"""Original directed graph grammar with configurable sides/spans and raster junction.
No source reference, image, native engine or implicit repair is used.
"""
import heapq


class HydroReject(Exception):
    def __init__(self,code,detail):self.code=code;self.detail=detail;super().__init__(detail)


def build(config,draw,choose,field,points,at,wet):
    w,h=config['dimensions']['width'],config['dimensions']['height'];area=w*h;layout=config['surface_layout'];wc=config['water']
    def near(p):
        x,y=p;return [(xx,yy) for xx,yy in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)] if 0<=xx<w and 0<=yy<h]
    def anchor(p):
        side=p['side'];mid=sum(p['span'])//2
        return (mid,h-1) if side=='N' else (mid,0) if side=='S' else (0,mid) if side=='W' else (w-1,mid)
    def edge_cells(p):
        return {anchor(dict(p,span=[i,i])) for i in range(p['span'][0],p['span'][1]+1)}
    sea_side=layout['sea_side'];sea_count=area*choose('sea-coverage',wc['sea_pct'])//100;sea=set()
    if sea_count:
        edge_length=w if sea_side in {'N','S'} else h
        if sea_count<edge_length:raise HydroReject('COAST_SCALE','sea count cannot cover its declared coast')
        def coast_key(p):
            x,y=p;distance=y if sea_side=='S' else h-1-y if sea_side=='N' else x if sea_side=='W' else w-1-x
            along=x if sea_side in {'N','S'} else y
            return (distance*1024+field('port-coast',along,0,max(4,edge_length//6))//2,p)
        sea=set(sorted(points,key=coast_key)[:sea_count])
        for p in sea:wet(p,'SEA','sea-'+sea_side.lower())
    sea_body='sea-'+sea_side.lower()
    cx=w*layout['lake_pct'][0]//100;cy=h*layout['lake_pct'][1]//100
    # Seed changes shape within the configured anchor; percentages are design positions, not copied source data.
    target=area*choose('lake-coverage',wc['lake_area_pct'])//100
    eligible={(x,y) for x,y in points if 4<=x<w-4 and 4<=y<h-4 and at((x,y))['water']=='NONE'}
    center=(cx,cy)
    if center not in eligible:raise HydroReject('LAKE_ANCHOR','lake anchor conflicts with coast or bounds')
    def lake_score(p):
        dx,dy=p[0]-cx,p[1]-cy
        return dx*dx*5+dy*dy*4+field('ports-lake-shape',*p,max(3,min(w,h)//8))//5
    heap=[(lake_score(center),center)];seen={center};lake=set()
    while heap and len(lake)<target:
        _,p=heapq.heappop(heap);lake.add(p)
        for q in near(p):
            if q in eligible and q not in seen:seen.add(q);heapq.heappush(heap,(lake_score(q),q))
    if len(lake)!=target:raise HydroReject('LAKE_PACKING','lake flood growth exhausted')
    for p in lake:wet(p,'LAKE','lake-main')
    junction=(w*layout['junction_pct'][0]//100,h*layout['junction_pct'][1]//100)
    jr=2;zone={(junction[0]+dx,junction[1]+dy) for dx in range(-jr,jr+1) for dy in range(-jr,jr+1)}
    if any(p not in eligible or p in lake for p in zone):raise HydroReject('JUNCTION_ANCHOR','junction footprint intersects water or bounds')
    for p in zone:wet(p,'RIVER','trunk')
    width=choose('channel-width',wc['river_width_tiles']);radius=width//2
    # Width is a brush diameter; even widths use an asymmetric square of the exact selected size.
    offsets=[(dx,dy) for dx in range(-(width//2),width-width//2) for dy in range(-(width//2),width-width//2)]
    rivers=[];ports=[];route_stats=[]
    normals={'N':(0,-1),'S':(0,1),'E':(-1,0),'W':(1,0)}
    def brush(p):return {(p[0]+dx,p[1]+dy) for dx,dy in offsets if 0<=p[0]+dx<w and 0<=p[1]+dy<h}
    def route(start,goals,rid,stage,*,terminal_kind,terminal_id,port=None,prefix=None):
        permitted_edge=edge_cells(port) if port else set()
        validity={}
        def valid(p):
            if p in validity:return validity[p]
            result=valid_uncached(p);validity[p]=result;return result
        def valid_uncached(p):
            if at(p)['water']!='NONE' and not (rid=='trunk' and p in zone):return False
            # Edge contact is legal only on the explicit span, never by accidental brush leakage.
            for q in brush(p):
                edge=q[0] in {0,w-1} or q[1] in {0,h-1}
                if edge and q not in permitted_edge and not (terminal_kind=='SEA' and q in sea):return False
                c=at(q)
                if c['water']!='NONE':
                    if (terminal_kind=='LAKE' or rid=='lake-out') and q in lake:continue
                    if terminal_kind=='SEA' and q in sea:continue
                    if q in zone and (rid=='trunk' or terminal_kind=='JUNCTION'):continue
                    return False
                # One dry-cell separator prevents undeclared parallel touches.
                for t in near(q):
                    tc=at(t)
                    if tc['water']=='RIVER' and tc['body']!=rid and t not in zone:return False
            return True
        goals={g for g in goals if valid(g)}
        if not goals or not valid(start):raise HydroReject('CHANNEL_CLEARANCE','no valid start/mouth for '+rid)
        gx0=min(p[0] for p in goals);gx1=max(p[0] for p in goals);gy0=min(p[1] for p in goals);gy1=max(p[1] for p in goals)
        def heuristic(p):return (max(gx0-p[0],0,p[0]-gx1)+max(gy0-p[1],0,p[1]-gy1))*100
        frontier=[(heuristic(start),0,start)];cost={start:0};parent={};expanded=0;end=None
        while frontier:
            _,g,p=heapq.heappop(frontier)
            if g!=cost[p]:continue
            expanded+=1
            if expanded>area:raise HydroReject('ROUTE_BOUND','A* exceeded map-cell expansion budget')
            if p in goals:end=p;break
            for q in near(p):
                if not valid(q):continue
                ng=g+100+field(stage,*q,max(3,min(w,h)//9))//12
                if ng<cost.get(q,10**30):cost[q]=ng;parent[q]=p;heapq.heappush(frontier,(ng+heuristic(q),ng,q))
        if end is None:raise HydroReject('ROUTE_UNREACHABLE','bounded route failed for '+rid)
        path=[end]
        while path[-1]!=start:path.append(parent[path[-1]])
        path.reverse()
        if prefix:path=list(prefix[:-1])+path
        footprint=set().union(*(brush(p) for p in path))
        # Bodies retain their identities at terminals; incoming channels stop outside the junction zone.
        footprint={p for p in footprint if at(p)['water']=='NONE' or rid=='trunk' and p in zone}
        if port:
            edge=edge_cells(port);footprint={p for p in footprint if not(p[0] in {0,w-1} or p[1] in {0,h-1}) or p in edge}
            footprint|=edge
        if any(p not in footprint for p in path):raise HydroReject('PATH_OWNERSHIP','centerline enters another body in '+rid)
        for p in footprint:wet(p,'RIVER',rid)
        route_stats.append({'segment':rid,'expanded_cells':expanded,'centerline_cells':len(path),'footprint_cells':len(footprint)})
        return path
    # Route downstream first, preserving the junction's explicit outgoing ownership.
    lake_banks={q for p in lake for q in near(p) if at(q)['water']=='NONE'}
    trunk_path=route(junction,lake_banks,'trunk','trunk-cost',terminal_kind='LAKE',terminal_id='lake-main')
    rivers.append(dict(id='trunk',path=[[x,y,'SURFACE'] for x,y in trunk_path],source=dict(kind='JUNCTION',target='confluence-main'),sink=dict(kind='LAKE',target='lake-main')))
    incoming=[]
    for spec in layout['inlets']:
        rid='river-'+spec['id'];incoming.append(rid);p=anchor(spec);dx,dy=normals[spec['side']]
        prefix=[(p[0]+i*dx,p[1]+i*dy) for i in range(radius+3)]
        goals={q for z in zone for q in near(z) if q not in zone and at(q)['water']=='NONE'}
        path=route(prefix[-1],goals,rid,'inlet-cost-'+spec['id'],terminal_kind='JUNCTION',terminal_id='confluence-main',port=spec,prefix=prefix)
        rivers.append(dict(id=rid,path=[[x,y,'SURFACE'] for x,y in path],source=dict(kind='EDGE',target=spec['id']),sink=dict(kind='JUNCTION',target='confluence-main')))
        ports.append(dict(id=spec['id'],at=[p[0],p[1],'SURFACE'],side=spec['side'],role='INLET',body=rid,span=spec['span'][:]))
    outlet=layout['outlet'];out_anchor=anchor(outlet);dx,dy=normals[outlet['side']]
    # A lake outlet must route from a bank that also has enough dry raster clearance.
    out_banks={q for p in lake for q in near(p) if at(q)['water']=='NONE'}
    if outlet['kind']=='SEA':
        mouths={q for p in sea for q in near(p) if at(q)['water']=='NONE' and (outlet['span'][0]<= (q[0] if outlet['side'] in {'N','S'} else q[1])<=outlet['span'][1])}
        destination=mouths
        sink=dict(kind='SEA',target=sea_body)
        # Pick a bank near the desired outlet, with deterministic tie breaking.
        start=min(out_banks,key=lambda p:(abs(p[0]-out_anchor[0])+abs(p[1]-out_anchor[1]),p)) if out_banks else None
        if start is None:raise HydroReject('LAKE_OUTLET','no dry lake bank')
        path=route(start,destination,'lake-out','lake-out-cost',terminal_kind='SEA',terminal_id=sea_body)
        ports.append(dict(id=outlet['id'],at=[out_anchor[0],out_anchor[1],'SURFACE'],side=outlet['side'],role='OCEAN',body=sea_body,span=outlet['span'][:]))
    else:
        # Build from edge inward, then reverse so graph direction is outward.
        prefix=[(out_anchor[0]+i*dx,out_anchor[1]+i*dy) for i in range(radius+3)]
        backwards=route(prefix[-1],out_banks,'lake-out','lake-out-cost',terminal_kind='LAKE',terminal_id='lake-main',port=outlet,prefix=prefix)
        path=list(reversed(backwards));sink=dict(kind='EDGE',target=outlet['id'])
        ports.append(dict(id=outlet['id'],at=[out_anchor[0],out_anchor[1],'SURFACE'],side=outlet['side'],role='OUTLET',body='lake-out',span=outlet['span'][:]))
    rivers.append(dict(id='lake-out',path=[[x,y,'SURFACE'] for x,y in path],source=dict(kind='LAKE',target='lake-main'),sink=sink))
    junction_record=dict(id='confluence-main',at=[*junction,'SURFACE'],incoming=incoming,outgoing='trunk',footprint=[[*p,'SURFACE'] for p in sorted(zone)])
    return dict(sea=sea,lakes=[dict(id='lake-main',terminal_basin=False,outflow='lake-out')],lake_sets=[lake],rivers=rivers,ports=ports,
                max_width=max(width,5),net_count=1,lake_count=1,junctions=[junction_record],route_stats=route_stats)
