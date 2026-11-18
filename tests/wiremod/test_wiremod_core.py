"""Offline source checks for the integrated circuit (Wiremod) module.

Behaviour is covered on the engine by run.py with probe.dm; these checks hold the
rules that keep that behaviour safe and need no compiler.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE = ROOT / 'code/modules/wiremod'
DEFINES = ROOT / 'code/__defines/wiremod.dm'
EDITOR = ROOT / 'tgui/src/interfaces/IntegratedCircuit'


def read(path):
    return path.read_text(encoding='utf-8')


def code(text):
    """Source without comments or string contents."""
    text = re.sub(r'//[^\n]*', '', text)
    return re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', text)


def proc_body(text, header):
    start = text.index(header)
    end = re.search(r'\n(?=/)', text[start + 1:])
    return text[start:start + 1 + end.start()] if end else text[start:]


class WiremodSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.files = sorted(MODULE.rglob('*.dm'))
        cls.sources = {path: read(path) for path in cls.files}
        cls.circuit = read(MODULE / 'core/integrated_circuit.dm')
        cls.port = read(MODULE / 'core/port.dm')

    def test_every_module_file_is_included_once(self):
        dme = read(ROOT / 'civ13.dme')
        self.assertGreaterEqual(len(self.files), 20)
        for path in self.files + [DEFINES]:
            include = '#include "%s"' % str(path.relative_to(ROOT)).replace('/', '\\')
            self.assertEqual(dme.count(include), 1, include)

    def test_constants_live_in_the_shared_defines_folder(self):
        # The Dream Maker IDE re-sorts civ13.dme, so a define used by another
        # file must not depend on include order.
        for path, source in self.sources.items():
            self.assertNotRegex(source, r'(?m)^\s*#\s*define\b', str(path))
        defines = read(DEFINES)
        for name in ('PORT_TYPE_NUMBER', 'PORT_MAX_STRING_LENGTH', 'CIRCUIT_MAX_LIST_LENGTH',
                     'CIRCUIT_MAX_EXECUTIONS', 'CIRCUIT_MAX_COMPONENTS', 'CIRCUIT_MAX_VARIABLES',
                     'CIRCUIT_OVERLOAD_COOLDOWN', 'CIRCUIT_DELAY_MIN', 'CIRCUIT_DELAY_MAX'):
            self.assertRegex(defines, r'(?m)^#define %s\b' % name)
        # Item sizes use Civ13's own names, not tgstation's.
        for source in list(self.sources.values()) + [defines]:
            self.assertNotIn('WEIGHT_CLASS_', source)

    def test_in_is_never_mixed_with_a_logical_operator_unparenthesised(self):
        # DM binds `in` more loosely than && and ||: `a || b in list` is
        # `(a || b) in list`. The submitted port rejected number-to-number links
        # this way. Every `in` beside && or || must sit in its own parentheses.
        for path, source in self.sources.items():
            for number, line in enumerate(code(source).splitlines(), 1):
                if re.match(r'\s*for\s*\(', line):
                    continue
                self.assertNotRegex(line, r'(\|\||&&)\s*!?[\w.\[\]?]+\s+in\s', '%s:%d' % (path, number))
                self.assertNotRegex(line, r'[^(\s!]\s*[\w.\[\]?]+\s+in\s+(list\([^()]*\)|[\w.]+)\s*(\|\||&&)', '%s:%d' % (path, number))

    def test_ports_hold_plain_values_only(self):
        for handler in ('any', 'number', 'boolean', 'string', 'signal', 'list'):
            self.assertIn('/datum/circuit_datatype/%s' % handler, self.port)
        base = proc_body(self.port, '/datum/circuit_datatype/proc/convert(value)')
        self.assertIn('wiremod_safe_value(value)', base)
        self.assertIn('isnan(value) || isinf(value)', self.port)
        self.assertIn('length(result) < CIRCUIT_MAX_LIST_LENGTH', self.port)
        self.assertIn('copytext(value, 1, PORT_MAX_STRING_LENGTH + 1)', self.port)
        # No handler turns an object into text or passes it through.
        self.assertNotIn('/atom', self.port)
        remote = read(MODULE / 'shell/compact_remote.dm')
        self.assertNotRegex(remote, r'set_output\(user\)')
        self.assertIn('user.name', remote)

    def test_deleted_ports_and_components_release_each_other(self):
        destroy = proc_body(self.port, '/datum/port/Destroy()')
        self.assertIn('connected_component = null', destroy)
        self.assertIn('disconnect()', proc_body(self.port, '/datum/port/input/Destroy()'))
        self.assertIn('disconnect_all()', proc_body(self.port, '/datum/port/output/Destroy()'))
        component = read(MODULE / 'core/component.dm')
        self.assertIn('parent.remove_component(src)', proc_body(component, '/obj/item/circuit_component/Destroy()'))
        circuit_destroy = proc_body(self.circuit, '/obj/item/integrated_circuit/Destroy()')
        self.assertIn('qdel(component)', circuit_destroy)
        self.assertIn('qdel(circuit_variables[variable_name])', circuit_destroy)
        self.assertIn('deltimer(timer_id)', read(MODULE / 'components/utility/delay.dm'))

    def test_execution_is_bounded_and_recovers(self):
        queue = proc_body(self.circuit, '/obj/item/integrated_circuit/proc/queue_input(')
        self.assertIn('length(execution_queue) >= CIRCUIT_MAX_EXECUTIONS', queue)
        self.assertIn('world.time < overloaded_until', queue)
        self.assertIn('try', queue)
        self.assertLess(queue.index('is_executing = FALSE'), queue.index('throw failure'))
        # A feedback loop is a player's wiring, not a code fault: no runtime log.
        self.assertNotIn('stack_trace', queue)
        # No sleeping or detached procs anywhere in the module.
        for path, source in self.sources.items():
            self.assertNotRegex(code(source), r'\b(spawn|sleep)\s*\(', str(path))

    def test_editor_actions_match_what_the_editor_sends(self):
        actions = set(re.findall(r'"(\w+)"', proc_body(self.circuit, '/obj/item/integrated_circuit/ui_actions(')))
        sent = set()
        for path in EDITOR.glob('*.jsx'):
            sent.update(re.findall(r"\bact\(\s*'(\w+)'", read(path)))
        # Buttons the Civ13 data never shows: per-component actions and the admin save.
        self.assertEqual(sent - actions, {'perform_action', 'save_circuit'})
        self.assertEqual(actions - sent, set())
        handler = proc_body(self.circuit, '/obj/item/integrated_circuit/ui_act(')
        for action in actions:
            self.assertIn('if("%s")' % action, handler)
        # Every field the handler reads is one the transport is told to allow.
        fields = set(re.findall(r'"(\w+)"', proc_body(self.circuit, '/obj/item/integrated_circuit/ui_action_fields(')))
        for key in set(re.findall(r'params\["(\w+)"\]', handler)):
            self.assertIn(key, fields)

    def test_editor_input_is_checked_before_use(self):
        handler = proc_body(self.circuit, '/obj/item/integrated_circuit/ui_act(')
        self.assertLess(handler.index('wiremod_circuit_state.can_use_topic(src, user) != STATUS_INTERACTIVE'), handler.index('switch(action)'))
        # Components are named by a checked position, variables by text only.
        self.assertNotRegex(handler, r'attached_components\[(?!length)')
        self.assertNotRegex(handler, r'circuit_variables\[params')
        self.assertIn('!istext(value) || !(value in circuit_variables)', self.circuit)
        self.assertIn('value != round(value)', proc_body(self.circuit, '/proc/wiremod_action_index('))
        # New components come only from the fixed list.
        self.assertEqual(re.findall(r'\bnew (\w+)\(', handler), ['typepath'])
        self.assertIn('for(var/available_type in wiremod_available_components())', handler)
        self.assertNotIn('text2path', self.circuit)
        self.assertNotIn('locate(', self.circuit)
        # Player text that reaches chat or examine goes through the label filter.
        self.assertIn('display_name = wiremod_clean_label(params["display_name"], 32)', handler)
        self.assertIn('wiremod_clean_label(params["variable_name"], 24)', handler)
        self.assertNotRegex(handler, r'\bname = (?!length)[^"\n]*params')
        self.assertIn('length(circuit_variables) >= CIRCUIT_MAX_VARIABLES', handler)

    def test_editor_cannot_mint_items(self):
        handler = proc_body(self.circuit, '/obj/item/integrated_circuit/ui_act(')
        self.assertIn('new_component.printed = TRUE', handler)
        detach = proc_body(self.circuit, '/obj/item/integrated_circuit/proc/detach_component(')
        self.assertLess(detach.index('component.printed'), detach.index('put_in_hands'))
        self.assertIn('!component.removable', detach)

    def test_only_a_living_holder_or_neighbour_may_edit(self):
        state = proc_body(self.circuit, '/datum/topic_state/wiremod_circuit/can_use_topic(')
        self.assertIn('!istype(user, /mob/living)', state)
        self.assertIn('user.stat', state)
        self.assertIn('user.restrained()', state)
        self.assertIn('isturf(holder.loc) && holder.Adjacent(user)', state)

    def test_examine_prints_instead_of_appending_to_a_number(self):
        examine = proc_body(self.circuit, '/obj/item/integrated_circuit/examine(')
        self.assertNotIn('. +=', examine)
        self.assertIn('to_chat(user', examine)

    def test_circuits_stay_out_of_persistent_saves(self):
        for path, owner in ((MODULE / 'core/integrated_circuit.dm', '/obj/item/integrated_circuit\n'),
                            (MODULE / 'core/component.dm', '/obj/item/circuit_component\n'),
                            (MODULE / 'shell/compact_remote.dm', '/obj/item/compact_remote\n'),
                            (MODULE / 'core/port.dm', '/datum/port\n'),
                            (MODULE / 'core/integrated_circuit.dm', '/datum/circuit_variable\n')):
            self.assertIn('should_save = FALSE', proc_body(read(path), owner), owner)

    def test_shared_signal_stub_is_left_alone(self):
        # The port once replaced the unused signal stub in code/datums/datum.dm;
        # the module registers no signals and must not need it.
        for source in self.sources.values():
            self.assertNotIn('RegisterSignal', source)
            self.assertNotIn('SEND_SIGNAL', source)

    def test_module_does_not_depend_on_tgstation_ui_or_hardware(self):
        joined = '\n'.join(self.sources.values())
        for token in ('/datum/tgui', 'SStgui', '/obj/machinery/component_printer',
                      '/obj/item/stock_parts/power_store', 'GLOB.integrated_circuits'):
            self.assertNotIn(token, joined)

    def test_editor_is_registered_and_sends_plain_values(self):
        self.assertIn('open_tgui(user, ui_key, "wiremod_circuit.tmpl"', self.circuit)
        self.assertIn("'wiremod_circuit.tmpl': WiremodCircuit", read(ROOT / 'tgui/src/interfaces/index.tsx'))
        adapter = read(ROOT / 'tgui/src/interfaces/WiremodCircuit.tsx')
        self.assertIn('value === null || value === undefined', adapter)
        self.assertIn("typeof value === 'boolean'", adapter)
        self.assertIn('export type Params = Record<string, string | number>;', read(ROOT / 'tgui/src/types.ts'))

    def test_editor_layout_matches_the_upstream_pointer_maths(self):
        # The editor subtracts a 32px title bar from pointer positions; the
        # Civ13 layout must provide that bar or every wire is drawn too high.
        self.assertIn('export const ABSOLUTE_Y_OFFSET = -32;', read(EDITOR / 'constants.ts'))
        layout = read(EDITOR / 'wiremod-compat.scss')
        self.assertRegex(layout, r'\.wiremod-window__content \{[^}]*top: 32px;')
        self.assertRegex(layout, r'\.wiremod-window__buttons \{[^}]*height: 32px;')
        # Icon glyphs are written as escapes: a literal one makes Sass emit a
        # byte-order mark, which lands after the bundle banner and voids the
        # first rule of the whole stylesheet.
        self.assertTrue(layout.isascii())
        self.assertNotIn('\ufeff', read(ROOT / 'UI/tgui/civ13-tgui.css'))
        # Every icon the editor names has a glyph (Civ13 ships no icon font).
        icons = set()
        for path in EDITOR.glob('*.jsx'):
            icons.update(re.findall(r'icon="([a-z-]+)"', read(path)))
        for icon in icons | {'plus', 'minus', 'chevron-down'}:
            self.assertIn('.Icon.fa-%s::before' % icon, layout, icon)

    def test_borrowed_work_is_credited(self):
        readme = read(MODULE / 'README.md')
        for text in ('Terrariola', 'tgstation', 'AGPL-3.0', 'CC BY-SA 3.0'):
            self.assertIn(text, readme)
        for icon in ('icons/obj/devices/circuitry_n_data.dmi', 'icons/obj/science/circuits.dmi'):
            self.assertTrue((ROOT / icon).is_file(), icon)
            notice = read(ROOT / (icon + '.LICENSE.md'))
            self.assertIn('CC BY-SA 3.0', notice)
            self.assertIn('tgstation/tgstation', notice)
        third_party = read(ROOT / 'tgui/THIRD_PARTY.md')
        self.assertIn('IntegratedCircuit', third_party)
        self.assertIn('AGPL-3.0', third_party)


    def test_players_craft_the_circuit_and_remote(self):
        recipes = read(ROOT / 'config/crafting/material_recipes_global.txt')
        admin_only = read(ROOT / 'code/game/mob/crafting_atlas_admin.dm')
        for path in ('/obj/item/integrated_circuit', '/obj/item/compact_remote'):
            line = re.search(r'^RECIPE: /material/electronics/,[^,]+,' + re.escape(path) + r',.*$', recipes, re.M)
            self.assertIsNotNone(line, path)
            self.assertNotIn('//', line.group(0))
            self.assertNotIn(path + ' =', admin_only)
        self.assertIn('/obj/item/circuit_component =', admin_only)


if __name__ == '__main__':
    unittest.main()
