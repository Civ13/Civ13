"""Offline authored-map and injected build tests; never starts BYOND or Git."""
import importlib.util
import json
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('nomads_catalog_supervisor', ROOT/'scripts/nomads-lifecycle/supervisor.py')
core = importlib.util.module_from_spec(spec)
spec.loader.exec_module(core)


def conditional_map_source(default_map):
    return '\n'.join((
        '// untouched prefix', '// BEGIN_SELECTED_MAP',
        '#ifdef EXTRACTION_MODERN_CITY_MAP',
        '#include "maps\\extraction\\modern_city_extraction.dmm"', '#else',
        '#ifdef EXTRACTION_SURVIVAL_MAP',
        '#include "maps\\extraction\\industrial_district.dmm"', '#else',
        '#include "maps\\nomads\\'+default_map+'"', '#endif', '#endif',
        '// END_SELECTED_MAP', '// untouched suffix', ''))


class NomadsCatalogTests(unittest.TestCase):
    def test_every_declared_subtype_is_explicitly_audited(self):
        declarations = {}
        for path in (ROOT/'code/game/objects/map_metadata/nomads').glob('*.dm'):
            for match in re.finditer(r'^(/obj/map_metadata/nomads[^\r\n()]*)\r?\n((?:[\t ][^\n]*\n|\r?\n)*)', path.read_text(), re.M):
                identity = re.search(r'^\tID = (MAP_\w+)$', match[2], re.M)
                if identity:
                    declarations[match[1]] = (identity[1].removeprefix('MAP_'), path)
        source = (ROOT/'code/modules/persistence/durable_nomads.dm').read_text().split('/obj/map_metadata\n', 1)[0]
        admitted = set(re.findall(r'/obj/map_metadata/nomads(?:/[a-z_]+)*', source))
        self.assertEqual(set(declarations), admitted)
        self.assertEqual(len(admitted), 26)
        dme = (ROOT/'civ13.dme').read_text().replace('\\', '/')
        for _, path in declarations.values():
            self.assertIn(str(path.relative_to(ROOT)).replace('\\', '/'), dme)

    def test_catalog_binds_every_authored_nomads_map_to_its_actual_id(self):
        declarations = {}
        for path in (ROOT/'code/game/objects/map_metadata/nomads').glob('*.dm'):
            text = path.read_text()
            for match in re.finditer(r'^(/obj/map_metadata/nomads[^\r\n()]*)\r?\n((?:[\t ][^\n]*\n|\r?\n)*)', text, re.M):
                identity = re.search(r'^\tID = (MAP_\w+)$', match[2], re.M)
                if identity: declarations[match[1]] = identity[1].removeprefix('MAP_')
        actual = {}
        for path in (ROOT/'maps/nomads').glob('*.dmm'):
            types = set(re.findall(r'/obj/map_metadata/nomads(?:/[a-z_]+)*', path.read_text()))
            self.assertEqual(len(types), 1, path.name)
            actual[declarations[types.pop()]] = path.name
        self.assertEqual(core.NOMADS_MAPS, actual)
        self.assertEqual(len(actual), 25)
        self.assertNotIn('NOMADS_WASTELAND_3', core.NOMADS_MAPS)

    def test_all_authored_maps_build_the_configured_map_and_verify_cache(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = root/'config'
            config.mkdir()
            (config/'lifecycle-token.txt').write_text('a'*32)
            for identity, map_file in core.NOMADS_MAPS.items():
                with self.subTest(map=identity):
                    supervisor = core.Supervisor(dict(root=str(root/identity), map=identity, port=1714,
                        config_directory=str(config), repository=str(root/'unused'), git='GIT_DISABLED', python='PYTHON_DISABLED', compiler='NATIVE_DISABLED'))
                    def command(arguments, cwd=None, log=None, timeout=1800):
                        if arguments[:2] == ['GIT_DISABLED', 'clone']:
                            game = Path(arguments[-1])
                            (game/'code/modules/persistence').mkdir(parents=True)
                            (game/'code/modules/persistence/nomads_lifecycle.dm').write_text('// inert fixture')
                            (game/'civ13.dme').write_text('#include "maps/original.dmm"\n')
                        elif arguments[:2] == ['GIT_DISABLED', 'checkout']:
                            pass
                        elif arguments[0] == 'PYTHON_DISABLED':
                            pass
                        elif arguments[0] == 'NATIVE_DISABLED':
                            game = Path(cwd)
                            self.assertEqual((game/'civ13.dme').read_text().strip(), '#include "maps\\nomads\\'+map_file+'"')
                            for name in ('civ13.dmb', 'civ13.rsc'): (game/name).write_bytes(b'inert compiler result')
                            return '0 errors, 0 warnings'
                        else:
                            self.fail('Unexpected external action: '+repr(arguments))
                        return ''
                    with patch.object(supervisor, 'command', side_effect=command):
                        build = supervisor.build('a'*40)
                    manifest = json.loads((build/'build.json').read_text())
                    self.assertEqual(manifest['map'], identity)
                    with patch.object(supervisor, 'command', side_effect=AssertionError('cache invoked external action')):
                        self.assertEqual(supervisor.build('a'*40), build)
                    manifest['map'] = 'WRONG_MAP'
                    (build/'build.json').write_text(json.dumps(manifest))
                    with self.assertRaisesRegex(RuntimeError, 'identity changed'):
                        supervisor.build('a'*40)

    def test_unknown_map_refused_before_build_actions(self):
        with tempfile.TemporaryDirectory() as temporary:
            config = Path(temporary)/'config'
            config.mkdir()
            (config/'lifecycle-token.txt').write_text('a'*32)
            supervisor = core.Supervisor(dict(root=temporary, config_directory=str(config), map='UNREVIEWED_MAP', port=1714))
            with patch.object(supervisor, 'command') as command:
                with self.assertRaisesRegex(RuntimeError, 'Unsupported Nomads build map'):
                    supervisor.build('a'*40)
                command.assert_not_called()
            self.assertFalse((Path(temporary)/'builds').exists())

    def test_real_conditional_dme_selects_only_the_configured_map(self):
        source = (ROOT/'civ13.dme').read_text()
        for identity, name in core.NOMADS_MAPS.items():
            selected = core.select_nomads_map(source, identity)
            includes = re.findall(r'^#include "[^"\r\n]*\.dmm"', selected, re.M)
            self.assertEqual(includes, ['#include "maps\\nomads\\'+name+'"'])
            self.assertEqual(source.split('// BEGIN_SELECTED_MAP')[0], selected.split('// BEGIN_SELECTED_MAP')[0])
            self.assertEqual(source.split('// END_SELECTED_MAP')[1], selected.split('// END_SELECTED_MAP')[1])

    def test_reviewed_conditional_defaults_select_all_authored_maps(self):
        for default_map in ('nomads.dmm', 'nomads_gaia.dmm'):
            source = conditional_map_source(default_map)
            for identity, name in core.NOMADS_MAPS.items():
                with self.subTest(default=default_map, target=identity):
                    selected = core.select_nomads_map(source, identity)
                    self.assertEqual(selected, '// untouched prefix\n// BEGIN_SELECTED_MAP\n'
                        '#include "maps\\nomads\\'+name+'"\n// END_SELECTED_MAP\n// untouched suffix\n')

    def test_changed_conditional_branches_rejected_for_both_defaults(self):
        for default_map in ('nomads.dmm', 'nomads_gaia.dmm'):
            source = conditional_map_source(default_map)
            for bad in (
                source.replace(default_map, 'unreviewed.dmm'),
                source.replace(default_map, 'nomads_europe.dmm'),
                source.replace('modern_city_extraction.dmm', 'unreviewed.dmm'),
                source.replace('#else', '#elif UNREVIEWED_MAP', 1),
                source.replace('#endif\n', '', 1),
                source.replace('// END_SELECTED_MAP', '#include "maps/extra.dmm"\n// END_SELECTED_MAP'),
            ):
                with self.subTest(default=default_map, source=bad), self.assertRaisesRegex(RuntimeError, 'Unsupported selected-map block'):
                    core.select_nomads_map(bad, 'NOMADS_GAIA')

    def test_legacy_single_map_selection_preserves_surrounding_source(self):
        for source, expected in (
            ('// before\n#include "maps/legacy.dmm"\n// after\n',
             '// before\n#include "maps\\nomads\\nomads_gaia.dmm"\n// after\n'),
            ('// before\n// BEGIN_SELECTED_MAP\n#include "maps/legacy.dmm"\n// END_SELECTED_MAP\n// after\n',
             '// before\n// BEGIN_SELECTED_MAP\n#include "maps\\nomads\\nomads_gaia.dmm"\n// END_SELECTED_MAP\n// after\n'),
        ):
            with self.subTest(source=source):
                self.assertEqual(core.select_nomads_map(source, 'NOMADS_GAIA'), expected)

    def test_malformed_map_blocks_and_external_includes_are_rejected(self):
        source = (ROOT/'civ13.dme').read_text()
        for bad in (source.replace('// END_SELECTED_MAP', ''),
                    source.replace('// BEGIN_SELECTED_MAP', '// BEGIN_SELECTED_MAP\n// BEGIN_SELECTED_MAP'),
                    source.replace('#ifdef EXTRACTION_MODERN_CITY_MAP', '#ifdef UNREVIEWED_MAP'),
                    source+'\n#include "maps/other.dmm"\n',
                    '#include "one.dmm"\n#include "two.dmm"\n'):
            with self.subTest(input=bad[-70:]), self.assertRaises(RuntimeError):
                core.select_nomads_map(bad, 'NOMADS')


if __name__ == '__main__':
    unittest.main()
