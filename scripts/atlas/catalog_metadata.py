"""Source-derived reference metadata. Era tiers are not map availability promises."""
import re

ERA_NAMES = ['Stone Age', 'Bronze Age', 'Middle Ages', 'Imperial Age',
             'Industrial Age', 'Early Modern Age', 'WW2', 'Cold War', 'Modern Age', 'Digital Age']


def add_tablet_press(files, add, records):
    path = 'code/modules/reagents/tablet_press.dm'
    if path not in files:
        return
    source = files[path]
    contract = 'new(src, user, reagents, product.reagents, list("calcium_carbonate" = 1, "aspirin" = 4), product)'
    if contract not in source or 'year > 1843' not in source:
        raise ValueError('Tablet press source contract changed; review quantities and date')
    line = source[:source.index(contract)].count('\n') + 1
    add('Press aspirin tablet', 'Processor', [('calcium_carbonate', 1), ('aspirin', 4)],
        [('/obj/item/weapon/reagent_containers/pill', 1)], path, line,
        'Anchored tablet press; calendar >1843 and Pharmacology. Internal buffer only: '
        '1 carbonate + 4 aspirin -> one 5-unit tablet. Whole selected stocks; unrelated '
        'contents retained. No new aspirin supply or medical effect.')
    records[-1].update(processor='tablet_press', processor_name='Tablet press',
                      station='/obj/structure/chem_master/tablet_press/constructed')


def annotate_eras(records, nodes, splitargs):
    tiers = {}
    for match in re.finditer(r'new /datum/research_node\(', nodes):
        end, depth, quoted = match.end(), 1, False
        while end < len(nodes) and depth:
            char = nodes[end]
            if char == '"' and nodes[end-1] != '\\':
                quoted = not quoted
            if not quoted:
                depth += (char == '(') - (char == ')')
            end += 1
        args = splitargs(nodes[match.end():end-1])
        if len(args) >= 8 and args[7].isdigit():
            tiers[args[0].strip('"')] = int(args[7])
    gates = dict(re.findall(r'"(/obj/[^"\n]+)"\s*=\s*"([^"\n]+)"', nodes))
    for recipe in records:
        eras, evidence = set(), []
        maximum = re.search(r'maximum era ordinal (\d+)', recipe['conditions'])
        if maximum:
            recipe['maximum_era'] = int(maximum[1])
        if recipe['kind'].startswith('Material /') or recipe.get('processor'):
            targets = ([recipe['station']] if recipe.get('processor') else
                       [x['id'] for x in recipe['outputs']])
            unknown = []
            for target in targets:
                node = gates.get(target)
                if node in tiers:
                    eras.add(tiers[node])
                    evidence.append(('Station construction research: ' if recipe.get('processor') else 'Research node: ') + node)
                else:
                    unknown.append(target)
            if unknown:
                eras.clear()
                evidence.append('Combined unlock unknown; unmapped: ' + ', '.join(unknown))
        bounds = re.search(r'Era ordinals (\d+) through (\d+)', recipe['conditions'])
        if bounds and recipe['kind'] == 'Anvil':
            eras.add(int(bounds[1]))
            recipe['maximum_era'] = int(bounds[2])
            evidence.append('Anvil minimum era')
        if recipe['kind'] == 'Flintlock assembly':
            eras.add(3)
            recipe['maximum_era'] = 4
            evidence.append('Assembly minimum era')
        minimum = re.search(r'Minimum era Modern \(ordinal (\d+)\)', recipe['conditions'])
        if minimum:
            eras = {max(int(minimum[1]), max(eras, default=0))}
            evidence.append('Construction minimum era')
        if recipe.get('research_status') == 'gated':
            # Every node in this route is required. Keep explicit minimum eras;
            # a maximum expiry is never evidence of a minimum unlock.
            required_tiers = [tiers[node] for node in recipe['research_nodes']]
            eras = {max([*eras, *required_tiers])}
            evidence.append('Required research: ' + ', '.join(recipe['research_nodes']))
        elif recipe.get('research_status') == 'basic':
            eras = {0}
            evidence = ['Explicit basic recipe; existing map/mode and maximum-era gates remain.']
        recipe['unlock_eras'] = sorted(eras)
        recipe['era_sort'] = min(eras, default=99)
        recipe['era_status'] = 'multiple' if len(eras) > 1 else 'known' if eras else 'unknown'
        recipe['era_label'] = (' / '.join(f'{n}: {ERA_NAMES[n]}' for n in sorted(eras))
                               if eras else 'Unknown / context dependent')
        recipe['era_basis'] = '; '.join(evidence) or 'No explicit minimum era or mapped unlock research tier extracted; maximum era is not an unlock.'
    records.sort(key=lambda r: (r['era_sort'], r['name'].casefold(), r['id']))


def add_processors(files, add, records):
    path = 'code/modules/1713/production.dm'
    source = files[path]

    def body(proc):
        start = source.index(proc)
        end = source.find('\n/obj/', start + len(proc))
        return source[start:end if end != -1 else len(source)], source[:start].count('\n') + 1

    saw, saw_line = body('/obj/structure/sawmill/proc/produce(')
    primitive, primitive_line = body('/obj/structure/sawmill/proc/cut_primitive_log(')
    finish, _ = body('/obj/structure/sawmill/proc/finish_work(')
    attack, _ = body('/obj/structure/sawmill/attackby(')
    yields = re.findall(r'current_work = new P\(null, W.amount \* (\d+), FALSE\)', saw)
    if yields != ['10', '12', '4'] or 'give_exp' not in finish or 'clamp(ceil(this_production.amount/2' not in finish or '/obj/item/stack/material/woodplank' not in attack:
        raise ValueError('Sawmill source contract changed; review atlas quantities and conditions')
    if 'new(site, 1, FALSE)' not in primitive or 'flint_blade_uses--' not in primitive or 'cut_primitive_logs(W, H)' not in attack:
        raise ValueError('Primitive sawmill source contract changed; review atlas quantities and conditions')
    for required in ('!H.in_mood()', '!anchored', 'istype(src, /obj/structure/sawmill/powered) && powered == FALSE', 'if (current_work)', 'if (do_after(H, work_time_amount, src.loc))'):
        if required not in saw:
            raise ValueError('Sawmill source contract changed; review atlas conditions')
    for suffix, name, amount in [('', 'Primitive sawmill', '1'), ('/large', 'Large sawmill', yields[0]), ('/powered', 'Powered sawmill', yields[1])]:
        station = '/obj/structure/sawmill' + suffix
        conditions = 'Anchored, idle sawmill; actor in mood; complete the action. Nominal yield per log; skill failure can reduce output. Interrupting can lose inputs. Time depends on stack size, crafting and dexterity.'
        if not suffix:
            conditions = 'Anchored, idle primitive mill; held ordinary log and installed sharpened flint blade required. One log yields one plank and one bark in 20 deciseconds at strength coefficient 1. Each blade cuts 20 logs. Keeps cutting the held stack one log at a time until it runs out, the blade breaks or the worker stops. Interruption or saving cancels work without consuming a log or blade use.'
        if suffix == '/powered':
            conditions += ' Requires cable power (powerneeded = 1).'
        add(name + ': logs to planks', 'Processor', [('/obj/item/stack/material/wood', 1)], [('/obj/item/stack/material/woodplank', amount + (' nominal' if suffix else ''))], path, primitive_line if not suffix else saw_line, conditions)
        records[-1].update(processor='sawmill', processor_name='Sawmills', station=station)
    mill, line = body('/obj/structure/mill/attackby(')
    mill_finish, _ = body('/obj/structure/mill/proc/finish_work(')
    mill_work, _ = body('/obj/structure/mill/proc/produce(')
    pairs = re.findall(r'istype\(W,\s*(/obj/[^)]+)\)\)\s*\n\s*produce\(W, H, (/obj/[^)]+)\)', mill)
    if len(pairs) != 4 or 'new current_work.type(src.loc)' not in mill_finish or 'current_work = new P(null)' not in mill_work:
        raise ValueError('Grain mill source contract changed; review atlas conversions')
    for required in ('!anchored', 'H.stats["stamina"][2]*0.1', '!H.in_mood()', 'while (complete_percent<100)', 'spawn(30+rand(1,30))'):
        if required not in mill_work:
            raise ValueError('Grain mill source contract changed; review atlas conditions')
    for feed, product in pairs:
        for suffix, name in [('', 'Manual grain mill'), ('/large', 'Large grain mill')]:
            conditions = 'Anchored mill; one whole grain item becomes one fresh product item (not equal reagent volume). '
            conditions += ('Automatic 31-60 tick wait; idle mill.' if suffix else 'Manual work to 100%; actor mood and at least 10% stamina; interrupted progress can be resumed or helped.')
            add(name + ': ' + feed.rsplit('/', 1)[1], 'Processor', [(feed, 1)], [(product, 1)], path, line, conditions)
            records[-1].update(processor='grain_mill', processor_name='Grain mills', station='/obj/structure/mill' + suffix)
