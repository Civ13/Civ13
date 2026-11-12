"""Hand-interaction routes read from the game source, so new content shows up without curation.

Catalog recipes only cover the crafting menus. Many things are made by using one
item on another: drying on a dehydrator, steeping herbs in water, grinding in a
mortar, knapping flint, picking wild herbs and harvesting crops. Each extractor
here reads one shared mechanism from its declared variables or its result table,
so a new crop, dried food, tea or mortar ingredient appears in the atlas at the
next regeneration with no edit to `resource-sources.json`.

Every extractor first checks that the mechanism code it describes still says what
the route text claims. If that code changes, generation stops with a message
naming the file to review, instead of publishing a stale description.

Routes already covered by a curated mechanism in `resource-sources.json` are
skipped, so curated text (with its extra review notes) always wins.
"""
import re

from .entity_inventory import include_graph
from .facts import declared, inherited, prose

DRYER = 'code/modules/1713/production.dm'
STEEP = 'code/modules/ecology/wild_herbs.dm'
GROWN_STEEP = 'code/modules/1713/herb_garden.dm'
MORTAR = 'code/modules/1713/herbalism.dm'
KNAP = 'code/modules/1713/flint_mining.dm'
KNAP_EXTRA = 'code/modules/1713/stone_age_arms.dm'
FARMING = 'code/game/objects/farming.dm'
SHELL = 'code/modules/1713/herb_garden.dm'
FISH = 'code/modules/reagents/reagent_containers/food/snacks/meat.dm'
VARS = {'name', 'dried_type', 'dry_size', 'steep_reagent', 'steep_amount', 'sprig_type', 'plant', 'stack',
        'condiment', 'stack_amount', 'biomes', 'seasons'}
MAP_NOTE = 'Availability depends on the selected map; placements and construction reachability were not executed.'
NO_ERA = 'No additional era restriction established by this procedure.'
AUDIT = 'current source (regenerated on every build)'
STATUS = 'Generated from current source by scripts/atlas/interactions.py; gameplay/map reachability unverified'
DRINK = '/datum/reagent/'


def require(source, path, *needles):
    missing = [needle for needle in needles if needle not in source]
    if missing:
        raise ValueError(f'{path} changed ({missing[0]!r} not found): review scripts/atlas/interactions.py')


def line_of(source, needle):
    return source[:source.index(needle)].count('\n') + 1 if needle in source else 1


def defines(files):
    found = {}
    for text in files.values():
        for name, value in re.findall(r'^#define[ \t]+(\w+)[ \t]+(-?\d+)\b', text, re.M):
            found.setdefault(name, int(value))
    return found


def path_value(value):
    match = re.fullmatch(r'(/[\w/]+)', (value or '').strip())
    return match[1] if match else None


def string_value(value):
    match = re.fullmatch(r'"(\w+)"', (value or '').strip())
    return match[1] if match else None


def defined_in(built, typepath):
    """(file, line) of the block that declares a type, or (None, 1)."""
    pattern = re.compile('^' + re.escape(typepath) + r'[ \t]*\r?$', re.M)
    for path in sorted(built):
        match = pattern.search(built[path])
        if match:
            return path, built[path][:match.start()].count('\n') + 1
    return None, 1


def own_name(types, typepath):
    return prose(types.get(typepath, {}).get('name'))


def add_interactions(files, add, records, covered):
    """Add generated routes as recipes; return acquisition entries for the outputs.

    `covered` holds output ids that already have a curated acquisition route.
    """
    reachable = include_graph(files)
    built = {path: text for path, text in files.items() if path in reachable and path.startswith('code/')}
    types = declared(built, VARS)
    numbers = defines(built)
    routes = []
    seen = set()

    def route(name, kind, inputs, outputs, path, line, steps, conditions, tools=(), station=None, era=NO_ERA):
        key = (kind, tuple(inputs), tuple(outputs))
        if key in seen:
            return
        seen.add(key)
        add(name, kind, inputs, outputs, path, line, conditions)
        record = records[-1]
        made = [x['id'] for x in record['outputs']]
        if made and all(x in covered for x in made):
            records.pop()
            return
        record['interaction'] = True
        if station:
            record['station'] = station
        routes.append(dict(name=name, file=path, line=line, inputs=[x['id'] for x in record['inputs']], outputs=made,
                           steps=list(steps), tools=list(tools), conditions=conditions, era=era,
                           map_notes=MAP_NOTE, status=STATUS, audit_commit=AUDIT))

    # Dehydrator: any item whose dried_type is a type path dries into it.
    dryer = files[DRYER]
    require(dryer, DRYER, 'if (!W.dried_type)', 'if (W.dry_size>15)', 'P = new I.dried_type(null)',
            '/var/const/TIME_TO_DRY = 1200', 'if (D.rotten)')
    for typepath in sorted(types):
        dried = path_value(inherited(types, typepath, 'dried_type'))
        size = inherited(types, typepath, 'dry_size')
        if not dried or dried not in types or not own_name(types, typepath) or not own_name(types, dried):
            continue
        if not size or not size.isdigit() or not 0 < int(size) <= 15:
            continue
        route(f'Dry {own_name(types, typepath)} on a dehydrator', 'Drying', [(typepath, 1)], [(dried, 1)],
              DRYER, line_of(dryer, '/obj/structure/dehydrator/attackby'),
              ('Put the item on a dehydrator and leave it for about two minutes.',),
              'Dehydrator required. Rotten food cannot be dried.', ('/obj/structure/dehydrator',),
              '/obj/structure/dehydrator')

    # Steeping: hold an herb with steep_reagent and use it on an open container of water.
    steep = files[STEEP]
    require(steep, STEEP, 'proc/herb_steep_into(source_name, obj/vessel, mob/user, reagent, amount, message)',
            'var/needed = max(HERB_STEEP_WATER, amount)', 'vessel.reagents.remove_reagent("water", amount)',
            'vessel.reagents.add_reagent(reagent, amount)')
    water = numbers.get('HERB_STEEP_WATER', 10)
    reagent_names = {string_value(values.get('id')) for path, values in declared(built).items()
                     if path.startswith(DRINK)} - {None}
    for typepath in sorted(types):
        reagent = string_value(inherited(types, typepath, 'steep_reagent'))
        if not reagent or reagent not in reagent_names or not own_name(types, typepath):
            continue
        raw = inherited(types, typepath, 'steep_amount') or ''
        amount = int(raw) if raw.isdigit() else numbers.get(raw)
        if not amount:
            continue
        need = max(water, amount)
        route(f'Steep {own_name(types, typepath)} into {reagent.replace("_", " ")}', 'Steeping',
              [(typepath, 1), ('reagent:water', amount)], [('reagent:' + reagent, amount)],
              STEEP, line_of(steep, '/proc/herb_steep_into'),
              (f'Hold it and use it on an open container holding at least {need} units of water, in your hand or next to you.',),
              f'Makes {amount} units, replacing the same amount of water. One herb is used up.')

    # Mortar and pestle: its result table lists each ingredient and what it grinds into.
    mortar = files[MORTAR]
    require(mortar, MORTAR, '/proc/mortar_grind_result(obj/item/I)', 'reagents.add_reagent(id, result[id])')
    table = mortar[mortar.index('/proc/mortar_grind_result'):].split('\n/', 1)[0]
    pairs = re.findall(r'istype\(I, (/[\w/]+)\)\)\s*\n\s*return list\(([^)]*)\)', table)
    if not pairs:
        raise ValueError(f'{MORTAR} changed (no grind results found): review scripts/atlas/interactions.py')
    for ingredient, result in pairs:
        outputs = [('reagent:' + rid, int(n)) for rid, n in re.findall(r'"(\w+)" = (\d+)', result)]
        route(f'Grind {own_name(types, ingredient) or ingredient.rsplit("/", 1)[1]} in a mortar and pestle',
              'Mortar grinding', [(ingredient, 1)], outputs, MORTAR, line_of(mortar, 'return ' + 'list(' + result + ')'),
              ('Hold the ingredient and use it on a mortar and pestle. Pour the result out like any other container.',),
              'The mortar holds 30 units; empty it when full. One ingredient is used up per grind.',
              ('/obj/item/weapon/reagent_containers/glass/mortar',))

    # Knapping: flint plus a hammerstone; each menu choice names its product.
    knap = files[KNAP]
    extra = files[KNAP_EXTRA]
    require(knap, KNAP, '/obj/item/weapon/flint/proc/knap(mob/living/human/H, obj/item/hammer)', 'is_hammerstone(M)',
            'result = stone_age_knap_result(choice, T, H)', 'var/delay = 40', 'var/fail_chance = 10')
    body = knap[knap.index('/obj/item/weapon/flint/proc/knap('):].split('\n/', 1)[0]
    extra_body = extra[extra.index('/proc/stone_age_knap_result'):].split('\n/', 1)[0]
    delays = dict(re.findall(r'if \("([^"]+)"\)\s*\n\s*delay = (\d+)', body))
    products = [(choice, path, int(count or 1)) for choice, path, count in
                re.findall(r'if \("([^"]+)"\)\s*\n\s*result = new (/[\w/]+)\(T(?:, (\d+))?\)', body)]
    products += [(choice, path, 1) for choice, path in re.findall(r'if \("([^"]+)"\)\s*\n\s*path = (/[\w/]+)', extra_body)]
    for choice, product, count in products:
        delay = int(delays.get(choice, 40))
        route(f'Knap a {choice.lower()} from flint', 'Knapping', [('/obj/item/weapon/flint', 1)], [(product, count)],
              KNAP, line_of(knap, f'if ("{choice}")'),
              ('Hold a hammerstone and use it on a flint in your other hand or next to you, then choose '
               f'"{choice}" ({delay // 10} seconds before dexterity).',),
              'The flint can shatter into a shard; crafting skill lowers the chance.', ('Hammerstone',),
              era='Basic Toolmaking research rules apply where the recipe is gated.')

    # Wild herb patches: pick by hand on help intent.
    for typepath in sorted(types):
        sprig = path_value(types[typepath].get('sprig_type'))
        if not sprig or not own_name(types, typepath) or not own_name(types, sprig):
            continue
        source, line = defined_in(built, typepath)
        route(f'Pick {own_name(types, sprig)}', 'Foraging', [(typepath, 'not used up')], [(sprig, 1)],
              source, line,
              ('Click a wild patch on help intent to pick one sprig.',),
              'Each patch regrows a sprig every 20 minutes and has none in winter.')

    # Shelling: a sunflower head used in hand gives three handfuls of seeds.
    shell = files[SHELL]
    require(shell, SHELL, '/obj/item/weapon/reagent_containers/food/snacks/grown/sunflower/attack_self(mob/user)',
            'for (var/i = 1, i <= 3, i++)')
    route('Shell a sunflower head', 'Food preparation',
          [('/obj/item/weapon/reagent_containers/food/snacks/grown/sunflower', 1)],
          [('/obj/item/weapon/reagent_containers/food/snacks/grown/sunflower_seeds', 3)],
          SHELL, line_of(shell, 'grown/sunflower/attack_self'), ('Use the sunflower head in hand.',), 'No tool needed.')

    # Filleting: a raw fish cut with a knife, bayonet or hatchet.
    fish = files[FISH]
    fillets = re.findall(r'^(/obj/[\w/]+)/attackby\([^\n]*\n\tif \(!roasted[^\n]*knife[^\n]*\n'
                         r'\t\tfor \(var/i=1, i<=(\d+), i\+\+\)\n\t\t\tnew (/[\w/]+)\(src\)', fish, re.M)
    if not fillets:
        raise ValueError(f'{FISH} changed (no fish filleting found): review scripts/atlas/interactions.py')
    for whole, count, fillet in fillets:
        if whole in types and fillet in types:
            route(f'Fillet {own_name(types, whole)}', 'Food preparation', [(whole, 1)], [(fillet, int(count))],
                  FISH, line_of(fish, whole + '/attackby'),
                  ('Use a knife, bayonet or hatchet on a raw fish that is not rotten.',), 'The whole fish is used up.',
                  ('/obj/item/weapon/material/kitchen/utensil/knife',))

    # Crops: each plant type yields the product its plant/stack/condiment names, plus seeds.
    farming = files[FARMING]
    require(farming, FARMING, 'fruitpath = text2path("/obj/item/stack/[stack]")',
            'fruitpath = "/obj/item/weapon/reagent_containers/food/condiment/[condiment]"',
            'fruitpath = "/obj/item/weapon/reagent_containers/food/snacks/grown/[plant]"',
            'var/seedpath = "/obj/item/stack/farming/seeds/[plant]"')
    for typepath in sorted(types):
        if not typepath.startswith('/obj/structure/farming/plant/') or not own_name(types, typepath):
            continue
        plant = string_value(inherited(types, typepath, 'plant'))
        stack = string_value(inherited(types, typepath, 'stack'))
        condiment = string_value(inherited(types, typepath, 'condiment'))
        if not plant or plant == 'name':
            continue
        if stack and stack != 'product_name':
            produce = ['/obj/item/stack/' + stack]
        elif condiment and condiment != 'product_name':
            produce = ['/obj/item/weapon/reagent_containers/food/condiment/' + condiment]
        else:
            produce = ['/obj/item/weapon/reagent_containers/food/snacks/grown/' + plant]
        source, line = defined_in(built, typepath)
        override = re.search('^' + re.escape(typepath) + r'/spawn_produce\([^)]*\)\r?\n((?:\t.*\n|\r?\n)*)', built[source], re.M)
        if override:
            extra_made = re.findall(r'new (/[\w/]+)\(', override[1])
            produce = (produce if '..()' in override[1] else []) + extra_made
        seeds = '/obj/item/stack/farming/seeds/' + plant
        if seeds not in types or any(p not in types for p in produce):
            continue
        biomes = ', '.join(re.findall(r'"(\w[\w ]*)"', inherited(types, typepath, 'biomes') or ''))
        route(f'Grow and harvest {own_name(types, typepath)}', 'Farming', [(seeds, 1)],
              [(p, 'harvest') for p in dict.fromkeys(produce)] + [(seeds, 2)], source, line,
              ('Plant a seed in ploughed soil, water it and wait until it is ready.',
               'Harvest it with a knife, hatchet, bayonet or scythe for its produce and two seeds.'),
              'Fed soil can give up to three times the produce; farming skill adds more.'
              + (f' Grows in: {biomes}.' if biomes else ''),
              ('/obj/item/weapon/plough', '/obj/item/weapon/material/kitchen/utensil/knife'))
    return routes
