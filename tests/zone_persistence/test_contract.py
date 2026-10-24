"""Offline wire-contract examples and production wiring. Never launches BYOND.

The independent model checks the intended format; it is not native DM evidence.
"""
from copy import deepcopy
import json
from pathlib import Path
import subprocess
import sys
import unittest
from itertools import groupby

ROOT = Path(__file__).resolve().parents[2]
CODE = (ROOT / 'code/modules/persistence/zone_topology.dm').read_text()
REGISTRIES = ('latejoin', 'start', 'join', 'paradrop', 'supply')


NAMESPACE = 'round-v2:' + '0' * 32


def capture_rows(grid, dims):
    plane = dims[0] * dims[1]
    return [dict(entry=i % plane + 1, index=i+1, zone=zone) for i, zone in enumerate(grid)]


def validate(packet, dims=(2, 2, 2)):
    """Independent oracle: membership models scalar records in level files."""
    if set(packet) != {'schema', 'zones', 'membership', 'spawns', 'allocator'} or packet['schema'] != 2:
        raise ValueError('envelope')
    allocator = packet['allocator']
    if set(allocator) != {'namespace','next'} or not namespace_valid(allocator['namespace']) or not counter_valid(allocator['next']):
        raise ValueError('allocator')
    ids = set()
    for zone in packet['zones']:
        if set(zone) != {'id', 'type', 'fields'} or not isinstance(zone['id'], str) or not zone['id'] or zone['id'] in ids:
            raise ValueError('zone')
        prefix = 'zone:' + allocator['namespace'] + ':'
        if zone['id'].startswith(prefix):
            issued = zone['id'][len(prefix):]
            if not counter_valid(issued) or int(issued) >= int(allocator['next']): raise ValueError('counter high-water')
        ids.add(zone['id'])
    cells = dims[0] * dims[1] * dims[2]
    if len(packet['membership']) != cells: raise ValueError('coverage')
    grid, entries = [], set()
    for position, record in enumerate(packet['membership'], start=1):
        if set(record) != {'entry','index','zone'} or type(record['index']) is not int or record['index'] != position or type(record['entry']) is not int or record['entry'] < 1 or record['zone'] not in ids:
            raise ValueError('captured membership')
        key = ((position-1)//(dims[0]*dims[1])+1, record['entry'])
        if key in entries: raise ValueError('duplicate captured entry')
        entries.add(key)
        grid.append(record['zone'])
    spawns = packet['spawns']
    if set(spawns) != {'latejoin', 'start', 'join', 'paradrop', 'supply'}:
        raise ValueError('registries')
    groups = list(spawns['latejoin'].values()) + [spawns[key] for key in ('start', 'join', 'paradrop', 'supply')]
    for group in groups:
        seen = set()
        for row in group:
            if set(row) != {'x', 'y', 'z', 'zone'}: raise ValueError('spawn')
            xyz = tuple(row[axis] for axis in ('x', 'y', 'z'))
            if any(type(n) is not int or n < 1 or n > bound for n, bound in zip(xyz, dims)): raise ValueError('coordinate')
            x,y,z = xyz
            if xyz in seen or grid[((z-1)*dims[1]+y-1)*dims[0]+x-1] != row['zone']: raise ValueError('spawn identity')
            seen.add(xyz)
    return grid


def namespace_valid(value):
    import re
    return isinstance(value,str) and re.fullmatch(r'round-v[12]:[0-9a-f]{32}',value) is not None


def counter_valid(value):
    import re
    return isinstance(value,str) and re.fullmatch(r'[1-9][0-9]{0,11}',value) is not None

def fixture():
    return {'schema': 2, 'allocator': {'namespace':NAMESPACE,'next':'1'}, 'zones': [{'id': k, 'type': '/area', 'fields': {}} for k in ('base', 'created')],
            'membership': capture_rows(['base']*7+['created'], (2,2,2)),
            'spawns': {'latejoin': {'moved': [{'x': 2, 'y': 2, 'z': 2, 'zone': 'created'}],
                                   'new': [{'x': 1, 'y': 1, 'z': 1, 'zone': 'base'}], 'deleted': []},
                       'start': [], 'join': [], 'paradrop': [], 'supply': []}}


def successive_generations():
    """Independent examples matching the prepared native writer's three saves."""
    def index(x, y, z):
        return ((z-1)*8+y-1)*8+x-1
    packets = {}
    for stage in ('baseline', 'changed', 'deleted'):
        grid = ['base'] * 128
        ids = ['base']
        if stage != 'deleted':
            ids.append('existing')
            grid[index(2, 3, 1 if stage == 'baseline' else 2)] = 'existing'
        if stage == 'changed':
            ids.append('created')
            grid[index(8, 8, 2)] = 'created'
        def destination(x, y, z):
            return dict(x=x, y=y, z=z, zone=grid[index(x, y, z)])
        spawns = {}
        for slot, key in enumerate(REGISTRIES, start=2):
            points = [] if stage == 'deleted' else [destination(slot, 3, 1 if stage == 'baseline' else 2)]
            if stage == 'changed':
                points.append(destination(slot, 6, 2))
            spawns[key] = {'target': points} if key == 'latejoin' else points
        if stage != 'deleted':
            spawns['latejoin']['remove-me'] = [destination(7, 7, 1)]
        if stage == 'changed':
            spawns['latejoin']['new-group'] = [destination(8, 8, 2)]
        packets[stage] = dict(schema=2, allocator={'namespace':NAMESPACE,'next':'1'},
                              zones=[dict(id=key, type='/area', fields={}) for key in ids],
                              membership=capture_rows(grid, (8,8,2)),
                              spawns=spawns)
    return packets


def registry_points(packet, key):
    return packet['spawns']['latejoin']['target'] if key == 'latejoin' else packet['spawns'][key]


def remove_referenced_zone(packet, spawn):
    """Remove exactly the identity used by an unchanged spawn and membership."""
    zone = spawn['zone']
    matches = [row for row in packet['zones'] if row['id'] == zone]
    cells = sum(row['zone'] == zone for row in packet['membership'])
    if len(matches) != 1 or not cells:
        raise ValueError('control has no unique referenced zone')
    packet['zones'].remove(matches[0])
    return zone, cells


class Contract(unittest.TestCase):
    def test_all_five_registries_create_move_delete_across_three_generations(self):
        generations = successive_generations()
        for packet in generations.values():
            validate(packet, (8, 8, 2))
        for slot, key in enumerate(REGISTRIES, start=2):
            with self.subTest(registry=key):
                initial = registry_points(generations['baseline'], key)
                changed = registry_points(generations['changed'], key)
                deleted = registry_points(generations['deleted'], key)
                self.assertEqual([(p['x'],p['y'],p['z']) for p in initial], [(slot,3,1)])
                self.assertEqual([(p['x'],p['y'],p['z']) for p in changed], [(slot,3,2),(slot,6,2)])
                self.assertEqual(deleted, [])

    def test_previously_saved_zone_moves_then_is_deleted(self):
        stages = successive_generations()
        grids = {name: validate(packet, (8,8,2)) for name, packet in stages.items()}
        old, new = 17, 81
        self.assertEqual((grids['baseline'][old], grids['baseline'][new]), ('existing', 'base'))
        self.assertEqual((grids['changed'][old], grids['changed'][new]), ('base', 'existing'))
        self.assertEqual(grids['changed'][127], 'created')
        self.assertEqual(set(grids['deleted']), {'base'})
        self.assertNotIn('existing', [row['id'] for row in stages['deleted']['zones']])
        self.assertNotIn('created', [row['id'] for row in stages['deleted']['zones']])

    def test_successive_and_repeated_loads_replace_all_five_inventories(self):
        runtime = {key: ['startup-default'] for key in REGISTRIES}
        for stage, packet in successive_generations().items():
            for repeat in range(2):
                with self.subTest(stage=stage, repeat=repeat):
                    validate(packet, (8,8,2))
                    runtime = deepcopy(packet['spawns'])
                    for key in REGISTRIES:
                        points = runtime['latejoin']['target'] if key == 'latejoin' else runtime[key]
                        self.assertEqual(len(points), {'baseline':1, 'changed':2, 'deleted':0}[stage])
                    if stage == 'deleted':
                        self.assertIn('target', runtime['latejoin'])
                        self.assertNotIn('remove-me', runtime['latejoin'])
                        self.assertNotIn('new-group', runtime['latejoin'])

    def test_absent_zone_negative_retains_proven_spawn_and_membership_references(self):
        for key in REGISTRIES:
            p = successive_generations()['changed']
            validate(p, (8,8,2))
            spawn = registry_points(p, key)[0]
            before_spawn, before_rows = deepcopy(spawn), deepcopy(p['membership'])
            zone, cells = remove_referenced_zone(p, spawn)
            with self.subTest(registry=key):
                self.assertGreater(cells, 0)
                self.assertEqual(spawn, before_spawn)
                self.assertEqual(p['membership'], before_rows)
                self.assertNotIn(zone, [row['id'] for row in p['zones']])
                with self.assertRaises(ValueError): validate(p, (8,8,2))

    def test_missing_registry_is_malformed_but_empty_registry_is_valid(self):
        for key in REGISTRIES:
            p = successive_generations()['deleted']
            validate(p, (8,8,2))
            del p['spawns'][key]
            with self.subTest(registry=key), self.assertRaises(ValueError): validate(p, (8,8,2))

    def test_create_move_delete_and_same_type_instances(self):
        p = fixture()
        self.assertEqual(validate(p)[-1], 'created')
        self.assertEqual(p['spawns']['latejoin']['deleted'], [])
        self.assertEqual(p['zones'][0]['type'], p['zones'][1]['type'])

    def test_coordinate_order_covers_multiple_levels_and_edges(self):
        for z in (1, 2):
            for y in (1, 2):
                for x in (1, 2):
                    p = fixture()
                    p['spawns']['start'] = [{'x': x, 'y': y, 'z': z, 'zone': 'created' if (x,y,z)==(2,2,2) else 'base'}]
                    validate(p)

    def test_malformed_inputs_preserve_the_callers_packet(self):
        for axis, value in [('x', 0), ('y', 3), ('z', 3), ('x', 1.5), ('z', '2'), ('x', None), ('x', True)]:
            p = fixture()
            p['spawns']['latejoin']['moved'][0][axis] = value
            before = deepcopy(p)
            with self.subTest(axis=axis, value=value), self.assertRaises(ValueError):
                validate(p)
            self.assertEqual(p, before)

    def test_duplicate_and_stale_spawns_reject(self):
        for mode in ('duplicate', 'stale', 'wrong-zone'):
            p = fixture()
            moved = p['spawns']['latejoin']['moved']
            if mode == 'duplicate': moved.append(deepcopy(moved[0]))
            else: moved[0]['zone'] = 'absent' if mode == 'stale' else 'base'
            with self.subTest(mode=mode), self.assertRaises(ValueError): validate(p)

    def test_zone_inventory_and_run_rejection(self):
        for mode in ('duplicate', 'absent', 'short', 'overlong', 'fractional', 'negative', 'zero'):
            p = fixture()
            if mode == 'duplicate': p['zones'].append(deepcopy(p['zones'][0]))
            elif mode == 'absent': p['zones'].pop()
            elif mode == 'short': p['membership'].pop()
            else: p['membership'][0]['index'] = {'overlong': 9, 'fractional': 1.5, 'negative': -1, 'zero': 0}[mode]
            with self.subTest(mode=mode), self.assertRaises(ValueError): validate(p)

    def test_absent_and_empty_spawn_groups_remain_absent_and_empty(self):
        p = fixture()
        p['spawns']['latejoin'].pop('deleted')
        validate(p)
        self.assertNotIn('deleted', p['spawns']['latejoin'])
        p['spawns']['latejoin'] = {}
        validate(p)
        self.assertEqual(p['spawns']['latejoin'], {})

    def test_repeated_load_replaces_defaults(self):
        packet = fixture()
        runtime = {'old-default': [1]}
        for _ in range(3):
            validate(packet)
            runtime = deepcopy(packet['spawns']['latejoin'])
            self.assertNotIn('old-default', runtime)
            self.assertEqual(len(runtime['moved']), 1)

    def test_production_rejects_before_clear_map_and_uses_projection(self):
        loading = (ROOT/'code/modules/persistence/loading.dm').read_text()
        functions = (ROOT/'code/modules/persistence/functions.dm').read_text()
        self.assertLess(loading.index('prepare_saved_zones(round_state'), loading.index('prepare_saved_roof_areas(round_state'))
        body = functions.split('/datum/controller/gameticker/proc/loadmap(', 1)[1]
        self.assertLess(body.index('validate_world_save()'), body.index('ClearMap()'))
        self.assertLess(body.index('restore_round_state(src'), body.index('restore_zone_spawns()'))
        self.assertLess(body.index('restore_zone_spawns()'), body.index('finish_player_restoration()'))
        area = functions.split('/map_storage/proc/save_validation_area_type(', 1)[1].split('/map_storage/proc/save_validation_area_key(', 1)[0]
        self.assertIn('validated_zones[saved_zone_id(x, y, z)]', area)

    def test_production_commits_spawn_indexes_only_after_full_resolution(self):
        body = CODE.split('/map_storage/proc/restore_zone_spawns()', 1)[1]
        self.assertLess(body.index('verify_zone_topology()'), body.index('latejoin_turfs = named'))
        self.assertLess(body.index('resolve_zone_spawns(spawns["supply"])'), body.index('area_list = index'))
        self.assertNotIn('+=', body.split('latejoin_turfs = named', 1)[1].split('clear_saved_zones()', 1)[0])
        self.assertIn('clear_saved_zones()', body)

    def test_production_preserves_legacy_and_cleans_failures(self):
        self.assertIn('world_state["schema"] == 1) return', CODE)
        loading = (ROOT/'code/modules/persistence/loading.dm').read_text()
        catch = loading.split('/map_storage/proc/validate_world_save()',1)[1].split('catch(var/exception/e)',1)[1]
        self.assertIn('clear_saved_zones()', catch)
        durable = (ROOT/'code/modules/persistence/durable_world.dm').read_text()
        self.assertIn('state["schema"] in list(1, 2)', durable)

    def test_production_detects_snapshot_drift_before_completion_marker(self):
        saving = (ROOT/'code/modules/persistence/saving.dm').read_text()
        self.assertLess(saving.index('validate_captured_world_save(round_state)'), saving.index('text2file(generation,"map_saves/save_complete.txt")'))
        self.assertNotIn('capture_zone_topology(FALSE)', saving)
        self.assertLess(saving.index('capture_zone_turf(savefile, frame)'), saving.index('for(var/obj/content in parent.contents)'))
        self.assertIn('Duplicate spawn destination', CODE)
        self.assertIn('Stale spawn destination', CODE)
        self.assertIn('validate_current_zone_identities()', CODE)

    def test_landmark_and_job_paths_cannot_recreate_deleted_spawn(self):
        normal = (ROOT/'code/game/objects/effects/landmarks/normal.dm').read_text()
        self.assertLess(normal.index('map_storage.validated_zone_state'), normal.index('latejoin_turfs[name] += loc'))
        jobs = (ROOT/'code/game/jobs/job_controller.dm').read_text()
        body = jobs.split('if(persistence_spawns_authoritative)',1)[1].split('spawnpoint = locate(48,50,1)',1)[0]
        self.assertIn('return FALSE', body)
        lobby = (ROOT/'code/game/mob/new_player/new_player.dm').read_text().split('/mob/new_player/proc/AttemptLateSpawn(',1)[1]
        self.assertLess(lobby.index('saved_spawn_missing'), lobby.index('create_character('))

    def test_native_modes_are_present_but_local_execution_is_refused(self):
        probe = (ROOT/'tests/zone_persistence/probe.dm').read_text()
        for mode in ('duplicate-spawn','stale-zone','wrong-z','fractional','duplicate-zone','absent-zone','incomplete','overlong','legacy-read','legacy-write','write-sequence','read-sequence'):
            self.assertIn('"'+mode+'"', probe)
        runner = ROOT/'tests/world_save/run-durable-world.py'
        r = subprocess.run([sys.executable, str(runner), '--zone-topology'], cwd=ROOT, text=True, capture_output=True, timeout=30)
        self.assertEqual(r.returncode, 2)
        self.assertIn('zone native execution remains held', r.stderr)
        self.assertNotIn('Retained evidence', r.stdout)

    def test_native_writer_covers_every_registry_and_archives_real_successive_saves(self):
        probe = (ROOT/'tests/zone_persistence/probe.dm').read_text()
        registry_body = probe.split('/proc/zone_fixture_registry_lists()',1)[1].split('/proc/',1)[0]
        for symbol in ('latejoin_turfs["target"]', 'newplayer_start', 'latejoin', 'paradrop_landmarks', 'supplydrop_turfs'):
            self.assertIn(symbol, registry_body)
        sequence = probe.split('/proc/zone_fixture_sequence(',1)[1].split('/proc/zone_fixture_remove_referenced_zone(',1)[0]
        for stage in ('baseline','changed','deleted'):
            self.assertIn('zone_fixture_archive("'+stage+'", manifest)', sequence)
        self.assertLess(sequence.index('zone_fixture_archive("baseline"'), sequence.index('base.contents += locate(2,3,1)'))
        self.assertLess(sequence.index('zone_fixture_archive("changed"'), sequence.index('qdel(existing)'))
        self.assertLess(sequence.index('qdel(existing)'), sequence.index('zone_fixture_archive("deleted"'))
        self.assertIn('points[1] = locate(i+1,3,2)', sequence)
        self.assertIn('points += locate(i+1,6,2)', sequence)
        self.assertIn('for(var/list/points in zone_fixture_registry_lists()) points.Cut()', sequence)
        control = probe.split('/proc/zone_fixture_remove_referenced_zone(',1)[1].split('/world\n',1)[0]
        self.assertIn('var/id = spawn["zone"]', control)
        self.assertIn('membership_cells > 0', control)
        self.assertIn('removed == 1 && spawn["zone"] == id', control)
        self.assertNotIn('if("absent-zone") zones.Cut(1, 2)', probe)


if __name__ == '__main__':
    unittest.main()
