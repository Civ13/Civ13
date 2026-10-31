"""Prepare review-only native fixture from exact source; never runs BYOND."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
EXPECTED = {
    'code/game/gameticker.dm': 'd33acb7ac7217d0249c003a869bbd4e96f9202aa0f3a556411a965a3a72ba343',
    'code/modules/persistence/persistence.dm': 'e8da151c3864524e6683f91a4f3802927e42b299adf6306e70f7554adb600f8c',
    'code/modules/admin/admin.dm': 'b8263e7d50e5bf8465e53ba672146035b4dcc531979ab8400893bfa415a82f5e',
    'code/modules/persistence/bed_return.dm': '964f0ff6ea4b04bef7adbb6ab02e91c166fbf83531be44e8c844073122d00221',
    'code/modules/persistence/nomads_lifecycle.dm': 'd1c1883bb364df7b8cdffd697f3bb5aa973e6b5cdbe4268a881d729441e98aa9',
}

def once(text, old, new):
    if text.count(old) != 1:
        raise ValueError(f'anchor occurs {text.count(old)} times: {old!r}')
    return text.replace(old, new, 1)

def between(text, start, end):
    if text.count(start) != 1 or text.count(end) != 1:
        raise ValueError('source boundary drift')
    return text[text.index(start):text.index(end)]

def build(control):
    # Locate the next verb only in the tail; the global file has many verbs.
    sources = {}
    for name, digest in EXPECTED.items():
        b = (ROOT / 'source' / name).read_bytes()
        if hashlib.sha256(b).hexdigest() != digest:
            raise ValueError('source hash mismatch: ' + name)
        sources[name] = b.decode('utf-8').replace('\r\n', '\n')
    ticker = between(sources['code/game/gameticker.dm'], '/datum/controller/gameticker/proc/cancel_pregame_autostart()', '/datum/controller/gameticker/proc/close_jobs()')
    toggle = between(sources['code/modules/persistence/persistence.dm'], '/datum/admins/proc/persistent()', '/datum/admins/proc/persistent_chad()')
    admin = sources['code/modules/admin/admin.dm']
    start = admin.index('/datum/admins/verb/startnow()')
    end = admin.index('\n/datum/', start + 1)
    manual = admin[start:end]
    beds = sources['code/modules/persistence/bed_return.dm']
    enabled = between(beds, '/proc/persistence_bed_return_enabled()', '// Scalar ownership')
    recovery = between(beds, '/map_storage/proc/character_recovery_unready()', '// TRUE only when every registered entry')
    recovery = once(recovery, '/map_storage/proc/character_recovery_unready()', '/datum/fixture_storage/proc/character_recovery_unready()')
    lifecycle = sources['code/modules/persistence/nomads_lifecycle.dm']
    locked = between(lifecycle, '/proc/persistence_mode_change_locked()', '/proc/nomads_lifecycle_hex(')

    if control == 'boot':
        ticker = once(ticker, '\t\t\tif (!pregame_autostart_blocked())\n\t\t\t\tpregame_timeleft = GAMETICKER_PREGAME_TIME', '\t\t\tpregame_timeleft = GAMETICKER_PREGAME_TIME')
    if control == 'postvote':
        ticker = once(ticker, '\t\t\t\t// A vote callback may have enabled persistence while we slept.\n\t\t\t\tif (pregame_autostart_blocked()) continue\n', '')
    if control == 'postadmission':
        ticker = once(ticker, '\tif (pregame_autostart_blocked()) return FALSE\n\tif (!can_start_round)', '\tif (!can_start_round)')
    if control == 'latch':
        toggle = once(toggle, '\t\tif (ticker) ticker.cancel_pregame_autostart()\n', '')
    ticker = once(ticker, '\t\t\t\tpregame_timeleft = GAMETICKER_PREGAME_TIME', '\t\t\t\tpregame_timeleft = GAMETICKER_PREGAME_TIME\n\t\t\t\tfixture_armed++') if control != 'boot' else once(ticker, '\t\t\tpregame_timeleft = GAMETICKER_PREGAME_TIME', '\t\t\tpregame_timeleft = GAMETICKER_PREGAME_TIME\n\t\t\tfixture_armed++')
    ticker = once(ticker, '\t\t\t\t\tcurrent_state = GAME_STATE_SETTING_UP', '\t\t\t\t\tcurrent_state = GAME_STATE_SETTING_UP\n\t\t\t\t\tfixture_setting_up++')
    ticker = once(ticker, '/datum/controller/gameticker/proc/setup()\n', '/datum/controller/gameticker/proc/setup()\n\tfixture_setup_entries++\n')
    # Replace only logging effects that refer to an absent interactive usr.
    manual = once(manual, 'log_admin("[usr.key] has started the game.")', 'log_admin("fixture")')
    manual = once(manual, 'message_admins("[usr.key] has started the game.", usr.key)', 'message_admins("fixture", null)')
    return ticker + '\n' + toggle + '\n' + manual + '\n' + enabled + '\n' + recovery + '\n' + locked

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--control', choices=['none', 'boot', 'postvote', 'postadmission', 'latch'], default='none')
    p.add_argument('--output', required=True, type=Path)
    a = p.parse_args()
    a.output.mkdir(parents=True, exist_ok=False)
    files = {'production.dm': build(a.control), 'fixture.dm': (ROOT / 'fixture.dm').read_text(encoding='utf-8'),
             'probe.dme': '#define GAMETICKER_PREGAME_TIME 3\n#include "fixture.dm"\n#include "production.dm"\n'}
    hashes = {}
    for name, data in files.items():
        b = data.encode('utf-8')
        (a.output / name).write_bytes(b)
        hashes[name] = hashlib.sha256(b).hexdigest()
    manifest = {'source_commit': '304a95ef5bd0dfa7bdadd511bca6cb740d4f0167', 'control': a.control,
                'source_sha256': EXPECTED, 'generated_sha256': hashes, 'native_run': False}
    (a.output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(manifest, indent=2))

if __name__ == '__main__': main()
