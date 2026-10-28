"""Strict adapter for the two small production preflight helpers only.

This is neither a DM compiler nor a BYOND savefile implementation. Unknown syntax
fails; file/field/list behavior below is synthetic. Tests also pin the actual
serializer's scalar envelope shape. Never describe these checks as engine evidence.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]


def procedure(source, signature):
    start = source.index(signature)
    tail = source[start + len(signature):]
    end = re.search(r"\n/[^/*]", tail)
    return source[start:start + len(signature) + end.start()] if end else source[start:]


class DMList(list):
    def Find(self, item):
        return self.index(item) + 1 if item in self else 0

    def __getitem__(self, key):
        return None if isinstance(key, str) else super().__getitem__(key)


class FileEntry(dict):
    @property
    def dir(self):
        return DMList(self.keys())

    def __getitem__(self, key):
        return self.get(key)


def expression(text):
    parts = re.split(r'("(?:\\.|[^"\\])*")', text)
    for i in range(0, len(parts), 2):
        part = parts[i].replace('&&', ' and ').replace('||', ' or ')
        part = re.sub(r'!(?!=)', 'not ', part)
        part = re.sub(r'\bTRUE\b', 'True', part)
        part = re.sub(r'\bFALSE\b', 'False', part)
        part = re.sub(r'\blist\(', 'dm_list(', part)
        part = re.sub(r'\bEXCEPTION\(', 'ValueError(', part)
        part = re.sub(r'\b([A-Za-z_]+)\.len\b', r'len(\1)', part)
        parts[i] = part
    return ''.join(parts)


def compile_helper(source, signature, function_name, arguments, namespace):
    lines = [f'def {function_name}({arguments}):']
    body = procedure(source, signature).splitlines()[1:]
    for raw in body:
        text = raw.split('//', 1)[0].rstrip()
        if not text.strip():
            continue
        depth = len(text) - len(text.lstrip('\t'))
        if not depth:
            raise AssertionError(f'Unsupported indentation: {raw}')
        text = text.strip()
        if text.startswith('if (') and text.endswith(')'):
            statement = 'if ' + expression(text[4:-1]) + ':'
        elif text.startswith('for (var/') and text.endswith(')'):
            match = re.fullmatch(r'for \(var/(\w+) in (.+)\)', text)
            if not match:
                raise AssertionError(f'Unsupported loop: {text}')
            statement = f'for {match[1]} in {expression(match[2])}:'
        elif text.startswith('throw '):
            statement = 'raise ' + expression(text[6:])
        elif text.startswith('return'):
            statement = expression(text)
        elif text.startswith('var/') and '=' in text:
            statement = expression(re.sub(r'^var/(?:\w+/)*(\w+)', r'\1', text))
        else:
            raise AssertionError(f'Unsupported statement: {text}')
        lines.append('    ' * depth + statement)
    exec(compile('\n'.join(lines), '<translated-irrigation-preflight>', 'exec'), namespace)
    return namespace[function_name]


def validator(source):
    namespace = {
        'islist': lambda value: isinstance(value, (dict, DMList)),
        'isnum': lambda value: isinstance(value, (int, float)),
        'dm_list': lambda *items: DMList(items),
    }
    compile_helper(source, '/proc/irrigation_saved_scalar(savefile/F, field, version)',
                   'irrigation_saved_scalar', 'F, field, version', namespace)
    return compile_helper(source, '/proc/validate_saved_irrigation(savefile/F, version)',
                          'validate_saved_irrigation', 'F, version', namespace)


def admitted_fields(source):
    if '/turf/floor/get_saved_vars()' not in source:
        return ()
    body = procedure(source, '/turf/floor/get_saved_vars()')
    match = re.search(r'\. \|= list\(([^\n]+)\)', body)
    if not match:
        raise AssertionError('No explicit channel admission')
    return tuple(re.findall(r'"([a-z_]+)"', match[1]))


def export_channel(source, bits, name='custom named plot'):
    row = {'type': '/turf/floor/dirt', 'name': {'kind': 'value', 'value': name}}
    if bits[0]:
        values = dict(zip(('irrigation', 'flooded', 'salty'), bits), irrigation_save_version=1)
        for field in admitted_fields(source):
            row[field] = {'kind': 'value', 'value': values[field]}
    return row
