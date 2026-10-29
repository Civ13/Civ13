"""Original bounded oceanic backend: seed-grown islands in a connected deep sea.

No map/image templates or native engine. One candidate, no repair or seed search.
Coordinate randomness is domain separated from every SURFACE algorithm version.
"""
from collections import Counter,deque
from copy import deepcopy
import heapq
import json
from .configuration import OCEAN_CONFIG_VERSION,validate_config,seed_manifest
from .surface_generator import Rejection,ground,neighbors,distances,CONTENT_VERSION,CHAIN
from .validator import OCEAN_VERSION,stable_u64,canonical_hash,validate

ALGORITHM_VERSION='oceanic-offline/0.1.0'
PROFILE_VERSION='OCEANIC-offline/1'


def _generate(config,traversal):
    errors=validate_config(config)
    if errors:raise Rejection('CONFIG_REJECTED',json.dumps(errors,sort_keys=True))
    if config['schema']!=OCEAN_CONFIG_VERSION or config['profile']!='OCEANIC':
        raise Rejection('BACKEND_PROFILE','oceanic backend requires version-3 OCEANIC config')
    if traversal not in {'forward','reverse'}:raise ValueError('traversal')
    seed=config['seed'];cfg_hash=canonical_hash(config)
    def draw(stage,x=0,y=0,slot=0):
        return stable_u64(seed,ALGORITHM_VERSION,CONTENT_VERSION,PROFILE_VERSION+':'+cfg_hash,stage,'SURFACE',x,y,slot)
    def choose(stage,bounds,slot=0):
        span=bounds[1]-bounds[0]+1;limit=2**64-2**64%span
        for retry in range(32):
            value=draw(stage,slot=slot*32+retry)
            if value<limit:return bounds[0]+value%span
        raise Rejection('RANDOM_REJECTION_BOUND','32 integer draws exhausted')
    w,h=config['dimensions']['width'],config['dimensions']['height'];area=w*h
    points=[(x,y) for y in range(h) for x in range(w)];all_points=set(points)
    iteration=points if traversal=='forward' else list(reversed(points))
    grid=[[None]*w for _ in range(h)];underground=[[None]*w for _ in range(h)]
    for x,y in iteration:
        grid[y][x]=ground(terrain='WATER',water='SEA',salinity='SALT',body='ocean',depth_cm=200,soil='SILT',biome='COAST')
        underground[y][x]=ground(terrain='ROCK',biome='CAVERN',soil='ROCK',blocked=True)
    def at(p):return grid[p[1]][p[0]]
    layout=config['ocean_layout'];water=config['water']
    count=choose('island-count',layout['island_count']);sea_pct=choose('sea-coverage',water['sea_pct'])
    dry_target=area*(100-sea_pct)//100
    # Split the longer extent recursively. Every region retains an explicit sea
    # margin, so separate growth fronts cannot join or form a map-edge mainland.
    regions=[]
    def split(box,n):
        x0,y0,x1,y1=box
        if n==1:regions.append(box);return
        first=n//2
        if x1-x0>=y1-y0:
            cut=x0+(x1-x0)*first//n;split((x0,y0,cut,y1),first);split((cut,y0,x1,y1),n-first)
        else:
            cut=y0+(y1-y0)*first//n;split((x0,y0,x1,cut),first);split((x0,cut,x1,y1),n-first)
    split((0,0,w,h),count)
    margin=max(layout['coast_width_tiles']+2,(layout['island_gap_tiles']+1)//2+layout['ship_radius']+1)
    weights=[80+draw('island-weight',slot=i)%41 for i in range(count)]
    quotas=[dry_target*v//sum(weights) for v in weights]
    for i in range(dry_target-sum(quotas)):quotas[i%count]+=1
    growth_stats=[]
    def grow(allowed,start,target,priority,label):
        if start not in allowed or target>len(allowed):raise Rejection('OCEAN_PACKING',label+' exceeds eligible area')
        heap=[(priority(start),start)];queued={start};seen=set();expanded=0
        while heap and len(seen)<target:
            _,p=heapq.heappop(heap);seen.add(p);expanded+=1
            for q in neighbors(p,w,h):
                if q in allowed and q not in queued:queued.add(q);heapq.heappush(heap,(priority(q),q))
        growth_stats.append(dict(feature=label,target=target,expanded=expanded,eligible=len(allowed)))
        if len(seen)!=target:raise Rejection('OCEAN_PACKING',label+' connected growth exhausted')
        return seen
    islands=[]
    for i,(x0,y0,x1,y1) in enumerate(regions):
        allowed={(x,y) for y in range(y0+margin,y1-margin) for x in range(x0+margin,x1-margin)}
        if not allowed:raise Rejection('OCEAN_SCALE','island margins do not fit partition')
        cx=(x0+x1)//2+int(draw('center-x',slot=i)%5)-2
        cy=(y0+y1)//2+int(draw('center-y',slot=i)%5)-2
        center=min(allowed,key=lambda p:(abs(p[0]-cx)+abs(p[1]-cy),p))
        sx=max(1,x1-x0-2*margin);sy=max(1,y1-y0-2*margin)
        # Smooth radial cost with bounded seeded fine variation. Growth is
        # cardinally connected; any residual sea pocket fails the final oracle.
        def priority(p):
            x,y=p;return ((x-cx)**2*sy*sy+(y-cy)**2*sx*sx)*64+draw('coast-fine-'+str(i),x,y)%max(1,sx*sy*8)
        island=grow(allowed,center,quotas[i],priority,'island-'+str(i));islands.append(island)
        for p in island:at(p).update(ground())
    sea=all_points-set.union(*islands)
    shore_distance,_=distances(sea,all_points,w,h)
    lake_pct=choose('lake-coverage',water['lake_area_pct']);lake_target=area*lake_pct//100
    lakes=[];lake_sets=[]
    for i,island in enumerate(islands):
        target=lake_target//count+(i<lake_target%count)
        eligible={p for p in island if shore_distance[p]>=layout['coast_width_tiles']+3}
        if not eligible or not target:raise Rejection('OCEAN_FRESHWATER','island cannot fit positive inland lake')
        center=max(eligible,key=lambda p:(shore_distance[p],draw('lake-center',*p),p))
        def priority(p):return ((p[0]-center[0])**2+(p[1]-center[1])**2)*1024+draw('lake-fine',*p)%512
        wet=grow(eligible,center,target,priority,'lake-'+str(i));lake_sets.append(wet)
        name='island-lake-'+str(i);lakes.append(dict(id=name,terminal_basin=True,outflow=''))
        for p in wet:at(p).update(terrain='WATER',water='LAKE',salinity='FRESH',body=name,depth_cm=200,soil='SILT')
    dry={p for p in points if at(p)['water']=='NONE'}
    range_count=choose('range-count',config['mountains']['range_count']);ridges=[];mountains=set()
    island_order=sorted(range(count),key=lambda i:(draw('range-island',slot=i),i))
    forbidden=all_points-dry;water_distance,_=distances(forbidden,all_points,w,h)
    for i in range(range_count):
        island=islands[island_order[i]];width=choose('range-width',config['mountains']['range_width_tiles'],i)
        radius=max(1,width//2);eligible={p for p in island&dry if water_distance[p]>radius+layout['coast_width_tiles']}
        if not eligible:raise Rejection('OCEAN_RANGE','no dry island interior for requested range')
        center=max(eligible,key=lambda p:(water_distance[p],draw('ridge-center',*p),p))
        horizontal=bool(draw('ridge-axis',slot=i)%2)
        def priority(p):
            dx,dy=p[0]-center[0],p[1]-center[1]
            return (dx*dx+(dy*width)**2 if horizontal else (dx*width)**2+dy*dy)*1024+draw('ridge-fine',*p)%512
        target=max(config['mountains']['range_min_area'],width*max(4,min(w,h)//8))
        ridge=grow(eligible,center,target,priority,'ridge-'+str(i));ridges.append([list(p) for p in sorted(ridge)]);mountains|=ridge
        for p in ridge:at(p).update(terrain='MOUNTAIN',soil='ROCK',blocked=True,elevation_m=400+water_distance[p]*10)
    hill_distance,_=distances(mountains,dry,w,h)
    for p,d in hill_distance.items():
        if d in {1,2}:at(p).update(terrain='HILL',soil='ROCK',elevation_m=(3-d)*100)
    # Interior climatic quantiles use an oriented integer field. COAST labels
    # preserve the underlying moisture/temperature instead of creating a desert.
    mix=config['biome_mix_pct'];interior=[b for b in CHAIN if mix.get(b,0)]
    ax,ay=layout['climate_axis'];ordered=sorted(dry,key=lambda p:(p[0]*ax+p[1]*ay,p))
    interior_weight=sum(mix.get(b,0) for b in interior);cursor=0
    moist={'LUSH':75,'TEMPERATE':55,'STEPPE':40,'ARID':25,'DESERT':15}
    lo,hi=config['climate']['moisture_range'];tlo,thi=config['climate']['temperature_c_range']
    for index,b in enumerate(interior or ['TEMPERATE']):
        size=len(ordered)-cursor if index==len(interior or ['TEMPERATE'])-1 else len(ordered)*mix[b]//interior_weight
        for p in ordered[cursor:cursor+size]:
            c=at(p);c.update(biome=b,moisture=max(lo,min(hi,moist[b])),temperature_c=tlo+(thi-tlo)*p[1]//max(1,h-1))
            if c['terrain']=='PLAIN':c['soil']='SAND' if b in {'ARID','DESERT'} else 'LOAM'
        cursor+=size
    coast_count=len(dry)*mix.get('COAST',0)//100
    coastal=sorted(dry,key=lambda p:(shore_distance[p],draw('coast-biome',*p),p))[:coast_count]
    for p in coastal:at(p)['biome']='COAST'
    for p in dry:
        if shore_distance[p]<=layout['coast_width_tiles'] and at(p)['terrain']=='PLAIN':at(p).update(terrain='BEACH',soil='SAND')
    walk={p for p in dry if not at(p)['blocked']};max_route=config['starts']['max_route_tiles']
    banks={p for p in walk if any(at(q)['water']=='LAKE' for q in neighbors(p,w,h))}
    coasts={p for p in walk if any(q in sea for q in neighbors(p,w,h))}
    fresh_distance,fresh_parent=distances(banks,walk,w,h);coast_distance,coast_parent=distances(coasts,walk,w,h)
    candidates={p for p in walk if fresh_distance.get(p,area)<=max_route and coast_distance.get(p,area)<=max_route and len(neighbors(p,w,h))==4 and all(q in walk for q in neighbors(p,w,h))}
    reserved=set();starts=[];routes=[]
    for i in range(config['starts']['count']):
        wanted=i%count;choices=candidates&islands[wanted]
        if not choices:raise Rejection('OCEAN_START_PACKING','no safe separated island start with fresh/coast routes')
        p=max(choices,key=lambda q:(min((abs(q[0]-s[0])+abs(q[1]-s[1]) for s in starts),default=0),draw('start-rank',*q),q));starts.append(p)
        candidates={q for q in candidates if abs(q[0]-p[0])+abs(q[1]-p[1])>=config['starts']['min_spacing_tiles']}
        record=dict(start=list(p),island=wanted)
        for label,targets,parent in [('freshwater_bank_route',banks,fresh_parent),('coast_route',coasts,coast_parent)]:
            route=[p]
            while route[-1] not in targets:route.append(parent[route[-1]])
            reserved.update(route);record[label]=[list(q) for q in route]
        supply_distance,supply_parent=distances([p],walk,w,h)
        supplies=sorted([q for q,d in supply_distance.items() if 1<=d<=min(4,max_route) and at(q)['resource']=='NONE'],key=lambda q:(supply_distance[q],draw('supply-rank',*q),q))
        if len(supplies)<3:raise Rejection('OCEAN_SUPPLIES','not enough distinct abstract supply sites')
        record['resource_routes']={}
        for kind,q in zip(['FOOD','WOOD','STONE'],supplies[:3]):
            at(q)['resource']=kind;route=[q]
            while route[-1]!=p:route.append(supply_parent[route[-1]])
            reserved.update(route);record['resource_routes'][kind]=[list(t) for t in reversed(route)]
        routes.append(record)
    density=choose('resource-density',config['resources']['density_per_1000_land_tiles'])
    extra=sorted([p for p in walk if p not in reserved and at(p)['resource']=='NONE'],key=lambda p:(draw('extra-resources',*p),p))[:len(dry)*density//1000]
    for p in extra:at(p)['resource']=['FOOD','WOOD','STONE'][draw('resource-kind',*p)%3];reserved.add(p)
    eligible=[]
    for p in iteration:
        c=at(p)
        if p in reserved or c['water']!='NONE' or c['blocked'] or c['resource']!='NONE':continue
        species='NONE'
        if c['soil']=='SAND' and 20<=c['moisture']<=85 and 18<=c['temperature_c']<=45:species='PALM'
        elif c['soil']=='LOAM' and 35<=c['moisture']<=90 and -5<=c['temperature_c']<=35:species='BROADLEAF'
        elif c['soil'] in {'LOAM','SAND'} and 20<=c['moisture']<=80 and -20<=c['temperature_c']<=25:species='PINE'
        elif c['soil']=='SAND' and c['moisture']<=30 and c['temperature_c']>=10:species='CACTUS'
        if species!='NONE':eligible.append((p,species))
    vegetation=choose('vegetation-density',config['vegetation']['suitable_site_density_pct'])
    eligible.sort(key=lambda item:(draw('tree-rank',*item[0]),item[0]))
    for p,species in eligible[:len(eligible)*vegetation//100]:at(p)['tree']=species
    ports=[dict(id='ocean-'+side,at=[x,y,'SURFACE'],side=side,role='OCEAN',body='ocean') for side,x,y in [('W',0,h//2),('E',w-1,h//2),('S',w//2,0),('N',w//2,h-1)]]
    doc=dict(schema=OCEAN_VERSION,seed=seed,algorithm_version=ALGORITHM_VERSION,content_version=CONTENT_VERSION,profile_version=PROFILE_VERSION,
             profile='OCEANIC',active_layer='SURFACE',width=w,height=h,layers={'SURFACE':dict(native_z=2,cells=grid),'UNDERGROUND':dict(native_z=1,cells=underground)},
             ports=ports,rivers=[],lakes=lakes,starts=[[x,y,'SURFACE'] for x,y in starts],portals=[],
             ocean_policy=dict(island_count=count,island_min_area=layout['island_min_area'],island_gap_tiles=layout['island_gap_tiles'],
                               start_min_spacing=config['starts']['min_spacing_tiles'],coast_route_max=max_route),
             policy=dict(mountain_min_area=config['mountains']['range_min_area'],mountain_max_components=max(1,range_count),max_moisture_step=25,max_temperature_step=10,
                         max_resource_distance=max_route,max_water_distance=max_route,ship_radius=layout['ship_radius'],ocean_ports_min=4,land_components_min=count,
                         start_count=len(starts),river_half_width=1,max_path_uphill_m=0))
    reasons=validate(doc);counts=Counter(at(p)['water'] for p in points)
    for actual,bounds,label in [(area-counts['NONE'],water['coverage_pct'],'total'),(counts['SEA'],water['sea_pct'],'sea'),(counts['LAKE'],water['lake_area_pct'],'lake')]:
        if actual*100+100<bounds[0]*area or actual*100>bounds[1]*area+100:reasons.append(dict(code='CONFIG_REALIZED_WATER',detail=label+' outside configured coverage'))
    if reasons:raise Rejection('INVARIANT_REJECTED',json.dumps(reasons,sort_keys=True))
    manifest=seed_manifest(config,ALGORITHM_VERSION,CONTENT_VERSION,PROFILE_VERSION)
    manifest.update(status='GENERATED_VALID_OFFLINE_IR',generation_result=dict(ir_sha256=canonical_hash(doc),validation_errors=[],native_acceptance='NOT_RUN'),
                    generated_topology=dict(islands=count,lakes=count,ranges=range_count,river_networks=0,ship_radius=layout['ship_radius']),
                    abstract_routes=routes,reserved_route_cells=[list(p) for p in sorted(reserved)],ridge_skeletons=ridges,
                    realized_water_cells=dict(sorted(counts.items())),eligible_vegetation_sites=len(eligible),selected_vegetation_density_pct=vegetation,
                    bounded_growth=growth_stats,cave_layer='UNGENERATED_BLOCKED_RESERVE',reference_matching='NOT_EVALUATED')
    return doc,manifest


def generate(config,*,traversal='forward'):
    try:
        doc,manifest=_generate(deepcopy(config),traversal)
        return dict(status='GENERATED_VALID_OFFLINE_IR',document=doc,manifest=manifest,reasons=[])
    except Rejection as e:
        return dict(status='REJECTED_OFFLINE_CANDIDATE',document=None,manifest=None,reasons=[dict(code=e.code,detail=e.detail)],configuration_sha256=canonical_hash(config))
