"""Source contracts for the DM side of transfer storage. Never launches BYOND.

The design (tools/server-management/TRANSFER-STORAGE-SQLITE.md) needs the
world save to list the transfer effects it contains, report them only after the
completion marker, and reconcile on load. These checks keep that ordering and
the default-off configuration honest.
"""
import importlib.util
import json
import os
from pathlib import Path
from types import SimpleNamespace
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def read(path):
    with open(os.path.join(ROOT, path), encoding='utf-8-sig') as f:
        return f.read().replace('\r\n', '\n')


def proc(source, name):
    start = source.index('\n' + name + '(') + 1
    # The next top-level definition ends the proc; preprocessor lines do not.
    end = re.search(r'\n(?=[^\s#])', source[start + 1:])
    return source[start:start + 1 + end.start()] if end else source[start:]


SAVING = read('code/modules/persistence/saving.dm')
LOADING = read('code/modules/persistence/loading.dm')
FUNCTIONS = read('code/modules/persistence/functions.dm')
BRIDGE = read('code/modules/persistence/transfer_bridge.dm')
POST = read('code/modules/persistence/transfer_trade_post.dm')
DME = read('civ13.dme')


class SaveOrdering(unittest.TestCase):
    def test_capture_is_written_with_round_state_and_reported_after_the_marker(self):
        capture = SAVING.index('var/list/transfer_capture = transfer_capture(generation)')
        stored = SAVING.index('round_state["transfer"] = transfer_capture')
        written = SAVING.index('text2file(json_encode(round_state), "map_saves/round.json")')
        marker = SAVING.index('text2file(generation,"map_saves/save_complete.txt")')
        report = SAVING.index('transfer_saved(transfer_capture)')
        self.assertLess(SAVING.index('operation.diagnostic_phase = "write_marker"'), capture)
        self.assertLess(capture, stored)
        self.assertLess(stored, written)
        self.assertLess(written, marker)
        self.assertLess(marker, report)
        self.assertEqual(SAVING.count('transfer_saved('), 1)

    def test_load_reports_after_the_world_is_restored(self):
        body = proc(LOADING, '/map_storage/proc/load_world_contents')
        self.assertLess(body.index('restore_level_links()'), body.index('transfer_loaded(transfer_round_state)'))
        self.assertLess(body.index('transfer_loaded(transfer_round_state)'), body.index('log_startup_progress("Finished loading.")'))
        # An unreadable round state must not abort a load that already succeeded.
        self.assertIn('try\n\t\ttransfer_round_state = read_round_state()\n\tcatch', body)


class RoundState(unittest.TestCase):
    def test_transfer_key_is_counted_and_validated(self):
        body = proc(FUNCTIONS, '/map_storage/proc/read_round_state')
        self.assertIn('has_transfer = islist(state) && ("transfer" in state)', body)
        self.assertIn('+ has_debug_recovery + has_transfer', body)
        self.assertIn('if(has_transfer && !valid_transfer_capture(state["transfer"])) throw EXCEPTION', body)

    def test_validator_bounds(self):
        body = proc(FUNCTIONS, '/proc/valid_transfer_capture')
        for needle in ('capture.len != 3', '"generation" in capture', '"effects" in capture', '"ledger_seq" in capture',
                       'length(generation) > 128', 'seq != round(seq)', 'seq > 1e12', 'effects.len > TRANSFER_CAPTURE_MAX',
                       'length(effect) > 96'):
            self.assertIn(needle, body)

    def test_fixtures_get_inert_stubs(self):
        self.assertEqual(proc(FUNCTIONS, '/map_storage/proc/transfer_capture').strip().splitlines()[-1].strip(), 'return null')
        for name in ('transfer_saved', 'transfer_loaded'):
            self.assertEqual(proc(FUNCTIONS, '/map_storage/proc/' + name).strip().splitlines()[-1].strip(), 'return')


class BirthChartTravel(unittest.TestCase):
    def test_capture_is_staged_but_restore_never_discards_a_record(self):
        config = read('code/datums/configuration.dm')
        wheel = read('code/game/mob/living/carbon/human/birth_chart_wheel.dm')
        travel = read('code/modules/persistence/region_travel.dm')
        self.assertIn('var/birth_chart_records = FALSE', config)
        capture = proc(wheel, '/mob/living/human/proc/record_birth_chart')
        self.assertLess(capture.index('if (shard_group.enabled && !config.birth_chart_records)'),
                        capture.index('birth_chart_record = record'))
        self.assertNotIn('config.birth_chart_records', travel)
        self.assertIn('P["chart_record"] = birth_chart_record.Copy()', travel)
        self.assertIn('H.birth_chart_record = P["chart_record"].Copy()', travel)
        self.assertIn('P["v"] in list(1, 2, 3)', travel)

    def test_only_the_actual_current_receiving_world_admits_birth_records(self):
        group = read('code/modules/persistence/shard_group.dm')
        describe = proc(group, '/datum/shard_group/proc/describe')
        self.assertIn('.["birth_chart_records"] = TRUE', describe)
        self.assertNotIn('config.birth_chart_records', describe)
        record = proc(group, '/datum/shard_group/proc/record')
        self.assertLess(record.index('if(reply["group"] != group || reply["region"] != id)'),
                        record.index('peer["birth_chart_records"] ='))
        admitted = proc(group, '/datum/shard_group/proc/peer_accepts_birth_chart_records')
        self.assertLess(admitted.index('if(!poll_peer(id))\n\t\treturn FALSE'),
                        admitted.index('peer["birth_chart_records"] == TRUE'))
        self.assertNotIn('refresh_peer', admitted)

    def test_direct_poll_cannot_record_a_reply_from_a_stale_endpoint(self):
        spec = importlib.util.spec_from_file_location('chart_poll_source_adapter',
            Path(ROOT) / 'tests/save_movement/source_adapter.py')
        adapter = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(adapter)
        group = read('code/modules/persistence/shard_group.dm')
        reload = proc(group, '/datum/shard_group/proc/reload_directory')
        self.assertLess(reload.index('directory_generation++'),
                        reload.index('address = entry["address"]'))
        source = group.replace('polls_waiting ? polls_waiting[id] : null',
                               'polls_waiting.get(id)')
        source = source.replace(
            '"byond://[polled_address]?shard_region=1&format=json"',
            'direct_url(polled_address)').replace(
            '"byond://[peer_address(peer)]?shard_region=1&format=json"',
            'direct_url(peer_address(peer))')
        # Replace only the scheduler wait with a deterministic simulated yield.
        # The admission and publication logic is projected from poll_peer().
        wait = '\twhile(!poll.done && world.time < deadline)\n\t\tsleep(1)'
        self.assertEqual(source.count(wait), 1)
        source = source.replace(wait, '\tschedule_reply(poll, deadline)')

        class Entry(dict):
            # A DM list identity comparison does not compare its values.
            def __ne__(self, other):
                return self is not other

        for change in ('none', 'address', 'generation', 'entry', 'newer poll'):
            with self.subTest(change=change):
                entry = Entry(address='old:1000')
                recorded = []
                asked = []
                waiting = {}
                replacement = SimpleNamespace(done=False)
                poll = SimpleNamespace(done=False, answer='capable', ask=asked.append)

                def schedule_reply(pending, deadline):
                    if change == 'address':
                        entry['address'] = 'new:1000'
                    if change == 'generation':
                        env['directory_generation'] += 2  # moved away and back
                    if change == 'entry':
                        env['peers']['land'] = Entry(entry)
                    if change == 'newer poll':
                        waiting['land'] = replacement
                    pending.done = True

                env = dict(peers={'land': entry}, world=SimpleNamespace(time=1),
                    directory_generation=0, polls_waiting=waiting,
                    peer_address=lambda peer: peer['address'] if peer else None,
                    direct_url=lambda endpoint: 'byond://' + endpoint,
                    new_operation=lambda: poll, SHARD_POLL_TIMEOUT=10,
                    LAZYSET=lambda mapping, k, v: mapping.__setitem__(k, v),
                    LAZYREMOVE=lambda mapping, k: mapping.pop(k, None),
                    log_game=lambda message: None, schedule_reply=schedule_reply,
                    record=lambda *args: recorded.append(args) or True)
                actual = adapter.project(source, '/datum/shard_group/proc/poll_peer',
                                         'id', env)('land')
                self.assertEqual(asked, ['byond://old:1000'])
                self.assertEqual(actual, change == 'none')
                self.assertEqual(recorded, [('land', 'capable', 1)] if change == 'none' else [])
                self.assertEqual(waiting, {'land': replacement} if change == 'newer poll' else {})

    def test_immunization_codec_and_capability_do_not_depend_on_activation(self):
        travel = read('code/modules/persistence/region_travel.dm')
        self.assertIn('P["immunization_record"] = immunizations', travel)
        self.assertIn('H.immunization_record = immunization_record_copy(P["immunization_record"])', travel)
        self.assertIn('("immunization_record" in P) && !immunization_record_valid(P["immunization_record"])', travel)
        self.assertNotIn('shard_immunization_records', travel)
        self.assertIn('P["v"] in list(1, 2, 3)', travel)
        group = read('code/modules/persistence/shard_group.dm')
        describe = proc(group, '/datum/shard_group/proc/describe')
        self.assertIn('.["immunization_records"] = TRUE', describe)
        self.assertNotIn('config.shard_immunization_records', describe)
        record = proc(group, '/datum/shard_group/proc/record')
        self.assertLess(record.index('if(reply["group"] != group || reply["region"] != id)'),
                        record.index('peer["immunization_records"] ='))
        admitted = proc(group, '/datum/shard_group/proc/peer_accepts_immunization_records')
        self.assertLess(admitted.index('if(!poll_peer(id))'),
                        admitted.index('peer["immunization_records"] == TRUE'))
        self.assertIn('!needs_birth_chart || peer["birth_chart_records"] == TRUE', admitted)
        self.assertNotIn('refresh_peer', admitted)

    def test_mixed_or_unconfirmed_receiver_never_records_escrow_for_any_passenger(self):
        spec = importlib.util.spec_from_file_location('chart_custody_source_adapter',
            Path(ROOT) / 'tests/save_movement/source_adapter.py')
        adapter = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(adapter)
        # Translate only DM association-list construction; the rest, including
        # the network admission/escrow order, is projected from the real proc.
        last = 'list("peer" = peer, "payloads" = payloads, "fast" = fast ? 1 : 0)'
        self.assertEqual(BRIDGE.count(last), 1)
        source = BRIDGE.replace(last, 'make_args(peer, payloads, fast)')
        calls = []
        supports = False
        held = False
        now_held = False

        def poll(peer):
            nonlocal held
            calls.append(('poll', peer))
            held = now_held
            return supports

        def effect(path, args):
            calls.append((path, args))
            return "recorded"

        vaccine_support = False

        def vaccine_poll(peer, needs_chart):
            ready = poll(peer)
            return vaccine_support and (ready or not needs_chart)

        shard = SimpleNamespace(peer_transfers_held=lambda peer: held,
                                peer_accepts_birth_chart_records=poll,
                                peer_accepts_immunization_records=vaccine_poll)
        escrow = adapter.project(source, '/datum/transfer_bridge/proc/begin_escrow',
            'peer, payloads, fast=False', dict(shard_group=shard, begin_effect=effect,
                make_args=lambda peer, payloads, fast: (peer, payloads, fast),
                istext=lambda v: isinstance(v, str), findtextEx=lambda s, x: x in s))
        legacy = json.dumps({"kind": "character", "chart": "owl"})
        detailed = json.dumps({"kind": "character", "chart": "owl",
                               "chart_record": {"v": 1, "day": 0}})
        fake_field_in_value = json.dumps({"kind": "character", "name": '"chart_record"'})
        self.assertEqual(escrow("land", [legacy, fake_field_in_value]), "recorded")
        self.assertEqual([x[0] for x in calls], ["/escrow"])
        calls.clear()
        self.assertIsNone(escrow("land", [legacy, detailed]))
        self.assertEqual(calls, [("poll", "land")])
        calls.clear()
        supports = True
        batch = [legacy, detailed, detailed]
        self.assertEqual(escrow("land", batch, True), "recorded")
        self.assertEqual(calls, [("poll", "land"), ("/escrow", ("land", batch, True))])
        calls.clear()
        now_held = True
        self.assertIsNone(escrow("land", batch))
        self.assertEqual(calls, [("poll", "land")])
        calls.clear()
        self.assertIsNone(escrow("land", batch))
        self.assertEqual(calls, [])
        vaccine = json.dumps({"kind": "character", "immunization_record": {"cholera": [300, 660]}})
        value_only = json.dumps({"kind": "character", "name": '"immunization_record'})
        held = now_held = False
        self.assertEqual(escrow("land", [legacy, value_only]), "recorded")
        self.assertEqual([entry[0] for entry in calls], ["/escrow"])
        calls.clear()
        self.assertIsNone(escrow("land", [legacy, vaccine]))
        self.assertEqual(calls, [("poll", "land")])
        calls.clear()
        vaccine_support = True
        supports = False
        self.assertIsNone(escrow("land", [vaccine, detailed]))
        self.assertEqual(calls, [("poll", "land")])
        calls.clear()
        supports = True
        both = [legacy, vaccine, detailed]
        self.assertEqual(escrow("land", both), "recorded")
        self.assertEqual(calls, [("poll", "land"), ("/escrow", ("land", both, False))])
        calls.clear()
        now_held = True
        self.assertIsNone(escrow("land", [vaccine]))
        self.assertEqual(calls, [("poll", "land")])


class Bridge(unittest.TestCase):
    def test_overrides_load_after_the_stubs(self):
        includes = [line for line in DME.splitlines() if line.startswith('#include')]
        bridge = includes.index('#include "code\\modules\\persistence\\transfer_bridge.dm"')
        self.assertGreater(bridge, includes.index('#include "code\\modules\\persistence\\functions.dm"'))
        self.assertGreater(bridge, includes.index('#include "code\\modules\\persistence\\saving.dm"'))

    def test_off_unless_configured(self):
        new = proc(BRIDGE, '/datum/transfer_bridge/New')
        self.assertIn('if(!fexists("config/transfer_agent.json")) return', new)
        self.assertIn('length(secret) < 32', new)
        self.assertLess(new.index('length(secret) < 32'), new.index('port = settings["port"]'))
        self.assertIn('return port && token', proc(BRIDGE, '/datum/transfer_bridge/proc/enabled'))
        request = proc(BRIDGE, '/datum/transfer_bridge/proc/request')
        self.assertIn('"http://127.0.0.1:[port][path]"', request)
        # json_encode(list()) is "[]", which the agent refuses as a body.
        self.assertIn('var/payload = length(body) ? json_encode(body) : "{}"', request)
        self.assertNotIn('json_encode(body || list())', request)

    def test_a_world_without_its_agent_carries_the_saved_capture_through(self):
        # The underground migration boots without the agent's token. Its save must
        # keep the loaded transfer state, or the next real load is a rollback hold.
        capture = proc(BRIDGE, '/datum/transfer_bridge/proc/capture')
        self.assertIn('if(!enabled()) return carried_capture ? carried_capture.Copy() : null', capture)
        loaded = proc(BRIDGE, '/datum/transfer_bridge/proc/loaded')
        self.assertLess(loaded.index('carried_capture = valid_transfer_capture(kept) ? kept.Copy() : null'), loaded.index('ledger_base = null'))

    def test_effects_refused_during_saves_and_before_reconcile(self):
        body = proc(BRIDGE, '/datum/transfer_bridge/proc/begin_effect')
        self.assertIn('if(!ready() || persistence_save_active() || length(applied) >= TRANSFER_CAPTURE_MAX / 2) return null', body)
        # Checked again after the request returns, before the effect is recorded.
        self.assertEqual(body.count('persistence_save_active()'), 2)
        self.assertLess(body.rindex('persistence_save_active()'), body.index('applied += result["effect_id"]'))
        self.assertIn('!isnull(ledger_base) && !hold_reason', proc(BRIDGE, '/datum/transfer_bridge/proc/ready'))

    def test_unreconciled_saves_repeat_the_loaded_capture(self):
        body = proc(BRIDGE, '/datum/transfer_bridge/proc/capture')
        self.assertLess(body.index('if(isnull(ledger_base))'), body.index('loaded_capture.Copy()'))
        saved = proc(BRIDGE, '/datum/transfer_bridge/proc/saved')
        self.assertEqual(saved.splitlines()[1].strip(), 'set waitfor = FALSE')
        self.assertIn('if(isnull(ledger_base) || capture["ledger_seq"] > ledger_base) return', saved)



class TradePost(unittest.TestCase):
    def test_included_after_the_bridge(self):
        includes = [line for line in DME.splitlines() if line.startswith('#include')]
        self.assertEqual(includes.index('#include "code\\modules\\persistence\\transfer_trade_post.dm"'),
                         includes.index('#include "code\\modules\\persistence\\transfer_bridge.dm"') + 1)

    def test_goods_are_exact_allowlisted_types(self):
        kind = proc(POST, '/proc/transfer_trade_kind')
        self.assertIn('S.type == transfer_trade_goods[kind]', kind)
        self.assertNotIn('istype(S, transfer_trade_goods', kind)
        goods = re.findall(r'"(\w+)" = (/obj/item/stack/material/\w+)', POST)
        self.assertEqual(15, len(goods))
        for name, path in goods:
            self.assertEqual(path.rsplit('/', 1)[1], name)

    def test_payload_is_bounded_on_decode(self):
        body = proc(POST, '/proc/transfer_trade_decode')
        for needle in ('length(payload) > 512', 'P.len != 5', 'P["v"] != 1', '(P["kind"] in transfer_trade_goods)',
                       'amount != round(amount)', 'amount > transfer_trade_max(P["kind"])', 'ckey(key) != key'):
            self.assertIn(needle, body)

    def test_send_rechecks_after_prompts_and_ships_through_one_path(self):
        body = proc(POST, '/obj/structure/transfer_trade_post/proc/send_goods')
        recheck = body.index('// The prompts slept: check everything again.')
        self.assertLess(body.index('input(user'), recheck)
        self.assertLess(recheck, body.index('ship_stack(S, peer, user.ckey, recipient)'))
        self.assertNotIn('begin_escrow', body)

    def test_ship_holds_the_stack_and_removes_it_only_after_the_escrow_is_recorded(self):
        body = proc(POST, '/obj/structure/transfer_trade_post/proc/ship_stack')
        self.assertIn('!(peer in transfer_bridge.peers)', body)
        hold = body.index('S.forceMove(src)')
        escrow = body.index('transfer_bridge.begin_escrow(')
        remove = body.index('qdel(S)')
        self.assertIn('persistence_save_active()', body[:hold])
        self.assertLess(hold, escrow)
        self.assertLess(escrow, body.index('if(result)'))
        self.assertLess(body.index('if(result)'), remove)
        for blocking in ('sleep(', 'input(', 'alert('):
            self.assertNotIn(blocking, body[escrow:remove])
        self.assertIn('S.forceMove(get_turf(src))', body[remove:])

    def test_holdings_are_saved_with_the_post(self):
        self.assertIn('map_storage_saved_vars = "density;icon_state;dir;name;pixel_x;pixel_y;holdings"', POST)

    def test_arrivals_credit_right_after_the_recorded_effect(self):
        body = proc(BRIDGE, '/datum/transfer_bridge/proc/poll_once')
        effect = body.index('begin_import(transfer_id) : begin_return(transfer_id)')
        credit = body.index('transfer_trade_credit(post, result["payloads"], incoming)')
        self.assertLess(effect, credit)
        self.assertNotIn('sleep(', body[effect:credit])
        self.assertNotIn('request(', body[effect:credit])
        # A post deleted during the request is replaced on its turf, so the credit has a home.
        self.assertIn('new /obj/structure/transfer_trade_post(post_turf)', body[effect:credit])
        self.assertIn('if(ready() && !persistence_save_active())', proc(BRIDGE, '/datum/transfer_bridge/proc/poll_loop'))
        credit_proc = proc(POST, '/proc/transfer_trade_credit')
        self.assertIn('incoming ? P["to"] : P["from"]', credit_proc)
        self.assertNotIn('return FALSE', credit_proc)

    def test_journaled_trips_replay_after_reconcile_without_sleeping(self):
        loop = proc(BRIDGE, '/datum/transfer_bridge/proc/reconcile_loop')
        self.assertLess(loop.index('ledger_base = result["ledger_seq"]'), loop.index('replay(result["replay"])'))
        body = proc(BRIDGE, '/datum/transfer_bridge/proc/replay')
        self.assertNotIn('sleep(', body)
        self.assertNotIn('request(', body)
        self.assertIn('(effect_id in applied)', body)
        # Listed before the world change, so a runtime cannot make it build twice.
        self.assertLess(body.index('applied += effect_id'), body.index('region_travel_replay_departure('))
        self.assertIn('catch(', body)
        # A running save must finish before the replay touches the world.
        wait = loop.index('while(persistence_active_operation || persistence_save_active())')
        self.assertLess(wait, loop.index('ledger_base = result["ledger_seq"]'))
        self.assertNotIn('sleep(', loop[loop.index('ledger_base = result["ledger_seq"]'):loop.index('replay(result["replay"])')])
        self.assertIn('#define TRANSFER_CAPTURE_MAX 1024', FUNCTIONS)
        # Only characters travel fast; goods at trade posts keep the save-confirmed path.
        self.assertIn('begin_import(transfer_id, TRUE) : begin_return(transfer_id, TRUE)',
                      proc(BRIDGE, '/datum/transfer_bridge/proc/poll_character'))
        self.assertIn('begin_import(transfer_id) : begin_return(transfer_id)',
                      proc(BRIDGE, '/datum/transfer_bridge/proc/poll_once'))
        travel = read('code/modules/persistence/region_travel.dm')
        self.assertIn('transfer_bridge.begin_escrow(destination, payloads, TRUE)', travel)
        self.assertNotIn('begin_escrow(peer, list(payload), TRUE)', POST)

    def test_polling_starts_only_after_reconcile(self):
        body = proc(BRIDGE, '/datum/transfer_bridge/proc/reconcile_loop')
        self.assertLess(body.index('ledger_base = result["ledger_seq"]'), body.index('poll_loop()'))

if __name__ == '__main__':
    unittest.main()
