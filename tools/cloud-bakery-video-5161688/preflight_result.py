"""Validate native-generated city preflight receipts; no runtime or screen access."""
from route_receipt_check import check, load_routes
from pathlib import Path
import json, math

def require(value, reason):
    if not value: raise ValueError(reason)
def read(path):
    path=Path(path)
    require(path.is_file() and not path.is_symlink() and path.stat().st_size<65536, 'missing/linked/oversize receipt')
    return json.loads(path.read_text(encoding='utf-8'))
def yes(v): return v is True or (type(v) is int and v==1)
def no(v): return v is False or (type(v) is int and v==0)
def validate(source, route_file):
    source=Path(source)
    route=read(source/'city-route-receipt.json')
    check(route,load_routes(route_file))
    bakery=read(source/'city-bakery-receipt.json')
    before=read(source/'city-train-before.json'); after=read(source/'city-train-after.json')
    require(bakery.get('flour')==route['flour'] and type(bakery.get('bread')) is str and bakery.get('bread')!=bakery.get('dough'), 'same flour and distinct bread')
    require(bakery.get('bread') == bakery.get('picked_ref') == bakery.get('placed_ref') == bakery.get('received_ref') and yes(bakery.get('customer_holds_output')) and yes(bakery.get('fuel_paid')), 'same bread handoff and oven fuel')
    require(bakery.get('flour_paid')==5 and bakery.get('water_paid')==5, 'dough inputs')
    dep=bakery.get('departure')
    require(type(dep) is dict and dep.get('customer') == bakery.get('customer') and dep.get('bread') == bakery.get('bread'), 'same customer and bread departure')
    require((dep.get('x'),dep.get('y'),dep.get('z'),dep.get('dir'))==(76,54,1,4) and yes(dep.get('driver_bound')) and yes(dep.get('horse_bound')) and yes(dep.get('bread_in_inactive_hand')) and yes(dep.get('reins_in_active_hand')) and no(dep.get('moving')) and dep.get('speed')==0, 'carriage departure and stop')
    expected=[(74,59),(74,58),(74,57),(73,57),(73,56),(73,55),(73,54)]
    rows=dep.get('route')
    require(type(rows) is list and len(rows)==len(expected), 'customer route length')
    previous=None
    for row,xy in zip(rows,expected):
        require(type(row) is dict and (row.get('x'),row.get('y'))==xy and row.get('bread')==bakery.get('bread'), 'customer route and bread custody')
        t=row.get('time')
        require(type(t) in (int,float) and math.isfinite(t) and (previous is None or t-previous>=4), 'customer route timing')
        previous=t
    boarding=dep.get('boarding_started'); boarded=dep.get('boarded_at')
    require(type(boarding) in (int,float) and type(boarded) in (int,float) and math.isfinite(boarding) and math.isfinite(boarded) and boarding>=previous and boarded-boarding>=40, 'normal boarding timer')
    times=[bakery.get('mixed_at'),bakery.get('cook_started'),bakery.get('produced_at'),bakery.get('time')]
    require(all(type(v) in (int,float) and math.isfinite(v) for v in times) and times==sorted(times) and bakery.get('cooking_time')==50 and times[2]-times[1]>=50, 'normal bake time')
    require(times[0]>=route['events'][-1]['time_ds'], 'bake follows flour handoff')
    require(before.get('phase')=='train_staged' and after.get('phase')=='train_complete', 'train phases')
    for key in ('engine','fireman','brakeman','health'):
        require(before.get(key) is not None and before[key]==after.get(key), 'train identity or health')
    require((before.get('x'),before.get('y'),before.get('z'),before.get('rail_count'))==(83,54,1,8), 'train start')
    require((after.get('x'),after.get('y'),after.get('z'),after.get('rail_count'))==(85,54,1,8) and no(after.get('on')) and no(after.get('automovement')), 'train stop')
    tt=[after.get('fueled_at'),after.get('started_at'),after.get('arrived_at'),after.get('stopped_at'),after.get('time')]
    require(type(after.get('coal')) is str and len(after['coal'])>0, 'coal identity')
    require(all(type(v) in (int,float) and math.isfinite(v) for v in tt) and tt==sorted(tt) and tt[0]>=times[-1] and tt[2]>tt[1] and tt[4]-tt[3]>=15, 'train action timing')
    return {'status':'SCRIPTED_NATIVE_PREFLIGHT_REVIEW_REQUIRED','capture_performed':False,'native_acceptance':False}
