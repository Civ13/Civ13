"""Declared river graphs for SURFACE config schema 2.

A graph layout names its own edge inlets, confluences, through or terminal lakes
and sea/edge outlets, joined by directed segments. It can hold several separate
networks. Each segment is routed as one bounded noise-weighted A* channel; the
result uses the same IR v2 ports, junction zones and validator as the fixed
three-inlet family in hydrology_ports. No source map, image or repair is used.
"""
import heapq
from .hydrology_ports import HydroReject

GRAPH_ALGORITHM_VERSION="surface-offline/0.3.0"
GRAPH_KEYS={'sea_side','inlets','outlets','junctions','lakes','segments','climate_axis'}
NORMALS={'N':(0,-1),'S':(0,1),'E':(-1,0),'W':(1,0)}


def is_graph_layout(layout):
    return type(layout) is dict and 'segments' in layout


def river_id(source):return 'river-'+source


def validate_layout(d):
    """Return a rejection detail for a graph layout, or None when it is consistent."""
    layout=d['surface_layout'];w,h=d['dimensions']['width'],d['dimensions']['height'];water=d['water']
    def exact(v,keys):return type(v) is dict and set(v)==set(keys)
    def ints(v,n,lo,hi):return type(v) is list and len(v)==n and all(type(i) is int and lo<=i<=hi for i in v)
    if not exact(layout,GRAPH_KEYS):return 'graph layout keys'
    sea_side=layout['sea_side']
    if sea_side not in {'N','S','E','W','NONE'}:return 'sea side'
    if (sea_side=='NONE')!=(water['sea_pct']==[0,0]) or sea_side!='NONE' and water['sea_pct'][0]<=0:
        return 'sea side NONE needs sea_pct [0,0]; a sea side needs a positive sea_pct minimum'
    if not ints(layout['climate_axis'],2,-4,4) or layout['climate_axis']==[0,0]:return 'climate axis must be nonzero integer vector -4..4'
    for key,lo,hi in [('inlets',1,8),('outlets',1,4),('junctions',0,8),('lakes',0,12),('segments',1,32)]:
        if type(layout[key]) is not list or not lo<=len(layout[key])<=hi:return '%s count %d..%d'%(key,lo,hi)
    ids=set();kinds={}
    def named(item,keys,kind):
        if not exact(item,keys):return kind+' keys'
        if type(item['id']) is not str or not 1<=len(item['id'])<=40 or not item['id'].isascii() or item['id'] in ids:return 'unique short ASCII node IDs required'
        ids.add(item['id']);kinds[item['id']]=kind
    for kind,keys in [('inlets',{'id','side','span'}),('outlets',{'id','kind','side','span'}),('junctions',{'id','at_pct'}),('lakes',{'id','at_pct','terminal'})]:
        for item in layout[kind]:
            problem=named(item,keys,kind)
            if problem:return problem
    occupied=set()
    for p in layout['inlets']+layout['outlets']:
        if p['side'] not in {'N','S','E','W'}:return 'port side'
        length=w if p['side'] in {'N','S'} else h
        if not ints(p['span'],2,1,length-2) or not 1<=p['span'][1]-p['span'][0]+1<=16:return 'port span must be ordered, width 1..16 and exclude corners'
        for offset in range(p['span'][0],p['span'][1]+1):
            if (p['side'],offset) in occupied:return 'overlapping edge-port spans'
            occupied.add((p['side'],offset))
    for p in layout['inlets']:
        if p['side']==sea_side:return 'inlet cannot occupy the solid sea coast side'
    for p in layout['outlets']:
        if p['kind'] not in {'SEA','EDGE'}:return 'outlet kind'
        if p['kind']=='SEA' and p['side']!=sea_side:return 'sea outlet must lie on the sea side'
        if p['kind']=='EDGE' and p['side']==sea_side:return 'edge outlet cannot lie on the sea side'
    anchors=[]
    for item in layout['junctions']+layout['lakes']:
        if not ints(item['at_pct'],2,15,85):return 'feature positions 15..85 percent'
        anchors.append(item['at_pct'])
    for item in layout['lakes']:
        if type(item['terminal']) is not bool:return 'lake terminal flag must be true or false'
    if any(abs(a[0]-b[0])+abs(a[1]-b[1])<12 for i,a in enumerate(anchors) for b in anchors[i+1:]):return 'graph anchors too close'
    outgoing={};incoming={i:[] for i in ids}
    for s in layout['segments']:
        if not exact(s,{'from','to'}):return 'segment keys'
        a,b=s['from'],s['to']
        if kinds.get(a) not in {'inlets','junctions','lakes'}:return 'segment source must be an inlet, junction or lake'
        if kinds.get(b) not in {'junctions','lakes','outlets'}:return 'segment target must be a junction, lake or outlet'
        if a==b:return 'segment cannot loop to itself'
        if a in outgoing:return 'each source node has one outgoing segment'
        outgoing[a]=b;incoming[b].append(a)
    for item in layout['inlets']:
        if item['id'] not in outgoing:return 'every inlet needs its segment'
    for item in layout['junctions']:
        if item['id'] not in outgoing or not 2<=len(incoming[item['id']])<=8:return 'a confluence needs 2..8 inflows and one outflow'
    for item in layout['lakes']:
        if not incoming[item['id']]:return 'every lake needs an inflow'
        if item['terminal']==(item['id'] in outgoing):return 'terminal lakes have no outflow; through lakes have exactly one'
    for item in layout['outlets']:
        if len(incoming[item['id']])!=1:return 'every outlet takes exactly one river'
    for start in outgoing:
        node=start
        for _ in range(len(ids)+1):
            if node not in outgoing:break
            node=outgoing[node]
        else:return 'river graph has a cycle'
    parent={i:i for i in ids}
    def find(i):
        while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
        return i
    for a,b in outgoing.items():parent[find(a)]=find(b)
    networks=len({find(i) for i in ids})
    if not water['river_networks'][0]<=networks<=water['river_networks'][1]:return 'river_networks interval must contain the %d declared networks'%networks
    lakes=len(layout['lakes'])
    if not water['lake_count'][0]<=lakes<=water['lake_count'][1]:return 'lake_count interval must contain the %d declared lakes'%lakes
    if (lakes==0)!=(water['lake_area_pct'][1]==0) or lakes==0 and water['lake_area_pct'][0]:return 'lake area must be zero exactly when no lakes are declared'
    return None


def build(config,draw,choose,field,points,at,wet):
    w,h=config['dimensions']['width'],config['dimensions']['height'];area=w*h;layout=config['surface_layout'];wc=config['water']
    def near(p):
        x,y=p;return [(xx,yy) for xx,yy in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)] if 0<=xx<w and 0<=yy<h]
    def anchor(p):
        side=p['side'];mid=sum(p['span'])//2
        return (mid,h-1) if side=='N' else (mid,0) if side=='S' else (0,mid) if side=='W' else (w-1,mid)
    def edge_cells(p):
        return {anchor(dict(p,span=[i,i])) for i in range(p['span'][0],p['span'][1]+1)}
    def pct(item):return (w*item['at_pct'][0]//100,h*item['at_pct'][1]//100)
    def on_edge(p):return p[0] in {0,w-1} or p[1] in {0,h-1}
    def near_water(p,reach):
        x,y=p
        return any(0<=x+dx<w and 0<=y+dy<h and at((x+dx,y+dy))['water']!='NONE' for dx in range(-reach,reach+1) for dy in range(-reach,reach+1))
    # Sea: the same coast fill as the fixed family.
    sea_side=layout['sea_side'];sea_count=area*choose('sea-coverage',wc['sea_pct'])//100 if sea_side!='NONE' else 0;sea=set()
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
    # Lakes share one sampled area; each grows from its anchor and keeps two dry cells from other water.
    lake_specs=layout['lakes'];lake_sets={}
    total=area*choose('lake-coverage',wc['lake_area_pct'])//100 if lake_specs else 0
    for i,spec in enumerate(lake_specs):
        target=total//len(lake_specs)+(i<total%len(lake_specs))
        if target<4:raise HydroReject('LAKE_PACKING','lake '+spec['id']+' below four cells')
        cx,cy=pct(spec)
        eligible={(x,y) for x,y in points if 4<=x<w-4 and 4<=y<h-4 and not near_water((x,y),2)}
        if (cx,cy) not in eligible:raise HydroReject('LAKE_ANCHOR','lake anchor '+spec['id']+' conflicts with water or bounds')
        def lake_score(p,cx=cx,cy=cy,lid=spec['id']):
            dx,dy=p[0]-cx,p[1]-cy
            return dx*dx*5+dy*dy*4+field('graph-lake-shape-'+lid,*p,max(3,min(w,h)//8))//5
        heap=[(lake_score((cx,cy)),(cx,cy))];seen={(cx,cy)};lake=set()
        while heap and len(lake)<target:
            _,p=heapq.heappop(heap);lake.add(p)
            for q in near(p):
                if q in eligible and q not in seen:seen.add(q);heapq.heappush(heap,(lake_score(q),q))
        if len(lake)!=target:raise HydroReject('LAKE_PACKING','lake flood growth exhausted for '+spec['id'])
        for p in lake:wet(p,'LAKE',spec['id'])
        lake_sets[spec['id']]=lake
    # Confluence zones are owned by their outgoing segment, as in IR v2.
    zones={}
    for spec in layout['junctions']:
        jx,jy=pct(spec);zone={(jx+dx,jy+dy) for dx in range(-2,3) for dy in range(-2,3)}
        if any(not(4<=x<w-4 and 4<=y<h-4) or near_water((x,y),2) for x,y in zone):
            raise HydroReject('JUNCTION_ANCHOR','junction '+spec['id']+' footprint intersects water or bounds')
        for p in zone:wet(p,'RIVER',river_id(spec['id']))
        zones[spec['id']]=zone
    width=choose('channel-width',wc['river_width_tiles']);radius=width//2
    offsets=[(dx,dy) for dx in range(-(width//2),width-width//2) for dy in range(-(width//2),width-width//2)]
    def brush(p):return {(p[0]+dx,p[1]+dy) for dx,dy in offsets if 0<=p[0]+dx<w and 0<=p[1]+dy<h}
    inlets={p['id']:p for p in layout['inlets']};outlets={p['id']:p for p in layout['outlets']}
    lakes={p['id']:p for p in lake_specs};outgoing={s['from']:s['to'] for s in layout['segments']}
    route_stats=[]
    def route(source,target):
        rid=river_id(source);own_zone=zones.get(source,set());sink_zone=zones.get(target,set())
        terminal_lakes={l for l in (source,target) if l in lake_sets}
        sea_sink=target in outlets and outlets[target]['kind']=='SEA'
        port_in=inlets.get(source);port_out=outlets.get(target) if target in outlets and not sea_sink else None
        permitted_edge=(edge_cells(port_in) if port_in else set())|(edge_cells(port_out) if port_out else set())
        validity={}
        def valid(p):
            if p not in validity:validity[p]=valid_uncached(p)
            return validity[p]
        def valid_uncached(p):
            if at(p)['water']!='NONE' and p not in own_zone:return False
            for q in brush(p):
                if on_edge(q) and q not in permitted_edge and not(sea_sink and q in sea):return False
                c=at(q)
                if c['water']!='NONE':
                    if q in own_zone or q in sink_zone or c['water']=='LAKE' and c['body'] in terminal_lakes or sea_sink and q in sea:continue
                    return False
                # One dry separator keeps undeclared rivers and lakes apart.
                for t in near(q):
                    tc=at(t)
                    if tc['water']=='RIVER' and tc['body']!=rid and t not in sink_zone:return False
                    if tc['water']=='LAKE' and tc['body'] not in terminal_lakes:return False
            return True
        prefix=[];suffix=[]
        if port_in:
            p=anchor(port_in);dx,dy=NORMALS[port_in['side']];prefix=[(p[0]+i*dx,p[1]+i*dy) for i in range(radius+3)]
            starts=[prefix[-1]]
        elif source in zones:starts=[pct(next(j for j in layout['junctions'] if j['id']==source))]
        else:
            banks={q for p in lake_sets[source] for q in near(p) if at(q)['water']=='NONE'}
            aim=anchor(outlets[target]) if target in outlets else pct(lakes[target]) if target in lakes else pct(next(j for j in layout['junctions'] if j['id']==target))
            starts=[min((b for b in banks if valid(b)),key=lambda b:(abs(b[0]-aim[0])+abs(b[1]-aim[1]),b),default=None)]
            if starts[0] is None:raise HydroReject('LAKE_OUTLET','no clear lake bank for '+rid)
        if target in zones:goals={q for z in sink_zone for q in near(z) if q not in sink_zone and at(q)['water']=='NONE'}
        elif target in lake_sets:goals={q for p in lake_sets[target] for q in near(p) if at(q)['water']=='NONE'}
        elif sea_sink:
            spec=outlets[target];axis=0 if spec['side'] in {'N','S'} else 1
            goals={q for p in sea for q in near(p) if at(q)['water']=='NONE' and spec['span'][0]<=q[axis]<=spec['span'][1]}
        else:
            p=anchor(port_out);dx,dy=NORMALS[port_out['side']];suffix=[(p[0]+i*dx,p[1]+i*dy) for i in range(radius+3)]
            goals={suffix[-1]}
        goals={g for g in goals if valid(g)};start=starts[0]
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
                ng=g+100+field('graph-cost-'+source,*q,max(3,min(w,h)//9))//12
                if ng<cost.get(q,10**30):cost[q]=ng;parent[q]=p;heapq.heappush(frontier,(ng+heuristic(q),ng,q))
        if end is None:raise HydroReject('ROUTE_UNREACHABLE','bounded route failed for '+rid)
        path=[end]
        while path[-1]!=start:path.append(parent[path[-1]])
        path.reverse()
        if prefix:path=prefix[:-1]+path
        if suffix:path=path+list(reversed(suffix[:-1]))
        footprint=set().union(*(brush(p) for p in path))
        footprint={p for p in footprint if at(p)['water']=='NONE' or p in own_zone}
        footprint={p for p in footprint if not on_edge(p) or p in permitted_edge}|permitted_edge
        if any(p not in footprint for p in path) or len(set(path))!=len(path):raise HydroReject('PATH_OWNERSHIP','centerline enters another body in '+rid)
        for p in footprint:wet(p,'RIVER',rid)
        route_stats.append({'segment':rid,'expanded_cells':expanded,'centerline_cells':len(path),'footprint_cells':len(footprint)})
        return path
    # Route the segments nearest their final sink first, so through lakes and
    # confluences already own their downstream channel when inflows arrive.
    def depth(node):
        n=0
        while node in outgoing:node=outgoing[node];n+=1
        return n
    order=sorted(layout['segments'],key=lambda s:(depth(s['from']),s['from']))
    paths={s['from']:route(s['from'],s['to']) for s in order}
    def terminal(node):
        if node in inlets:return dict(kind='EDGE',target=node)
        if node in zones:return dict(kind='JUNCTION',target=node)
        if node in lake_sets:return dict(kind='LAKE',target=node)
        return dict(kind='SEA',target=sea_body) if outlets[node]['kind']=='SEA' else dict(kind='EDGE',target=node)
    rivers=[dict(id=river_id(s['from']),path=[[x,y,'SURFACE'] for x,y in paths[s['from']]],source=terminal(s['from']),sink=terminal(s['to'])) for s in layout['segments']]
    ports=[]
    for spec in layout['inlets']:
        p=anchor(spec);ports.append(dict(id=spec['id'],at=[p[0],p[1],'SURFACE'],side=spec['side'],role='INLET',body=river_id(spec['id']),span=spec['span'][:]))
    for spec in layout['outlets']:
        p=anchor(spec);body=sea_body if spec['kind']=='SEA' else river_id(next(s['from'] for s in layout['segments'] if s['to']==spec['id']))
        ports.append(dict(id=spec['id'],at=[p[0],p[1],'SURFACE'],side=spec['side'],role='OCEAN' if spec['kind']=='SEA' else 'OUTLET',body=body,span=spec['span'][:]))
    junctions=[dict(id=spec['id'],at=[*pct(spec),'SURFACE'],incoming=[river_id(s['from']) for s in layout['segments'] if s['to']==spec['id']],
                    outgoing=river_id(spec['id']),footprint=[[*p,'SURFACE'] for p in sorted(zones[spec['id']])]) for spec in layout['junctions']]
    lake_records=[dict(id=spec['id'],terminal_basin=spec['terminal'],outflow='' if spec['terminal'] else river_id(spec['id'])) for spec in lake_specs]
    parent={}
    def find(i):
        while parent.setdefault(i,i)!=i:i=parent[i]
        return i
    for a,b in outgoing.items():parent[find(a)]=find(b)
    networks=len({find(i) for i in list(inlets)+list(outlets)+list(zones)+list(lake_sets)})
    return dict(sea=sea,lakes=lake_records,lake_sets=[lake_sets[s['id']] for s in lake_specs],rivers=rivers,ports=ports,
                max_width=max(width,5),net_count=networks,lake_count=len(lake_specs),junctions=junctions,route_stats=route_stats)


def river_graph_preset(seed='graph-0',width=64,height=80):
    """Two networks on a south coast: two confluences, a through lake to the sea and an endorheic lake."""
    from .configuration import port_surface_preset
    d=port_surface_preset(seed,width,height,sea_side='S')
    d['water'].update(river_networks=[2,2],lake_count=[2,2],lake_area_pct=[4,7],coverage_pct=[12,30],river_width_tiles=[3,3],sea_pct=[2,4],swamp_pct=[0,2])
    def span(n,pct):
        centre=n*pct//100;return [centre-1,centre+1]
    d['surface_layout']={'sea_side':'S',
        'inlets':[{'id':'inlet-w','side':'W','span':span(height,70)},{'id':'inlet-nw','side':'N','span':span(width,22)},
                  {'id':'inlet-ne','side':'N','span':span(width,72)},{'id':'inlet-e','side':'E','span':span(height,66)}],
        'outlets':[{'id':'mouth','kind':'SEA','side':'S','span':span(width,28)}],
        'junctions':[{'id':'confluence-west','at_pct':[26,70]},{'id':'confluence-east','at_pct':[72,72]}],
        'lakes':[{'id':'lake-west','at_pct':[30,40],'terminal':False},{'id':'lake-east','at_pct':[70,38],'terminal':True}],
        'segments':[{'from':'inlet-w','to':'confluence-west'},{'from':'inlet-nw','to':'confluence-west'},
                    {'from':'confluence-west','to':'lake-west'},{'from':'lake-west','to':'mouth'},
                    {'from':'inlet-ne','to':'confluence-east'},{'from':'inlet-e','to':'confluence-east'},
                    {'from':'confluence-east','to':'lake-east'}],
        'climate_axis':[1,1]}
    return d
