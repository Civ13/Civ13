from pathlib import Path
import html
import importlib.util
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('newspaper_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


def read_newspaper(writing):
    source = adapter.read('code/modules/1713/newspaper.dm')
    # The old parent attack_self is a no-op. Model that engine boundary so
    # the same behavioral test executes both the old and changed procedures.
    source = source.replace('return ..(user)', 'return FALSE', 1)
    messages = []
    env = {'to_chat': lambda user, text: messages.append(text),
           'SPAN_NOTICE': lambda text: text,
           'html_encode': lambda text: html.escape(text, quote=True),
           'html_decode': html.unescape}
    proc = adapter.project(source, '/obj/item/weapon/newspaper/attack_self', 'src, user', env)
    result = proc(SimpleNamespace(scribble=writing), object())
    return result, messages


class NewspaperReadingTest(unittest.TestCase):
    def test_written_text_can_be_read_safely(self):
        result, messages = read_newspaper('Price &lt; 5')
        self.assertTrue(result)
        self.assertIn('Price &lt; 5', messages)
        self.assertNotIn('Price < 5', messages)

    def test_writer_sanitizes_only_once(self):
        source = adapter.read('code/modules/1713/newspaper.dm')
        body = adapter.extract(source, 'obj/item/weapon/newspaper/attackby')
        self.assertEqual(body.count('sanitize('), 1)

    def test_blank_newspaper_does_not_display_stale_writing(self):
        result, messages = read_newspaper('')
        self.assertTrue(result)
        self.assertEqual(messages, ['There is no writing on the newspaper.'])


if __name__ == '__main__':
    unittest.main()
