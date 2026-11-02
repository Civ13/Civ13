"""Startup/import hook ordering and fixed observer seam; not native execution."""
from pathlib import Path
import re
import unittest

ROOT=Path(__file__).resolve().parents[2]
def read(path):return (ROOT/path).read_text(encoding='utf-8-sig')


def require_once(source,token):
    if source.count(token)!=1:raise AssertionError('missing/duplicate hook: '+token)
    return source.index(token)


def init_order(world):
    begin=require_once(world,'call(game_ready_hook)("begin", area_startup)')
    setup=require_once(world,'setup_everything(area_startup)')
    complete=require_once(world,'call(game_ready_hook)("initialization_complete", startup_context, scheduler_ready == TRUE)')
    fail=require_once(world,'call(game_ready_hook)("initialization_failed", startup_context)')
    catch=world.index('catch(var/exception/E)',setup)
    rethrow=world.index('throw E',catch)
    close=world.index('area_startup.close()',rethrow)
    if not begin < setup < catch < fail < rethrow < close < complete:
        raise AssertionError('initialization proof/order changed')
    require_once(world,'scheduler_ready = processScheduler.setup()')


def load_order(functions):
    body=functions.split('/datum/controller/gameticker/proc/loadmap(',1)[1].split('/map_storage/proc/capture_round_state(',1)[0]
    names=(
        'begin_persistence_operation(storage, "load", transaction)',
        'call(game_ready_hook)("claim_load", startup_ready, operation, storage, transaction)',
        'var/list/saved_round = storage.read_round_state()',
        'ready_round = saved_round["game_id"]',
        'ready_generation = saved_round["generation"]',
        'operation.authorize_restore_mutation(storage)',
        'storage.restore_round_state(src, saved_round)',
        'storage.finish_player_restoration()',
        'if(operation.finish(TRUE) != TRUE)',
        'persistence_startup_recovery_status = null',
        'call(game_ready_hook)("loaded", ready_ticket, operation, storage, transaction, ready_round, ready_generation)',
        'return 1',
    )
    offsets=[require_once(body,name) for name in names]
    if offsets!=sorted(offsets):raise AssertionError('load readiness precedes exact release/restoration')
    gate=body[body.index('if(operation.finish(TRUE) != TRUE)'):body.index('persistence_startup_recovery_status = null')]
    if 'return FALSE' not in gate:raise AssertionError('release refusal fell through')
    if body.count('call(game_ready_hook)("load_failed", ready_ticket, operation)')!=2:
        raise AssertionError('load failure observer cleanup missing')


class HookContracts(unittest.TestCase):
    def test_normal_and_exceptional_initialization_paths_keep_closed_token_barrier(self):
        init_order(read('code/world.dm'))

    def test_early_init_notification_and_early_loaded_callback_are_rejected(self):
        world=read('code/world.dm')
        line='\t\tif(game_ready_hook) call(game_ready_hook)("initialization_complete", startup_context, scheduler_ready == TRUE)\n'
        require_once(world,line)
        mutant=world.replace(line,'').replace('\t\t\tsetup_everything(area_startup)\n',line+'\t\t\tsetup_everything(area_startup)\n',1)
        with self.assertRaises(AssertionError):init_order(mutant)
        functions=read('code/modules/persistence/functions.dm')
        line='\tif(game_ready_hook && ready_ticket) call(game_ready_hook)("loaded", ready_ticket, operation, storage, transaction, ready_round, ready_generation)\n'
        require_once(functions,line)
        mutant=functions.replace(line,'').replace('\tif(operation.finish(TRUE) != TRUE)\n',line+'\tif(operation.finish(TRUE) != TRUE)\n',1)
        with self.assertRaises(AssertionError):load_order(mutant)

    def test_loaded_identity_comes_from_exact_validated_import_after_affirmative_release(self):
        load_order(read('code/modules/persistence/functions.dm'))

    def test_automatic_restore_has_explicit_ticket_but_manual_later_load_has_none(self):
        setup=read('code/setup.dm')
        context=require_once(setup,'call(game_ready_hook)("setup_context", startup)')
        reserve=require_once(setup,'call(game_ready_hook)("reserve_restore", startup_context, null)')
        spawn=setup.index('spawn(50)',reserve)
        load=require_once(setup,'ticker.loadmap(null, null, ready_ticket)')
        self.assertLess(context,reserve);self.assertLess(reserve,spawn);self.assertLess(spawn,load)
        self.assertIn('if(!startup_round_pending)\n\t\tannounce_round_start_once()\n\t\tif(game_ready_hook) call(game_ready_hook)("fresh", startup_context, game_id)',setup)
        admin=read('code/modules/persistence/admin.dm')
        self.assertIn('if(ticker.loadmap()) announce_restored_round_once()',admin)
        for forbidden in ('reserve_restore','startup_ready','game_ready_startup_event'):
            self.assertNotIn(forbidden,admin)

    def test_restart_completion_follows_intent_consumption_and_actual_player_return(self):
        source=read('code/modules/persistence/restart_transaction.dm')
        body=source.split('/datum/persistence_restart_transaction/proc/resume_startup()',1)[1]
        calls=('consume(I)','startup_hold = FALSE','\n\t\tbusy = FALSE\n',
               'players_ready = map_storage.finish_player_restoration()',
               'call(game_ready_hook)("restart_completed", src, players_ready)')
        offsets=[require_once(body,token) for token in calls]
        self.assertEqual(offsets,sorted(offsets))
        self.assertIn('call(game_ready_hook)("restart_failed", src)',body)
        self.assertIn('call(game_ready_hook)("restart_ticket", src)',source)

    def test_module_and_dispatch_whitelist_are_explicit_and_no_saved_marker_is_reread(self):
        dme=read('civ13.dme')
        self.assertEqual(dme.count('#include "code\\modules\\webhooks\\game_ready.dm"'),1)
        source=read('code/modules/webhooks/game_ready.dm')
        events=re.findall(r'^\t\tif\("([a-z_]+)"\)',source,re.M)
        self.assertEqual(events,['begin','setup_context','initialization_failed','initialization_complete',
            'fresh','reserve_restore','restart_ticket','claim_load','load_failed','loaded','restart_failed','restart_completed'])
        for forbidden in ('save_complete.txt','file2text','read_round_state','webhook_send_round_start',
                          'world.log','message_admins','to_chat'):
            self.assertNotIn(forbidden,source)
        self.assertEqual(source.count('world.Export(query)'),1)
        self.assertIn('/datum/game_ready_load_ticket\n\tshould_save = FALSE',source)
        self.assertIn('/datum/game_ready_startup\n\tshould_save = FALSE',source)

    def test_feature_is_off_by_default_with_no_new_endpoint_or_secret_example(self):
        config=read('code/datums/configuration.dm')
        self.assertIn('var/webhook_game_ready = FALSE',config)
        self.assertIn('var/webhook_game_ready_server = null',config)
        self.assertIn('config.webhook_game_ready = text2num(value) == 1',config)
        example=read('config/game-ready.example.txt')
        self.assertIn('webhook_game_ready 0',example)
        self.assertNotRegex(example,r'(?m)^webhook_(?:address|key)\s+\S+')


if __name__=='__main__':unittest.main()
