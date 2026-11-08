"""get_saved_vars caches persistence_runtime_var per type and field.

The cache is only correct while every override answers from its key and type
alone. An override that reads the instance must name the fields it decides
that way in persistence_runtime_var_instance_keys (functions.dm), and be listed
in INSTANCE_OVERRIDES below with those fields.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]

# Override type -> the fields whose answer depends on the instance.
INSTANCE_OVERRIDES = {
    '/atom/movable': {'glide_size'},
    '/mob': {'mind'},
    '/mob/living/human': {'glide_size'},
    '/mob/living/simple_animal': {'glide_size', 'step_x', 'step_y'},
}
# Helpers that answer from the type and key only.
TYPE_ONLY_CALLS = {'persistence_world_time_stamp', 'src'}
ALLOWED = {'key', 'return', 'switch', 'if', 'else', 'in', 'list', 'TRUE', 'FALSE', 'null'}

TOP = re.compile(r'^(/[\w/]+?)/(?:proc/)?persistence_runtime_var\((?:var/)?(\w+)\)\s*$')
NESTED = re.compile(r'^(\t+)(?:proc/)?persistence_runtime_var\((?:var/)?(\w+)\)\s*$')
TYPE_LINE = re.compile(r'^(/[\w/]+)\s*$')


def overrides():
    for path in sorted((ROOT / 'code').rglob('*.dm')):
        lines = path.read_text(encoding='utf-8', errors='replace').split('\n')
        owner = None
        for i, line in enumerate(lines):
            stripped = line.rstrip()
            type_line = TYPE_LINE.match(stripped)
            if type_line:
                owner = type_line.group(1)
            top = TOP.match(stripped)
            nested = NESTED.match(stripped) if not top else None
            if top:
                kind, arg, indent = top.group(1), top.group(2), ''
            elif nested and owner and len(nested.group(1)) == 1:
                kind, arg, indent = owner, nested.group(2), nested.group(1)
            else:
                continue
            body = []
            for follow in lines[i + 1:]:
                if follow.strip() and not follow.startswith(indent + '\t'):
                    break
                body.append(follow)
            yield kind, arg, f'{path.relative_to(ROOT)}:{i + 1}', '\n'.join(body)


def foreign_names(arg, body):
    code = '\n'.join(line.split('//')[0] for line in body.split('\n'))
    code = re.sub(r'"[^"]*"', '""', code)
    names = set(re.findall(r'[A-Za-z_]\w*', code))
    return names - ALLOWED - TYPE_ONLY_CALLS - {arg}


class RuntimeVarCache(unittest.TestCase):
    def test_overrides_found(self):
        self.assertGreater(len(list(overrides())), 100)

    def test_instance_dependent_overrides_are_declared(self):
        functions = (ROOT / 'code/modules/persistence/functions.dm').read_text(encoding='utf-8')
        declared = re.search(r'persistence_runtime_var_instance_keys = list\(([^)]*)\)', functions)
        self.assertIsNotNone(declared)
        keys = set(re.findall(r'"(\w+)" = TRUE', declared.group(1)))
        found = {}
        for kind, arg, where, body in overrides():
            if foreign_names(arg, body):
                found[kind] = where
        self.assertEqual(set(found), set(INSTANCE_OVERRIDES), f'instance-dependent overrides changed: {found}')
        for kind, fields in INSTANCE_OVERRIDES.items():
            self.assertTrue(fields <= keys, f'{kind} fields {fields - keys} are cached')

    def test_export_uses_the_cache(self):
        saving = (ROOT / 'code/modules/persistence/saving.dm').read_text(encoding='utf-8')
        functions = (ROOT / 'code/modules/persistence/functions.dm').read_text(encoding='utf-8')
        self.assertIn('var/list/runtime_cache = persistence_runtime_var_type_cache(A, changing_vars)', saving)
        loop = saving[saving.index('persistence_runtime_var_type_cache(A, changing_vars)'):]
        loop = loop[:loop.index('switch(v)')]
        self.assertLess(loop.index('if(cached_runtime) continue'), loop.index('if(A.persistence_runtime_var(v))'))
        fill = functions[functions.index('/proc/persistence_runtime_var_type_cache('):]
        fill = fill[:fill.index('return cache')]
        self.assertIn('if (persistence_runtime_var_instance_keys[key] || !isnull(cache[key])) continue', fill)

    def test_saved_field_list_uses_the_cache(self):
        functions = (ROOT / 'code/modules/persistence/functions.dm').read_text(encoding='utf-8')
        body = functions[functions.index('/datum/proc/get_saved_vars()'):]
        body = body[:body.index('return to_save')]
        self.assertIn('var/list/runtime_cache = persistence_runtime_var_cache[type]', body)
        self.assertIn('if (!instance_key)\n\t\t\t\t\tcached = runtime_cache[key]', body)
        self.assertIn('if (!instance_key)\n\t\t\t\t\t\truntime_cache[key] = cached', body)


if __name__ == '__main__':
    unittest.main()
