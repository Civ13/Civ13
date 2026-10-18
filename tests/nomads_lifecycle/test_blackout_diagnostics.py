"""Offline production-reader tests and DM source mutation boundaries, no game."""
import copy
import importlib.util
import json
from pathlib import Path
import re
import struct
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('read_blackout', ROOT / 'scripts/nomads-lifecycle/read_blackout.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


def audit(lifecycle, source):
    required_auth = ('peer[1] != "127.0.0.1"', '!nomads_lifecycle_hex(token, 32)',
                     'input["token"] != token', '!nomads_lifecycle_hex(read_revision(), 40)',
                     'input.len != allowed.len', 'if(!(key in allowed))')
    errors = [x for x in required_auth if x not in lifecycle]
    auth = lifecycle.find('input["token"] != token')
    dispatch = lifecycle.find('return diagnose(input)')
    if not 0 <= auth < dispatch:
        errors.append('diagnostic before auth')
    for literal in ('list("nomads_lifecycle", "token", "action", "session", "operation", "target")',):
        if literal not in lifecycle:
            errors.append('strict request keys')
    for literal in ('input["session"] != boot_session()', '!nomads_lifecycle_hex(input["operation"], 32)',
                    'input["operation"] in diagnostic_nonces', 'diagnostic_nonces.len >= 64',
                    'world.time - diagnostic_last_tick < 100', 'length(file("config/host.txt")) > 128',
                    'input["target"] != own_host', 'directory[own_host]', '!(C.holder.rights & R_HOST)',
                    'C.ckey != own_host', 'length(encoded) > BLACKOUT_DIAGNOSTIC_LIMIT',
                    '#define BLACKOUT_DIAGNOSTIC_LIMIT 32768', 'C.mob == M',
                    'result["partial"] = TRUE', 'result["sample"] = null'):
        if literal not in source:
            errors.append(literal)
    if not source.index('diagnostic_last_tick = world.time') < source.index('var/client/C = directory[own_host]') < source.index('result["sample"] = blackout_diagnostic_capture(C, M)'):
        errors.append('admission before capture')
    for literal in ('for(var/i = 1 to 8)', 'min(values.len, 20)', 'for(var/i = 1 to 4)',
                    'for(var/dx = -1 to 1)', 'for(var/dy = -1 to 1)',
                    'list("[GAME_PLANE]", "[LIGHTING_PLANE]", "[HUD_PLANE]")',
                    'list("screen_cover", "damageoverlay", "flash", "pain", "fov")'):
        if literal not in source:
            errors.append('unbounded sample')
    if re.search(r'\b(?:vars|contents|address|computer_id|lastKnownIP)\b', source):
        errors.append('private/unbounded field')
    if re.search(r'\b(?:call|spawn|sleep|Life|reset_view|update_sight|forceMove|shell|world\.Export|locate)\s*\(', source.replace('locate(T.x + dx, T.y + dy, T.z)', '')):
        errors.append('effectful or arbitrary access')
    if re.search(r'\b(?:C|M|N|H|L|P|S|T|O|A|K)(?:\.\w+)+\s*(?:=(?!=)|\+=|-=|\+\+|--)', source):
        errors.append('gameplay state write')
    for literal in ('row["overlay_luminosity"] = O.luminosity',
                    '"icon" = T.icon ? blackout_diagnostic_scalar("[T.icon]") : null',
                    '"icon_state" = blackout_diagnostic_scalar(T.icon_state)',
                    '"alpha" = T.alpha', '"color" = blackout_diagnostic_color(T.color)',
                    '"plane" = T.plane', '"layer" = T.layer',
                    '"invisibility" = T.invisibility', '"blend_mode" = T.blend_mode',
                    '"appearance_flags" = T.appearance_flags'):
        if literal not in source:
            errors.append('missing raw appearance field')
    for literal in ('if(scanned >= 64)', 'min(lighting_overlay_list.len + 1, 257)',
                    'row["overlay_last_luminosity"] = O.last_luminosity',
                    'row["overlay_last_color"] = blackout_diagnostic_color(O.last_color)',
                    '"unknown beyond prefix"', '"loc_is_sample_turf" = O.loc == T',
                    '"owner_direction" = K.masters[T]', '"master_count" = K.masters.len',
                    '"season" = blackout_diagnostic_scalar(season)',
                    '"roof_count" = roof_count', '"cover_count" = cover_count',
                    '"local atom sample truncated at 64 per turf"'):
        if literal not in source:
            errors.append('missing bounded ownership diagnostic')
    if re.search(r'\b(?:icon|icon_states|fcopy_rsc|update_icon|update_overlay|get_window_coeff)\s*\(', source):
        errors.append('derived appearance access')
    return errors


class SourceBoundary(unittest.TestCase):
    def test_bounded_ownership_omission_controls(self):
        lifecycle = (ROOT / 'code/modules/persistence/nomads_lifecycle.dm').read_text()
        source = (ROOT / 'code/modules/persistence/blackout_diagnostics.dm').read_text()
        for field in ('if(scanned >= 64)', 'min(lighting_overlay_list.len + 1, 257)',
                      '"unknown beyond prefix"', '"owner_direction" = K.masters[T]',
                      '"season" = blackout_diagnostic_scalar(season)'):
            with self.subTest(field=field):
                self.assertTrue(audit(lifecycle, source.replace(field, 'null')))

    def test_raw_appearance_field_omission_and_derived_access_controls(self):
        lifecycle = (ROOT / 'code/modules/persistence/nomads_lifecycle.dm').read_text()
        source = (ROOT / 'code/modules/persistence/blackout_diagnostics.dm').read_text()
        for field in ('O.luminosity', 'T.icon_state', 'T.alpha', 'T.color', 'T.plane'):
            with self.subTest(field=field):
                self.assertTrue(audit(lifecycle, source.replace(field, 'null')))
        for effect in ('icon(T.icon)', 'icon_states(T.icon)', 'T.update_icon()',
                       'O.update_overlay()', 'T.get_window_coeff()'):
            with self.subTest(effect=effect):
                self.assertTrue(audit(lifecycle, source + '\n/proc/unsafe()\n\t' + effect + '\n'))

    def test_production_auth_target_and_capture_contracts(self):
        lifecycle = (ROOT / 'code/modules/persistence/nomads_lifecycle.dm').read_text()
        source = (ROOT / 'code/modules/persistence/blackout_diagnostics.dm').read_text()
        self.assertEqual(audit(lifecycle, source), [])
        self.assertEqual((ROOT / 'civ13.dme').read_text().count('#include "code\\modules\\persistence\\blackout_diagnostics.dm"'), 1)

    def test_unsafe_mutation_controls(self):
        lifecycle = (ROOT / 'code/modules/persistence/nomads_lifecycle.dm').read_text()
        source = (ROOT / 'code/modules/persistence/blackout_diagnostics.dm').read_text()
        for old in ('peer[1] != "127.0.0.1"', 'input["token"] != token', 'input.len != allowed.len'):
            with self.subTest(auth=old):
                self.assertTrue(audit(lifecycle.replace(old, 'FALSE'), source))
        for old in ('input["session"] != boot_session()', 'input["operation"] in diagnostic_nonces',
                    'diagnostic_nonces.len >= 64', 'world.time - diagnostic_last_tick < 100',
                    'input["target"] != own_host', '!(C.holder.rights & R_HOST)', 'C.mob == M',
                    'length(encoded) > BLACKOUT_DIAGNOSTIC_LIMIT', 'for(var/dx = -1 to 1)'):
            with self.subTest(boundary=old):
                self.assertTrue(audit(lifecycle, source.replace(old, 'FALSE')))
        for unsafe in ('\n/proc/unsafe()\n\treturn C.address\n', '\n/proc/unsafe()\n\tM.sight = 0\n', '\n/proc/unsafe()\n\tM.Life()\n'):
            self.assertTrue(audit(lifecycle, source + unsafe))


class Reader(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        config = self.root / 'config'
        config.mkdir()
        (self.root / 'supervisor.json').write_text(json.dumps(dict(port=1714, config_directory=str(config))))
        self.token, self.revision, self.session, self.nonce = 'a' * 32, 'b' * 40, 'c' * 32, 'd' * 32
        (config / 'lifecycle-token.txt').write_text(self.token)
        (config / 'host.txt').write_text('Own Player\n')
        self.status = dict(ok=1, revision=self.revision, session=self.session)
        self.result = dict(ok=1, schema=1, revision=self.revision, session=self.session, request=self.nonce,
                           target=dict(ckey='ownplayer', client_ref='[0x1000001]', mob_ref='[0x30006bd]'),
                           partial=0, same_target=1, tick_start=100, tick_end=100,
                           utc_start='2026-10-17 12:00:00', utc_end='2026-10-17 12:00:00', game_id='game-test', sample={})

    def transport(self, result=None):
        calls = []
        def injected(values):
            calls.append(values)
            return copy.deepcopy(self.status if values['action'] == 'status' else (result or self.result))
        return calls, injected

    def test_bootstrap_own_current_mob_without_vars_or_state_mutation(self):
        calls, transport = self.transport()
        result = m.collect(self.root, self.revision, transport=transport, nonce=self.nonce)
        self.assertEqual([c['action'] for c in calls], ['status', 'diagnose'])
        self.assertEqual(set(calls[1]), {'nomads_lifecycle', 'token', 'action', 'session', 'operation', 'target'})
        self.assertNotIn('mob', calls[1])
        self.assertEqual(result['target']['mob_ref'], '[0x30006bd]')
        self.assertNotIn(self.token, json.dumps(result))
        self.assertIn('reader_utc_start', result)

    def test_identity_redaction_size_and_partial_failures(self):
        cases = [dict(revision='e' * 40), dict(session='e' * 32), dict(request='e' * 32),
                 dict(target=dict(ckey='other', client_ref='[0x1]', mob_ref='[0x2]')),
                 dict(sample=dict(secret=self.token)), dict(sample='x' * 32769),
                 dict(same_target=0), dict(tick_end=101), dict(partial=None), dict(game_id=''),
                 dict(partial=2), dict(same_target=-1), dict(tick_start=float('nan')),
                 dict(tick_end=float('inf')), dict(tick_start=float('-inf'))]
        for changes in cases:
            with self.subTest(changes=list(changes)), self.assertRaises(ValueError):
                _, transport = self.transport(self.result | changes)
                m.collect(self.root, self.revision, transport=transport, nonce=self.nonce)
        partial = self.result | dict(partial=1, same_target=0, tick_end=101, sample=None)
        _, transport = self.transport(partial)
        self.assertEqual(m.collect(self.root, self.revision, transport=transport, nonce=self.nonce)['partial'], 1)

    def test_wrong_runtime_stops_before_diagnostic_and_no_default_credentials(self):
        self.status['revision'] = 'e' * 40
        calls, transport = self.transport()
        with self.assertRaises(ValueError):
            m.collect(self.root, self.revision, transport=transport, nonce=self.nonce)
        self.assertEqual(len(calls), 1)
        (self.root / 'config/lifecycle-token.txt').write_text('')
        with self.assertRaises(ValueError):
            m.collect(self.root, self.revision, transport=transport, nonce=self.nonce)
        self.assertEqual(len(calls), 1)

    def test_framing_fragmentation_and_no_oversize_body_read(self):
        class Connection:
            def __init__(self, frame):
                self.frame, self.reads, self.sent = frame, 0, b''
            def __enter__(self): return self
            def __exit__(self, *args): pass
            def settimeout(self, value): pass
            def sendall(self, value): self.sent = value
            def recv(self, count):
                self.reads += 1
                value, self.frame = self.frame[:1], self.frame[1:]
                return value
        raw = json.dumps(self.result).encode()
        connection = Connection(b'\x00\x83' + struct.pack('>H', len(raw) + 2) + b'\x06' + raw + b'\0')
        with patch.object(m.socket, 'create_connection', return_value=connection) as connect:
            self.assertEqual(m.exchange(dict(action='diagnose')), self.result)
            connect.assert_called_once_with(('127.0.0.1', 1714), timeout=15)
        for header in (b'\x00\x83\xff\xff', b'\x00\x00\x00\x10'):
            bad = Connection(header + b'never read')
            with patch.object(m.socket, 'create_connection', return_value=bad), self.assertRaises(ValueError):
                m.exchange(dict(action='diagnose'))
            self.assertEqual(bad.reads, 4)
        empty = Connection(b'')
        with patch.object(m.socket, 'create_connection', return_value=empty), self.assertRaises(ValueError):
            m.exchange(dict(action='diagnose'))
        expired = Connection(b'')
        with patch.object(m.socket, 'create_connection', return_value=expired), patch.object(m.time, 'monotonic', side_effect=[0, 16]), self.assertRaises(TimeoutError):
            m.exchange(dict(action='diagnose'))
        self.assertEqual(expired.sent, b'')
        for body in (b'\x06' + raw, b'\x06' + raw + b'\0\0', b'\x06{}\0{}\0'):
            bad = Connection(b'\x00\x83' + struct.pack('>H', len(body)) + body)
            with patch.object(m.socket, 'create_connection', return_value=bad), self.assertRaises(ValueError):
                m.exchange(dict(action='diagnose'))


if __name__ == '__main__':
    unittest.main(verbosity=2)
