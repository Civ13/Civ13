"""IR v2 graph-to-raster and full edge-span invariants, independent of generation."""
from collections import deque


def span_points(port,w,h):
    lo,hi=port['span'];side=port['side'];layer=port['at'][2]
    return {(i,h-1,layer) if side=='N' else (i,0,layer) if side=='S' else (0,i,layer) if side=='W' else (w-1,i,layer) for i in range(lo,hi+1)}


def validate_port_geometry(d):
    errors=[];w,h=d['width'],d['height']
    cells={(x,y,l):c for l,level in d['layers'].items() for y,row in enumerate(level['cells']) for x,c in enumerate(row)}
    rivers={r['id']:r for r in d['rivers']};covered={}
    def err(code,detail,at=None):errors.append({'code':code,'detail':detail,**({'at':list(at)} if at else {})})
    def near(p):
        x,y,l=p;return [(xx,yy,l) for xx,yy in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)] if 0<=xx<w and 0<=yy<h]
    for p in d['ports']:
        points=span_points(p,w,h)
        if tuple(p['at']) not in points:err('PORT_SPAN','port anchor outside its declared span',p['at'])
        for q in points:
            if q in covered:err('PORT_SPAN_OVERLAP','two spans cover the same edge cell',q)
            covered[q]=p
            c=cells[q];kind='SEA' if p['role']=='OCEAN' else 'RIVER'
            if c['water']!=kind or c['body']!=p['body']:err('PORT_SPAN_WATER','entire span must match declared typed body',q)
        if p['role']!='OCEAN' and p['body'] in rivers:
            path=[tuple(q) for q in rivers[p['body']]['path']];a,b=(path[0],path[1]) if p['role']=='INLET' else (path[-1],path[-2])
            inward={'N':(0,-1),'S':(0,1),'W':(1,0),'E':(-1,0)}[p['side']]
            if (b[0]-a[0],b[1]-a[1])!=inward:err('PORT_DIRECTION','river must cross the edge in the declared normal direction',a)
    for p,c in cells.items():
        if c['water']=='RIVER' and (p[0] in {0,w-1} or p[1] in {0,h-1}):
            if p not in covered or covered[p]['role']=='OCEAN' or covered[p]['body']!=c['body']:err('PORT_LEAK','river edge contact outside its declared span',p)
    allowed_contacts=set()
    for j in d['junctions']:
        zone={tuple(p) for p in j['footprint']};out=j['outgoing']
        if len(zone)!=len(j['footprint']) or tuple(j['at']) not in zone:err('JUNCTION_ZONE','duplicate zone cells or missing anchor')
        todo=[min(zone)];seen={todo[0]}
        while todo:
            for q in near(todo.pop()):
                if q in zone and q not in seen:seen.add(q);todo.append(q)
        if seen!=zone:err('JUNCTION_ZONE','junction raster zone is disconnected')
        if any(cells[p]['water']!='RIVER' or cells[p]['body']!=out for p in zone):err('JUNCTION_ZONE','zone must be owned by the outgoing river')
        if out not in rivers or rivers[out]['source']!={'kind':'JUNCTION','target':j['id']}:
            err('JUNCTION_GRAPH','outgoing segment does not start at this junction')
        for rid in j['incoming']:
            if rid not in rivers or rivers[rid]['sink']!={'kind':'JUNCTION','target':j['id']}:
                err('JUNCTION_GRAPH','incoming segment does not end at this junction')
                continue
            end=tuple(rivers[rid]['path'][-1])
            if not any(q in zone and cells[q]['body']==out for q in near(end)):err('JUNCTION_RASTER','incoming centerline lacks zone contact',end)
            for p in zone:
                for q in near(p):
                    if cells[q]['water']=='RIVER' and cells[q]['body']==rid:allowed_contacts.add(frozenset((p,q)))
        graph_in=sorted(r['id'] for r in rivers.values() if r['sink']=={'kind':'JUNCTION','target':j['id']})
        if graph_in!=sorted(j['incoming']):err('JUNCTION_GRAPH','junction incoming list differs from all graph references')
    for p,c in cells.items():
        if c['water']!='RIVER':continue
        for q in near(p):
            if q<p:continue
            other=cells[q]
            if other['water']=='RIVER' and other['body']!=c['body'] and frozenset((p,q)) not in allowed_contacts:
                # Legacy RIVER terminals are deliberately disallowed in IR2: named zones are required.
                err('UNDECLARED_RIVER_CONTACT','different river bodies touch outside a declared junction zone',p)
    return errors
