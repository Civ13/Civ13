"""Bounded tailoring route, tied to the current production transition costs."""
PATH = 'code/modules/1713/dressmaking.dm'
AUDIT_COMMIT = '98f34be22b7c594de1b9b113f9962cd61f6f0091'


def add_dressmaking(files, add, records):
    source = files[PATH]
    required = ('wait_for_tailoring(user, 30)', 'wait_for_tailoring(user, 60)',
                'stage = 1', 'stage = 2', 'var/obj/item/clothing/garment = new garment_type(site)',
                'crafting_node_allowed(user, "weaving")', 'tailoring_design_allowed(user, design_body, design_pieces, design_colors)')
    if any(text not in source for text in required):
        raise ValueError('Tailoring source changed; review Atlas costs and stages')
    marker = '/obj/item/tailoring_project/proc/sew_garment'
    line = source[:source.index(marker)].count('\n') + 1
    routes = []
    woven = ('Craft a tailoring project from one cloth sheet (woolcloth also works) in Clothing. Weaving is required.',
             'Use more sheets of the same fabric on the project, up to eight. Wool garments are warmer and lightly padded; linen is lighter and takes dyes brighter.')
    leather = ('Craft a tailoring project from one leather sheet in Clothing. Weaving is required.',
               'Use more leather sheets on the project if the design needs them. Leather shows its own tan through every dye. The finished piece protects and carries exactly like a plain one of its kind; the design is looks only.')
    for output, kind, start in (('/obj/item/clothing/under/tailored', 'clothing', woven),
                                ('/obj/item/clothing/suit/storage/jacket/tailored', 'overclothes', woven),
                                ('/obj/item/clothing/head/tailored', 'headwear', woven),
                                ('/obj/item/clothing/gloves/thick/leather/tailored', 'gloves', (
                                    leather[0].replace('one leather sheet', 'one leather or woolcloth sheet'),
                                    leather[1].replace('more leather sheets', 'more sheets of the same material'))),
                                ('/obj/item/clothing/shoes/tailored', 'shoes', leather),
                                ('/obj/item/clothing/shoes/leatherboots/tailored', 'boots', leather),
                                ('/obj/item/clothing/pouch_belt/tailored', 'belt', (
                                    leather[0].replace('one leather sheet', 'one leather sheet (a cloth or woolcloth sheet for a waist sash)'),
                                    leather[1]))):
        name = f'Design, cut and sew your own {kind}'
        steps = [
            start[0],
            start[1],
            f'Use the project in hand. Choose the {kind} to make from the garments your tailoring knowledge allows, and dye the body and each pattern piece from the dyes your knowledge allows (any colour with Textile Mills). Pattern book keeps up to 20 of your designs for every character you play on that server. Shirts, knee tunics, gowns, jackets, coats, cloaks and round, pointed, soft and tall hats also let you choose Pieces such as sleeves, necklines, legwear, belts, collars, closures, trims and patterns, or the band, brim, flaps and decoration of a hat; gloves, shoes, boots and belts have cuffs, backs, fingertips, soles, toes, fastenings, buckles, patterns and ends. Some pieces need more fabric or knowledge. A live preview shows all four sides.',
            'Choose Cut fabric (30 ticks) once the project holds enough fabric for that garment. Cutting locks the design and sets spare sheets aside.',
            'Use the cut pieces in hand and choose Sew (60 ticks). One paid project becomes one wearable garment. Finished garments accept ordinary clothing accessories.',
        ]
        add(name, 'Tailoring', [('/obj/item/tailoring_project', 1)], [(output, 1)], PATH, line, ' '.join(steps))
        record = records[-1]
        routes.append(dict(name=name, file=PATH, line=line, audit_commit=AUDIT_COMMIT,
                           inputs=[x['id'] for x in record['inputs']],
                           outputs=[x['id'] for x in record['outputs']],
                           tools=[], steps=steps, conditions=' '.join(steps),
                           era='Weaving for the project; each garment and some pieces need their own research (Classical Dress, Tailoring, Fine Garments, Textile Mills, Ready-Made Clothing or Synthetic Fabrics) and personal knowledge where enabled.',
                           map_notes='Fabric supply and research depend on the map. No new material spawns.',
                           status='Current-source route; native and connected-client checks are reported separately.'))
    return routes
