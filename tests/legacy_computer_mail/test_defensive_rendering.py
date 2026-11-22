"""Source-level Monkeysoft mail rendering contracts; no browser or native run."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
PROGRAMS = (ROOT / "code/modules/1713/computers/programs.dm").read_text()
MAIL = PROGRAMS.split("// Mail is stored as text;", 1)[1].split(
    "/////////////////////DEEPNET MARKETPLACE", 1)[0]


class LegacyMailRenderingTests(unittest.TestCase):
    def test_all_message_fields_are_escaped_in_mail_output(self):
        display = "\n".join(
            line for line in MAIL.splitlines()
            if "mainbody" in line and not line.lstrip().startswith("//")
        )
        fields = r'em\.\w+|chosen\.\w+|cname|tmp_comp_vars\["mail_\w+"\]'
        self.assertNotRegex(display, rf'\[({fields})\]')
        for field in ("em.subject", "chosen.subject", 'tmp_comp_vars["mail_subj"]'):
            self.assertIn(f"[monkeysoftmail_text_html({field})]", display)
        for field in ("chosen.message", 'tmp_comp_vars["mail_msg"]'):
            self.assertIn(f"[monkeysoftmail_body_html({field})]", display)

    def test_reply_and_storage_are_plain_text(self):
        reply = re.search(r'tmp_comp_vars\["mail_msg"\] = "___[^\n]+', MAIL)
        self.assertIsNotNone(reply)
        self.assertIn(r"\n[chosen.message]", reply.group())
        self.assertNotIn("<br>", reply.group())
        self.assertIn('eml.message = tmp_comp_vars["mail_msg"]', MAIL)
        self.assertIn('eml.subject = tmp_comp_vars["mail_subj"]', MAIL)

    def test_only_renderer_inserts_fixed_line_breaks_after_escaping(self):
        self.assertIn('return html_encode("[value]")', MAIL)
        escaped = MAIL.index("var/encoded = monkeysoftmail_text_html(value)")
        rendered = MAIL.index(r'return replacetext(encoded, "\n", "<br>")')
        self.assertLess(escaped, rendered)


if __name__ == "__main__":
    unittest.main()
