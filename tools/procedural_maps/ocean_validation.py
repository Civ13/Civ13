"""Mandatory schema-3 archipelago rules, separate from v1 synthetic fixtures.

Shared validator checks salinity, habitats, drainage, navigation and start routes.
This slice adds island identity, inland terminal basins and minimum sea channels.
"""
from collections import deque


def validate_archipelago(doc):
    w,h=doc['width'],doc['height'];grid=doc['layers']['SURFACE']['cells']
    rules=doc['ocean_policy'];errors=[]
    def fail(code,detail):errors.append(dict(code=code,detail=detail))
    def near(p):
        x,y=p
        return [(a,b) for a,b in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)] if 0<=a<w and 0<=b<h]
    points={(x,y) for y in range(h) for x in range(w)}
    def cell(p):return grid[p[1]][p[0]]
    land={p for p in points if cell(p)['water']=='NONE'}
    owner={};groups=[]
    for seed in sorted(land):
        if seed in owner:continue
        i=len(groups);group={seed};owner[seed]=i;todo=[seed]
        while todo:
            for q in near(todo.pop()):
                if q in land and q not in owner:owner[q]=i;group.add(q);todo.append(q)
        groups.append(group)
    if len(groups)!=rules['island_count']:fail('OCEAN_ISLAND_COUNT','dry components differ from declared island count')
    if any(len(g)<rules['island_min_area'] for g in groups):fail('OCEAN_ISLAND_AREA','undersized dry island component')
    if any(x in {0,w-1} or y in {0,h-1} for x,y in land):fail('OCEAN_BOUNDARY','islands must be separated from map edges by sea')
    sea={p for p in points if cell(p)['water']=='SEA'}
    if len({cell(p)['body'] for p in sea})!=1:fail('OCEAN_SEA_BODY','connected open sea must have one declared body identity')
    if len(doc['ports'])!=4 or {p['side'] for p in doc['ports']}!={'N','S','E','W'} or any(p['role']!='OCEAN' for p in doc['ports']):
        fail('OCEAN_PORT_LAYOUT','one explicit ocean port on each edge is mandatory for this family')
    if len(sea)*2<=w*h:fail('OCEAN_MAJORITY','archipelago requires majority sea')
    if doc['policy']['ship_radius']<1 or rules['island_gap_tiles']<2*doc['policy']['ship_radius']+2:
        fail('OCEAN_CLEARANCE','positive ship radius and navigable channel margin required')
    if doc['rivers'] or any(cell(p)['water'] in {'RIVER','SWAMP'} for p in points):
        fail('OCEAN_HYDROLOGY_SLICE','this version admits inland terminal lakes, not island rivers or swamps')
    if any(not lake['terminal_basin'] or lake['outflow'] for lake in doc['lakes']):
        fail('OCEAN_LAKE_ENDPOINT','island lakes must be declared terminal basins in this version')
    lake_owners={i:set() for i in range(len(groups))}
    for lake in doc['lakes']:
        wet={p for p in points if cell(p)['water']=='LAKE' and cell(p)['body']==lake['id']}
        ring={q for p in wet for q in near(p) if q not in wet}
        ids={owner[q] for q in ring if q in owner}
        if not wet or len(ids)!=1 or not ring<=land or any(x in {0,w-1} or y in {0,h-1} for x,y in wet):
            fail('OCEAN_INLAND_LAKE','each fresh lake must be wholly enclosed by one dry island')
        else:lake_owners[next(iter(ids))].add(lake['id'])
    if any(len(ids)!=1 for ids in lake_owners.values()):fail('OCEAN_ISLAND_WATER','each island needs exactly one inland freshwater basin')
    start_islands={owner.get(tuple(p[:2])) for p in doc['starts'] if p[2]=='SURFACE'}
    if not set(range(len(groups)))<=start_islands:fail('OCEAN_ISLAND_START','each island requires a start; no empty isolated start islands')
    starts=[tuple(p[:2]) for p in doc['starts']]
    if any(abs(a[0]-b[0])+abs(a[1]-b[1])<rules['start_min_spacing'] for i,a in enumerate(starts) for b in starts[i+1:]):
        fail('OCEAN_START_SPACING','starts violate declared cardinal spacing')
    walk={p for p in land if not cell(p)['blocked'] and not cell(p)['hazard'] and cell(p)['tree']=='NONE' and cell(p)['terrain'] not in {'ROCK','MOUNTAIN'}}
    shores={p for p in walk if any(q in sea for q in near(p))}
    shore_distance={p:0 for p in shores};queue=deque(sorted(shores))
    while queue:
        p=queue.popleft()
        for q in near(p):
            if q in walk and q not in shore_distance:shore_distance[q]=shore_distance[p]+1;queue.append(q)
    if any(shore_distance.get(p,w*h)>rules['coast_route_max'] for p in starts):
        fail('OCEAN_START_COAST_BOUND','no safe coast route within declared bound')
    # Multi-source labelled wavefront finds narrow channels in O(area), no pairwise tiles.
    labels=dict(owner);distance={p:0 for p in owner};queue=deque(sorted(owner));narrow=False
    while queue:
        p=queue.popleft()
        for q in near(p):
            if q not in labels:labels[q]=labels[p];distance[q]=distance[p]+1;queue.append(q)
            elif labels[q]!=labels[p] and distance[q]+distance[p]<rules['island_gap_tiles']:narrow=True
    if narrow:fail('OCEAN_ISLAND_GAP','island separation below configured sea-channel gap')
    return errors
