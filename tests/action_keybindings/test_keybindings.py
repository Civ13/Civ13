"""Offline skin, persistence wiring and source-bound key policy checks.

No engine is launched. Native fixture acceptance is reported separately.
"""
import ast
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = 'code/modules/client/action_keybindings.dm'
SAVE = 'code/modules/client/preferencesSQLite/preferences_saving&loading&del.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def strings(text):
    return re.findall(r'"([^"\n]*)"', text)


def catalog(source):
    rows = re.findall(r'^\t\t"(\w+)" = list\("([^"]+)", "([^"]+)", list\(([^)]*)\), list\(([^)]*)\)\)', source, re.M)
    if len(rows) != 13:
        raise AssertionError('Catalog grammar or action count changed; review skin capacity')
    return {key: (label, command, strings(normal), strings(hotkey)) for key, label, command, normal, hotkey in rows}


def skin(source):
    modes = {}
    for mode, body in re.findall(r'^macro "(\w+)"\n(.*?)(?=^(?:macro|menu|window) |\Z)', source, re.M | re.S):
        modes[mode] = []
        for identifier, params in re.findall(r'^\telem([^\n]*)\n((?:\t\t[^\n]*\n|\n)*)', body, re.M):
            name = re.search(r'^\t\tname = "([^"]*)"$', params, re.M)
            command = re.search(r'^\t\tcommand = "(.*)"$', params, re.M)
            if not name or not command:
                raise AssertionError('Unsupported macro declaration')
            modes[mode].append({'id': identifier.strip().strip('"'), 'key': name[1], 'command': command[1],
                                'disabled': 'is-disabled = true' in params})
    return modes


def candidates(source, mode):
    bases = strings(re.search(r'var/list/bases = list\(([^\n]*)\)', source)[1])
    modifiers = strings(re.search(r'for \(var/modifier in list\(([^\n]*)\)\)', source)[1])
    typing_plain = strings(re.search(r'!\(base in list\(([^\n]*)\)\)', source)[1])
    return {modifier + base for base in bases for modifier in modifiers
            if mode != 'macro' or (modifier != 'SHIFT+' and (modifier or base in typing_plain))}


def reserved(source, mode):
    body = source.split('/proc/action_keybinding_reserved(mode)')[1].split('/datum/preferences')[0]
    base = strings(re.search(r'var/list/keys = list\(([^\n]*)\)', body)[1])
    extra = strings(re.search(r'keys \+= list\(([^\n]*)\)', body)[1])
    return set(base + (extra if mode == 'hotkeymode' else []))


def slot_guard(source):
    # DM's `in` has lower precedence than ||. Require parenthesized membership
    # operands before projecting this one expression into Python.
    line = next(line.strip() for line in source.splitlines() if 'slot in bindings' in line)
    if line != 'if (!(slot in bindings) || (slot in seen))':
        raise AssertionError('Slot membership must stay parenthesized')
    expression = line[4:-1].replace('!', 'not ').replace('||', ' or ')
    tree = ast.parse(expression, mode='eval')
    return lambda slot, bindings, seen: eval(compile(tree, '<production slot guard>', 'eval'),
                                            {'__builtins__': {}}, dict(slot=slot, bindings=bindings, seen=seen))


class Keybindings(unittest.TestCase):
    def test_factory_defaults_and_every_fixed_macro_are_preserved(self):
        frozen = json.loads(Path(__file__).with_name('default_macros.json').read_text())
        current = skin(read('interface/skin.dmf'))
        for mode in frozen:
            self.assertEqual(sorted((row['key'], row['command']) for row in frozen[mode]),
                             sorted((row['key'], row['command']) for row in current[mode] if not row['disabled']))
            fixed = {row['key']: row for row in current[mode] if not row['id'].startswith('action_')}
            for row in frozen[mode]:
                if row['key'] in fixed:
                    self.assertEqual(fixed[row['key']], row)

    def test_catalog_has_exact_two_slot_capacity_and_static_commands(self):
        entries = catalog(read(SOURCE))
        for mode, rows in skin(read('interface/skin.dmf')).items():
            managed = {row['id']: row for row in rows if row['id'].startswith('action_')}
            self.assertEqual(len(managed), 26)
            for action, (_, command, normal, hotkey) in entries.items():
                defaults = normal if mode == 'macro' else hotkey
                for index in range(2):
                    row = managed[f'action_{action}_{index + 1}']
                    self.assertEqual(row['command'], command)
                    self.assertEqual(row['key'], defaults[index] if index < len(defaults) else '')
                    self.assertEqual(row['disabled'], index >= len(defaults))

    def test_available_keys_cannot_shadow_fixed_or_release_macros(self):
        source = read(SOURCE)
        for mode, rows in skin(read('interface/skin.dmf')).items():
            available = candidates(source, mode) - reserved(source, mode)
            for row in rows:
                if not row['id'].startswith('action_'):
                    self.assertNotIn(row['key'], available)
            for key in available:
                self.assertNotRegex(key, r'[;&=|/{}"\[\]]|UP|REP|Any|Mouse')
                self.assertNotIn(key.split('+')[-1], ('W', 'A', 'S', 'D', 'Q', 'R', 'X', 'Y', 'Z'))
            if mode == 'macro':
                self.assertEqual({key for key in available if '+' not in key}, {'F', 'Space'})
                self.assertIn('if (mode == "macro" && modifier == "SHIFT+")\n\t\t\t\tcontinue', source)
                self.assertNotIn('SHIFT+K', available)

    def test_slot_guard_rejects_unknown_and_duplicate_records_and_control(self):
        source = read(SOURCE)
        reject = slot_guard(source)
        valid = {'macro/aim', 'hotkeymode/prone'}
        for slot in ('unknown/prone', 'macro/unknown', 'macro/aim/extra', '', None):
            self.assertTrue(reject(slot, valid, set()))
        self.assertTrue(reject('macro/aim', valid, {'macro/aim'}))
        self.assertFalse(reject('macro/aim', valid, set()))
        with self.assertRaises(AssertionError):
            slot_guard(source.replace('|| (slot in seen)', '|| slot in seen'))

    def test_persistence_and_reconnect_are_wired_to_current_owner(self):
        saving = read(SAVE)
        self.assertIn('vars_to_save += "action_keybindings"', saving)
        self.assertIn('sanitize_action_keybindings()\n\tif (client && client.prefs == src)\n\t\tclient.apply_action_keybindings()', saving)
        connecting = read('code/modules/client/client_procs.dm').split('/client/New(TopicData)')[1].split('/client/MouseEntered')[0]
        self.assertLess(connecting.index('prefs.client = src'), connecting.index('. = ..()'))
        self.assertIn('apply_action_keybindings()', connecting)
        self.assertIn('client.apply_action_keybindings()', read('code/game/mob/login.dm'))

    def test_apply_changes_only_owned_skin_slots_without_focus_or_key_state(self):
        source = read(SOURCE)
        apply = source.split('/client/proc/apply_action_keybindings()')[1].split('/client/verb/')[0]
        apply = re.sub(r'//[^\n]*', '', apply)
        self.assertEqual(apply.count('winset('), 2)
        self.assertNotRegex(apply, r'focus|macro=|command|moving\s*=|disactivation\(')
        self.assertLess(apply.index('"is-disabled" = "true"'), apply.index('"name" = keys[i]'))
        self.assertIn('"[mode].action_[action]_[i]"', apply)

    def test_saved_records_are_bounded_validated_and_applied_atomically(self):
        source = read(SOURCE)
        for guard in ('!islist(records) || records.len > bindings.len', '!istext(record) || length(record) > 100',
                      'parts.len != 3', 'key != "NONE" && !(key in action_keybinding_candidates(mode))',
                      'if (key in used)'):
            self.assertIn(guard, source)
        setter = source.split('/datum/preferences/proc/set_action_keybinding(')[1].split('/client/proc/')[0]
        self.assertLess(setter.index('if (!action_keybinding_map(updated))'), setter.index('action_keybindings = updated'))

    def test_ui_cancellation_and_final_validation_follow_yielding_prompts(self):
        ui = read(SOURCE).split('/client/verb/configure_action_keybindings()')[1]
        self.assertIn('set category = "OOC"', ui)
        self.assertIn('as null|anything in available', ui)
        self.assertLess(ui.rindex('if (!src || prefs != owner)'), ui.index('owner.set_action_keybinding('))
        self.assertLess(ui.index('owner.set_action_keybinding('), ui.rindex('owner.save_preferences()'))
        self.assertIn('available -= bindings["[mode]/[other]"]', ui)
        self.assertIn('if (!key)\n\t\t\t\tcontinue', ui)
        self.assertIn('factory defaults', read('interface/interface.dm'))


if __name__ == '__main__':
    unittest.main()
