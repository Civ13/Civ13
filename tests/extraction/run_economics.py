"""Actual isolated PHP requests through the full production native economic spool."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import uuid


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--php', type=Path, required=True)
    parser.add_argument('--bot-root', type=Path, required=True)
    parser.add_argument('--bot-head', required=True)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0

    def command(argv, cwd=None):
        result = subprocess.run([str(x) for x in argv], cwd=cwd,
                                capture_output=True, text=True, timeout=120, creationflags=flags)
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
        return result.stdout.strip()

    bot_head = command(['git', 'rev-parse', 'HEAD'], args.bot_root)
    if bot_head != args.bot_head:
        raise RuntimeError('Bot checkout differs from the requested immutable head')
    if args.output and args.output.exists():
        parser.error('Evidence output must be a new directory')
    compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    driver = args.bot_root / 'tests/safehouse/economics-driver.php'
    prefix = '.economic_spool_' + uuid.uuid4().hex
    generated = [root / (prefix + suffix) for suffix in ('.dme', '_world.dm', '_globals.dm', '.dmb', '.rsc')]
    with tempfile.TemporaryDirectory(prefix='civ13-php-economics-') as folder:
        target = Path(folder)
        spool = target / 'data/economic_spool'
        spool.mkdir(parents=True)
        manifest = {'synthetic': True, 'key': '0123456789abcdef0123456789abcdef', 'clock': 1000,
                    'source_head': command(['git', 'rev-parse', 'HEAD'], root),
                    'source_dirty': bool(command(['git', 'status', '--porcelain'], root)),
                    'bot_head': bot_head, 'driver_sha256': hashlib.sha256(driver.read_bytes()).hexdigest()}

        manifest['bot_source_dirty'] = bool(command(['git', 'status', '--porcelain'], args.bot_root))
        manifest['bot_runtime_sha256'] = {
            name: hashlib.sha256((args.bot_root / 'src/Civ13/Safehouse' / name).read_bytes()).hexdigest()
            for name in ('Transport.php', 'Client.php', 'AsyncSpool.php')}
        manifest_path = target / 'manifest.json'
        manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='ascii')
        try:
            source = (root / 'civ13.dme').read_text(encoding='utf-8')
            world = (root / 'code/world.dm').read_text(encoding='utf-8')
            parent = world.index('\n\t..()', world.index('/world/New()'))
            world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
            world = world.replace('/world/New()', '/world/proc/unused_economic_spool_startup()', 1)
            world = world.replace('/datum/global_init/New()\n', '/datum/global_init/New()\n\treturn\n', 1)
            generated[1].write_text(world, encoding='utf-8')
            global_source = (root / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8')
            marker = '/datum/controller/global_vars/New()\n'
            if global_source.count(marker) != 1:
                raise RuntimeError('Global isolation marker changed')
            generated[2].write_text(global_source.replace(marker, marker + '\treturn\n'), encoding='utf-8')
            source = source.replace('code\\world.dm', generated[1].name).replace('code\\controllers\\mc\\globals.dm', generated[2].name)
            source = re.sub(r'^#include ".*\.dmm"\s*$', '', source, flags=re.M)
            source += '\n#include "tests/extraction/economic_spool_probe.dm"\n'
            generated[0].write_text(source, encoding='utf-8')
            build = command([compiler, '-max_errors', '0', generated[0]], root)
            (target / 'compile.log').write_text(build + '\n', encoding='utf-8')
            if '516.1681' not in build or '0 errors, 0 warnings' not in build:
                raise RuntimeError('Pinned native compile failed: ' + build)
            shutil.copy2(generated[3], target / 'probe.dmb')
            shutil.copy2(generated[4], target / 'probe.rsc')
            shutil.copytree(root / 'config/names', target / 'config/names')
            phases = []

            def native(phase='poll'):
                (target / 'result.txt').unlink(missing_ok=True)
                platform = ['-invisible', '-close'] if os.name == 'nt' else []
                output = command([daemon, 'probe.dmb', *platform, '-safe', '-params', 'phase=' + phase,
                                  '-log', 'runtime.log'], target)
                log = (target / 'runtime.log').read_text(errors='replace')
                result = (target / 'result.txt').read_text().strip()
                phases.append({'phase': phase, 'result': result})
                (target / f'phase-{len(phases):02}.log').write_text(output + '\n' + log, encoding='utf-8')
                if not result.startswith('PASS:') or any(x in (output + log).lower() for x in ('runtime error', 'bad ref', '## error')):
                    raise RuntimeError('Native phase failed: ' + result + '\n' + log)

            def php(action, request, *arguments):
                return command([args.php, driver, spool, manifest_path, action, request, *arguments])

            def poll(key, status='committed'):
                reply = json.loads(php('poll', key))
                if reply.get('status') != status:
                    raise RuntimeError('Unexpected authenticated reply: ' + json.dumps(reply))
                return reply

            def inspect(identifier, actor):
                key = php('inspect', identifier, actor)
                native()
                poll(key)
                return key

            def sale(identifier, actor, kind, selection, interrupt=False):
                inspection = inspect(identifier + '-inspect', actor)
                quote = php('quote', identifier + '-quote', inspection, kind, json.dumps(selection))
                native()
                poll(quote)
                confirmation = php('confirm', identifier + '-confirm', quote)
                native('interrupt' if interrupt else 'poll')
                return confirmation, poll(confirmation, 'pending' if interrupt else 'committed')

            native('init')
            listing_key, listing = sale('first-list', '123', 'player_listing', ['spool-part'])
            listing_id = listing['data']['listing_id']
            purchase_key, _ = sale('purchase', '456', 'player_purchase', listing_id)
            immutable_purchase = (spool / (purchase_key + '.request')).read_bytes()
            original_reply = poll(purchase_key)
            # Simulate loss of this fixture's published transport file. The
            # immutable request must recover its original account receipt.
            (spool / (purchase_key + '.reply')).unlink()
            native()
            if (spool / (purchase_key + '.request')).read_bytes() != immutable_purchase:
                raise RuntimeError('Native replay changed immutable PHP request')
            if poll(purchase_key) != original_reply:
                raise RuntimeError('Lost transport reply did not recover the exact durable purchase receipt')
            _, listing = sale('second-list', '456', 'player_listing', ['spool-part'])
            sale('cancel', '456', 'listing_cancel', listing['data']['listing_id'])
            interrupted_key, _ = sale('buyback', '456', 'server_buyback', ['spool-part'], interrupt=True)
            status_key = php('recover', 'buyback-status', interrupted_key)
            native()
            status = poll(status_key)
            if status['data']['operation_status'] != 'committed' or status['data']['operation_receipt']['request_id'] != 'buyback-confirm':
                raise RuntimeError('Fresh PHP status did not recover the original economic receipt')
            poll(interrupted_key)
            native('verify')
            manifest['phases'] = phases
            manifest['result'] = 'PASS: PHP/native list, purchase, cancel, buyback, immutable replay and interrupted settlement status recovery'
            manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='ascii')
            print(manifest['result'])
            if args.output:
                shutil.copytree(target, args.output)
                print('Synthetic evidence: ' + str(args.output))
        except Exception as error:
            manifest['result'] = 'FAIL: ' + str(error)
            manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='ascii')
            if args.output and not args.output.exists():
                shutil.copytree(target, args.output)
                print('Synthetic failure evidence: ' + str(args.output))
            raise
        finally:
            for path in generated:
                path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
