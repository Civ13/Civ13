"""Interpret bounded native state witnesses, never certify rendered motion."""
import json, math

def validate_probe(raw):
    def need(ok, why):
        if not ok: raise ValueError(why)
    need(len(raw) < 65536, 'probe witness cap')
    rows=[]
    for line in raw.splitlines():
        if line.startswith('{'):
            row=json.loads(line)
            if row.get('probe')=='fractional_glide_v1': rows.append(row)
    need([(r['step'],r['phase']) for r in rows]==[(1,'before_step'),(1,'after_step'),(2,'before_step'),(2,'after_step'),(2,'settled_before_restore'),(2,'restored')], 'probe phase sequence')
    identity=[m['ref'] for m in rows[0]['members']]
    need(len(identity)==4 and len(set(identity))==4, 'four original entities')
    for row in rows:
        need(row['world_fps']==20 and row['world_tick_lag']==.5 and row['client_fps']==20, 'unchanged native cadence')
        need(row['vehicle_delay_ds']==20 and row['scheduled_interval_ds']==21, 'unchanged normal gear')
        need(row['movement_mode']==rows[0]['movement_mode'], 'unchanged movement mode')
        need([m['ref'] for m in row['members']]==identity, 'probe identity continuity')
        need(row['members'][0]['bound_width']==64 and row['members'][0]['bound_height']==96, 'unchanged carriage bounds')
        for before,member in zip(rows[0]['members'],row['members']):
            for key in ('type','dir','animate_movement','appearance_flags','bound_width','bound_height','step_size','step_x','step_y'):
                need(member[key]==before[key], 'changed non-glide shape or appearance')
    stock=[m['glide_size'] for m in rows[0]['members']]
    need(stock==[0]*4 and [m['glide_size'] for m in rows[1]['members']]==stock, 'stock automatic glide control')
    expected=32*.5/21
    for row in rows[2:5]:
        need(all(math.isclose(m['glide_size'],expected,rel_tol=1e-5) for m in row['members']), 'fractional glide assigned to every member')
    need([m['glide_size'] for m in rows[5]['members']]==stock, 'original glide restored')
    delta=rows[2]['world_time_ds']-rows[0]['world_time_ds']
    need(21<=delta<=21.5, 'actual step spacing differs from proposed interval')
    for row,y in zip(rows,[9,8,8,7,7,7]):
        need(all((m['x'],m['y'],m['z'])==(8,y,1) for m in row['members']), 'original two-step route')
    need(rows[4]['world_time_ds']-rows[3]['world_time_ds']>=21, 'settle precedes fractional glide completion')
    return {'status':'NATIVE_STATE_WITNESSES_ONLY','stock_glide':stock,'candidate_glide':expected,'actual_step_interval_ds':delta,'rendered_smoothness_proven':False,'production_fix_proven':False}
