"""Project reviewed manual woodworking quantities from their production spec."""
import hashlib
import re

SOURCE = 'code/modules/1713/primitive_woodworking.dm'


def specifications(text):
    rows = {}
    for mode, body in re.findall(r'if \("([a-z_]+)"\)\n\t\t\treturn list\(([^\n]+)\)', text):
        fields = dict(re.findall(r'"(\w+)" = (/[\w/]+|\d+)', body))
        rows[mode] = {key: value if value.startswith('/') else int(value) for key, value in fields.items()}
    if set(rows) != {'pieces', 'wedge', 'mallet', 'plank', 'flatten'} or any(set(row) != {'cost', 'count', 'delay', 'output', 'bark'} for row in rows.values()):
        raise ValueError('Review changed woodworking specification before exporting')
    return rows


def add_woodworking(files, add, records, variants, audit_commit='uncommitted'):
    text = files.get(SOURCE, '')
    specs = specifications(text)
    log = '/obj/item/stack/material/wood'
    piece = '/obj/item/stack/material/wood_piece'
    crude = '/obj/item/stack/material/crude_plank'
    hammer = '/obj/item/weapon/hammer/tribalhammer'
    wedge = '/obj/item/weapon/material/wooden_wedge'
    names = {'pieces': 'Cut a small wood piece', 'wedge': 'Whittle a wooden wedge',
             'mallet': 'Whittle a wooden mallet', 'plank': 'Split crude planks with wooden hammer and wedge',
             'flatten': 'Flatten crude planks with a sharp non-wooden tool'}
    routes = []
    for mode, spec in specs.items():
        inputs = [(log if mode in ('pieces', 'plank') else crude if mode == 'flatten' else piece, spec['cost'])]
        outputs = [(spec['output'], spec['count'])]
        if spec['bark']:
            outputs.append(('/obj/item/stack/bark', spec['bark']))
        tools = (['Held wooden hammer (ordinary or simple wooden mallet)', 'Wooden wedge in other hand; reused, wears'] if mode == 'plank' else ['Held sharpened flint or sharp tool with verified non-wood working material; zero tool wear'] if mode == 'flatten'
                 else ['Held sharpened flint, or sharp knife with actual material hardness greater than the wood'])
        conditions = (f"{spec['delay']} deciseconds / strength coefficient. Exact source and held tools must remain in place; interrupted or save-crossing work pays nothing. "
                      + ('Two logs become one crude plank; no axe or saw required to split. Flatten with a sharp non-wooden tool before finished-plank recipes. ' if mode == 'plank' else 'One crude plank becomes one finished plank; tool durability is unchanged. Sharpened flint qualifies. Wooden working materials and unknown materials do not; wooden handles on metal blades are allowed. ' if mode == 'flatten' else 'No axe, prior plank or station required. ')
                      + 'Ordinary wood only; actual map resources are not guaranteed.')
        line = text[:text.index('if ("'+mode+'")')].count('\n') + 1
        add(names[mode], 'Manual woodworking', inputs, outputs, SOURCE, line, conditions, 'woodwork_spec and guarded primitive_woodwork_action')
        routes.append(dict(name=names[mode],file=SOURCE,line=line,inputs=[x[0] for x in inputs],outputs=[x[0] for x in outputs],
                           audit_commit=audit_commit,source_sha256=hashlib.sha256(text.encode()).hexdigest(),
                           tools=tools,conditions=conditions,steps=[names[mode]+'.', conditions],
                           era='No new processing era gate; normal starting materials and existing recipes retain their gates.',
                           status='current source contract; native gameplay and initialized reachability unverified',
                           map_notes='Logs and sharp tools must actually be obtained. Desert biome alone supplies no guarantee.'))
    variants[piece] = dict(type=piece,state='sheet-wood',name='small wood piece')
    variants[crude] = dict(type=crude,state='sheet-wood',name='crude plank (flatten before crafting)')
    variants[wedge] = dict(type=wedge,state='sharpened_stick',name='wooden splitting wedge')
    variants[hammer] = dict(type=hammer,state='tribalhammer',name='simple wooden mallet')
    return routes
