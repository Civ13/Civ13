"""Offline ABI/projection contract only. Does not allocate or move game objects."""
import copy


def need(value, reason):
    if not value:
        raise ValueError(reason)


def integers(value, length, lower, upper):
    return (isinstance(value, list) and len(value) == length and
            all(type(item) is int and lower <= item <= upper for item in value))


def validate(layout, template):
    need(isinstance(layout, dict), 'Layout object')
    need(isinstance(template, dict) and set(template) == {
        'schema', 'template_id', 'revision', 'width', 'height', 'decks', 'berths'}, 'Strict seven-field template')
    need(type(template['schema']) is int and template['schema'] == 1, 'ABI schema')
    need(template['template_id'] == layout.get('template_id') == 'dagger_home_draft_v4', 'Template identity')
    revision = layout.get('template_revision')
    need(type(revision) is int and 1 <= revision <= 16777215 and
         type(template['revision']) is int and template['revision'] == revision, 'Explicit template revision')
    need(layout.get('schema_version') == 2 and type(layout['schema_version']) is int, 'Manifest schema is independent')
    need(integers([template['width'], template['height']], 2, 1, 512), 'Template dimensions')
    need(template['decks'] == [{'layer': index + 1, 'id': name} for index, name in
         enumerate(('ground', 'upper_1', 'upper_2', 'roof'))] and
         all(type(deck['layer']) is int for deck in template['decks']), 'Four ordered ABI decks')
    need(template['berths'] == ['raid_west', 'raid_east'], 'Two independent ABI berths')
    need(layout.get('levels') == [{'id': name, 'local_z': index} for index, name in
         enumerate(('ground', 'upper_1', 'upper_2', 'roof'))] and
         all(type(level['local_z']) is int for level in layout['levels']), 'Zero-based local deck mapping')
    bounds = layout.get('footprint_bounds')
    need(integers(bounds, 4, 0, 511) and bounds == [0, 0, template['width'] - 1, template['height'] - 1],
         'Inclusive template footprint')
    world = layout.get('world')
    need(isinstance(world, dict) and integers([world.get(k) for k in ('width', 'height', 'levels')],
         3, 1, 32767), 'World dimensions')
    berths = layout.get('raid_berths')
    need(isinstance(berths, list) and len(berths) == 2 and
         [slot.get('id') for slot in berths if isinstance(slot, dict)] == template['berths'], 'Raid berth identity')
    projections = []
    for slot in berths:
        origin = slot.get('origin')
        need(integers(origin, 3, 1, 32767), 'Exactly three origin coordinates')
        x, y, z = origin
        end = [x + template['width'] - 1, y + template['height'] - 1, z + 3]
        need(all(end[i] <= world[k] for i, k in enumerate(('width', 'height', 'levels'))), 'Projected bounds')
        reserved = slot.get('reserved_bounds')
        need(integers(reserved, 4, 1, 32767) and reserved[0] <= x <= end[0] <= reserved[2]
             and reserved[1] <= y <= end[1] <= reserved[3]
             and reserved[2] <= world['width'] and reserved[3] <= world['height'],
             'Reserved clearance contains footprint within world')
        projections.append({'id': slot['id'], 'origin': origin[:], 'end': end,
                            'deck_z': list(range(z, z + 4)), 'cells': template['width'] * template['height'] * 4})
    a, b = projections
    need(a['end'][0] < b['origin'][0] or b['end'][0] < a['origin'][0] or
         a['end'][1] < b['origin'][1] or b['end'][1] < a['origin'][1] or
         a['end'][2] < b['origin'][2] or b['end'][2] < a['origin'][2], 'Destination footprints overlap')
    west, east = (slot['reserved_bounds'] for slot in berths)
    need(a['end'][2] < b['origin'][2] or b['end'][2] < a['origin'][2] or
         west[2] < east[0] or east[2] < west[0] or
         west[3] < east[1] or east[3] < west[1], 'Destination reserved clearances overlap')
    return copy.deepcopy({'template': template, 'destination_projections': projections})
