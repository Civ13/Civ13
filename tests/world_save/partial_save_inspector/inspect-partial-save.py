#!/usr/bin/env python3
"""Copy-only, bounded structural inspection of Civ13's incomplete level-2 save.

Run as the ordinary server user. No game imports, load operations, live control,
file replacements, credentials, or networking to the game are used.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import resource
import shutil
import stat
import subprocess
import sys
import tempfile

BIN = Path('/usr/local/byond/bin')
CURRENT_RUNTIME = None
MAX_BYTES = 256 * 1024 * 1024
SCHEMA_BASE = '8b91aff1a86c99062b2c07403a7d397884c3c06d'
TYPE_PATTERN = re.compile(r'/(?:mob|obj|datum|turf|area)(?:/[A-Za-z_][A-Za-z0-9_]*)*')
FIELD_PATTERN = re.compile(r'[A-Za-z_][A-Za-z0-9_]{0,95}')


def selected_runtime(bin_dir, archive):
    if archive is None: return None
    spec = importlib.util.spec_from_file_location('inspector_current_runtime', Path(__file__).parents[1]/'current_runtime.py')
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module.select(bin_dir, archive)

WORLD_HEADER = r'''
#define EXCEPTION(message) new /exception(message)
/world
    maxx = 1
    maxy = 1
    maxz = 1
    hub = ""
    hub_password = ""
    visibility = 0
/world/OpenPort(port)
    if(port == "none") return ..()
    return 0
/client/New()
    return null
/world/Error(exception/E)
    text2file("NATIVE_ERROR\n", "native-error.txt")
    del(world)
'''

WRITER = WORLD_HEADER + r'''
// The reader deliberately does not define these fixture types.
/obj/inspector_fixture
/mob/inspector_fixture
/world/New()
    OpenPort("none")
    if(world.port)
        del(world)
        return
    var/savefile/F = new("fixture.sav")
    F["/format_version"] << 2
    F["/generation"] << "PRIVATE_TEST_GENERATION"
    F["/entries/0/1/type"] << /obj/inspector_fixture
    F["/entries/0/1/name"] << list("kind"="value", "value"="PRIVATE_TEST_PLAYER_NAME")
    F["/entries/0/1/lastattacked"] << list("kind"="entry", "ref"=2)
    F["/entries/0/2/type"] << /mob/inspector_fixture
    F["/entries/0/2/mind"] << list("kind"="value", "value"="PRIVATE_TEST_CREDENTIAL")
    F["/entries/1/513/type"] << /obj/inspector_fixture
    F["/entries/1/513/original_target"] << list("kind"="entry", "ref"=2)
    F.Flush()
    del(F)
    var/savefile/B = new("malformed.sav")
    B["/format_version"] << 2
    B["/entries/0/1/type"] << /obj/inspector_fixture
    B["/entries/0/1/type/forbidden_child"] << "PRIVATE_TEST_DO_NOT_EXPORT"
    B.Flush()
    del(B)
    text2file("WRITER_OK\n", "writer-ok.txt")
    del(world)
'''

READER = WORLD_HEADER + r'''
/proc/require(ok)
    if(!ok) throw EXCEPTION("Inspector schema or bound check failed")
/proc/number_name(value, low, high)
    var/n = text2num(value)
    require(isnum(n) && n >= low && n <= high && n == round(n) && "[n]" == value)
    return n
/proc/inspect_file(filename)
    var/savefile/F = new(filename)
    require(F.name)
    // Export only the small primitive header; never deserialize saved values.
    F.cd = "/format_version"
    require(F.dir.len == 0)
    var/version_export = F.ExportText("/format_version")
    require(istext(version_export) && length(version_export) <= 256)
    F.cd = "/entries"
    var/list/shards = F.dir.Copy()
    require(shards.len > 0 && shards.len <= 4096)
    var/highest_shard = -1
    for(var/s in shards)
        highest_shard = max(highest_shard, number_name(s, 0, 4095))
    var/list/records = list()
    var/examined_shards = 0
    var/highest_entry = 0
    // Numeric IDs reflect allocation order. Savefile.dir order does not.
    for(var/shard = highest_shard, shard >= 0 && records.len < 12, shard--)
        if(!("[shard]" in shards)) continue
        examined_shards++
        require(examined_shards <= 12)
        F.cd = "/entries/[shard]"
        var/list/ids = F.dir.Copy()
        require(ids.len > 0 && ids.len <= 512)
        var/list/numeric_ids = list()
        for(var/id in ids)
            var/n = number_name(id, shard*512 + 1, (shard+1)*512)
            numeric_ids += n
        while(numeric_ids.len && records.len < 12)
            var/ref = max(numeric_ids)
            numeric_ids -= ref
            highest_entry = max(highest_entry, ref)
            var/path = "/entries/[shard]/[ref]"
            F.cd = path
            var/list/fields = F.dir.Copy()
            require(fields.len <= 1024)
            var/type_export = ""
            if("type" in fields)
                F.cd = "[path]/type"
                require(F.dir.len == 0)
                type_export = F.ExportText("[path]/type")
                require(istext(type_export) && length(type_export) <= 4096)
            records += list(list("entry"=ref, "type_export"=type_export, "fields"=fields))
    del(F)
    return list("schema_version_export"=version_export, "highest_entry"=highest_entry, "records"=records, "port"=world.port)
/world/New()
    // require() must unwind to this catch. An uncaught DM exception can return
    // to its caller, and del(world) alone is not an immediate control-flow stop.
    try
        OpenPort("none")
        require(!world.port)
        var/selftest = world.params["mode"] == "selftest"
        var/filename = selftest ? "fixture.sav" : (world.params["mode"] == "reject" ? "malformed.sav" : "input.sav")
        require(fexists(filename))
        var/list/result = inspect_file(filename)
        text2file(json_encode(result), selftest ? "native-selftest.json" : "native-result.json")
    catch(var/exception/E)
        // Use only the exception's kind, never its text or private data.
        text2file(istype(E, /exception) ? "NATIVE_ERROR\n" : "NATIVE_NONEXCEPTION_ERROR\n", "native-error.txt")
        del(world)
        return
    del(world)
    return
'''


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def digest(path):
    require(path.resolve() == path and stat.S_ISREG(path.stat(follow_symlinks=False).st_mode),
            'Hash target is not an ordinary non-symlink file.')
    h = hashlib.sha256()
    total = 0
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as stream:
        require(stat.S_ISREG(os.fstat(stream.fileno()).st_mode), 'Hash target changed type.')
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            total += len(block)
            require(total <= MAX_BYTES, 'Hash target exceeds the 256 MiB bound.')
            h.update(block)
    return h.hexdigest()


def stamp(st):
    return (st.st_dev, st.st_ino, st.st_size, st.st_mtime_ns, st.st_ctime_ns)


def stable_copy(source, dest):
    require(source.resolve() == source, 'Source or parent is a symlink; stopped.')
    fd = os.open(source, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    try:
        before = os.fstat(fd)
        require(stat.S_ISREG(before.st_mode), 'Source is not an ordinary file.')
        require(0 < before.st_size <= MAX_BYTES, 'Source is empty or exceeds the 256 MiB inspection bound.')
        require(shutil.disk_usage(dest.parent).free > before.st_size * 2 + 64*1024*1024,
                'Insufficient free staging space.')
        h = hashlib.sha256()
        with dest.open('xb') as out:
            total = 0
            while True:
                block = os.read(fd, 1024*1024)
                if not block:
                    break
                total += len(block)
                require(total <= before.st_size, 'Source grew while copying; stopped.')
                h.update(block)
                out.write(block)
        require(total == before.st_size and stamp(os.fstat(fd)) == stamp(before),
                'Source changed while copying; stopped.')
        os.lseek(fd, 0, os.SEEK_SET)
        second = hashlib.sha256()
        total = 0
        while True:
            block = os.read(fd, 1024*1024)
            if not block:
                break
            total += len(block)
            require(total <= before.st_size, 'Source grew during verification; stopped.')
            second.update(block)
        require(total == before.st_size and second.digest() == h.digest()
                and stamp(os.fstat(fd)) == stamp(before)
                and stamp(source.stat(follow_symlinks=False)) == stamp(before),
                'Source changed during verification; stopped.')
        return {'bytes': total, 'sha256': h.hexdigest(), 'mtime_ns': before.st_mtime_ns}
    finally:
        os.close(fd)


def limits():
    os.umask(0o077)
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    resource.setrlimit(resource.RLIMIT_CPU, (30, 30))
    resource.setrlimit(resource.RLIMIT_AS, (768*1024*1024, 768*1024*1024))
    resource.setrlimit(resource.RLIMIT_FSIZE, (8*1024*1024, 8*1024*1024))


def native_run(command, stage, label, timeout=60, expect_rejection=False):
    # Raw native logs stay private. Never echo them: malformed data can appear in errors.
    log = stage / (label + '.log')
    env = os.environ.copy()
    env['LD_LIBRARY_PATH'] = str(BIN) + (':' + env['LD_LIBRARY_PATH'] if env.get('LD_LIBRARY_PATH') else '')
    if CURRENT_RUNTIME: CURRENT_RUNTIME.before_launch(label, stage)
    with log.open('xb') as stream:
        result = subprocess.run(command, cwd=stage, env=env, stdout=stream,
                                stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                                timeout=timeout, preexec_fn=limits)
    require(result.returncode == 0, label + ' failed; private log retained locally, do not upload it.')
    require(log.stat().st_size <= 8*1024*1024, 'Native log exceeded bound.')
    if expect_rejection:
        require((stage/'native-error.txt').is_file(), 'Malformed fixture was not rejected.')
    else:
        require(not (stage / 'native-error.txt').exists(), 'Native reader raised an error; no result accepted.')
    return log.read_text(errors='replace')


def compile_world(stage, name, text):
    (stage / (name + '.dme')).write_text(text, encoding='utf-8')
    log = native_run([str(BIN/'DreamMaker'), name+'.dme'], stage, name+'-compile')
    if CURRENT_RUNTIME: CURRENT_RUNTIME.validate_compile(0, log, name+'.dmb')
    else: require(re.search(r'DM compiler version\s+516[.]1681\b', log), 'Expected existing BYOND 516.1681 compiler.')
    require('0 errors, 0 warnings' in log and (stage/(name+'.dmb')).is_file(),
            name + ' compilation did not pass with zero errors and warnings.')


def run_world(stage, name, mode, expect_rejection=False):
    return native_run([str(BIN/'DreamDaemon'), name+'.dmb', '0', '-ip', '127.0.0.1',
                       '-trusted', '-invisible', '-nowebclient', '-close', '-params', 'mode='+mode],
                      stage, name+'-'+mode, timeout=60, expect_rejection=expect_rejection)


def exported_type(raw):
    require(isinstance(raw, str) and len(raw) <= 4096, 'Invalid native type export.')
    # No raw export text or arbitrary scalar values are ever printed.
    match = re.fullmatch(r'\s*(?:(?:type|\"?/?type\"?|\.)\s*=\s*)?(' + TYPE_PATTERN.pattern + r')\s*', raw)
    return match.group(1) if match else 'unavailable'


def sanitize_report(native):
    require(isinstance(native, dict), 'Native report is not an object.')
    version = native.get('schema_version_export')
    require(isinstance(version, str) and len(version) <= 256, 'Missing format version export.')
    # Accept BYOND's optional directory label and whitespace around one primitive.
    require(re.fullmatch(r'\s*(?:(?:format_version|"?/?format_version"?|\.)\s*=\s*)?2\s*', version),
            'Expected format version 2; no alternate schema guessed.')
    require(native.get('port') in (0, None), 'Inspector port was not closed.')
    records = native.get('records')
    require(isinstance(records, list) and 0 < len(records) <= 12, 'Unexpected record count.')
    clean = []
    previous = 2**22
    for row in records:
        require(isinstance(row, dict), 'Invalid native record.')
        entry = row.get('entry')
        require(type(entry) is int and 0 < entry < previous, 'Entries are not descending numeric IDs.')
        previous = entry
        fields = row.get('fields')
        require(isinstance(fields, list) and len(fields) <= 1024, 'Invalid field list.')
        require(all(isinstance(f, str) and FIELD_PATTERN.fullmatch(f) for f in fields),
                'Non-schema field name encountered; no unsafe names printed.')
        clean.append({'entry': entry, 'type': exported_type(row.get('type_export')),
                      'field_names': sorted(fields)[:128], 'field_count': len(fields),
                      'field_names_truncated': len(fields) > 128, 'has_content_field': 'content' in fields})
    require(native.get('highest_entry') == clean[0]['entry'], 'Highest record mismatch.')
    return {'format_version': 2, 'highest_entry': clean[0]['entry'], 'records': clean}


def load_native(stage, filename):
    path = stage/filename
    require(path.is_file() and path.stat().st_size <= 512*1024, 'Native report absent or too large.')
    return sanitize_report(json.loads(path.read_text(encoding='utf-8')))


def selftest(stage):
    compile_world(stage, 'writer', WRITER)
    compile_world(stage, 'reader', READER)
    run_world(stage, 'writer', 'fixture')
    require((stage/'writer-ok.txt').read_text().strip() == 'WRITER_OK', 'Fixture writer did not finish.')
    before = digest(stage/'fixture.sav')
    run_world(stage, 'reader', 'selftest')
    require(digest(stage/'fixture.sav') == before, 'Reader changed the synthetic save file.')
    result = load_native(stage, 'native-selftest.json')
    require([r['entry'] for r in result['records']] == [513, 2, 1], 'Shard ordering self-test failed.')
    require([r['type'] for r in result['records']] ==
            ['/obj/inspector_fixture', '/mob/inspector_fixture', '/obj/inspector_fixture'],
            'Native ExportText did not retain unknown saved type paths; stopped before live copy.')
    require(result['records'][0]['field_names'] == ['original_target', 'type'], 'Field-name self-test failed.')
    require('PRIVATE_TEST' not in json.dumps(result), 'Privacy self-test failed.')
    bad_before = digest(stage/'malformed.sav')
    run_world(stage, 'reader', 'reject', expect_rejection=True)
    require(not (stage/'native-result.json').exists(), 'Malformed fixture produced a result.')
    require((stage/'native-error.txt').read_text().strip() == 'NATIVE_ERROR', 'Wrong rejection marker.')
    require(digest(stage/'malformed.sav') == bad_before, 'Malformed fixture was changed.')
    (stage/'native-error.txt').rename(stage/'selftest-rejection-confirmed.txt')
    return result


def main():
    global BIN, CURRENT_RUNTIME
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--self-test-only', action='store_true')
    parser.add_argument('--source', type=Path, help='Explicit existing map_saves/2.sav; never used by self-test.')
    parser.add_argument('--byond-bin', type=Path, help='Native CI path; allowed only with --self-test-only.')
    parser.add_argument('--byond-archive', type=Path)
    args = parser.parse_args()
    require(not args.byond_archive or (args.self_test_only and args.source is None and args.byond_bin is not None),
            'Current archive mode requires synthetic self-test only and explicit tools; private source mode stays historical.')
    if args.self_test_only:
        require(args.source is None, 'Synthetic self-test must not receive a private source path.')
    else:
        require(args.source is not None and args.source.is_absolute()
                and args.source.name == '2.sav' and args.source.parent.name == 'map_saves',
                'Specify the absolute existing map_saves/2.sav path with --source.')
    if args.byond_bin:
        require(args.self_test_only, '--byond-bin is limited to synthetic self-tests.')
        BIN = args.byond_bin.absolute() if args.byond_archive else args.byond_bin.resolve()
    require(os.geteuid() != 0, 'Run as the ordinary civ13 user, without sudo.')
    CURRENT_RUNTIME = selected_runtime(BIN, args.byond_archive)
    for name in ('DreamMaker', 'DreamDaemon'):
        require((BIN/name).is_file() and os.access(BIN/name, os.X_OK), 'Existing BYOND binary missing: '+name)
    os.umask(0o077)
    home = Path.home()
    require(home.is_dir() and home.resolve() == home, 'Unexpected home directory or symlink.')
    stage = Path(tempfile.mkdtemp(prefix='civ13-save-inspect-', dir=home))
    print('Private staging directory: '+str(stage), flush=True)
    selftest(stage)
    summary = {'synthetic_selftest_passed': True, 'schema_version': 2,
               'compiler_required': CURRENT_RUNTIME.identity['version'] if CURRENT_RUNTIME else '516.1681',
               'unknown_type_paths_retained': True, 'numeric_shard_order_passed': True,
               'scalar_values_omitted': True, 'malformed_type_leaf_rejected': True,
               'synthetic_save_bytes_unchanged': True,
               'script_sha256': digest(Path(__file__).resolve())}
    (stage/'selftest-summary.json').write_text(json.dumps(summary, sort_keys=True)+'\n', encoding='utf-8')
    print('Synthetic native read-only/type/privacy self-test: PASS', flush=True)
    print(json.dumps(summary, sort_keys=True), flush=True)
    if args.self_test_only:
        return
    copied = stable_copy(args.source, stage/'input.sav')
    before = copied['sha256']
    run_world(stage, 'reader', 'sample')
    require(digest(stage/'input.sav') == before, 'Reader changed its private copy; result rejected.')
    require(digest(args.source) == before, 'Live source changed after copy; result rejected as stale.')
    report = load_native(stage, 'native-result.json')
    report.update(schema_source_commit=SCHEMA_BASE, source_copy=copied,
                  diagnostic_only=True, checkpoint_verified=False,
                  limits='Last 12 numeric entry IDs only. Field names have no write-order guarantee. '
                         'The failed field can be absent; an unfinished ancestor can be older than this window. '
                         'This report cannot prove the offending live object or make this save loadable.')
    text = json.dumps(report, indent=2, sort_keys=True)
    (stage/'report.json').write_text(text+'\n', encoding='utf-8')
    print(text)
    print('Share only this printed report or report.json. Keep input.sav and native logs private.')


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, ValueError, subprocess.SubprocessError) as exc:
        print('STOP: '+str(exc), file=sys.stderr)
        sys.exit(1)
