"""Audit-only lexical entity candidates. Never a compiled or player-facing registry."""
import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
import re

from .facts import HEADER, VALUE, literal
from .families import declared_parents

ROOTS = (('/obj/item', 'items'), ('/obj/structure', 'structures'),
         ('/obj/machinery', 'machinery'), ('/obj/covers', 'covers'),
         ('/mob/living/simple_animal', 'animals'), ('/turf', 'terrain'))
INCLUDE = re.compile(r'^\s*#include\s+"([^"]+)"', re.M)
CONDITIONAL = re.compile(r'^\s*#\s*(if|ifdef|ifndef|elif|else|endif)\b')


def family(typepath):
    if any(part in {'proc', 'verb', 'var'} for part in typepath.split('/')):
        return None
    return next((label for root, label in ROOTS if typepath == root or typepath.startswith(root + '/')), None)


def masked_source(source):
    """Blank comments and multiline strings, preserving offsets for provenance.

    Ordinary quoted strings remain intact. This is not a preprocessor/parser;
    multiline text is deliberately unsupported rather than scanned as DM code.
    """
    chars = list(source)
    i = 0
    while i < len(source):
        end = None
        if source.startswith('//', i):
            end = source.find('\n', i)
            end = len(source) if end < 0 else end
        elif source.startswith('/*', i):
            end, nesting = i + 2, 1
            while end < len(source) and nesting:
                if source.startswith('/*', end):
                    nesting += 1
                    end += 2
                elif source.startswith('*/', end):
                    nesting -= 1
                    end += 2
                else:
                    end += 1
        elif source.startswith('{"', i):
            end = i + 2
            while end < len(source):
                if source[end] == '\\':
                    end += 2
                elif source.startswith('"}', end):
                    end += 2
                    break
                else:
                    end += 1
            end = min(end, len(source))
        elif source[i] == '"':
            i += 1
            while i < len(source):
                if source[i] == '\\':
                    i += 2
                    continue
                if source[i] == '"':
                    i += 1
                    break
                i += 1
            continue
        if end is not None:
            for j in range(i, end):
                if chars[j] not in '\r\n':
                    chars[j] = ' '
            if source.startswith('{"', i):
                chars[i] = '?'  # Retain an explicitly unsupported RHS marker.
            i = end
        else:
            i += 1
    return ''.join(chars)


def include_graph(files, entry='civ13.dme'):
    """Literal include reachability only; #if conditions are NOT evaluated."""
    seen, pending = set(), [entry]
    while pending:
        path = pending.pop()
        if path in seen or path not in files:
            continue
        seen.add(path)
        for target in INCLUDE.findall(masked_source(files[path])):
            # DM includes are relative to the containing file.
            joined = Path(path).parent / target.replace('\\', '/')
            if '..' not in joined.parts and not joined.is_absolute():
                pending.append(joined.as_posix())
    return seen


def inventory(files, resources):
    referenced = include_graph(files)
    sanitized = {path: masked_source(text) for path, text in files.items()}
    parents = declared_parents(sanitized)
    aliases = defaultdict(set)
    for identity, resource in resources.items():
        if isinstance(resource, dict) and isinstance(resource.get('type'), str):
            aliases[resource['type']].add(identity)
        aliases[identity].add(identity)
    records = {}
    excluded = Counter()
    for path, source in sorted(sanitized.items()):
        if not path.startswith('code/') or not path.endswith('.dm'):
            continue
        current, depth = None, 0
        for number, line in enumerate(source.splitlines(), 1):
            directive = CONDITIONAL.match(line)
            if directive:
                if directive[1] in ('if', 'ifdef', 'ifndef'):
                    depth += 1
                elif directive[1] == 'endif':
                    depth = max(0, depth - 1)
                if current:
                    records[current]['conditional_source'] = True
                continue
            header = HEADER.fullmatch(line)
            if header:
                current = header[1].rstrip('/') if family(header[1].rstrip('/')) else None
                if not current:
                    reason = 'proc_verb_var_path' if any(p in {'proc', 'verb', 'var'} for p in header[1].split('/')) else 'outside_selected_families'
                    excluded[reason] += 1
                if current:
                    row = records.setdefault(current, dict(type=current, family=family(current), declarations=[],
                        fields={'name': [], 'desc': []}, conditional_source=False))
                    row['declarations'].append(dict(file=path, line=number,
                        include_status='referenced_unpreprocessed' if path in referenced else 'not_in_literal_include_graph'))
                    row['conditional_source'] |= depth > 0
                continue
            if line and not line[0].isspace():
                current = None
            if current:
                match = VALUE.fullmatch(line)
                if match and match[1] in ('name', 'desc'):
                    expression = literal(match[2])
                    plain = re.fullmatch(r'"([^"\\\[\]]*)"', expression)
                    records[current]['fields'][match[1]].append(dict(file=path, line=number,
                        status='literal' if plain else 'unsupported_expression',
                        value=plain[1] if plain else None))
    for typepath, row in records.items():
        row['atlas_ids'] = sorted(aliases[typepath])
        row['atlas_match'] = 'ambiguous_aliases' if len(row['atlas_ids']) > 1 else ('exact' if row['atlas_ids'] else 'absent')
        row['parent_hint'] = parents.get(typepath)
        row['inheritance_status'] = 'unresolved_not_compiled'
        row['public_eligibility'] = 'unreviewed_including_possible_abstract_internal_types'
        for field, entries in row['fields'].items():
            values = {entry['value'] for entry in entries if entry['status'] == 'literal'}
            row[field + '_status'] = ('not_declared_here' if not entries else
                'unresolved_conditional' if row['conditional_source'] else
                'unresolved_expression' if any(entry['status'] != 'literal' for entry in entries) else
                'conflicting_redeclarations' if len(values) > 1 else 'direct_literal_candidate')
    entries = [records[key] for key in sorted(records)]
    summary = dict(candidates=len(entries), families=dict(sorted(Counter(x['family'] for x in entries).items())),
        atlas_matches=dict(sorted(Counter(x['atlas_match'] for x in entries).items())),
        name_status=dict(sorted(Counter(x['name_status'] for x in entries).items())),
        desc_status=dict(sorted(Counter(x['desc_status'] for x in entries).items())),
        conditional_candidates=sum(x['conditional_source'] for x in entries),
        only_off_graph=sum(all(d['include_status'] == 'not_in_literal_include_graph' for d in x['declarations']) for x in entries))
    return dict(schema_version=1, excluded_absolute_declarations=dict(sorted(excluded.items())), scope='Audit-only explicit absolute declarations in selected code/ entity families. Not compiled types, active build coverage, public eligibility, inherited defaults or obtainable entities.',
        limitations=['Conditional preprocessing and macros not evaluated.', 'Relative/nested/inline declarations, non-tab field layout and multiline string values not resolved.',
            'Missing direct fields may be inherited or set at runtime; no absence-of-description claim.',
            'Atlas matches are exact resource IDs or resources[type] reverse aliases, not acquisition evidence.',
            'No constructors, engine, map scan, private instance data or gameplay execution.'], summary=summary, entries=entries)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--summary-only', action='store_true')
    args = parser.parse_args()
    root = args.root.resolve()
    paths = sorted(root.rglob('*.dm')) + [root / 'civ13.dme']
    files = {p.relative_to(root).as_posix(): p.read_text(encoding='utf-8', errors='replace') for p in paths if p.is_file()}
    catalog = json.loads((root / 'UI/crafting-atlas.json').read_text())
    report = inventory(files, catalog.get('resources', {}))
    if args.summary_only:
        report.pop('entries')
    args.output.write_text(json.dumps(report, indent=2, ensure_ascii=True) + '\n')


if __name__ == '__main__':
    main()
