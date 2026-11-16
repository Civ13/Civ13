"""The generic panel window: its helpers, its screen and the owners that use it, from source."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
PANEL = (ROOT / 'code/modules/nano/tgui_panel.dm').read_text(encoding='utf-8')
SCREEN = (ROOT / 'tgui/src/interfaces/Panel.tsx').read_text(encoding='utf-8')
TYPES = (ROOT / 'tgui/src/data.ts').read_text(encoding='utf-8')
ACTION = re.compile(r'panel_button\((?:"(?:[^"\\]|\\.)*"|[^,()]+|\([^()]*\))+?,\s*"([A-Za-z_]+)"')


def owners():
    for path in sorted((ROOT / 'code').rglob('*.dm')):
        source = path.read_text(encoding='utf-8', errors='replace')
        if 'open_panel(' in source and path.name != 'tgui_panel.dm':
            yield path, source


def undeclared(source):
    declared = set(re.findall(r'"([A-Za-z_]+)"', ''.join(re.findall(r'/ui_actions\([^)]*\)\n((?:\t.*\n)+)', source))))
    used = set(ACTION.findall(source))
    # The shared document row adds an open action of the caller's choice plus rename and remove.
    rows = re.findall(r'paper_document_container_row\(\w+, "([A-Za-z_]+)"', source)
    if rows:
        used |= set(rows) | {'rename', 'remove'}
    return sorted(used - declared)


class PanelTest(unittest.TestCase):
    def test_included_and_registered(self):
        self.assertIn('#include "code\\modules\\nano\\tgui_panel.dm"', (ROOT / 'civ13.dme').read_text(encoding='utf-8'))
        self.assertIn("'panel.tmpl': Panel,", (ROOT / 'tgui/src/interfaces/index.tsx').read_text(encoding='utf-8'))
        self.assertIn('open_tgui(user, ui_key, "panel.tmpl", title, width, height, data, ui, force_open, state, FALSE, auto_update)', PANEL)

    def test_helper_fields_are_the_fields_the_screen_reads(self):
        sent = set(re.findall(r'"([a-z]+)"\]? =', PANEL))
        self.assertEqual(sent, {'label', 'action', 'id', 'disabled', 'selected', 'value', 'tone', 'buttons', 'name', 'detail',
                                'title', 'notes', 'rows', 'items', 'empty', 'sections',
                                'text', 'columns', 'table', 'image', 'series', 'points', 'slots', 'top', 'left', 'right', 'chart'})
        block = TYPES.split('export type PanelButton', 1)[1].split('export type PromptData', 1)[0]
        for field in sent:
            self.assertRegex(block, r'\b%s\?:' % field)
        # A button's value travels as "id", which the frontend never rewrites.
        self.assertIn('value={button.id ?? 1}', SCREEN)
        self.assertRegex((ROOT / 'tgui/src/state.ts').read_text(encoding='utf-8'), r'\^\(id\|key\)\$')

    def test_every_panel_button_sends_a_declared_action(self):
        found = list(owners())
        self.assertGreaterEqual(len(found), 3)
        for path, source in found:
            self.assertTrue(ACTION.findall(source) or 'panel_row(' in source or 'paper_document_container_row(' in source or 'panel_section(' in source, path.name)
            self.assertEqual(undeclared(source), [], path.name)
            self.assertNotRegex(source, r'show_browse\([^\n]*window=(safe|filingcabinet|tablet_press)', path.name)

    def test_negative_control_undeclared_action_is_reported(self):
        sample = '/obj/x/ui_actions(ui_key)\n\treturn list("open")\n\n/obj/x/ui_interact()\n\tpanel_button("[open ? "Close" : "Open"] it", "open")\n\tpanel_button("Take", "retrieve", "\\ref[P]")\n'
        self.assertEqual(undeclared(sample), ['retrieve'])
        rows = '/obj/x/ui_actions(ui_key)\n\treturn list("read", "remove")\n\n/obj/x/ui_interact()\n\tpaper_document_container_row(P, "look", "Look")\n'
        self.assertEqual(undeclared(rows), ['look', 'rename'])

    def test_object_refresh_reaches_manager_windows(self):
        objs = (ROOT / 'code/game/objects/objs.dm').read_text(encoding='utf-8', errors='replace')
        for proc in ('updateUsrDialog', 'updateDialog'):
            body = objs.split('/obj/proc/%s()' % proc, 1)[1].split('\n/', 1)[0]
            self.assertIn('GLOB.nanomanager.update_uis(src)', body)


if __name__ == '__main__':
    unittest.main()
