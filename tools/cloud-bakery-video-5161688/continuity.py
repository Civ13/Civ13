"""Offline witness validator candidate; not yet wired to a recording controller."""
import math


def require(value, label):
    if not value:
        raise ValueError(label)


def validate(before, after, end_tick):
    require(before['phase'] == 'before' and after['phase'] == 'after', 'phase')
    for key in ('flour', 'bucket', 'baker', 'customer', 'oven', 'counter'):
        value = before[key]
        require(type(value) is str and 0 < len(value) < 64 and value == after[key], 'identity: '+key)
    require(before['counter_clear'] == 1, 'empty counter before take')
    for ingredient in ('water', 'flour'):
        start, finish = before[ingredient+'_before'], after[ingredient+'_after']
        require(type(start) in (int, float) and type(finish) in (int, float)
                and math.isfinite(start) and math.isfinite(finish)
                and start >= 5 and start - finish == 5, 'paid: '+ingredient)
    dough, bread = after['dough_input'], after['produced_ref']
    require(type(dough) is str and 0 < len(dough) < 64, 'dough identity')
    require(type(bread) is str and 0 < len(bread) < 64 and bread != dough
            and bread == after['picked_ref'] == after['placed_ref'] == after['received_ref'], 'same baked output')
    require(after['product'] == 'flatbread' and after['customer_holds_output'] == 1
            and after['fuel_paid'] == 1, 'product/fuel/handoff')
    times = [before['time'], after['mixed_at'], after['cook_started'], after['produced_at'], after['picked_at'],
             after['placed_at'], after['received_at'], after['time'], end_tick]
    require(all(type(t) in (int, float) and math.isfinite(t) and t >= 0 for t in times)
            and times == sorted(times), 'event order')
    require(after['mixed_at'] - before['time'] >= 10, 'starting beat')
    require(after['cook_started'] - after['mixed_at'] >= 10, 'dough beat')
    require(after['cooking_time'] == 50 and after['produced_at'] - after['cook_started'] >= 50, 'oven timer')
    require(after['picked_at'] - after['produced_at'] >= 5, 'output beat')
    require(after['placed_at'] - after['picked_at'] >= 10, 'held bread beat')
    require(after['received_at'] - after['placed_at'] >= 10, 'table beat')
    require(type(after['departure']) is dict, 'departure witness')
    dep=after['departure']
    for key in ('carriage','horse','door'):
        value=before[key]
        require(type(value) is str and 0<len(value)<64 and dep[key]==value, 'departure identity: '+key)
    require(dep['customer']==before['customer'] and dep['bread']==bread, 'same customer and produced bread')
    require(before['counter_clear']==1 and before['door_open']==1 and before['horse_bound']==1, 'staged ready state')
    require((before['carriage_x'],before['carriage_y'],before['carriage_dir'])==(8,3,8), 'carriage starting position')
    require((dep['x'],dep['y'],dep['z'],dep['dir'])==(6,3,1,8), 'carriage destination')
    require(dep['driver_bound']==1 and dep['horse_bound']==1 and dep['bread_in_inactive_hand']==1
            and dep['reins_in_active_hand']==1 and dep['moving']==0 and dep['speed']==0, 'settled custody and reins')
    route=dep['route']
    expected=[(8,9),(8,8),(8,7),(7,7),(7,6),(7,5),(7,4),(7,3)]
    require(type(route) is list and len(route)==len(expected), 'walking route length')
    previous=None
    for row,xy in zip(route,expected):
        require(type(row) is dict and set(row)=={'x','y','time','bread'} and (row['x'],row['y'])==xy and row['bread']==bread, 'walking route and bread')
        require(type(row['time']) in (int,float) and math.isfinite(row['time']) and row['time']>=after['received_at'], 'walking timestamp')
        require(previous is None or row['time']-previous>=4, 'walking pace')
        previous=row['time']
    sequence=[after['received_at'],dep['walk_started'],route[0]['time'],route[-1]['time'],dep['boarding_started'],
              dep['boarded_at'],dep['driving_started'],dep['arrived_at'],dep['stopped_at'],dep['ended_at'],after['time'],end_tick]
    require(all(type(t) in (int,float) and math.isfinite(t) and t>=0 for t in sequence) and sequence==sorted(sequence), 'departure event order')
    require(route[0]['time']-dep['walk_started']>=5, 'handoff beat')
    require(dep['boarding_started']-route[-1]['time']>=4, 'last walking beat')
    require(dep['boarded_at']-dep['boarding_started']>=40, 'normal boarding wait')
    require(dep['driving_started']-dep['boarded_at']>=10 and dep['arrived_at']>dep['driving_started'], 'boarding and driving beat')
    require(dep['ended_at']-dep['stopped_at']>=15 and dep['ended_at']==after['time'], 'stopped beat')
    require(after['time'] - before['time'] <= 240, 'finish before end of 25-second take')
