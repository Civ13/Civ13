"""Research coverage is a runtime contract, not a label-based best guess."""
import re

NODE_SOURCE = 'code/modules/research_tree/research_node.dm'
GATE_SOURCE = 'code/modules/research_tree/recipe_gates.dm'


def research_contract(files, canon):
    source = files[NODE_SOURCE]
    nodes = set(re.findall(r'new /datum/research_node\("([^"\n]+)"', source))
    mappings = dict(re.findall(r'"(/obj/[^"\n]+)"\s*=\s*"([^"\n]+)"', source))
    basic_block = files[GATE_SOURCE].split('basic_crafting_recipes = list(', 1)[1].split(')', 1)[0]
    basics = set(re.findall(r'"(/obj/[^"\n]+)"', basic_block))
    bad = sorted(set(mappings.values()) - nodes)
    if bad:
        raise ValueError('Unknown research nodes in recipe map: ' + ', '.join(bad))
    canonical = {canon(path): node for path, node in mappings.items() if path not in basics}
    return nodes, mappings, basics, canonical, {canon(path) for path in basics}


def annotate_research(records, files, canon):
    nodes, mappings, basics, canonical, basic_ids = research_contract(files, canon)
    missing = []
    for recipe in records:
        kind, path = recipe['kind'], recipe['file']
        outputs = [x['id'] for x in recipe['outputs']]
        exclusion = None
        # The curated acquisition category stays open. These four extra acquisition
        # records were historically filed under tanning/flintlock preparation.
        if kind == 'Chemistry':
            exclusion = 'Generic chemistry reactions remain ungated; apparatus and explicit production are gated.'
        elif kind == 'Acquisition / processing':
            exclusion = 'Acquisition, gathering, mining and butchering remain ungated.'
        elif kind == 'Leather tanning' and path == 'code/modules/1713/animal_harvest.dm':
            exclusion = 'Corpse hide harvesting is acquisition, not tanning.'
        elif kind == 'Flintlock preparation' and outputs == ['/obj/item/weapon/flint']:
            exclusion = 'Gathering flint from a rock is acquisition.'
        if exclusion:
            recipe.update(research_status='excluded', research_nodes=[], research_exclusion=exclusion)
            continue
        required = []
        basic = False
        if kind.startswith('Material /'):
            fields = recipe['raw'].split('RECIPE: ', 1)[1].split(',')
            result = fields[2].strip()
            basic = result in basics
            required = [mappings[result]] if not basic and result in mappings else []
        elif kind == 'Factory fabricator':
            required = [recipe['raw'].split('|')[-1].strip()]
        elif kind == 'Foundry casting':
            required = (sorted({'machined_tools'} | {canonical[value] for value in outputs})
                        if outputs and all(value in canonical for value in outputs) else [])
        elif kind == 'Armor assembly':
            match = re.search(r'"node" = "([^"\n]+)"', recipe['raw'])
            required = [match[1]] if match else []
        elif kind == 'Processor':
            if recipe.get('processor') == 'tablet_press':
                required = ['pharmacology']
            else:
                node = mappings.get(recipe.get('station'))
                required = [node] if node else []
        elif kind == 'Leather tanning':
            required = ['basic_tools'] if path == 'code/modules/materials/material_sheets.dm' else ['resource_processing']
        elif kind == 'Manual woodworking':
            required = ['basic_tools']
        elif kind == 'Flintlock assembly':
            required = ['gunsmithing']
        else:
            basic = bool(outputs) and all(value in basic_ids for value in outputs)
            required = sorted({canonical[value] for value in outputs if value in canonical}) if not basic else []
        if not basic and (not required or any(node not in nodes for node in required)):
            missing.append(f"{recipe['id']}: {kind}: {recipe['name']} ({path}:{recipe['line']})")
        recipe.update(research_status='basic' if basic else 'gated', research_nodes=required)
    if missing:
        raise ValueError('Non-basic crafting recipes lack valid research nodes:\n' + '\n'.join(missing))
