"""Offline source checks for the Discord world save notices; no BYOND or network."""
import re
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


def source(path):
    return (ROOT / path).read_text(encoding='utf-8')


def proc(text, declaration):
    body = text.split(declaration + '\n', 1)[1]
    return re.split(r'\n(?=/)', body, maxsplit=1)[0]


class SaveNoticeTests(unittest.TestCase):
    def setUp(self):
        self.functions = source('code/modules/persistence/functions.dm')
        self.webhooks = source('code/modules/webhooks/webhooks.dm')

    def test_every_save_attempt_reports_start_and_outcome(self):
        body = proc(self.functions, '/map_storage/proc/run_world_operation(kind, datum/persistence_world_operation/operation)')
        started = body.index('if(kind == "save") notify_world_save("started", operation)')
        attempt = body.index('success = save_world_contents(operation)')
        self.assertLess(started, attempt, 'start notice goes out before the save runs')
        # admission refusals return before the notice, so a busy save is never announced
        self.assertLess(body.index('if(!operation.enter_backend(src, kind)) return FALSE'), started)
        failed = body.index('if(kind == "save") notify_world_save("finished", operation, FALSE)')
        self.assertLess(failed, body.index('throw e'), 'an exception still reports failure')
        self.assertIn('if(kind == "save") notify_world_save("finished", operation, success)', body)

    def test_notice_sink_is_optional_and_contained(self):
        body = proc(self.functions, '/proc/notify_world_save(event, datum/persistence_world_operation/operation, success = FALSE)')
        self.assertIn('text2path("/proc/webhook_send_world_save")', body)
        self.assertIn('if(!hook) return', body)
        self.assertIn('event = success ? "completed" : "failed"', body)
        self.assertIn('var/shutdown = operation && operation.shutdown_save', body)
        self.assertLess(body.index('world_save_notice_started = world.timeofday'), body.index('text2path('),
                        'the start time is kept even when the webhook module is absent')
        self.assertRegex(body, r'try\n\t\tcall\(hook\)\(event, shutdown, started\)\n\tcatch')

    def test_webhook_payload(self):
        body = proc(self.webhooks, '/proc/webhook_send_world_save(event, shutdown = FALSE, started = null)')
        self.assertIn('if(!webhook_enabled()) return', body)
        self.assertIn('webhook_send("world_save", query)', body)
        for key in ('"event" = event', '"round" = ', '"shutdown" = shutdown ? TRUE : FALSE', 'query["seconds"] = round(elapsed / 10, 0.1)'):
            self.assertIn(key, body)
        self.assertIn('if(elapsed < 0) elapsed += 864000', body)


if __name__ == '__main__':
    unittest.main()
