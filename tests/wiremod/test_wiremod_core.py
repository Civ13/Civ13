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
        cls.ui = read(MODULE / 'core/circuit_ui.dm')
        cls.variables = read(MODULE / 'core/variables.dm')
        cls.port = read(MODULE / 'core/port.dm')
        cls.component = read(MODULE / 'core/component.dm')

    def action_table(self):
        """{action: (handler, [fields])} as written in ui_action_table()."""
        body = proc_body(self.ui, '/obj/item/integrated_circuit/proc/ui_action_table(')
        rows = [line.strip() for line in body.splitlines() if line.startswith('\t\t"')]
        table = {}
        for row in rows:
            match = re.fullmatch(r'"(\w+)" = list\(PROC_REF\((\w+)\)((?:, "\w+")*)\),', row)
            self.assertIsNotNone(match, row)
            self.assertNotIn(match.group(1), table)
            table[match.group(1)] = (match.group(2), re.findall(r'"(\w+)"', match.group(3)))
        return table

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
        actions = set(self.action_table())
        sent = set()
        for path in EDITOR.glob('*.jsx'):
            sent.update(re.findall(r"\bact\(\s*'(\w+)'", read(path)))
        # Buttons the Civ13 data never shows: per-component actions and the admin save.
        self.assertEqual(sent - actions, {'perform_action', 'save_circuit'})
        self.assertEqual(actions - sent, set())

    def test_one_table_holds_every_action(self):
        # The handler, the action's name and its fields are one entry, so an
        # action cannot be offered without a handler or handled without being
        # offered, and a handler cannot read a field the transport would drop.
        table = self.action_table()
        self.assertGreaterEqual(len(table), 15)
        defined = re.findall(r'(?m)^/obj/item/integrated_circuit/proc/(act_\w+)\(([^)]*)\)', self.ui)
        self.assertEqual(sorted(name for name, _ in defined), sorted(handler for handler, _ in table.values()))
        self.assertEqual(len(defined), len({name for name, _ in defined}))
        for name, arguments in defined:
            self.assertEqual(arguments, 'list/params, mob/user', name)
        placed = set(re.findall(r'params\["(\w+)"\]', proc_body(self.ui, '/obj/item/integrated_circuit/proc/ui_new_component(')))
        self.assertEqual(placed, {'rel_x', 'rel_y'})
        for action, (handler, fields) in table.items():
            self.assertEqual(handler, 'act_' + action)
            self.assertEqual(len(fields), len(set(fields)), action)
            self.assertLessEqual(len(fields), 7, action)  # the transport takes 8 keys, "value" included
            body = proc_body(self.ui, '/obj/item/integrated_circuit/proc/%s(' % handler)
            read_fields = set(re.findall(r'params\["(\w+)"\]', body))
            if 'ui_new_component(' in body:
                read_fields |= placed
            self.assertEqual(read_fields, set(fields), action)
        # Nothing else lists actions or fields, and nothing but the table dispatches.
        for name in ('ui_actions(', 'ui_action_fields(', 'ui_act('):
            body = proc_body(self.ui, '/obj/item/integrated_circuit/' + name)
            self.assertIn('ui_action_table()', body, name)
            self.assertNotRegex(code(body), r'\bif\(""\)|switch\(', name)
        dispatch = proc_body(self.ui, '/obj/item/integrated_circuit/ui_act(')
        self.assertIn('call(src, entry[1])(params, user)', dispatch)
        self.assertEqual(code(self.ui + self.circuit + self.variables).count('call('), 1)
        for other in (self.circuit, self.variables):
            self.assertNotIn('params[', other)

    def test_editor_input_is_checked_before_use(self):
        handler = proc_body(self.ui, '/obj/item/integrated_circuit/ui_act(')
        self.assertLess(handler.index('!can_be_edited_by(user)'), handler.index('call(src'))
        self.assertIn('return user && wiremod_circuit_state.can_use_topic(src, user) == STATUS_INTERACTIVE',
                      proc_body(self.ui, '/obj/item/integrated_circuit/proc/can_be_edited_by('))
        # The topic state is asked in that one place; every way in goes through it.
        self.assertEqual('\n'.join(self.sources.values()).count('wiremod_circuit_state.can_use_topic('), 1)
        self.assertIn('if(!can_be_edited_by(user))', proc_body(self.ui, '/obj/item/integrated_circuit/ui_interact('))
        self.assertIn('circuit?.can_be_edited_by(user)', read(MODULE / 'shell/compact_remote.dm'))
        self.assertIn('istext(action) ? ui_action_table()[action] : null', handler)
        # Components are named by a checked number, ports by a checked position,
        # variables by text only; no handler indexes a list with a raw field.
        self.assertNotRegex(self.ui, r'\[params\[')
        self.assertNotRegex(self.ui, r'attached_components\[')
        self.assertNotRegex(self.ui, r'_ports\[')
        self.assertIn('!istext(value) || !(value in circuit_variables)', self.ui)
        self.assertIn('value != round(value)', proc_body(self.ui, '/proc/wiremod_action_index('))
        port = proc_body(self.ui, '/obj/item/integrated_circuit/proc/ui_port(')
        self.assertIn('wiremod_action_index(port_value, length(ports))', port)
        self.assertIn('ui_component(component_value)', port)
        # New components come only from the fixed list or the two variable nodes.
        self.assertEqual(re.findall(r'\bnew (?!/datum/)([\w/]+)\(', self.ui), ['typepath', 'typepath'])
        self.assertEqual(self.ui.count('ui_new_component('), 3)
        printing = proc_body(self.ui, '/obj/item/integrated_circuit/proc/act_print_component(')
        self.assertIn('for(var/available_type in wiremod_available_components())', printing)
        self.assertIn('ui_new_component(typepath, params, user)', printing)
        nodes = proc_body(self.ui, '/obj/item/integrated_circuit/proc/act_add_setter_or_getter(')
        self.assertIn('? /obj/item/circuit_component/variable/setter : /obj/item/circuit_component/variable/getter', nodes)
        for source in self.sources.values():
            self.assertNotIn('text2path', source)
            self.assertNotIn('locate(', source)
        # Player text that reaches chat or examine goes through the label filter.
        self.assertIn('display_name = wiremod_clean_label(params["display_name"], 32)', self.ui)
        self.assertIn('wiremod_clean_label(params["variable_name"], 24)', self.ui)
        self.assertNotRegex(self.ui, r'\bname = (?!length)[^"\n]*params')
        self.assertIn('length(circuit_variables) >= CIRCUIT_MAX_VARIABLES', self.ui)

    def test_editor_cannot_mint_items(self):
        making = proc_body(self.ui, '/obj/item/integrated_circuit/proc/ui_new_component(')
        self.assertLess(making.index('length(attached_components) >= CIRCUIT_MAX_COMPONENTS'), making.index('new typepath(src)'))
        self.assertLess(making.index('new_component.printed = TRUE'), making.index('add_component(new_component, user)'))
        self.assertIn('qdel(new_component)', making)
        detach = proc_body(self.circuit, '/obj/item/integrated_circuit/proc/detach_component(')
        self.assertLess(detach.index('component.printed'), detach.index('put_in_hands'))
        self.assertIn('!component.removable', detach)
        self.assertIn('printed = TRUE', proc_body(self.variables, '/obj/item/circuit_component/variable\n'))

    def test_components_have_ids_that_are_never_reused(self):
        # The editor names a component by circuit_id, never by list position:
        # a request for a removed component must not reach its neighbour.
        add = proc_body(self.circuit, '/obj/item/integrated_circuit/proc/add_component(')
        self.assertIn('component.circuit_id = ++last_component_id', add)
        self.assertEqual(len(re.findall(r'last_component_id\s*(?:=|\+\+|--|[-+]=)|(?:\+\+|--)last_component_id', self.circuit + self.ui + self.variables)), 2)
        self.assertIn('var/last_component_id = 0', self.circuit)
        self.assertIn('component.circuit_id = 0', proc_body(self.circuit, '/obj/item/integrated_circuit/proc/remove_component('))
        lookup = proc_body(self.ui, '/obj/item/integrated_circuit/proc/ui_component(')
        self.assertIn('wiremod_action_index(value, last_component_id)', lookup)
        self.assertIn('component_by_id(id)', lookup)
        reference = proc_body(self.ui, '/proc/wiremod_ui_port_ref(')
        self.assertIn('"output-[component.circuit_id]-', reference)
        self.assertIn('"input-[component.circuit_id]-', reference)
        self.assertNotIn('component_index', self.ui)
        self.assertIn('"id" = component.circuit_id', self.ui)
        # The upstream editor sends list positions; the adapter turns each into
        # the id of the component shown at that position.
        adapter = read(ROOT / 'tgui/src/interfaces/WiremodCircuit.tsx')
        for field in ('component_id', 'input_component_id', 'output_component_id'):
            self.assertIn("'%s'," % field, adapter)
        self.assertIn('components[Number(adjusted[field]) - 1]?.id', adapter)
        fields = {field for _, names in self.action_table().values() for field in names}
        self.assertEqual({field for field in fields if field.endswith('component_id')},
                         {'component_id', 'input_component_id', 'output_component_id'})

    def test_every_component_type_is_offered_or_listed_as_left_out(self):
        # The menu list is kept by hand so nothing becomes reachable by accident;
        # this makes sure nothing is forgotten either.
        def listed(header):
            return re.findall(r'(?m)^\t\t(/obj/item/circuit_component/[\w/]+)(?:,| = "[^"]{10,}",)$', proc_body(self.circuit, header))
        available = listed('/proc/wiremod_available_components()')
        unlisted = listed('/proc/wiremod_unlisted_components()')
        self.assertGreaterEqual(len(available), 16)
        self.assertEqual(len(available), len(set(available)))
        self.assertEqual(len(unlisted), len(set(unlisted)))
        self.assertEqual(set(available) & set(unlisted), set())
        declared = set()
        for source in self.sources.values():
            declared.update(re.findall(r'(?m)^(/obj/item/circuit_component(?:/\w+)+)(?=\s*$|/(?:proc/)?\w+\()', source))
        declared = {re.sub(r'/proc$', '', path) for path in declared} - {'/obj/item/circuit_component'}
        self.assertEqual(declared, set(available) | set(unlisted))
        # A left-out type is one the editor's print action can never make.
        for path in unlisted:
            self.assertNotIn(path + ',', proc_body(self.circuit, '/proc/wiremod_available_components()'))

    def test_module_is_split_by_concern_and_safe_in_any_include_order(self):
        # No proc is written twice for one type: two definitions run in include
        # order, which the Dream Maker IDE changes when it re-sorts civ13.dme.
        seen = {}
        for path, source in self.sources.items():
            for owner, name in re.findall(r'(?m)^(/[\w/]*?)/(?:proc/)?(\w+)\([^\n]*\)\s*$', source):
                key = (re.sub(r'/proc$', '', owner), name)
                self.assertNotIn(key, seen, '%s and %s' % (path, seen.get(key)))
                seen[key] = path
        self.assertGreater(len(seen), 80)
        core = MODULE / 'core'
        homes = {'ui_act': 'circuit_ui.dm', 'ui_actions': 'circuit_ui.dm', 'ui_interact': 'circuit_ui.dm',
                 'circuit_editor_data': 'circuit_ui.dm', 'refresh_editor': 'circuit_ui.dm',
                 'queue_input': 'integrated_circuit.dm', 'add_component': 'integrated_circuit.dm',
                 'overload': 'integrated_circuit.dm', 'Destroy': 'integrated_circuit.dm',
                 'add_variable': 'variables.dm', 'remove_variable': 'variables.dm'}
        for name, home in homes.items():
            self.assertEqual(seen[('/obj/item/integrated_circuit', name)], core / home, name)
        self.assertEqual(seen[('/datum/circuit_variable', 'set_value')], core / 'variables.dm')
        self.assertEqual(seen[('/obj/item/circuit_component/operator', 'run_operation')], core / 'operator.dm')
        self.assertFalse('nanomanager' in self.circuit)
        # The circuit lets go of a component through a hook, not by knowing its type.
        removal = proc_body(self.circuit, '/obj/item/integrated_circuit/proc/remove_component(')
        self.assertLess(removal.index('component.removed_from_circuit(src)'), removal.index('component.disconnect()'))
        self.assertNotIn('istype(component, /obj/item/circuit_component/', self.circuit)

    def test_each_datatype_reads_typed_values_in_one_place(self):
        joined = '\n'.join(self.sources.values())
        # One list of truth words, one list of the types a player may set.
        self.assertEqual(joined.count('"true"'), 1)
        self.assertIn('"true" = TRUE', proc_body(self.port, '/proc/wiremod_parse_boolean('))
        self.assertNotRegex(joined, r'lowertext\(\w+\) in list')
        self.assertNotIn('list(PORT_TYPE_NUMBER, PORT_TYPE_BOOLEAN', joined)
        self.assertRegex(read(DEFINES), r'(?m)^#define CIRCUIT_USER_TYPES list\(PORT_TYPE_NUMBER, PORT_TYPE_BOOLEAN, PORT_TYPE_STRING, PORT_TYPE_ANY\)$')
        self.assertEqual(joined.count('CIRCUIT_USER_TYPES'), 3)
        for user in ('/datum/circuit_datatype/boolean/convert(', '/datum/circuit_datatype/boolean/parse_manual('):
            self.assertIn('wiremod_parse_boolean(value)', proc_body(self.port, user))
        self.assertIn('wiremod_parse_boolean(value)', proc_body(self.ui, '/proc/wiremod_ui_flag('))
        manual = proc_body(self.ui, '/obj/item/integrated_circuit/proc/set_manual_input(')
        self.assertIn('input_port.datatype_handler.parse_manual(manual_value)', manual)
        self.assertIn('input_port.datatype_handler.manual_error', manual)
        self.assertLess(manual.index('length(manual_value) > PORT_MAX_STRING_LENGTH'), manual.index('parse_manual'))
        # The editor code itself knows no datatype's rules.
        self.assertNotIn('text2num(manual_value)', self.ui)
        self.assertNotRegex(manual, r'PORT_TYPE_')

    def test_a_wire_hands_on_a_list_only_from_a_port(self):
        # The shortcut that skips re-validating a list takes an output port, so
        # it cannot be reached with a value no handler has checked, and only the
        # two datatypes whose convert() would merely copy the list allow it.
        receive = proc_body(self.port, '/datum/port/input/proc/receive_from(datum/port/output/output)')
        self.assertIn('if(islist(output.value) && !options && datatype_handler.keeps_port_lists)', receive)
        self.assertIn('set_value(output.value)', receive)
        self.assertEqual(self.port.count('value = output.value'), 1)
        self.assertEqual(self.port.count('keeps_port_lists = TRUE'), 2)
        for handler in ('any', 'list'):
            self.assertIn('keeps_port_lists = TRUE', proc_body(self.port, '/datum/circuit_datatype/%s\n' % handler))
        self.assertIn('var/keeps_port_lists = FALSE', self.port)
        self.assertEqual(self.port.count('receive_from('), 3)
        self.assertIn('set_value(new_value)', proc_body(self.port, '/datum/port/output/proc/set_output('))
        self.assertIn('var/list/result = list()', proc_body(self.port, '/proc/wiremod_safe_list('))
        # No component changes a port's list in place or writes a port's value itself.
        for path, source in self.sources.items():
            text = code(source)
            self.assertNotRegex(text, r'\.value\s*(\+=|-=|\|=|&=|\[[^\]]*\]\s*=[^=])', str(path))
            self.assertNotRegex(text, r'\.value\.(Add|Remove|Cut|Insert|Swap|Splice)\(', str(path))
            if path.name != 'port.dm':
                self.assertNotRegex(text, r'(?<!variable)\.value\s*=[^=]', str(path))

    def test_editor_refreshes_are_coalesced(self):
        refresh = proc_body(self.ui, '/obj/item/integrated_circuit/proc/refresh_editor()')
        self.assertLess(refresh.index('if(editor_refresh_timer || QDELETED(src))'), refresh.index('addtimer('))
        self.assertIn('if(world.time < next_editor_refresh)', refresh)
        self.assertIn('next_editor_refresh - world.time, TIMER_STOPPABLE)', refresh)
        now = proc_body(self.ui, '/obj/item/integrated_circuit/proc/refresh_editor_now()')
        self.assertIn('editor_refresh_timer = null', now)
        self.assertIn('next_editor_refresh = world.time + CIRCUIT_UI_REFRESH_INTERVAL', now)
        joined = '\n'.join(self.sources.values())
        self.assertEqual(joined.count('update_uis('), 1)
        self.assertIn('update_uis(src)', now)
        self.assertIn('refresh_editor()', proc_body(self.circuit, '/obj/item/integrated_circuit/proc/queue_input('))
        destroy = proc_body(self.circuit, '/obj/item/integrated_circuit/Destroy()')
        self.assertIn('deltimer(editor_refresh_timer)', destroy)
        self.assertRegex(read(DEFINES), r'(?m)^#define CIRCUIT_UI_REFRESH_INTERVAL [2-5]$')

    def test_operator_components_share_one_base(self):
        base = read(MODULE / 'core/operator.dm')
        ports = proc_body(base, '/obj/item/circuit_component/operator/populate_ports()')
        self.assertEqual(re.findall(r'add_(?:input|output)_port\("(\w+)"', ports), ['A', 'B', 'Operation', 'Result'])
        self.assertIn('default = operations[1], options = operations', ports)
        operators = {}
        for path, source in self.sources.items():
            for name in re.findall(r'(?m)^/obj/item/circuit_component/operator/(\w+)$', source):
                operators[name] = source
        self.assertEqual(set(operators), {'arithmetic', 'comparison', 'logic', 'string_concat', 'list_concat'})
        for name, source in operators.items():
            self.assertIn('/obj/item/circuit_component/operator/%s/operate(left, right, chosen)' % name, source)
            self.assertNotIn('add_input_port', source)
            self.assertNotIn('populate_ports', source)
            self.assertNotIn('set_output', source)

    def test_only_a_living_holder_or_neighbour_may_edit(self):
        state = proc_body(self.ui, '/datum/topic_state/wiremod_circuit/can_use_topic(')
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
                            (MODULE / 'core/variables.dm', '/datum/circuit_variable\n')):
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
        self.assertIn('open_tgui(user, ui_key, "wiremod_circuit.tmpl"', self.ui)
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
