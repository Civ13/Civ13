"""Check the explicit map-state field inventory against source declarations.

This is a source contract check, not a DM compiler or runtime acceptance test.
"""
import json
from pathlib import Path
import re


def main():
    root = Path(__file__).resolve().parents[2]
    contract = (root / 'code/modules/persistence/durable_contract.dm').read_text(encoding='utf-8')
    groups = re.findall(r'^\t\t"([a-z_]+)" = list\(([^\n]+)\)', contract, re.M)
    fields = {}
    for kind, names in groups:
        for name in re.findall(r'"([a-zA-Z0-9_]+)"', names):
            if name in fields:
                raise RuntimeError(f'Duplicate map field: {name}')
            fields[name] = kind
    if len(fields) < 100:
        raise RuntimeError('Explicit field inventory unexpectedly shrank')
    paths = [root / name for name in (
        'code/game/objects/map_metadata/_map_metadata.dm',
        'code/modules/research_tree/research_faction.dm',
        'code/game/mob/groups/faction_creation.dm',
        'code/game/mob/groups/faction_symbol.dm')]
    declarations = set()
    for path in paths:
        owner = None
        for line in path.read_text(encoding='utf-8').splitlines():
            if re.match(r'^/[^/]', line):
                owner = line.strip()
            if owner == '/obj/map_metadata':
                match = re.match(r'\tvar/(?:[\w]+/)*([\w]+)(?:\[.*\])?\s*(?:=|$)', line)
                if match:
                    declarations.add(match.group(1))
    missing = fields.keys() - declarations
    if missing:
        raise RuntimeError(f'Fields absent from map declarations: {sorted(missing)}')
    forbidden = {'season_epoch', 'season_busy', 'season_retired', 'season_queue',
                 'season_loop_scheduled', 'win_condition', 'faction_symbol_icon',
                 'faction_symbol_undo', 'faction_symbol_tool', 'faction_symbol_color'}
    if forbidden & fields.keys():
        raise RuntimeError('Runtime objects or editor sessions entered durable inventory')
    required = {'custom_civs', 'faction_research', 'faction_forge_progress',
                'faction_research_director', 'age2_timer', 'berryeffects',
                'persistence', 'research_active', 'resourceresearch', 'perschadplus'}
    if required - fields.keys():
        raise RuntimeError('Required durable domains disappeared')
    associative = {'faction1_squads', 'faction2_squads',
                   'faction1_squad_leaders', 'faction2_squad_leaders'}
    if any(fields.get(name) != 'alist' for name in associative):
        raise RuntimeError('Native squad associations lost their collection contract')
    print(json.dumps({'map_fields': len(fields), 'declared': True,
                      'runtime_exclusions_checked': True,
                      'native_compilation': 'not performed',
                      'production_integration': 'pending'}, indent=2))


if __name__ == '__main__':
    main()
