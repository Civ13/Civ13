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
    for ingredient in ('water', 'flour'):
        start, finish = before[ingredient+'_before'], after[ingredient+'_after']
        require(type(start) in (int, float) and type(finish) in (int, float)
                and math.isfinite(start) and math.isfinite(finish)
                and start >= 5 and start - finish == 5, 'paid: '+ingredient)
    dough, bread = after['dough_input'], after['produced_ref']
    require(type(dough) is str and 0 < len(dough) < 64, 'dough identity')
    require(type(bread) is str and 0 < len(bread) < 64 and bread != dough
            and bread == after['placed_ref'] == after['received_ref'], 'same baked output')
    require(after['product'] == 'flatbread' and after['customer_holds_output'] == 1
            and after['fuel_paid'] == 1, 'product/fuel/handoff')
    times = [before['time'], after['mixed_at'], after['cook_started'], after['produced_at'],
             after['placed_at'], after['received_at'], after['time'], end_tick]
    require(all(type(t) in (int, float) and math.isfinite(t) and t >= 0 for t in times)
            and times == sorted(times), 'event order')
    require(after['mixed_at'] - before['time'] >= 10, 'starting beat')
    require(after['cook_started'] - after['mixed_at'] >= 10, 'dough beat')
    require(after['cooking_time'] == 50 and after['produced_at'] - after['cook_started'] >= 50, 'oven timer')
    require(after['placed_at'] - after['produced_at'] >= 5, 'output beat')
    require(after['received_at'] - after['placed_at'] >= 10, 'table beat')
    require(after['time'] - before['time'] <= 110, 'finish before end of 12-second proposal')
