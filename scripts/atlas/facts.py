"""Item facts for atlas resource pages: examine text and declared basics.

Each resource page works as a small wiki entry. Facts are read from literal
declarations only (`desc = "..."`, `force = 12`), inherited down the type
path. Anything computed at runtime is left out rather than guessed, so a
missing fact means "not declared", never "zero".
"""
import re

HEADER = re.compile(r'^(/[\w/]+)[ \t]*(?://.*)?$')
VALUE = re.compile(r'^\t(?:var/(?:[a-z_]+/)*)?(\w+)[ \t]*=[ \t]*(.+)$')
WANTED = {'name', 'desc', 'description', 'taste_description', 'id', 'w_class', 'slot_flags', 'force', 'throwforce',
          'sharp', 'edge', 'armor', 'caliber', 'nutriment_amt', 'storage_slots', 'max_storage_space', 'max_amount',
          'slowdown', 'health', 'maxHealth', 'body_parts_covered'}
SIZES = {'ITEM_SIZE_TINY': 'Tiny', 'ITEM_SIZE_SMALL': 'Small', 'ITEM_SIZE_NORMAL': 'Normal', 'ITEM_SIZE_LARGE': 'Large',
         'ITEM_SIZE_HUGE': 'Huge', 'ITEM_SIZE_GARGANTUAN': 'Gargantuan', '1': 'Tiny', '2': 'Small', '3': 'Normal',
         '4': 'Large', '5': 'Huge', '6': 'Gargantuan'}
SLOTS = {'SLOT_OCLOTHING': 'over clothing', 'SLOT_ICLOTHING': 'as clothing', 'SLOT_GLOVES': 'hands', 'SLOT_EYES': 'eyes',
         'SLOT_EARS': 'ear', 'SLOT_TWOEARS': 'ears', 'SLOT_MASK': 'face', 'SLOT_HEAD': 'head', 'SLOT_FEET': 'feet',
         'SLOT_ID': 'ID', 'SLOT_BELT': 'belt', 'SLOT_BACK': 'back', 'SLOT_POCKET': 'pocket',
         'SLOT_ACCESSORY': 'accessory', 'SLOT_SHOULDER': 'shoulder', 'SLOT_HOLSTER': 'holster'}
COVERS = {'HEAD': 'head', 'FACE': 'face', 'EYES': 'eyes', 'UPPER_TORSO': 'chest', 'LOWER_TORSO': 'groin',
          'LEGS': 'legs', 'LEG_LEFT': 'left leg', 'LEG_RIGHT': 'right leg', 'FEET': 'feet', 'FOOT_LEFT': 'left foot',
          'FOOT_RIGHT': 'right foot', 'ARMS': 'arms', 'ARM_LEFT': 'left arm', 'ARM_RIGHT': 'right arm',
          'HANDS': 'hands', 'HAND_LEFT': 'left hand', 'HAND_RIGHT': 'right hand'}
KINDS = (('/obj/item/weapon/reagent_containers/food/drinks', 'Drink'), ('/obj/item/weapon/reagent_containers/food', 'Food'),
         ('/obj/item/weapon/gun', 'Firearm'), ('/obj/item/ammo', 'Ammunition'), ('/obj/item/clothing', 'Clothing'),
         ('/obj/item/stack/medical', 'Medical supply'), ('/obj/item/stack/farming/seeds', 'Seeds'),
         ('/obj/item/stack/material', 'Material'), ('/obj/item/stack/ore', 'Ore'), ('/obj/item/stack', 'Stackable item'),
         ('/obj/item/weapon/material', 'Tool or weapon'), ('/obj/item/weapon/reagent_containers', 'Container'),
         ('/obj/item/weapon/storage', 'Storage'), ('/obj/item', 'Item'), ('/obj/structure', 'Structure'),
         ('/obj/covers', 'Floor or wall'), ('/mob', 'Animal'), ('/turf', 'Terrain'))


def literal(text):
    """Value text without its trailing comment; quotes are respected."""
    quoted = False
    index = 0
    while index < len(text):
        char = text[index]
        if char == '\\' and quoted:
            index += 2
            continue
        if char == '"':
            quoted = not quoted
        elif char == '/' and not quoted and text[index:index + 2] == '//':
            return text[:index].strip()
        index += 1
    return text.strip()


def declared(files):
    """{type path: {var: literal text}} for top-level type blocks."""
    types = {}
    for path in sorted(files):
        if not path.endswith('.dm'):
            continue
        current = None
        for line in files[path].split('\n'):
            line = line.rstrip('\r')
            header = HEADER.match(line)
            if header:
                current = None if re.search(r'/(proc|verb)(/|$)', header[1]) else types.setdefault(header[1], {})
            elif line[:1] not in ('\t', ' ', ''):
                current = None
            elif current is not None:
                value = VALUE.match(line)
                if value and value[1] in WANTED:
                    current.setdefault(value[1], literal(value[2]))
    return types


def inherited(types, typepath, name):
    while typepath.count('/') >= 1 and typepath:
        value = types.get(typepath, {}).get(name)
        if value is not None:
            return value
        typepath = typepath.rsplit('/', 1)[0]
    return None


def prose(value):
    """A plain string literal as a player reads it, or '' when it is built at runtime."""
    if not value or len(value) < 2 or value[0] != '"' or value[-1] != '"' or '[' in value:
        return ''
    text = value[1:-1].replace('\\"', '"').replace('\\n', ' ').replace("\\'", "'")
    text = re.sub(r'\\(?:the|The|a|an|A|An|improper|proper|icon|red|blue|green|black|bold|italic)\b ?', '', text)
    text = re.sub(r'<[^>]+>', '', text)
    if '\\' in text:
        return ''
    # A sentence holding a starting counter ("It has 0 bars on it") is live state, not a description.
    sentences = [part for part in re.split(r'(?<=[.!?])\s+', ' '.join(text.split())) if not re.search(r'\b0\b', part)]
    return ' '.join(sentences)


def number(value):
    try:
        result = float(value)
    except (TypeError, ValueError):
        return None
    return int(result) if result == int(result) else round(result, 2)


def flags(value, names):
    if not value:
        return ''
    found = [names[part.strip()] for part in value.split('|') if part.strip() in names]
    return ', '.join(dict.fromkeys(found)) if len(found) == len(value.split('|')) else ''


def kind(resource, typepath):
    if not typepath.startswith('/'):
        return 'Chemical'
    if resource.startswith('/material/'):
        return 'Material'
    return next((label for prefix, label in KINDS if typepath.startswith(prefix)), 'Item')


def stats(types, typepath):
    rows = []

    def get(name):
        return inherited(types, typepath, name)
    item = typepath.startswith('/obj/item')
    if item and SIZES.get(get('w_class')):
        rows.append(['Size', SIZES[get('w_class')]])
    if item and flags(get('slot_flags'), SLOTS):
        rows.append(['Worn on', flags(get('slot_flags'), SLOTS)])
    if typepath.startswith('/obj/item/clothing') and flags(get('body_parts_covered'), COVERS):
        rows.append(['Covers', flags(get('body_parts_covered'), COVERS)])
    armor = get('armor')
    if typepath.startswith('/obj/item/clothing') and armor and armor.startswith('list('):
        parts = [(key, number(amount)) for key, amount in re.findall(r'(\w+)\s*=\s*([\w.]+)', armor)]
        shown = ', '.join(f'{key} {amount}' for key, amount in parts if amount)
        if shown:
            rows.append(['Armor', shown])
    # Material tools take their damage from what they are made of.
    if item and not typepath.startswith(('/obj/item/weapon/material', '/obj/item/clothing')):
        for name, label in (('force', 'Melee damage'), ('throwforce', 'Thrown damage')):
            amount = number(get(name))
            if amount and amount > 0:
                rows.append([label, str(amount)])
    if item:
        edges = [label for name, label in (('sharp', 'sharp'), ('edge', 'edged')) if get(name) in ('TRUE', '1')]
        if edges:
            rows.append(['Blade', ' and '.join(edges)])
    if typepath.startswith(('/obj/item/weapon/gun', '/obj/item/ammo')) and prose(get('caliber')):
        rows.append(['Caliber', prose(get('caliber'))])
    if typepath.startswith('/obj/item/weapon/reagent_containers/food'):
        amount = number(get('nutriment_amt'))
        if amount and amount > 0:
            rows.append(['Nutrition', str(amount)])
    if typepath.startswith('/obj/item/weapon/storage') or typepath.startswith('/obj/item/clothing'):
        amount = number(get('storage_slots'))
        if amount and amount > 0:
            rows.append(['Holds', f'{amount} items'])
    if typepath.startswith('/obj/item/stack'):
        amount = number(get('max_amount'))
        if amount and amount > 1:
            rows.append(['Stack size', str(amount)])
    if item:
        amount = number(get('slowdown'))
        if amount and amount > 0:
            rows.append(['Slows you', 'yes'])
    if typepath.startswith('/mob'):
        amount = number(get('maxHealth')) or number(get('health'))
        if amount and amount > 0:
            rows.append(['Health', str(amount)])
    return rows


def resource_facts(files, resource_types):
    """Return {resource id: {'kind', 'desc'?, 'stats'?}} for {resource id: DM type or reagent id}."""
    types = declared(files)
    reagents = {}
    for typepath, values in types.items():
        if typepath.startswith('/datum/reagent') and prose(values.get('id')):
            reagents.setdefault(prose(values['id']), typepath)
    facts = {}
    for resource, typepath in sorted(resource_types.items()):
        entry = {'kind': kind(resource, typepath)}
        if typepath.startswith('/'):
            text = prose(inherited(types, typepath, 'desc'))
            rows = stats(types, typepath)
        else:
            reagent = reagents.get(typepath, '')
            text = prose(inherited(types, reagent, 'description')) if reagent else ''
            taste = prose(inherited(types, reagent, 'taste_description')) if reagent else ''
            rows = [['Taste', taste]] if taste else []
        if text:
            entry['desc'] = text
        if rows:
            entry['stats'] = rows
        facts[resource] = entry
    return facts
