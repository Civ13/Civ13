"""Source contracts for the DM side of transfer storage. Never launches BYOND.

The design (tools/server-management/TRANSFER-STORAGE-SQLITE.md) needs the
world save to list the transfer effects it contains, report them only after the
completion marker, and reconcile on load. These checks keep that ordering and
the default-off configuration honest.
"""
import os
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
        self.assertIn('transfer_bridge.begin_escrow(destination, list(payload), TRUE)', travel)
        self.assertNotIn('begin_escrow(peer, list(payload), TRUE)', POST)

    def test_polling_starts_only_after_reconcile(self):
        body = proc(BRIDGE, '/datum/transfer_bridge/proc/reconcile_loop')
        self.assertLess(body.index('ledger_base = result["ledger_seq"]'), body.index('poll_loop()'))

if __name__ == '__main__':
    unittest.main()
