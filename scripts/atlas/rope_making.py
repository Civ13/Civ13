"""Reviewed procedural cordage routes. Drift checks bind tuning to production."""
PATH = 'code/modules/1713/rope_making.dm'
PREFIX = '/obj/item/'
# First implementation containing the reviewed production actions, retained as
# provenance only. Generation/tests read current files, never Git history.
AUDIT_COMMIT = '9bd17d45d3815ca38dbab3c3438d43040adc6fc9'


def add_rope_making(files, add, records):
    source = files[PATH]
    required = ('if (!use(2))', 'user.rope_making_wait(300, src)',
                'new /obj/item/stack/dressed_hemp(site, 2, FALSE)',
                'if (!F.use(1))', 'new product(T, 1, FALSE)',
                'if (Y.amount < 4 || !Y.use(4))', 'B.stage = 1',
                'new /obj/item/stack/material/rope(site, 4, FALSE)',
                'user.rope_making_wait(50, F)', 'user.rope_making_wait(100, src)')
    if any(text not in source for text in required):
        raise ValueError('Rope source changed; review Atlas quantities and stages')
    routes = []

    def route(name, inputs, outputs, marker, steps, station=None, tools=()):
        line = source[:source.index(marker)].count('\n') + 1
        add(name, 'Rope making', inputs, outputs, PATH, line, ' '.join(steps))
        record = records[-1]
        if station:
            record.update(processor='rope_making', processor_name='Rope making', station=station)
        routes.append(dict(name=name, file=PATH, line=line,
                           audit_commit=AUDIT_COMMIT,
                           inputs=[x['id'] for x in record['inputs']],
                           outputs=[x['id'] for x in record['outputs']],
                           steps=list(steps), tools=list(tools), conditions=' '.join(steps),
                           era='Spindle construction: Basic Tools. Benches and ropewalk: Resource Processing. Actual faction/map research gates apply.',
                           map_notes='Hemp/flax acquisition and fresh water depend on the map. No new spawn grants.',
                           status='Source-reviewed gameplay tuning; durations/yields are not historical measurements.'))

    route('Tie and ret hemp for rope', [(PREFIX+'stack/material/hemp', 2)],
          [(PREFIX+'hemp_rope_bundle', 1)], '/obj/item/stack/material/hemp/proc/tie_rope_bundle',
          ('Hold two raw hemp and choose Tie Hemp Bundle. Use the bundle on adjacent non-irradiated fresh water.',
           'Complete one attended 300-tick retting action. Interruption preserves the paid bundle; click it in water to resume.',
           'Recover the retted bundle into a hand before loading the dressing bench.'))
    route('Dry, break, scutch and comb hemp', [(PREFIX+'hemp_rope_bundle', 1)],
          [(PREFIX+'stack/dressed_hemp', 2)], '/obj/structure/hemp_dressing_bench/proc/dress',
          ('Load one held retted hemp bundle into an empty anchored dressing bench.',
           'Four separate 100-tick uses dry it, break woody stems, scutch shives and comb fibres.',
           'Drag the bench onto yourself to recover unfinished work; completed stages survive removal and saves.'),
          '/obj/structure/hemp_dressing_bench')
    for material, feed in [('hemp', 'dressed_hemp'), ('flax', 'flax_tow')]:
        route('Spin '+material+' rope yarn', [(PREFIX+'stack/'+feed, 1)],
              [(PREFIX+'stack/rope_yarn/'+material, 1)], '/obj/item/rope_spindle/proc/spin',
              ('Hold the fibre and hand spindle in opposite hands; use the spindle on the fibre for 50 ticks.',
               'Loss of either held item or interruption produces nothing and consumes nothing.',
               'Flax tow comes from the existing tied-flax, water-retting and flax-comb route. Its quick twine action remains available.'),
              tools=('Hand spindle',))
        route('Load, twist and counter-lay '+material+' rope', [(PREFIX+'stack/rope_yarn/'+material, 4)],
              [(PREFIX+'stack/material/rope', 4)], '/obj/structure/ropewalk/proc/load_yarn',
              ('Load four bundles of the same yarn material into an empty anchored hand ropewalk. Materials cannot be mixed.',
               'Use for 100 ticks to twist four strands under tension, then use again for 100 ticks to lay them together in the opposite direction.',
               'Four yarn bundles represent equal-length groups of yarn, not four individual threads. Four output coils are game units.',
               'Recover paid unfinished work by dragging the frame onto yourself. A twisted batch resumes at counter-laying.',
               'Output is ordinary rope for existing consumers. Grass crude twine, sinew, tow twine and direct raw-plant recipes remain available.'),
              '/obj/structure/ropewalk')
    return routes
