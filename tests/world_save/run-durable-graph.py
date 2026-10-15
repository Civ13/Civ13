"""Stage or run the actual bounded durable metadata graph in isolated storage."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile


def adjudicate(result, log, control, contracts, associative=False):
    minimum = {'binding': 1, 'alist-binding': 4, 'alist-kind': 3, 'alist-values': 6}.get(control, 13 if associative else (32 if contracts else 16))
    if not result.get('done') or result.get('checks', 0) < minimum:
        raise RuntimeError('Native fixture omitted required checks')
    if any(marker in log.lower() for marker in ('runtime error', 'bad ref', 'unexpected exception')):
        raise RuntimeError('Native fixture did not complete cleanly')
    failures = [line.removeprefix('FAIL: ') for line in log.splitlines() if line.startswith('FAIL: ')]
    if result.get('failures') != len(failures):
        raise RuntimeError('Fixture failure count differs from native log')
    expected = {
        'infinity': ('infinite artillery integrity did not restore',),
        'generation': ('cross-generation leader accepted',),
        'alias': ('list alias/cycle changed',),
        'binding': ('unsaved metadata leader was silently dropped',),
        'alist-values': ('alist numeric associations lost',),
        'alist-kind': ('alist graph kind lost',),
        'alist-alias': ('alist alias or mixed cycle lost',),
        'alist-binding': ('alist unsaved leader was silently dropped',),
        'clock': ('clock values did not rebase:',),
        'omission': ('missing field mutated metadata', 'invalid field mutated metadata')
                    + ('invalid artillery wire value mutated target',) * 8,
        'timer': ('old callback survived restored timer or new callback duplicated',
                  'repeated restoration stacked callbacks',
                  'invalid restore cancelled valid pending callback',
                  'timer fired while save/load lock was owned',
                  'deferred callback did not resume exactly once', 'cancelled callback fired'),
    }
    if not control:
        if failures:
            raise RuntimeError(f'Positive fixture failed: {failures}')
        return
    prefixes = expected[control]
    if len(failures) != len(prefixes) or any(not message.startswith(prefix) for message, prefix in zip(failures, prefixes)):
        raise RuntimeError(f'Control failed outside its intended assertions: {failures}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--negative-control', choices=('generation', 'alias', 'binding', 'clock', 'omission', 'timer', 'infinity', 'alist-values', 'alist-kind', 'alist-alias', 'alist-binding'))
    parser.add_argument('--alist', action='store_true', help='Verify native associative collections and actual map squad defaults')
    parser.add_argument('--contracts', action='store_true',
                        help='Also verify the actual field and portable-timer contracts')
    args = parser.parse_args()
    if args.negative_control in ('clock', 'omission', 'timer', 'infinity'):
        args.contracts = True
    if args.negative_control and args.negative_control.startswith('alist-'):
        args.alist = True
    if args.alist and args.contracts:
        parser.error('Keep associative graph and scalar contract controls separate')
    if not args.prepare_only and not args.byond_bin:
        parser.error('--byond-bin is required to launch native verification')
    root = Path(__file__).resolve().parents[2]
    source_path = root / 'code/modules/persistence/durable_graph.dm'
    probe_path = Path(__file__).with_name('durable_graph_probe.dm')
    source = source_path.read_text(encoding='utf-8')
    mutations = {
        'generation': ('F["/generation"] != generation || ', ''),
        'alias': ('if(list_ids[identity]) return list_ids[identity]', 'if(list_ids[identity]) return add_node(list("kind" = "value", "value" = null))'),
        'binding': ('if(node["kind"] == "entry" && !node["ref"])', 'if(node["kind"] == "entry" && node["ref"] < 0)'),
        'alist-binding': ('if(node["kind"] == "entry" && !node["ref"])', 'if(node["kind"] == "entry" && node["ref"] < 0)'),
        'alist-values': ('values += encode(snapshot[key], depth + 1)', 'values += encode(null, depth + 1)'),
        'alist-kind': ('is_associative ? "alist" : "list"', '"list"'),
        'alist-alias': ('\t\t\t\ttarget[key] = restored[values[j]]\n', '\t\t\t\ttarget[key] = restored[values[j]] == target ? null : restored[values[j]]\n'),
    }
    if args.negative_control in mutations:
        before, after = mutations[args.negative_control]
        if source.count(before) != 1:
            raise RuntimeError('Negative-control source anchor changed')
        source = source.replace(before, after, 1)
    output = Path(tempfile.mkdtemp(prefix='civ13-durable-graph-'))
    (output / 'graph.dm').write_text(source, encoding='utf-8', newline='\n')
    probe = probe_path.read_text(encoding='utf-8')
    metadata_source = (root / 'code/game/objects/map_metadata/_map_metadata.dm').read_text(encoding='utf-8')
    defaults_start = metadata_source.index('\tvar/list/list/faction1_squads = alist(')
    defaults_end = metadata_source.index('\tvar/required_players', defaults_start)
    defaults = metadata_source[defaults_start:defaults_end]
    probe = probe.replace('/obj/map_metadata\n', '/obj/map_metadata\n' + defaults, 1)
    macros = (root / 'code/_macros.dm').read_text(encoding='utf-8')
    list_macro = re.findall(r'^#define islist\(A\) .+$', macros, re.M)
    if len(list_macro) != 1:
        raise RuntimeError('Production islist macro anchor changed')
    environment = list_macro[0] + '\n#include "probe.dm"\n#include "graph.dm"\n'
    infinity_macro = re.findall(r'^#define INFINITY\s+.+$', (root / 'code/predefines.dm').read_text(encoding='utf-8'), re.M)
    if len(infinity_macro) != 1:
        raise RuntimeError('Production infinity macro anchor changed')
    environment = infinity_macro[0] + '\n' + environment
    if args.alist:
        probe = probe.replace('\t\tcheck_graph()\n', '\t\tcheck_alist_graph()\n', 1)
        alist_probe = probe_path.with_name('durable_alist_probe.dm')
        (output / alist_probe.name).write_bytes(alist_probe.read_bytes())
        environment += f'#include "{alist_probe.name}"\n'
        if args.negative_control in ('alist-kind', 'alist-binding', 'alist-values'):
            environment = '#define DURABLE_' + args.negative_control.upper().replace('-', '_') + '_CONTROL\n' + environment
    if args.negative_control == 'binding':
        environment = '#define DURABLE_BINDING_CONTROL\n' + environment
    if args.contracts:
        if args.negative_control in mutations:
            parser.error('Keep graph mutation controls separate from contract verification')
        anchor = '\t\tcheck_graph()\n'
        if probe.count(anchor) != 1:
            raise RuntimeError('Contract probe insertion anchor changed')
        probe = probe.replace(anchor, anchor + '\t\tcheck_contract()\n\t\tcheck_timers()\n', 1)
        for name in ('durable_contract.dm', 'durable_timers.dm'):
            part = source_path.with_name(name).read_text(encoding='utf-8')
            contract_mutations = {
                'infinity': ('durable_contract.dm',
                             'if(kind == "artillery_integrity" && value == "positive_infinity") value = INFINITY',
                             'if(kind == "artillery_integrity" && value == "positive_infinity") value = 0'),
                'clock': ('durable_contract.dm',
                          '\t\tif(kind == "world_time_deadline") value = isnull(value) ? -1 : world.time + value',
                          '\t\tif(kind == "world_time_deadline") value = isnull(value) ? -1 : value'),
                'omission': ('durable_contract.dm',
                             '\tdurable_metadata_validate_fields(values, schema)',
                             '\tif(FALSE) durable_metadata_validate_fields(values, schema)'),
                'timer': ('durable_timers.dm',
                          '\t\tif(!owner || revision != expected_revision || pending[key] != row) return',
                          '\t\tif(!owner) return'),
            }
            if args.negative_control in contract_mutations:
                filename, before, after = contract_mutations[args.negative_control]
                if name == filename:
                    if part.count(before) != 1:
                        raise RuntimeError('Contract negative-control source anchor changed')
                    part = part.replace(before, after, 1)
            (output / name).write_text(part, encoding='utf-8', newline='\n')
            environment += f'#include "{name}"\n'
        contract_probe = probe_path.with_name('durable_contract_probe.dm')
        (output / contract_probe.name).write_bytes(contract_probe.read_bytes())
        environment += f'#include "{contract_probe.name}"\n'
    (output / 'probe.dm').write_text(probe, encoding='utf-8', newline='\n')
    (output / 'probe.dme').write_text(environment, encoding='utf-8')
    receipt = {'source_sha256': hashlib.sha256(source_path.read_bytes()).hexdigest(),
               'probe_sha256': hashlib.sha256(probe_path.read_bytes()).hexdigest(),
               'negative_control': args.negative_control, 'prepared_only': args.prepare_only,
               'contracts': args.contracts, 'alist': args.alist,
               'generated_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                                    for p in output.iterdir() if p.suffix in ('.dm', '.dme')}}
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    print(f'Retained evidence: {output}', flush=True)
    if args.prepare_only:
        return
    byond = args.byond_bin.resolve(strict=True)
    compiler = byond / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = byond / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    build = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=output,
                           capture_output=True, text=True, timeout=120)
    (output / 'compile.log').write_text(build.stdout + build.stderr, encoding='utf-8')
    if build.returncode or '0 errors, 0 warnings' not in build.stdout:
        raise RuntimeError('Native compilation failed; see retained compile.log')
    run = subprocess.run([str(daemon), 'probe.dmb', '-invisible', '-trusted', '-close', '-log', 'native.log'],
                         cwd=output, capture_output=True, text=True, timeout=60)
    (output / 'daemon.log').write_text(run.stdout + run.stderr, encoding='utf-8')
    result = json.loads((output / 'result.json').read_text(encoding='utf-8'))
    log = (output / 'native.log').read_text(encoding='utf-8', errors='replace')
    if run.returncode:
        raise RuntimeError('Native fixture did not complete cleanly')
    adjudicate(result, log, args.negative_control, args.contracts, args.alist)
    receipt.update(result=result, expected_failure_caught=bool(args.negative_control))
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    print(json.dumps(receipt, indent=2))


if __name__ == '__main__':
    main()
