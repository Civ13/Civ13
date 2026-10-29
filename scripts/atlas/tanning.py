"""Reviewed procedural tanning routes, with source drift checks before export.

These actions are callbacks, not declarative recipes. Quantities below are an
explicit source audit; changing an audited source requires reviewing this file.
"""
import hashlib
import json
from pathlib import Path
import re

LEATHER = 'code/game/objects/items/stacks/sheets/leather.dm'
HARVEST = 'code/modules/1713/animal_harvest.dm'
LOGS = 'code/modules/materials/material_sheets.dm'
RACK = 'code/game/objects/structures/converters.dm'
STACK = '/obj/item/stack/material/'
BARK = '/obj/item/stack/bark'
STATION = '/obj/structure/converter/tanning'


def add_tanning(files, add, records, variants):
    audit = json.loads(Path(__file__).with_name('tanning-contracts.json').read_text())
    for path, expected in audit['sources'].items():
        actual = hashlib.sha256(files[path].replace('\r\n', '\n').encode()).hexdigest()
        if actual != expected:
            raise ValueError('Tanning source changed: review atlas routes and tanning-contracts.json: ' + path)
    routes = []

    def route(name, inputs, outputs, path, marker, steps, tools=(), processor=False):
        line = files[path][:files[path].index(marker)].count('\n') + 1
        conditions = ' '.join(steps)
        add(name, 'Leather tanning', inputs, outputs, path, line, conditions)
        record = records[-1]
        if processor:
            record.update(processor='tanning_rack', processor_name='Tanning racks', station=STATION)
        routes.append(dict(name=name, file=path, line=line,
                           audit_commit=audit['reviewed_commit'],
                           inputs=[x['id'] for x in record['inputs']],
                           outputs=[x['id'] for x in record['outputs']],
                           steps=list(steps), tools=list(tools), conditions=conditions,
                           era='Processing adds no era gate; rack construction retains Resource Processing research and map/faction gates.',
                           map_notes='Animals, logs, water, vessels and construction depend on the selected map.',
                           status='source-reviewed route; native gameplay and graphical acceptance pending'))

    route('Butcher mammals for raw hides', [('/mob/living/simple_animal', 'eligible corpse; consumed')],
          [(STACK+'rawhide', '1-6, species dependent')], HARVEST, '/mob/living/simple_animal/proc/harvest_skin_yield()',
          ('Use a held sharp tool on a dead eligible mammal on harm intent and complete harvesting nearby.',
           'Raw-hide pieces = min(6, max(1, butcher_yield() - 2)); meat and other corpse products are separate.',
           'Grab-intent skinning preserves species fur pelts where defined; the corpse can be claimed only once.'), ['Held sharp tool'])
    for sex in ('f', 'm'):
        route('Harvest adult turkey '+('hen' if sex == 'f' else 'tom')+' skin',
              [('/mob/living/simple_animal/turkey_'+sex, 'dead corpse; consumed')], [(STACK+'rawhide', 1)],
              HARVEST, '/mob/living/simple_animal/proc/harvest_skin_yield()',
              ('Use a held sharp tool on harm or grab intent and finish harvesting adjacent to the corpse.',
               'One adult turkey gives one raw hide and its normal meat; chicks give no hide.',
               'Turkeys do not yield mammalian organs, bones, sinew or fat. One claim per corpse.'), ['Held sharp tool'])
    pelts = sorted(set(re.findall(r'new (/obj/item/stack/material/pelt[^\s(]*)\(site,', files[HARVEST])))
    for source in [STACK+'rawhide', STACK+'pelt', *pelts]:
        name = source.rsplit('/', 1)[1].replace('_', ' ')
        route('Scrape '+name+' into a prepared hide', [(source, 1)], [(STACK+'hairlesshide', 1)], LEATHER,
              '/obj/item/stack/material/proc/prepare_hide(',
              ('Apply a held sharp tool to a nearby raw hide or fur pelt; complete 50 ticks of scraping.',
               'One piece becomes one prepared hairless hide; cancellation retains the input.',
               'Scraping a pelt sacrifices that piece for leather; unprocessed fur remains usable in pelt recipes.'), ['Held sharp tool'])
    route('Wash a prepared hide', [(STACK+'hairlesshide', 1), ('water', 5)], [(STACK+'wethide', 1)],
          LEATHER, '/obj/item/stack/material/hairlesshide/attackby(',
          ('Apply a held open liquid container containing at least 5 units of water to a nearby prepared hide.',
           'Or hold the hide and click a nearby open container or unlocked barrel. Each use consumes one hide and 5 water; saved hairless hides enter here.'), ['Accessible liquid container'])
    route('Rack-dry washed hides', [(STACK+'wethide', 'n pieces'), (STATION, 'station; not consumed')],
          [(STACK+'dryhide', 'n pieces')], RACK, '/obj/structure/converter/tanning\n',
          ('Put a held wet-hide stack on an empty nearby tanning rack; drying takes 300 ticks, normally 30 seconds.',
           'Retrieve the contents with an empty hand; early removal cancels the batch without consuming hides.',
           'Retrieve dry hides before loading another stack. Prepared hides and lead are not valid inputs.',
           'A restored wet batch restarts its full delay. One input piece remains one output piece.'), processor=True)
    route('Tan a dry hide into leather', [(STACK+'dryhide', 1), ('tannin', 5)], [(STACK+'leather', 1)],
          LEATHER, '/obj/item/stack/material/dryhide/attackby(',
          ('Apply a held open liquid container containing at least 5 units of tannin to a nearby dry hide.',
           'Or hold the hide and click a nearby open container or unlocked barrel. Each use consumes one dry hide and 5 tannin, producing one ordinary leather sheet for existing recipes.'), ['Accessible liquid container'])
    route('Extract bark tannin', [(BARK, 1), ('water', 10)], [('tannin', 10)],
          LEATHER, '/obj/item/stack/bark/attackby(',
          ('Apply a held open liquid container with at least 10 water to a nearby piece of tree bark.',
           'One bark and 10 water become 10 tannin in that vessel; a full vessel works because liquid volume is unchanged.',
           'Or hold the bark and click a nearby open container or unlocked barrel. Wood mugs and other open liquid containers work; sealed or inaccessible holders do not. This is an explicit paid interaction, not a splash.'), ['Accessible liquid container'])
    for tool, cost, planks in [('hatchet', 2, 1), ('saw', 1, 4)]:
        route('Cut logs with a '+tool+' for bark', [(STACK+'wood', cost)],
              [(STACK+'woodplank', planks), (BARK, cost)], LOGS, '/obj/item/stack/material/wood/proc/cut_logs(',
              (f'Use a held {tool} on nearby logs and finish cutting; {cost} log units yield {planks} plank units and {cost} bark pieces.',
               'Interrupted work consumes nothing; actor, held tool, log location and remaining stock are rechecked.'), ['Held '+tool])
    for stage, name in [('rawhide', 'raw hide'), ('hairlesshide', 'prepared hairless hide'),
                        ('wethide', 'wet hide'), ('dryhide', 'dry hide'), ('leather', 'leather')]:
        variants['/material/'+stage] = dict(type=STACK+stage, name=name)
    variants[BARK] = dict(type=BARK, name='tree bark')
    variants[STATION] = dict(type=STATION, name='tanning rack')
    # Tannin is a reagent, not an atom. Keep the atlas's explicit source symbol.
    variants['tannin'] = dict(type='tannin', name='tannin (bark tanning solution)')
    return routes
