"""Pinned BYOND production account journal checks in isolated temporary storage."""
import argparse
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import re
import uuid


def intended_assertion_only(log, expected):
    """Accept one injected assertion, while rejecting unrelated engine errors."""
    pattern = r'Runtime error: ' + re.escape(expected) + r'\s+at tests[/\\]extraction[/\\]equipment_probe\.dm:\d+'
    matches = list(re.finditer(pattern, log))
    if len(matches) != 1:
        return False
    remainder = re.sub(pattern, '', log, count=1).lower()
    return not any(marker in remainder for marker in ('runtime error', 'bad ref', '## error'))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--compile-only', action='store_true', help='Compile the isolated fixture without launching DreamDaemon')
    parser.add_argument('--surface-negative-control', choices=('epoch', 'claim', 'duplicate', 'movement', 'discovery', 'forfeit', 'inventory', 'retirement', 'identity', 'escrow', 'mail_binding', 'auxiliary_pending', 'home_owner', 'home_graph', 'home_placement', 'home_revision', 'world_stale', 'fresh_incomplete', 'home_admission', 'marker_save'))
    parser.add_argument('--probe', choices=('store', 'restart', 'settlement', 'equipment', 'mode', 'npc', 'city', 'insurance', 'groups', 'vehicles'), default='store')
    parser.add_argument('--provenance-negative-control', action='store_true')
    parser.add_argument('--vote-negative-control', choices=('stale', 'cancel', 'reentry', 'disruptive_creation', 'disruptive_pending', 'disruptive_result'))
    parser.add_argument('--group-negative-control', choices=('debit', 'visibility', 'premium', 'car', 'return', 'fee'))
    parser.add_argument('--vehicle-loss-negative-control', action='store_true')
    parser.add_argument('--vehicle-purchase-negative-control', action='store_true')
    parser.add_argument('--vehicle-raid-negative-control', choices=('debit', 'credit'))
    parser.add_argument('--supply-negative-control', action='store_true')
    parser.add_argument('--city-presence-negative-control', action='store_true')
    parser.add_argument('--city-pursuit-negative-control', action='store_true')
    parser.add_argument('--economic-payment-negative-control', action='store_true')
    parser.add_argument('--room-payment-negative-control', action='store_true')
    parser.add_argument('--corpse-release-negative-control', action='store_true')
    parser.add_argument('--npc-insurance-negative-control', action='store_true')
    parser.add_argument('--workshop-negative-control', choices=('wear', 'cleanup'))
    parser.add_argument('--insurance-fixture-output', type=Path)
    args = parser.parse_args()
    if args.city_pursuit_negative_control and (args.probe != 'city' or any(value for key, value in vars(args).items() if key.endswith('negative_control') and key != 'city_pursuit_negative_control')):
        parser.error('City pursuit control requires the city probe without another control')
    if args.surface_negative_control and (args.probe != 'mode' or any(value for key, value in vars(args).items() if key.endswith('negative_control') and key != 'surface_negative_control')):
        parser.error('Surface control requires the mode probe without another control')
    if args.workshop_negative_control and (args.probe != 'equipment' or any(value for key, value in vars(args).items() if key.endswith('negative_control') and key != 'workshop_negative_control')):
        parser.error('Workshop control requires equipment without another mutation')
    if args.npc_insurance_negative_control and args.probe != 'npc':
        parser.error('NPC insurance control requires the focused npc probe')
    if args.insurance_fixture_output and (args.probe != 'equipment' or args.insurance_fixture_output.exists()):
        parser.error('Insurance fixture export requires equipment and a new output directory')
    if args.insurance_fixture_output and any(value for key, value in vars(args).items() if key.endswith('negative_control')):
        parser.error('Insurance fixture export requires unmodified production sources')
    if args.corpse_release_negative_control and (args.probe != 'mode' or any(value for key, value in vars(args).items() if key.endswith('negative_control') and key != 'corpse_release_negative_control')):
        parser.error('Corpse release control requires the mode probe without another mutation')
    if args.room_payment_negative_control and (args.probe != 'equipment' or args.economic_payment_negative_control):
        parser.error('Room payment control requires the equipment probe without the economic payment control')
    if args.economic_payment_negative_control and args.probe != 'equipment':
        parser.error('Economic payment control requires the equipment probe')
    if args.city_presence_negative_control and (args.probe != 'city' or args.provenance_negative_control or args.vote_negative_control or args.group_negative_control or args.vehicle_loss_negative_control or args.vehicle_purchase_negative_control or args.vehicle_raid_negative_control or args.supply_negative_control):
        parser.error('City presence control requires the city probe without another control')
    if args.supply_negative_control and (args.probe != 'mode' or args.provenance_negative_control or args.vote_negative_control or args.group_negative_control or args.vehicle_loss_negative_control or args.vehicle_purchase_negative_control or args.vehicle_raid_negative_control):
        parser.error('Supply control requires the mode probe without another control')
    if args.vehicle_raid_negative_control and (args.probe != 'mode' or args.provenance_negative_control or args.vote_negative_control or args.group_negative_control or args.vehicle_loss_negative_control or args.vehicle_purchase_negative_control):
        parser.error('Vehicle raid control requires the mode probe without another control')
    if args.vehicle_purchase_negative_control and (args.probe != 'mode' or args.provenance_negative_control or args.vote_negative_control or args.group_negative_control or args.vehicle_loss_negative_control):
        parser.error('Vehicle purchase control requires the mode probe without another control')
    if args.vehicle_loss_negative_control and (args.probe != 'vehicles' or args.provenance_negative_control or args.vote_negative_control or args.group_negative_control):
        parser.error('Vehicle loss control requires the vehicles probe without another control')
    if args.provenance_negative_control and args.probe not in ('equipment', 'mode'):
        parser.error('Provenance control requires the equipment or mode probe')
    if args.vote_negative_control and (args.probe != 'mode' or args.provenance_negative_control):
        parser.error('Vote control requires the mode probe without another control')
    if args.group_negative_control and (args.probe != 'groups' or args.provenance_negative_control or args.vote_negative_control):
        parser.error('Group control requires the groups probe without another control')
    root = Path(__file__).resolve().parents[2]
    binary = args.byond_bin.resolve()
    compiler = binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    if args.probe in ('equipment', 'mode', 'npc', 'city', 'insurance', 'groups', 'vehicles'):
        return equipment(root, compiler, daemon, flags, args.probe, args.provenance_negative_control, args.vote_negative_control, args.group_negative_control, args.vehicle_loss_negative_control, args.vehicle_purchase_negative_control, args.vehicle_raid_negative_control, args.supply_negative_control, args.city_presence_negative_control, args.economic_payment_negative_control, args.room_payment_negative_control, args.corpse_release_negative_control, args.insurance_fixture_output, args.npc_insurance_negative_control, args.workshop_negative_control, args.compile_only, args.surface_negative_control, args.city_pursuit_negative_control)
    with tempfile.TemporaryDirectory(prefix='civ13-extraction-') as temp:
        target = Path(temp)
        (target / 'tests/extraction').mkdir(parents=True)
        (target / 'code/modules/1713/extraction').mkdir(parents=True)
        probe_name = 'restart_probe.dm' if args.probe == 'restart' else ('settlement_probe.dm' if args.probe == 'settlement' else 'store_probe.dm')
        shutil.copy2(root / 'tests/extraction' / probe_name, target / 'tests/extraction' / probe_name)
        shutil.copy2(root / 'code/modules/1713/extraction/account_store.dm', target / 'code/modules/1713/extraction/account_store.dm')
        shutil.copy2(root / 'code/modules/1713/extraction/transactions.dm', target / 'code/modules/1713/extraction/transactions.dm')
        shutil.copy2(root / 'code/modules/1713/extraction/settlement.dm', target / 'code/modules/1713/extraction/settlement.dm')
        shutil.copy2(root / 'tests/extraction/journal_adapters.dm', target / 'tests/extraction/journal_adapters.dm')
        shared_sources = ('ipc_crypto', 'ipc_wire', 'ipc_request', 'insurance_mail')
        for name in shared_sources:
            shutil.copy2(root / f'code/modules/1713/extraction/{name}.dm',
                         target / f'code/modules/1713/extraction/{name}.dm')
        includes = [f'#include "tests/extraction/{probe_name}"',
                    '#include "tests/extraction/journal_adapters.dm"']
        includes.extend(f'#include "code/modules/1713/extraction/{name}.dm"' for name in shared_sources)
        (target / 'probe.dme').write_text('\n'.join(includes) + '\n', encoding='utf-8')
        built = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=target,
                               capture_output=True, text=True, timeout=60, creationflags=flags)
        print(built.stdout + built.stderr)
        if built.returncode or '516.1681' not in built.stdout or '0 errors, 0 warnings' not in built.stdout:
            raise RuntimeError('Pinned compile failed')
        if args.compile_only:
            print('COMPILE ONLY: native assertions and negative controls were not executed')
            return
        platform = ['-invisible', '-close'] if os.name == 'nt' else []
        phases = ('write', 'reload', 'recover') if args.probe == 'restart' else (('write', 'reload', 'replay') if args.probe == 'settlement' else ('store',))
        for phase in phases:
            (target / 'result.txt').unlink(missing_ok=True)
            try:
                ran = subprocess.run([str(daemon), 'probe.dmb', *platform, '-safe', '-params', f'phase={phase}', '-log', 'runtime.log'],
                                     cwd=target, capture_output=True, text=True, timeout=45, creationflags=flags)
            except subprocess.TimeoutExpired:
                log_path = target / 'runtime.log'
                if log_path.exists():
                    print(log_path.read_text(errors='replace'))
                raise
            result = (target / 'result.txt').read_text().strip() if (target / 'result.txt').exists() else 'MISSING'
            log = (target / 'runtime.log').read_text(errors='replace') if (target / 'runtime.log').exists() else ''
            print(result)
            if ran.returncode or not result.startswith('PASS:') or any(x in log.lower() for x in ('runtime error', 'bad ref', '## error')):
                print(log)
                raise RuntimeError('Account journal verification failed')


def equipment(root, compiler, daemon, flags, probe, provenance_control=False, vote_control=None, group_control=None, vehicle_loss_control=False, vehicle_purchase_control=False, vehicle_raid_control=None, supply_control=False, city_presence_control=False, economic_payment_control=False, room_payment_control=False, corpse_release_control=False, insurance_fixture_output=None, npc_insurance_control=False, workshop_control=None, compile_only=False, surface_control=None, city_pursuit_control=False):
    prefix = '.extraction_' + uuid.uuid4().hex
    generated = [root / (prefix + suffix) for suffix in ('.dme', '_world.dm', '_globals.dm', '.dmb', '.rsc')]
    try:
        source = (root / 'civ13.dme').read_text(encoding='utf-8')
        if surface_control:
            surface_file = ('mode.dm' if surface_control == 'home_admission' else
                            'home_replica.dm' if surface_control.startswith('home_') or surface_control == 'marker_save' else
                            'surface_inventory.dm' if surface_control in ('mail_binding', 'auxiliary_pending') else 'surface_loot.dm')
            surface_path = 'code/modules/1713/extraction/' + surface_file
            surface = (root / surface_path).read_text(encoding='utf-8')
            marker, replacement = {
                'epoch': ('\t\tepoch_profile = store.load_profile("epoch")', '\t\tepoch_profile = store.load_profile("epoch")\n\t\tif (epoch_profile && epoch_profile["revision"]) epoch_profile["raid_sequence"]++'),
                'claim': ('\t\tP["surface_state"] = "claiming"', '\t\tP["surface_state"] = "issued"'),
                'duplicate': ('\t\tif (other)\n', '\t\tif (FALSE)\n'),
                'movement': ('else if (!V || !V.movement_allowed(src, destination)) return FALSE', 'else if (FALSE) return FALSE'),
                'inventory': ('world_inventory_levels.len != world_inventory_expected', 'FALSE'),
                'retirement': ('E["surface_retired_ids"] = retired', 'E["surface_retired_ids"] = list()'),
                'identity': ('var/list/graph = metadata.codec.encode(I, FALSE)\n\t\t\tvar/list/ids = graph_ids(graph, 2048)', 'var/list/graph = metadata.codec.encode(I)\n\t\t\tvar/list/ids = graph_ids(graph, 2048)'),
                'escrow': ('extraction_sha256(json_encode(entry["equipment"])) != digests[item_id]', 'FALSE'),
                'mail_binding': ('json_encode(mail_expected_nodes[id]) != json_encode(mail_active_nodes[id])', 'isnull(id)'),
                'auxiliary_pending': ('P["phase"] != "committed"', 'FALSE'),
                'home_owner': ('H.replica_owner != record["owner"]', 'FALSE'),
                'home_graph': ('extraction_sha256(json_encode(graph)) != R["digest"]', 'FALSE'),
                'home_placement': ('json_encode(replica_placement(I, H)) != json_encode(R["placement"])', 'FALSE'),
                'home_revision': ('H.replica_revision != B["revision"]', 'FALSE'),
                'world_stale': ('world_inventory_stamp == world.time', 'TRUE'),
                'fresh_incomplete': ('!current_world_complete || ', ''),
                'home_admission': ('marker.admission_available()', '!marker.session'),
                'marker_save': ('\t\t. |= list("room", "replica_owner", "replica_revision", "replica_digest")', '\t\t// Negative control: omit durable marker fields'),
                'discovery': ('if (discovered_ids[id] || (account_ids[id] && !approved_replica))', 'if (account_ids[id] && !approved_replica)'),
                'forfeit': ('\t\t\tqdel(I)\n\t\t\tif (I && I.loc)', '\t\t\t// Negative control: omit root retirement\n\t\t\tif (I && I.loc)'),
            }[surface_control]
            if surface.count(marker) != 1:
                raise RuntimeError('Surface mutation marker changed')
            control = root / (prefix + '_surface.dm')
            generated.append(control)
            control.write_text(surface.replace(marker, replacement), encoding='utf-8')
            source = source.replace(surface_path.replace('/', '\\'), control.name)
        if workshop_control:
            workshop = (root / 'code/modules/1713/extraction/private_car_workshop.dm').read_text(encoding='utf-8')
            marker, replacement = {
                'wear': ('\t\t\tW.update_icon()', '\t\t\tW.wconfig.current_health = W.wconfig.max_health\n\t\t\tW.update_icon()'),
                'cleanup': ('\t\tpaid_wheels = null', '\t\t// Negative control: retain paid wheel references'),
            }[workshop_control]
            if workshop.count(marker) != 1:
                raise RuntimeError('Workshop mutation marker changed')
            control = root / (prefix + '_workshop.dm')
            generated.append(control)
            control.write_text(workshop.replace(marker, replacement), encoding='utf-8')
            source = source.replace('code\\modules\\1713\\extraction\\private_car_workshop.dm', control.name)
        if npc_insurance_control:
            control = root / (prefix + '_insurance.dm')
            generated.append(control)
            production = (root / 'code/modules/1713/extraction/insurance.dm').read_text(encoding='utf-8')
            marker = '\t\t\trecovered[token] = TRUE\n\t\tvar/list/unrecovered_ids'
            if production.count(marker) != 1:
                raise RuntimeError('NPC suppression mutation marker changed')
            control.write_text(production.replace(marker, '\t\t\t// Negative control: omit NPC suppression\n\t\tvar/list/unrecovered_ids'), encoding='utf-8')
            source = source.replace('code\\modules\\1713\\extraction\\insurance.dm', control.name)
        if corpse_release_control:
            corpse_source = (root / 'code/processes/human_corpse_decay.dm').read_text(encoding='utf-8')
            marker = '\t\tdrop_from_inventory(I, site)'
            if corpse_source.count(marker) != 1:
                raise RuntimeError('Corpse release mutation marker changed')
            control = root / (prefix + '_corpse_decay.dm')
            generated.append(control)
            control.write_text(corpse_source.replace(marker, '\t\t// Negative control: retain worn root on body'), encoding='utf-8')
            source = source.replace('code\\processes\\human_corpse_decay.dm', control.name)
        expected_vote_failure = None
        expected_group_failure = None
        if room_payment_control:
            if probe != 'equipment' or economic_payment_control:
                raise RuntimeError('Room payment control requires the equipment probe without another economic mutation')
            transaction_source = (root / 'code/modules/1713/extraction/transactions.dm').read_text(encoding='utf-8')
            marker = 'candidate["stash"] = remaining\n\tcandidate["level"]++'
            if transaction_source.count(marker) != 1:
                raise RuntimeError('Room upgrade payment mutation marker changed')
            control = root / (prefix + '_transactions.dm')
            generated.append(control)
            control.write_text(transaction_source.replace(marker, 'candidate["level"]++'), encoding='utf-8')
            source = source.replace('code\\modules\\1713\\extraction\\transactions.dm', control.name)
        if economic_payment_control:
            economic_source = (root / 'code/modules/1713/extraction/ipc_economy.dm').read_text(encoding='utf-8')
            marker = 'actor_after["credits"] = wallet(current) - amount'
            if economic_source.count(marker) != 1:
                raise RuntimeError('Market purchase debit mutation marker changed')
            control = root / (prefix + '_ipc_economy.dm')
            generated.append(control)
            control.write_text(economic_source.replace(marker, 'actor_after["credits"] = wallet(current)'), encoding='utf-8')
            source = source.replace('code\\modules\\1713\\extraction\\ipc_economy.dm', control.name)
        if city_pursuit_control:
            zombie_source = (root / 'code/modules/1713/extraction/city_zombies.dm').read_text(encoding='utf-8')
            marker = 'if (!chosen && city_pursuing)'
            if zombie_source.count(marker) != 1:
                raise RuntimeError('City pursuit mutation marker changed')
            control = root / (prefix + '_city_zombies.dm')
            generated.append(control)
            control.write_text(zombie_source.replace(marker, 'if (FALSE)'), encoding='utf-8')
            source = source.replace('code\\modules\\1713\\extraction\\city_zombies.dm', control.name)
        if city_presence_control:
            city_source = (root / 'code/modules/1713/extraction/modern_city.dm').read_text(encoding='utf-8')
            marker = 'if (!..()) return FALSE'
            if city_source.count(marker) != 2:
                raise RuntimeError('City physical presence mutation marker changed')
            control = root / (prefix + '_modern_city.dm')
            generated.append(control)
            control.write_text(city_source.replace(marker, 'if (!H?.extraction_session) return FALSE', 1), encoding='utf-8')
            source = source.replace('code\\modules\\1713\\extraction\\modern_city.dm', control.name)
        if supply_control:
            progression_source = (root / 'code/modules/1713/extraction/progression.dm').read_text(encoding='utf-8')
            marker = 'candidate["credits"] = game_credits(S) - offer["price"]'
            if progression_source.count(marker) != 1:
                raise RuntimeError('Supply payment mutation marker changed')
            control = root / (prefix + '_progression.dm')
            generated.append(control)
            control.write_text(progression_source.replace(marker, 'candidate["credits"] = game_credits(S)'), encoding='utf-8')
            source = source.replace('code\\modules\\1713\\extraction\\progression.dm', control.name)
        if vehicle_raid_control:
            raid_source = (root / 'code/modules/1713/extraction/vehicle_raid.dm').read_text(encoding='utf-8')
            marker = '\tcandidate["garage"] = list()' if vehicle_raid_control == 'debit' else '\tcandidate["garage"] = list(vehicle)'
            if raid_source.count(marker) != 1:
                raise RuntimeError('Vehicle raid mutation marker changed')
            control = root / (prefix + '_vehicle_raid.dm')
            generated.append(control)
            control.write_text(raid_source.replace(marker, '\t// Negative control: omit vehicle ownership transition'), encoding='utf-8')
            source = source.replace('code\\modules\\1713\\extraction\\vehicle_raid.dm', control.name)
            expected_raid_failure = 'solo deployment debits saved garage before moving actual car' if vehicle_raid_control == 'debit' else 'vehicle exit credits actual car before private bay relocation'
        if vehicle_purchase_control:
            purchase_source = (root / 'code/modules/1713/extraction/vehicle_purchase.dm').read_text(encoding='utf-8')
            marker = '\tcandidate["stash"] = retained\n\tcandidate["garage_purchase"] = list("id" = md5("[owner]:car:'
            if purchase_source.count(marker) != 1:
                raise RuntimeError('Vehicle payment mutation marker changed')
            control = root / (prefix + '_vehicle_purchase.dm')
            generated.append(control)
            control.write_text(purchase_source.replace(marker, marker.replace('candidate["stash"] = retained', 'candidate["stash"] = profile["stash"]')), encoding='utf-8')
            source = source.replace('code\\modules\\1713\\extraction\\vehicle_purchase.dm', control.name)
        if vehicle_loss_control:
            store_source = (root / 'code/modules/1713/extraction/account_store.dm').read_text(encoding='utf-8')
            marker = '\tP["stash"] = list()\n\tP["garage"] = list()\n\tP["state"] = "home"'
            if store_source.count(marker) != 1:
                raise RuntimeError('Garage loss mutation marker changed')
            control = root / (prefix + '_account_store.dm')
            generated.append(control)
            control.write_text(store_source.replace(marker, '\tP["stash"] = list()\n\t// Negative control: retain uncertain garage\n\tP["state"] = "home"'), encoding='utf-8')
            source = source.replace('code\\modules\\1713\\extraction\\account_store.dm', control.name)
        if group_control:
            filename = 'transactions' if group_control in ('visibility', 'car', 'fee') else 'settlement'
            group_source = (root / f'code/modules/1713/extraction/{filename}.dm').read_text(encoding='utf-8')
            if group_control == 'debit':
                marker = 'if (json_encode(expected) != json_encode(after) || json_encode(plan["issued"]) != json_encode(part["issued"])) return FALSE'
                replacement = 'if (json_encode(plan["issued"]) != json_encode(part["issued"])) return FALSE'
                expected_group_failure = 'forged group projection rejected by planning authority'
            elif group_control == 'premium':
                marker = 'if (!islist(offer) || json_encode(V.plan_insurance_quote(part["selected"], offer["round"], FALSE)) != json_encode(offer)) return FALSE'
                replacement = 'if (!islist(offer)) return FALSE'
                expected_group_failure = 'forged group premium rejected by canonical pricing authority'
            elif group_control == 'car':
                marker = '\tcandidate["garage"] = list()'
                replacement = '\tcandidate["garage"] = profile["garage"]'
                expected_group_failure = 'native group recovery preserves exact vehicle debit without a second car'
            elif group_control == 'fee':
                marker = 'if (!isnull(vehicle) && !islist(vehicle)) return null\n\tvar/list/candidate = copy_profile()\n\tcandidate["credits"] -= fee'
                replacement = 'if (!isnull(vehicle) && !islist(vehicle)) return null\n\tvar/list/candidate = copy_profile()\n\t// Negative control: omit passenger fee debit'
                expected_group_failure = 'paid passenger projection reserves exact fee without premature debit'
            elif group_control == 'return':
                marker = 'if (json_encode(expected) != json_encode(after)) return FALSE'
                replacement = '// Negative control: permit a missing passenger credit'
                expected_group_failure = 'forged passenger credit rejected by return planning authority'
            else:
                marker = 'if (!group_journal.ready()) return FALSE'
                replacement = 'group_journal.ready()'
                expected_group_failure = 'interrupted group never exposes a partial account set'
            if group_source.count(marker) != 1:
                raise RuntimeError('Group mutation marker changed')
            control = root / (prefix + f'_{filename}.dm')
            generated.append(control)
            control.write_text(group_source.replace(marker, replacement), encoding='utf-8')
            source = source.replace(f'code\\modules\\1713\\extraction\\{filename}.dm', control.name)
        if vote_control:
            vote_source = (root / 'code/datums/vote.dm').read_text(encoding='utf-8')
            mutations = {
                'stale': (' && session_generation == generation', '', 'stale ballot and timer cannot touch replacement'),
                'cancel': ('H.state = "cancelled"', 'H.state = "pending"', 'cancel detaches callbacks and clears UI session'),
                'reentry': ('if (generation != H.generation || active_request) return .', 'reset()\n\t\tif (generation != H.generation || active_request) return .', 'reentrant callback replacement survives old completion'),
                'disruptive_creation': ('return disruptive_votes_enabled || !disruptive_action(vote_type, completion)', 'return TRUE', 'disabled manual and automatic disruptive creation denied'),
                'disruptive_pending': ('if (!disruptive_votes_enabled && is_current(active_request) && disruptive_action(mode, active_request.completion))', 'if (FALSE && is_current(active_request))', 'disabling disruptive votes cancels pending action and stale resolution'),
                'disruptive_result': ('if (!action_allowed(resolved_mode, completion)) return FALSE\n\t\tif (.) apply_result', '// omitted post-callback policy\n\t\tif (.) apply_result', 'callback policy change prevents old disruptive result route'),
            }
            marker, replacement, expected_vote_failure = mutations[vote_control]
            if vote_source.count(marker) != 1:
                raise RuntimeError('Vote mutation marker changed')
            control = root / (prefix + '_vote.dm')
            generated.append(control)
            control.write_text(vote_source.replace(marker, replacement), encoding='utf-8')
            source = source.replace('code\\datums\\vote.dm', control.name)
        if provenance_control:
            codec = (root / 'code/modules/1713/extraction/equipment.dm').read_text(encoding='utf-8')
            marker = 'I.extraction_found_in_raid = record["schema"] == 2 ? node["found_in_raid"] : FALSE'
            if codec.count(marker) != 1:
                raise RuntimeError('Provenance control marker changed')
            control = root / (prefix + '_equipment.dm')
            generated.append(control)
            control.write_text(codec.replace(marker, 'I.extraction_found_in_raid = FALSE'), encoding='utf-8')
            source = source.replace('code\\modules\\1713\\extraction\\equipment.dm', control.name)
        world = (root / 'code/world.dm').read_text(encoding='utf-8')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_extraction_startup()', 1)
        world = world.replace('/datum/global_init/New()\n', '/datum/global_init/New()\n\treturn\n', 1)
        generated[1].write_text(world, encoding='utf-8')
        globals_text = (root / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8')
        marker = '/datum/controller/global_vars/New()\n'
        if globals_text.count(marker) != 1:
            raise RuntimeError('Global startup isolation marker changed')
        generated[2].write_text(globals_text.replace(marker, marker + '\treturn\n'), encoding='utf-8')
        source = source.replace('code\\world.dm', generated[1].name).replace('code\\controllers\\mc\\globals.dm', generated[2].name)
        source = re.sub(r'^#include ".*\.dmm"\s*$', '', source, flags=re.M)
        if probe in ('mode', 'npc'):
            source = '#define EXTRACTION_MODE_PROBE\n' + source
            source += '\n#include "tests/extraction/mode_probe.dm"\n#include "tests/extraction/hub_probe.dm"\n#include "tests/extraction/progression_probe.dm"\n#include "tests/extraction/vote_probe.dm"\n#include "tests/extraction/group_probe.dm"\n#include "tests/extraction/vehicle_probe.dm"\n#include "tests/extraction/loot_probe.dm"\n#include "maps/extraction/industrial_district.dmm"\n'
        if probe == 'npc':
            source = '#define EXTRACTION_NPC_PROBE\n' + source
        if probe == 'city':
            source = '#define EXTRACTION_MODE_PROBE\n#define EXTRACTION_CITY_PROBE\n' + source
            source += '\n#include "tests/extraction/mode_probe.dm"\n#include "tests/extraction/hub_probe.dm"\n#include "tests/extraction/progression_probe.dm"\n#include "tests/extraction/vote_probe.dm"\n#include "tests/extraction/group_probe.dm"\n#include "tests/extraction/vehicle_probe.dm"\n#include "tests/extraction/loot_probe.dm"\n#include "tests/extraction/city_probe.dm"\n#include "maps/extraction/modern_city_extraction.dmm"\n'
        if probe in ('mode', 'npc', 'city'):
            source += '\n#include "tests/extraction/native_market_probe.dm"\n'
        source += '\n#include "tests/extraction/insurance_mail_probe.dm"\n'
        if probe == 'city':
            source += '\n#include "tests/extraction/city_zombie_probe.dm"\n'
        if probe == 'insurance':
            source = '#define EXTRACTION_RETURNS_PROCESS_PROBE\n' + source
            source += '\n#include "tests/extraction/insurance_process_probe.dm"\n'
        if probe == 'groups':
            source = '#define EXTRACTION_GROUP_PROCESS_PROBE\n' + source
            source += '\n#include "tests/extraction/group_process_probe.dm"\n'
        if probe == 'vehicles':
            source = '#define EXTRACTION_VEHICLE_PROCESS_PROBE\n' + source
            source += '\n#include "tests/extraction/vehicle_process_probe.dm"\n'
        source += '\n#include "tests/extraction/economy_probe.dm"\n#include "tests/extraction/scope_insurance_probe.dm"\n#include "tests/extraction/npc_extraction_probe.dm"\n#include "tests/extraction/container_keys_probe.dm"\n#include "tests/extraction/equipment_probe.dm"\n#include "tests/extraction/surface_probe.dm"\n'
        generated[0].write_text(source, encoding='utf-8')
        with tempfile.TemporaryDirectory(prefix='civ13-extraction-equipment-') as temp:
            target = Path(temp)
            built = subprocess.run([str(compiler), '-max_errors', '0', str(generated[0])], cwd=root,
                                   capture_output=True, text=True, timeout=90, creationflags=flags)
            print(built.stdout + built.stderr)
            if built.returncode or '516.1681' not in built.stdout or '0 errors, 0 warnings' not in built.stdout:
                raise RuntimeError('Pinned equipment compile failed')
            if compile_only:
                print('COMPILE ONLY: native assertions and negative controls were not executed')
                return
            shutil.copy2(generated[3], target / 'probe.dmb')
            shutil.copy2(generated[4], target / 'probe.rsc')
            shutil.copytree(root / 'config/names', target / 'config/names')

            if probe == 'city':
                (target / 'config/crafting').mkdir()
                shutil.copy2(root / 'config/crafting/material_recipes_global.txt', target / 'config/crafting/material_recipes_global.txt')
            platform = ['-invisible', '-close'] if os.name == 'nt' else []
            phases = ('write', 'reload', 'replay') if probe in ('insurance', 'groups', 'vehicles') else ('equipment',)
            for phase in phases:
                (target / 'result.txt').unlink(missing_ok=True)
                try:
                    ran = subprocess.run([str(daemon), 'probe.dmb', *platform, '-safe', '-params', f'phase={phase}', '-log', 'runtime.log'], cwd=target,
                                         capture_output=True, text=True, timeout=120 if probe in ('mode', 'equipment') else 60, creationflags=flags)
                except subprocess.TimeoutExpired:
                    log_path = target / 'runtime.log'
                    print(log_path.read_text(errors='replace')[-12000:] if log_path.exists() else 'Runtime log missing at timeout')
                    raise
                result = (target / 'result.txt').read_text().strip() if (target / 'result.txt').exists() else 'MISSING'
                log = (target / 'runtime.log').read_text(errors='replace') if (target / 'runtime.log').exists() else ''
                print(result)
                if surface_control:
                    expected = {
                        'epoch': 'surface restart preserves epoch without refill',
                        'claim': 'surface claim intent survives failed acknowledgement',
                        'duplicate': 'surface duplicate IDs quarantine both sources',
                        'movement': 'surface alternate forced pickup cannot bypass journal',
                        'inventory': 'surface incomplete world levels cannot seal discovery',
                        'retirement': 'surface forfeited identity remains in durable epoch retirement index',
                        'identity': 'surface loaded identity discovery never mints missing item identity',
                        'escrow': 'market wrong escrow digest rejected',
                        'mail_binding': 'auxiliary mismatched active mail identity fails closed',
                        'auxiliary_pending': 'pending shared projection blocks auxiliary census without repair',
                        'home_owner': 'private-home replica wrong owner rejected',
                        'home_graph': 'private-home replica changed graph rejected',
                        'home_placement': 'private-home replica wrong placement rejected',
                        'home_revision': 'private-home replica stale revision rejected',
                        'world_stale': 'stale world load barrier cannot seal census',
                        'fresh_incomplete': 'saved replica feed cannot authorize incomplete fresh-world census',
                        'home_admission': 'unbound second owner cannot enter replica-bound room or access its actual stash',
                        'marker_save': 'native marker entry round trip preserves room binding and parent fields while excluding session',
                        'discovery': 'surface duplicate loaded roots lock discovery',
                        'forfeit': 'surface round forfeit retires actual root before acknowledgement',
                    }[surface_control]
                    if ran.returncode or not result.startswith('FAIL:') or not intended_assertion_only(log, expected):
                        print(log)
                        raise RuntimeError('Surface control failed outside its intended assertion: ' + expected)
                    print('PASS: surface omission detected: ' + surface_control)
                    return
                if corpse_release_control:
                    expected = 'bones transition releases original nested insured equipment with stable identity and condition'
                    if ran.returncode or not result.startswith('FAIL:') or expected not in log or any(x in log.lower() for x in ('runtime error', 'bad ref', '## error')):
                        print(log)
                        raise RuntimeError('Corpse release control failed outside its intended assertion')
                    print('PASS: omitted corpse gear release rejected by integrated death/insurance assertion')
                    return
                if workshop_control:
                    expected = {'wear': 'assembled wheel retains actual identity and paid wear', 'cleanup': 'cancel cleanup releases busy power and all paid preview references'}[workshop_control]
                    if ran.returncode or not result.startswith('FAIL:') or not intended_assertion_only(log, expected):
                        print(ran.stdout)
                        print(ran.stderr)
                        print(log)
                        raise RuntimeError(f'Workshop {workshop_control} control did not fail at its intended ownership assertion: {expected}')
                    print(f'PASS: workshop {workshop_control} omission detected')
                    continue
                if room_payment_control:
                    if ran.returncode or not result.startswith('FAIL:') or 'native upgrade consumes exactly five roots and preserves unrelated wallet' not in log or any(x in log.lower() for x in ('runtime error', 'bad ref', '## error')):
                        print(log)
                        raise RuntimeError('Room payment control failed outside its intended assertion')
                    print('PASS: retained upgrade parts rejected by native payment assertion')
                    return
                if economic_payment_control:
                    if ran.returncode or not result.startswith('FAIL:') or 'purchase three-account settlement committed' not in log or any(x in log.lower() for x in ('runtime error', 'bad ref', '## error')):
                        print(log)
                        raise RuntimeError('Economic payment control failed outside its intended assertion')
                    print('PASS: shared conservation journal rejects retained market buyer payment')
                    return
                if city_pursuit_control:
                    expected = 'zombie lost perception cancels pursuit before idle cooldown expires'
                    if ran.returncode or not result.startswith('FAIL:') or not intended_assertion_only(log, expected):
                        print(log)
                        raise RuntimeError('City pursuit control failed outside its intended assertion')
                    print('PASS: stale city pursuit negative control rejected')
                    return
                if city_presence_control:
                    if ran.returncode or not result.startswith('FAIL:') or 'departure commits only conscious physically present reserved actor' not in log or any(x in log.lower() for x in ('runtime error', 'bad ref', '## error')):
                        print(log)
                        raise RuntimeError('City presence control failed outside its intended assertion')
                    print('PASS: absent evacuation presence negative control rejected')
                    return
                if supply_control:
                    if ran.returncode or not result.startswith('FAIL:') or 'payment and product share one snapshot without refund or reissue' not in log or any(x in log.lower() for x in ('runtime error', 'bad ref', '## error')):
                        print(log)
                        raise RuntimeError('Supply payment control failed outside its intended assertion')
                    print('PASS: retained game-credit payment negative control rejected')
                    return
                if npc_insurance_control:
                    if ran.returncode or not result.startswith('FAIL:') or 'NPC successful extraction suppresses every original insured component' not in log or any(x in log.lower() for x in ('runtime error', 'bad ref', '## error')):
                        print(log)
                        raise RuntimeError('NPC suppression control failed outside its intended assertion')
                    print('PASS: omitted NPC component suppression negative control rejected')
                    return
                if vehicle_raid_control and result.startswith('FAIL:'):
                    if ran.returncode or expected_raid_failure not in log or any(x in log.lower() for x in ('runtime error', 'bad ref', '## error')):
                        print(log)
                        raise RuntimeError('Vehicle raid control failed outside its intended assertion')
                    print('PASS: vehicle ownership control rejected: ' + vehicle_raid_control)
                    return
                if vehicle_purchase_control and result.startswith('FAIL:'):
                    if ran.returncode or 'paid dealer car contains no free fuel or refunded workshop parts' not in log or any(x in log.lower() for x in ('runtime error', 'bad ref', '## error')):
                        print(log)
                        raise RuntimeError('Vehicle payment control failed outside its intended assertion')
                    print('PASS: retained vehicle payment negative control rejected')
                    return
                if vehicle_loss_control and result.startswith('FAIL:'):
                    if ran.returncode or 'uncertain garage forfeited independently of empty stash' not in log or any(x in log.lower() for x in ('runtime error', 'bad ref', '## error')):
                        print(log)
                        raise RuntimeError('Vehicle loss control failed outside its intended assertion')
                    print('PASS: uncertain garage retention negative control rejected')
                    return
                if group_control and result.startswith('FAIL:'):
                    if ran.returncode or expected_group_failure not in log or any(x in log.lower() for x in ('runtime error', 'bad ref', '## error')):
                        print(log)
                        raise RuntimeError('Group control did not fail at its intended assertion')
                    print('PASS: group control rejected: ' + group_control)
                    return
                if vote_control:
                    if ran.returncode or not result.startswith('FAIL:') or expected_vote_failure not in log or any(x in log.lower() for x in ('runtime error', 'bad ref', '## error')):
                        print(log)
                        raise RuntimeError('Vote control did not fail at its intended assertion')
                    print('PASS: vote lifecycle control rejected: ' + vote_control)
                    return
                if provenance_control:
                    if ran.returncode or not result.startswith('FAIL:') or 'nested identities and raid provenance survive native disk reload' not in log or any(x in log.lower() for x in ('runtime error', 'bad ref', '## error')):
                        print(log)
                        raise RuntimeError('Provenance omission was not detected by the intended assertion')
                    print('PASS: generated provenance-loss control rejected at native disk reload')
                    return
                if ran.returncode or not result.startswith('PASS:') or any(x in log.lower() for x in ('runtime error', 'bad ref', '## error')):
                    print(log)
                    raise RuntimeError('Production equipment verification failed')
            if insurance_fixture_output:
                shutil.copytree(target / 'data/insurance_bot_fixture', insurance_fixture_output)
            if group_control:
                raise RuntimeError('Group control was not detected')
            if city_pursuit_control:
                raise RuntimeError('City pursuit control was not detected')
            if vehicle_loss_control:
                raise RuntimeError('Vehicle loss control was not detected')
            if vehicle_purchase_control:
                raise RuntimeError('Vehicle purchase control was not detected')
            if vehicle_raid_control:
                raise RuntimeError('Vehicle raid control was not detected')
    finally:
        for path in generated:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
