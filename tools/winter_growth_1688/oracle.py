"""Source-only natural-callback evidence oracle. Never launches native code.

Native records are observations, not their own pass verdict. File hashes and wall
elapsed must be supplied by the separately verified supervisor, never the DM JSON.
"""
import json
import math
import re
from prepare import ADAPTER, VERSION, HEAD, TREE

FATAL = re.compile(r'GROWTH1688_FATAL|runtime error|runtime in |uncaught exception|\bBUG:|##\s*ERROR|\berror:|\bwarning:|segmentation|out of memory|access violation|cleanup failed|bad ref|bad loc|infinite loop', re.I)
POPULATION = {'turnip': 4, 'potato': 4, 'plump_helmet': 16, 'mushroom': 16}
PLANT_KEYS = {'id','type','x','y','z','identity','stage','soil','water','plant_nutrition','vstatic'}
FOOD_KEYS = {'id','type','x','y','z','identity','nutriment','age','decay'}
SEED_KEYS = {'id','type','x','y','z','identity','amount'}
SNAPSHOT_KEYS = {'tick','elapsed','plants','foods','seeds'}
RESULT_KEYS = {'schema','adapter','candidate_manifest_sha256','version','variant','phase','port','status','failure','head','tree','tick_lag','fps','observations','poll_max_gap','origin_tick','setup_started_tick','save_started_tick','save_finished_tick','load_started_tick','load_finished_tick','writer_saved_snapshot','map_type','map_id','round_version'}
SAVE_NAMES = {'map_saves/1.sav','map_saves/map.txt','map_saves/round.json','map_saves/save_complete.txt','winter-growth-writer.json'}


def strict_json(raw):
    def pairs(rows):
        out = {}
        for key, value in rows:
            if key in out: raise ValueError('Duplicate JSON key')
            out[key] = value
        return out
    def bad(value): raise ValueError('Nonfinite JSON number')
    return json.loads(raw, object_pairs_hook=pairs, parse_constant=bad)


def require(condition, message):
    if not condition: raise ValueError(message)


def number(value):
    return type(value) in (int, float) and math.isfinite(value)


def integer(value):
    return type(value) is int


def listener_diagnostics(log):
    binds = list(re.finditer(r'World opened on network port (\d+) for address ([^\s]+)\.', log))
    require(len(binds) <= 1 and log.count('World opened on network port') == len(binds), 'Repeated/malformed native bind')
    for match in binds:
        require(match[2] == '127.0.0.1' and 1 <= int(match[1]) <= 65535, 'Nonloopback/invalid native bind')
        require(log.find('World no longer opened to new users.', match.end()) >= 0, 'Native bind lacks closure diagnostic')


def diagnostics(log):
    require(isinstance(log, str), 'Nontext diagnostics')
    require(not FATAL.search(log) and 'FAIL:' not in log, 'Fatal native diagnostic')
    listener_diagnostics(log)


def verify_compile(log):
    require(isinstance(log, str), 'Nontext compiler log')
    require(re.findall(r'DM compiler version ([0-9.]+)', log) == [VERSION], 'Exactly one pinned compiler banner required')
    require(len(re.findall(r'(?<!\d)0 errors, 0 warnings(?!\d)', log)) == 1, 'Exactly one clean compiler summary required')
    require(not FATAL.search(log) and not re.search(r'\b[1-9]\d* (?:errors?|warnings?)\b|invalid file', log, re.I), 'Compiler diagnostic rejected')
    return {'status':'passed','version':VERSION}


def kind(row):
    return row['id'].split(':', 1)[0]


def validate_snapshot(s):
    require(isinstance(s, dict) and set(s) == SNAPSHOT_KEYS, 'Snapshot schema')
    require(integer(s['tick']) and integer(s['elapsed']) and s['tick'] >= 0 and s['elapsed'] >= 0, 'Snapshot clock type')
    for group, keys, prefix, counts in (
        ('plants', PLANT_KEYS, '/obj/structure/farming/plant/', POPULATION),
        ('foods', FOOD_KEYS, '/obj/item/weapon/reagent_containers/food/snacks/grown/', {'turnip':1,'plump_helmet':1}),
        ('seeds', SEED_KEYS, '/obj/item/stack/farming/seeds/', {'turnip':1,'plump_helmet':1})):
        rows=s[group]
        require(isinstance(rows,list) and len(rows)==sum(counts.values()), 'Exact '+group+' population')
        seen=set(); identities=set(); positions=set(); got={k:0 for k in counts}
        for row in rows:
            require(isinstance(row,dict) and set(row)==keys, group+' row schema')
            require(isinstance(row['id'],str) and row['id'] and row['id'] not in seen, 'Duplicate/missing identity id')
            seen.add(row['id']); k=kind(row)
            require(k in counts and row['type']==prefix+k, 'Wrong '+group+' type')
            got[k]+=1
            require(isinstance(row['identity'],str) and bool(row['identity']) and row['identity'] not in identities, 'Missing/duplicate native identity')
            identities.add(row['identity'])
            for axis, maximum in [('x',10),('y',8),('z',1)]:
                require(integer(row[axis]) and 1<=row[axis]<=maximum,'Out-of-world position')
            if group=='plants':
                pos=(row['x'],row['y'],row['z'])
                require(pos not in positions,'Plants share a plot');positions.add(pos)
            for key in keys-{'id','type','identity','x','y','z'}:
                require(number(row[key]), 'Nonnumeric '+group+' field')
            if group=='plants':
                require(row['vstatic']==0 and integer(row['vstatic']), 'Frozen plant cannot prove callbacks')
                require(integer(row['stage']) and 1<=row['stage']<=6,'Unobserved maturity/death outside protocol')
                require(0<=row['soil']<=150 and 0<=row['plant_nutrition']<=150 and row['water']>=0,'Invalid plant resources')
            if group=='foods':
                require(row['decay']==(54000 if k=='turnip' else 36000),'Wrong finite food lifetime')
                require(row['nutriment']==1 and integer(row['age']) and row['age']>=0,'Partial food refilled/invalid age: '+row['id'])
            if group=='seeds':
                require(integer(row['amount']) and row['amount']==1,'Expected one paid seed remaining after sowing: '+row['id'])
        require(got==counts,'Wrong '+group+' species population')
        expected_ids={k+':'+str(i) for k,count in counts.items() for i in range(1,count+1)} if group=='plants' else set(counts)
        require(seen==expected_ids,'Wrong fixed '+group+' IDs')
    return s


def same_snapshot_values(left,right):
    """Across process boundaries native refs are NOT durable identities."""
    for group in ('plants','foods','seeds'):
        a={r['id']:{k:v for k,v in r.items() if k!='identity'} for r in left[group]}
        b={r['id']:{k:v for k,v in r.items() if k!='identity'} for r in right[group]}
        if a != b:
            ids=sorted(set(a)|set(b))
            changed=next(i for i in ids if a.get(i)!=b.get(i))
            left_row,right_row=a.get(changed),b.get(changed)
            fields=sorted(k for k in set(left_row or {})|set(right_row or {}) if (left_row or {}).get(k)!=(right_row or {}).get(k))
            raise ValueError('Save/load changed '+group+' '+changed+' fields '+','.join(fields))


def assess_result(result, *, expected_writer=None, process_receipt=None, expected_save_files=None):
    observations=result['observations']
    require(isinstance(observations,list) and 3<=len(observations)<=10000,'Missing/bounded observations')
    phase=result['phase'];origin=result['origin_tick']
    require(integer(origin) and origin>=0,'Invalid observation origin')
    require(integer(result['poll_max_gap']) and 1<=result['poll_max_gap']<=5,'Observer poll gap loses cadence precision')
    first=validate_snapshot(observations[0]);last=validate_snapshot(observations[-1])
    require(first['tick']==origin and first['elapsed']==0,'First observation origin')
    require(1350<=last['elapsed']<=1400,'Two full natural intervals and fixed observation window required')
    require(isinstance(process_receipt,dict) and number(process_receipt.get('elapsed_seconds')),
            'External supervisor wall time required')
    require(last['elapsed']/10 <= process_receipt['elapsed_seconds'] <= 180,
            'Native ticks lack ordinary elapsed wall time')
    saved=result['writer_saved_snapshot']
    require(isinstance(saved,dict) and set(saved)=={'before','after'},'Saved snapshot schema')
    for s in saved.values(): validate_snapshot(s)
    same_snapshot_values(saved['before'],saved['after'])
    if phase=='writer':
        start=result['setup_started_tick']; finish=origin
        require(integer(start) and 0<=start<=origin and origin-start<=50,'Unbounded setup timing')
        require(result['load_started_tick'] is None and result['load_finished_tick'] is None,'Writer carries load clock')
        a,b=result['save_started_tick'],result['save_finished_tick']
        require(integer(a) and integer(b) and last['tick']<=a<=b and b-a<=50,'Writer save timing')
        same_snapshot_values(last,saved['before'])
        require(last['tick']<=saved['before']['tick']<=a and b<=saved['after']['tick']<=b+5,'Save snapshot clock boundaries')
        require(all(s['elapsed']==s['tick']-origin for s in saved.values()),'Saved snapshot elapsed clock')
        for row in first['plants']:
            require(row['stage']==1 and row['soil']==147 and row['plant_nutrition']==147,'Initial constructor payment/stage differs')
        require(all(r['age']==0 for r in first['foods']),'Writer food must start unaged')
    else:
        start,finish=result['load_started_tick'],result['load_finished_tick']
        require(integer(start) and integer(finish) and 0<=start<=finish<=origin and origin-start<=50,'Reader load timing')
        require(result['save_started_tick'] is None and result['save_finished_tick'] is None,'Reader carries save clock')
        require(expected_writer is not None and saved==expected_writer,'Reader not bound to independently transferred writer snapshot')
        require(isinstance(expected_save_files,dict) and set(expected_save_files)==SAVE_NAMES,'Exact external save-set seal required')
        for row in expected_save_files.values():
            require(isinstance(row,dict) and set(row)=={'bytes','sha256'} and integer(row['bytes']) and row['bytes']>0
                    and isinstance(row['sha256'],str) and re.fullmatch('[0-9a-f]{64}',row['sha256']),'Malformed external save-set seal')
        same_snapshot_values(saved['after'],first)
    previous=first
    payments={r['id']:[] for r in first['plants']};food_events={r['id']:[] for r in first['foods']}
    plump_advances=0
    for current in observations[1:]:
        validate_snapshot(current)
        require(current['tick']>previous['tick'] and current['elapsed']==current['tick']-origin,'Observation clock order')
        require(current['tick']-previous['tick']<=105,'Missing observer heartbeat')
        for group in ('plants','foods','seeds'):
            require([r['id'] for r in current[group]]==[r['id'] for r in first[group]],'Changed row order/identity set')
            for a,b in zip(previous[group],current[group]):
                for key in ('id','type','identity','x','y','z'):
                    require(a[key]==b[key],'Lost/replaced/moved '+group+' identity: '+a['id'])
                if group=='plants':
                    debit=a['soil']-b['soil'];advance=b['stage']-a['stage']
                    require(debit in (0,3),'Missing/duplicate/unpaid soil debit: '+a['id']+' debit='+str(debit))
                    require(b['water']==a['water'],'Unexpected crop water change: '+a['id'])
                    if debit:
                        payments[a['id']].append(current['tick'])
                        require(b['plant_nutrition']==b['soil'],'Sampled fertility not paid soil: '+a['id'])
                        if kind(a)=='plump_helmet':
                            require(advance in (0,1),'Impossible stochastic growth: '+a['id']+' advance='+str(advance));plump_advances+=advance
                        else: require(advance==1,'Paid deterministic crop failed to advance once: '+a['id']+' advance='+str(advance))
                    else:
                        require(advance==0 and a['plant_nutrition']==b['plant_nutrition'],'Unpaid growth or fertility change: '+a['id'])
                elif group=='foods':
                    delta=b['age']-a['age']
                    require(delta in (0,600),'Missing/duplicate/reset food age debit: '+a['id']+' delta='+str(delta))
                    if delta: food_events[a['id']].append(current['tick'])
                else: require(a['amount']==b['amount'],'Seed stock changed without planting: '+a['id'])
        previous=current
    for identity, events in payments.items():
        detail=': '+identity+' payment_ticks='+str(events)
        require(len(events)==2,'Exactly two recurring crop payments required'+detail)
        require(start+600<=events[0]<=finish+605,'Crop payment early/late first cadence'+detail)
        require(595<=events[1]-events[0]<=605,'Crop payment recurring cadence'+detail)
    for identity, events in food_events.items():
        detail=': '+identity+' age_ticks='+str(events)
        require(len(events)==2,'Exactly two natural food aging events required'+detail)
        require(start+590<=events[0]<=finish+615,'Food first callback cadence'+detail)
        require(585<=events[1]-events[0]<=615,'Food recurring callback cadence'+detail)
    return {'status':'passed' if plump_advances else 'inconclusive',
            'reason':None if plump_advances else 'All plump helmets paid both intervals but made no stochastic advance',
            'payments_by_type':{k:sum(len(events) for identity,events in payments.items() if identity.split(':')[0]==k) for k in POPULATION},
            'crop_payments':sum(map(len,payments.values())), 'food_events':sum(map(len,food_events.values())),
            'plump_advances':plump_advances,
            'cadence_note':'Constructor-owned full wait observed; partial pre-save wait is not restored' if phase=='reader' else 'Two ordinary constructor-owned intervals observed'}


def verify_result(binding, variant, phase, result, log, auxiliary=None, *, expected_writer=None, process_receipt=None, expected_save_files=None):
    require(isinstance(binding,str) and re.fullmatch('[0-9a-f]{64}',binding),'Invalid manifest binding')
    require(variant=='baseline' and phase in ('writer','reader'),'Unknown variant/phase')
    require(isinstance(result,dict) and set(result)==RESULT_KEYS,'Unexpected growth result schema')
    for key,value in {'adapter':ADAPTER,'version':VERSION,'head':HEAD,'tree':TREE,'variant':variant,'phase':phase,'candidate_manifest_sha256':binding}.items():
        require(result[key]==value,'Wrong source/phase binding: '+key)
    require(type(result['schema']) is int and result['schema']==1 and type(result['port']) is int and result['port']==0,'Schema/native port')
    require(number(result['tick_lag']) and result['tick_lag']==1 and number(result['fps']) and result['fps']==10,'Changed native clock rate')
    require(result['map_type']=='/obj/map_metadata/nomads/winter_tester' and result['map_id']=='NOMADS_PANGEA' and result['round_version']=='round-v1','Wrong tiny-world transaction scope')
    require(result['status']=='observed' and result['failure'] is None,'DM terminal must be observations, not self-awarded success')
    diagnostics(log)
    marker='GROWTH1688_RESULT baseline:'+phase
    require([line for line in log.splitlines() if line.startswith('GROWTH1688_RESULT ')]==[marker] and log.count('GROWTH1688_RESULT ')==1,'Missing/duplicate terminal marker')
    prefix='GROWTH1688_OBSERVATION '
    found=[strict_json(line[len(prefix):]) for line in log.splitlines() if line.startswith(prefix)]
    require(found==result['observations'] and log.count(prefix)==len(found),'Missing/duplicate/reordered observation transcript')
    require(log.rfind(prefix)<log.index(marker),'Observation follows terminal marker')
    if auxiliary is not None:
        require(isinstance(auxiliary,dict),'Malformed auxiliary logs')
        for content in auxiliary.values():
            diagnostics(content)
            if prefix in content or 'GROWTH1688_RESULT ' in content:
                verify_result(binding,variant,phase,result,content,expected_writer=expected_writer,
                              process_receipt=process_receipt,expected_save_files=expected_save_files)
    return assess_result(result, expected_writer=expected_writer,process_receipt=process_receipt,expected_save_files=expected_save_files)
