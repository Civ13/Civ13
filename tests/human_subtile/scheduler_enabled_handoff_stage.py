"""One enabled-owner fixture adapter built on the reviewed transition stage."""
import hashlib
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('handoff_transition_stage', HERE/'scheduler_transition_stage.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)

SCOPE = 'headless mob scheduler; enabled flee to follow handoff; no client/contact parity'
FIXTURE = 'tests/human_subtile/scheduler_enabled_handoff_draft.dm'
PROBE = base.PROBE


def adapted_probe(original):
    text = base.adapt_probe(original)
    replacements = (
        ('fixture_scheduler_transition_main()', 'fixture_scheduler_enabled_handoff_main()'),
        ('"scope" = "' + base.SCOPE + '"', '"scope" = "' + SCOPE + '"'),
    )
    for before, after in replacements:
        if text.count(before) != 1:
            raise ValueError('handoff probe preimage')
        text = text.replace(before, after, 1)
    return text


def adapted_dme(original):
    include = '#include "tests\\human_subtile\\scheduler_enabled_handoff_draft.dm"'
    if '#include "tests\\human_subtile\\scheduler_core_draft.dm"' not in original or include in original:
        raise ValueError('handoff DME preimage')
    return original + '\n' + include + '\n'


def adapt(out, manifest, current):
    out = Path(out)
    # The accepted adapter supplies the sole subject-only clients.len exception
    # and retains all existing production commands and callback boundaries.
    base.adapt(out, manifest, current)
    stage = out/'stage'
    probe = stage/PROBE
    current_probe = probe.read_text(encoding='utf-8')
    before = 'fixture_scheduler_transition_main()'
    after = 'fixture_scheduler_enabled_handoff_main()'
    if current_probe.count(before) != 1 or current_probe.count('"scope" = "'+base.SCOPE+'"') != 1:
        raise ValueError('handoff staged probe preimage')
    updated = current_probe.replace(before, after, 1).replace('"scope" = "'+base.SCOPE+'"',
                                                               '"scope" = "'+SCOPE+'"', 1)
    dme = out/manifest['dme']
    old_dme = dme.read_text(encoding='utf-8')
    new_dme = adapted_dme(old_dme)
    fixture = stage/FIXTURE
    if not fixture.is_file():
        raise ValueError('handoff fixture absent')
    # All preimages are checked before the second-stage write.
    current.adapt(out, manifest, PROBE, current_probe, updated)
    dme.write_text(new_dme, encoding='utf-8', newline='\n')
    for path in (PROBE, dme.relative_to(stage).as_posix(), FIXTURE):
        raw=(stage/path).read_bytes()
        manifest['stage_files'][path]={'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
    manifest['handoff_scope']=SCOPE
    manifest['native_executed']=False
    (out/'handoff-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')