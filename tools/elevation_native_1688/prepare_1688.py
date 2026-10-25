"""Versioned 516.1688 test-only adapter. Source preparation only; no runtime."""
import argparse, hashlib, importlib.util, json
from pathlib import Path

def replace_once(text, before, after):
    if text.count(before) != 1:
        raise ValueError('Adapter anchor changed: ' + repr(before))
    return text.replace(before, after, 1)

def prepare(source, output):
    spec = importlib.util.spec_from_file_location('frozen_elevation_prepare', source/'tests/elevation/prepare.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    receipt = module.prepare(output)
    probe = (output/'probe.dm').read_text()
    probe = replace_once(probe, 'var/elevation_checks = 0', '''var/elevation_checks = 0
// Roof-free fixture declarations only: /obj/roof is deliberately absent.
var/list/area_list = list()
/area/caribbean/roofed
var/elevation_constructor_expected = null
var/elevation_constructor_checks = 0
/obj/item/elevation_payload/New()
	..()
	if(!isnull(elevation_constructor_expected))
		elevation_check(get_elevation(locate(3,3,1)) == elevation_constructor_expected, "profile absent during replacement constructor")
		elevation_constructor_checks++
/proc/elevation_1688_list_semantics()
	var/list/row = list("x1" = 2, "x2" = 4, "y1" = 2, "y2" = 4, "z" = 1, "metres" = 1200)
	var/list/rows = list(row)
	elevation_check(isnull(rows[row]), "native plain-list association lookup differs")
	var/datum/elevation_profile/P = build_elevation_profile(15, rows, 8, 6, 2)
	elevation_check(P.at(3,3,1) == 1200, "native valid row rejected")
	rows[row] = 42
	var/rejected = FALSE
	try
		build_elevation_profile(15, rows, 8, 6, 2)
	catch(var/exception/E)
		rejected = !!E
	elevation_check(rejected, "native associative outer-list record admitted")''')
    probe = replace_once(probe, '\tOpenPort("none")\n\ttry', '\tvar/initial_port = world.port\n\tOpenPort("none")\n\ttry')
    probe = replace_once(probe, '\t\televation_check(world.port == 0, "fixture port not closed")', '''		elevation_check(world.byond_version == 516 && world.byond_build == 1688, "wrong native runtime version")
		elevation_check(world.port == 0, "fixture port not closed")
		OpenPort(0)
		elevation_check(world.port == 0, "fixture reopened listener")
		elevation_1688_list_semantics()''')
    probe = replace_once(probe, '\t\televation_check(ticker.loadmap(), "saved elevation import failed")', '\t\televation_constructor_expected = 1200\n\t\televation_check(ticker.loadmap(), "saved elevation import failed")\n\t\televation_check(elevation_constructor_checks > 0, "saved constructor oracle not exercised")')
    probe = replace_once(probe, '\t\televation_check(ticker.loadmap(), "legacy missing elevation rejected")', '\t\televation_constructor_expected = 0\n\t\televation_constructor_checks = 0\n\t\televation_check(ticker.loadmap(), "legacy missing elevation rejected")\n\t\televation_check(elevation_constructor_checks > 0, "legacy constructor oracle not exercised")')
    probe = replace_once(probe, 'list("passed" = TRUE, "checks" = elevation_checks)', 'list("passed" = TRUE, "checks" = elevation_checks, "version" = "516.1688", "initial_port" = initial_port, "closed_port" = world.port, "constructor_checks" = elevation_constructor_checks)')
    (output/'probe.dm').write_text(probe)
    adapter = dict(adapter_version='elevation-native-516.1688-v1', required_byond='516.1688', frozen_required_byond=receipt['required_byond'], prepared_only=True, native_executed=False, source_receipt='preparation.json', adapter_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), generated_sha256={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in output.iterdir() if p.is_file()})
    (output/'adapter-1688.json').write_text(json.dumps(adapter,indent=2))
    return adapter

if __name__ == '__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args(); prepare(a.source.resolve(), a.output.resolve())
