"""Bounded dressmaking route, tied to the current production transition costs."""
PATH = 'code/modules/1713/dressmaking.dm'
AUDIT_COMMIT = '340661b78265f9b658e64a8efe012a920f121239'


def add_dressmaking(files, add, records):
    source = files[PATH]
    required = ('wait_for_dressmaking(user, 30)', 'wait_for_dressmaking(user, 60)',
                'stage = 1', 'stage = 2',
                'var/obj/item/clothing/under/tailored_dress/dress = new(site)',
                'crafting_node_allowed(user, "fine_garments")')
    if any(text not in source for text in required):
        raise ValueError('Dressmaking source changed; review Atlas costs and stages')
    name = 'Design, cut and sew a custom dress'
    marker = '/obj/item/dressmaking_project/proc/sew_dress'
    line = source[:source.index(marker)].count('\n') + 1
    steps = [
        'Craft one dressmaking project from four cloth sheets (woolcloth also works) in Feminine Clothing. Fine Garments is required.',
        'Use the project in hand. Choose Layered, Buttoned or Laced and color each panel. Laced dresses retain gold trim.',
        'Preview the front and back before confirming Cut fabric (30 ticks). Cutting locks the design.',
        'Use the cut pieces in hand and choose Sew dress (60 ticks). One paid project becomes one wearable dress; no extra ingredients.',
        'Interruption retains the project and completed cutting. Finished dresses accept ordinary clothing accessories.'
    ]
    add(name, 'Dressmaking', [('/obj/item/dressmaking_project', 1)],
        [('/obj/item/clothing/under/tailored_dress', 1)], PATH, line, ' '.join(steps))
    record = records[-1]
    return [dict(name=name, file=PATH, line=line, audit_commit=AUDIT_COMMIT,
                 inputs=[x['id'] for x in record['inputs']],
                 outputs=[x['id'] for x in record['outputs']],
                 tools=[], steps=steps, conditions=' '.join(steps),
                 era='Fine Garments research and personal knowledge where enabled. Project uses the existing dress recipe era window.',
                 map_notes='Fabric supply and research depend on the map. No new material spawns.',
                 status='Current-source route; native and connected-client checks are reported separately.')]
