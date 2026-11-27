"""Planned shutdown notices (code/modules/persistence/shutdown_notice.dm): source wiring.

The native countdown probe is developer evidence, outside the offline suite (it runs for
about 40 seconds): python3 tests/shutdown_notice/run.py
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(relative):
    return (ROOT / relative).read_text(encoding='utf-8')


class ShutdownNoticeSources(unittest.TestCase):
    def test_module_is_compiled_and_the_cancel_verb_is_offered(self):
        self.assertIn('#include "code\\modules\\persistence\\shutdown_notice.dm"', read('civ13.dme'))
        self.assertIn('/datum/admins/proc/cancel_planned_shutdown,', read('code/modules/admin/admin_verbs.dm'))

    def test_transaction_counts_down_through_a_runtime_hook(self):
        # The standalone transaction fixture compiles without shutdown_notice.dm.
        transaction = read('code/modules/persistence/restart_transaction.dm')
        self.assertNotIn('planned_shutdown_countdown(', transaction.replace('"/proc/planned_shutdown_countdown"', ''))
        self.assertIn('text2path("/proc/planned_shutdown_countdown")', transaction)
        self.assertIn('if(called_off) throw EXCEPTION(', transaction)
        self.assertIn('text2path("/proc/planned_shutdown_clear")', transaction)

    def test_lifecycle_takes_an_optional_bounded_warning(self):
        lifecycle = read('code/modules/persistence/nomads_lifecycle.dm')
        self.assertIn('if((action == "save_shutdown" || action == "handover_save") && ("warn" in input)) allowed += "warn"', lifecycle)
        self.assertIn('requested_warning < 0 || requested_warning > 3600', lifecycle)
        self.assertIn('"shutdown_warning" = TRUE, "shutdown_in" = planned_shutdown_remaining()', lifecycle)

    def test_every_planned_restart_path_uses_the_countdown(self):
        self.assertIn('planned_shutdown_countdown("reboot", delay, "restart by an admin")', read('code/modules/admin/admin.dm'))
        self.assertIn('planned_shutdown_countdown("reboot", 0, "immediate reboot by an admin")', read('code/modules/admin/admin.dm'))
        self.assertIn('planned_shutdown_countdown("restart", 300, "scheduled maintenance reboot", defer_for_vehicle_risk = TRUE)', read('code/world.dm'))
        self.assertIn('planned_shutdown_countdown("reboot", delay,', read('code/modules/agent_control/agent_actions.dm'))
        self.assertIn('warn_seconds = warn_seconds)', read('code/modules/persistence/admin.dm'))
        self.assertIn('planned_shutdown_status_text()', read('code/game/mob/mob.dm'))

    def test_reboot_links_rejoin_text_without_changing_tdm_handoff(self):
        world = read('code/world.dm')
        reboot = world.split('/world/Reboot(', 1)[1].split('#define COLOR_LIGHT_SEPIA', 1)[0]
        notice = reboot.split('tdm_battle.before_reboot()\n\t\telse\n', 1)[1].split('\n\t\tsleep(sleeptime)', 1)[0]
        self.assertIn(r'<a href=\"[rejoin_url]\">Click here to rejoin</a>', notice)
        self.assertIn('shard_group.relay_on() ? shard_group.gate_address() : null', notice)
        self.assertIn('if(!rejoin_address && world.internet_address && port)', notice)
        self.assertIn('rejoin_address = "[world.internet_address]:[port]"', notice)
        self.assertIn('if(rejoin_address)', notice)
        self.assertIn('html_encode("byond://[rejoin_address]")', notice)
        fallback = notice.split('\n\t\t\telse\n', 1)[1]
        self.assertIn('Reconnect from the BYOND pager', fallback)
        self.assertNotIn('href=', fallback)

    def test_vehicle_risk_gate_is_bounded_and_rechecks_live_piloting(self):
        notice = read('code/modules/persistence/shutdown_notice.dm')
        wait = notice.split('/proc/persistence_wait_for_safe_vehicle_state(', 1)[1].split('\n/proc/', 1)[0]
        limit = int(re.search(r'var/deadline = world.time \+ (\d+)', wait)[1])
        interval = int(re.search(r'sleep\(min\((\d+), deadline - world.time\)\)', wait)[1])
        self.assertEqual((limit, interval), (1200, 50))
        first, then = wait.split('while(world.time < deadline)', 1)
        self.assertIn('if(!vehicle_scheduled_save_risk()) return TRUE', first)
        self.assertNotIn('deadline =', then)
        self.assertIn('if(!vehicle_scheduled_save_risk()) break', then)
        self.assertIn('planned_shutdown_serial != notice_serial) return FALSE', then)
        provider = notice.split('/proc/vehicle_scheduled_save_risk()', 1)[1].split('\n/proc/', 1)[0]
        self.assertIn('text2path("/proc/any_crew_at_capsize_risk")', provider)
        self.assertIn('text2path("/proc/any_flight_at_disconnect_risk")', provider)

    def test_countdown_retains_cancel_during_wait_but_not_forced_reboot(self):
        notice = read('code/modules/persistence/shutdown_notice.dm')
        body = notice.split('/proc/planned_shutdown_countdown(', 1)[1].split('\n/proc/', 1)[0]
        wait = body.index('persistence_wait_for_safe_vehicle_state(serial)')
        self.assertIn('defer_for_vehicle_risk = FALSE', body)
        self.assertLess(body.index('while(world.time < at - mark * 10)'), wait)
        self.assertGreater(body.index('planned_shutdown_cancellable = FALSE // the stop is under way'), wait)
        immediate = read('code/modules/admin/admin.dm')
        self.assertIn('planned_shutdown_countdown("reboot", 0, "immediate reboot by an admin")', immediate)

    def test_routine_restart_and_handover_wait_before_save_or_world_moving(self):
        transaction = read('code/modules/persistence/restart_transaction.dm').split('/proc/execute(', 1)[1]
        self.assertLess(transaction.index('"moving to an updated build", TRUE, TRUE, TRUE'),
                        transaction.index('set_world_moving(TRUE)'))
        self.assertIn('stopped_by ? "requested by [stopped_by]" : null, TRUE, TRUE, TRUE', transaction)
        self.assertLess(transaction.index('if(prewarned && !handover)'), transaction.index('if(!save_generation_settled())'))
        self.assertLess(transaction.index('call(vehicle_wait)()'), transaction.index('if(!save_generation_settled())'))
        self.assertIn('if(clear_notice && !called_off)', transaction)

    def test_host_shutdown_completion_does_not_promise_restart(self):
        transaction = read('code/modules/persistence/restart_transaction.dm')
        completion = transaction.split('diagnostic_phase = "final_validation"', 1)[1]
        host_shutdown = completion.split('else if(shutdown)', 1)[1].split('else if(stay_down)', 1)[0]
        self.assertIn('else if(prewarned)', host_shutdown)
        fresh, maintenance = host_shutdown.split('else if(prewarned)', 1)
        maintenance, neutral = maintenance.split('\n\t\t\telse\n', 1)
        self.assertIn('restarting into a fresh nonpersistent round', fresh)
        self.assertIn('The server is restarting; reconnect', maintenance)
        self.assertIn('The server is shutting down. Your progress has been saved.', neutral)
        self.assertNotIn('restarting', neutral)
        self.assertNotIn('reconnect', neutral)
        self.assertIn('write_stop_marker("host")', neutral)

    def test_round_save_and_shutdown_notices_name_their_region(self):
        webhooks = read('code/modules/webhooks/webhooks.dm')
        helper = webhooks[webhooks.index('/proc/webhook_add_region('):]
        helper = helper[:helper.index('\n/proc/', 1)]
        self.assertIn('shard_group.enabled', helper)
        self.assertIn('query["region"] = shard_group.region', helper)
        self.assertIn('query["region_name"] = copytext(shard_group.name, 1, 81)', helper)
        for proc in ('/proc/webhook_send_round_start(', '/proc/webhook_send_world_save('):
            body = webhooks[webhooks.index(proc):]
            body = body[:body.index('\n/proc/', 1)]
            self.assertIn('webhook_add_region(query)', body, proc)
        notice = read('code/modules/persistence/shutdown_notice.dm')
        body = notice[notice.index('/proc/planned_shutdown_webhook('):]
        self.assertLess(body.index('webhook_add_region(query)'), body.index('webhook_send("shutdown_notice", query)'))
        # The standalone countdown probe compiles shutdown_notice.dm alone, so it stubs the helper.
        self.assertIn('/proc/webhook_add_region(list/query) return query', read('tests/shutdown_notice/probe.dm'))


if __name__ == '__main__':
    unittest.main()
