"""Offline source gates only. No native process, socket, account or capture."""
import hashlib
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parent
SCENE = (ROOT/'changed-source/filming/scene.dm').read_text()


class SceneContracts(unittest.TestCase):
    def test_exact_manifest_and_allowlist(self):
        old = json.loads((ROOT/'v4-source-manifest.json').read_text())
        current = json.loads((ROOT/'derived-source.json').read_text())
        self.assertEqual(old['revision'], '9683866a89d2bdc12f8dc7d25444e350583c5483')
        self.assertEqual(len(old['materialization_allowlist']), 3677)
        for row in old['materialization_allowlist']:
            name = row['path']
            self.assertFalse(name.startswith('/') or '\\' in name or '..' in name.split('/'))
            self.assertTrue(name == 'civ13.dme' or name.startswith(('code/', 'icons/', 'sound/', 'UI/', 'interface/', 'config/names/')))
        for name, expected in current['changes'].items():
            self.assertEqual(hashlib.sha256((ROOT/'changed-source'/name).read_bytes()).hexdigest(), expected, name)

    def test_real_guest_not_user_impersonation(self):
        for required in ('filming_observer_client ||', 'copytext(key, 1, 7) != "Guest-"', 'address != "127.0.0.1"', 'byond_build != 1688', 'guest=[is_guest];version=[byond_version];build=[byond_build]'):
            self.assertIn(required, SCENE)
        self.assertNotRegex(SCENE, r'\.(?:key|ckey|client)\s*=(?!=)')
        for forbidden in ('holder =', 'fake_client', 'observer_ckey'):
            self.assertNotIn(forbidden, SCENE)
        self.assertEqual(SCENE.count('for (var/fixture_verb in verbs.Copy())'), 3)

    def test_preserved_real_tanning_take(self):
        take = SCENE.split('/proc/filming_take()')[1].split('/proc/filming_lighting_loop()')[0]
        for forbidden in ('new ', 'new(', '.stageGrowth(', '.try_destroy(', 'forceMove(', 'add_reagent('):
            self.assertNotIn(forbidden, take)
        self.assertFalse(re.search(r'\.(?:loc|stage|health|last_growth_tick|ckey|client)\s*=(?!=)', take))
        for required in ('tan_raw.attackby(tan_knife, tan_worker)', 'tan_rack.attackby(wet, tan_worker)', 'tan_rack.attack_hand(tan_worker)', 'filming_pickup(tan_receiver, leather)', 'world.time - scrape_start >= 50'):
            self.assertIn(required, take)

    def test_readonly_camera_and_stops(self):
        for token in ('/client/Move()\n\treturn FALSE', '/client/Topic()\n\treturn null', '/world/Error(', 'spawn(1800)', 'OpenPort("none")', 'observer disconnected'):
            self.assertIn(token, SCENE)
        self.assertIn('\n\t\tfilming_allowed_port = text2num(params["filming_port"])\n', SCENE)
        self.assertIn('while (!fexists("cloud-stage-captured.txt"))', SCENE)

    def test_map_only_skin(self):
        dme = (ROOT/'changed-source/civ13.dme').read_text()
        skin = (ROOT/'changed-source/filming/cloud.dmf').read_text()
        self.assertIn('#include "filming\\cloud.dmf"', dme)
        self.assertNotIn('#include "interface\\skin.dmf"', dme)
        self.assertIn('type = MAP', skin)
        self.assertNotIn('BROWSER', skin)
        self.assertEqual(skin.count('size = 480x480'), 2)

    def test_owned_native_controller_and_sampling_disclosure(self):
        controller = (ROOT/'run_scene.py').read_text()
        adapter = (ROOT/'windows.py').read_text()
        for token in ("'dm.exe'", "'dd.exe'", "'-trusted'", "'-ip', '127.0.0.1'", "'dreamseeker.exe'", '##guest', 'adapter.cleanup(', 'adapter.exited(', '165', '180'):
            self.assertIn(token, controller)
        self.assertIn('GLOBAL socket tables', adapter)
        self.assertIn('return [] if self.exited(process) else rows', adapter)
        self.assertIn('limits.basic.process_time = 60 * 10000000', adapter)
        self.assertIn('self.capture_identity(process, argv[0])', adapter)
        self.assertLess(adapter.index('self.capture_identity(process, argv[0])'), adapter.index('self.k.ResumeThread(process.thread)'))

    def test_workflow_selects_all_offline_controls_and_fresh_engine(self):
        workflow_path = ROOT/'cloud-bakery-5161688.yml'
        if not workflow_path.exists():
            workflow_path = ROOT.parents[1]/'.github/workflows/cloud-bakery-5161688.yml'
        workflow = workflow_path.read_text()
        pin = "actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065"
        self.assertIn(pin, workflow)
        self.assertIn("python-version: '3.12'", workflow)
        self.assertLess(workflow.index(pin), workflow.index('python -B -m unittest'))
        general = "python -B -m unittest discover -s tools/cloud-bakery-5161688 -p 'test_*.py' -v"
        capture = "python -B -m unittest discover -s tools/cloud-bakery-5161688/tests -p 'test_capture.py' -v"
        checked = "\n          if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }"
        self.assertIn(general + checked, workflow)
        self.assertIn(capture + checked, workflow)
        create = "New-Item -ItemType Directory -Path $engine -ErrorAction Stop | Out-Null"
        self.assertIn("if (Test-Path -LiteralPath $engine) { throw 'Fresh engine directory required.' }", workflow)
        self.assertLess(workflow.index(create), workflow.index('acquire.py --root "$engine"'))
        for name in ('acquisition-receipt.json', 'dependency-receipt.json', 'acquisition-failure.json'):
            self.assertIn(name, workflow)
        self.assertNotIn("if (!(Test-Path -LiteralPath (Join-Path $root 'receipt.json')))", workflow)

    def test_windows_materialization_uses_raw_blobs_without_normalized_pins(self):
        workflow_path = ROOT/'cloud-bakery-5161688.yml'
        if not workflow_path.exists():
            workflow_path = ROOT.parents[1]/'.github/workflows/cloud-bakery-5161688.yml'
        workflow = workflow_path.read_text()
        command = 'python -B tools/cloud-bakery-5161688/materialize.py --repository "$env:GITHUB_WORKSPACE" --revision "$env:GITHUB_SHA" --destination "$env:RUNNER_TEMP/bakery-tooling"'
        self.assertIn(command, workflow)
        self.assertLess(workflow.index(command), workflow.index('python -B -m unittest'))
        self.assertLess(workflow.index('actions/setup-python@'), workflow.index(command))
        self.assertEqual(workflow.count('working-directory: ${{ runner.temp }}/bakery-tooling'), 5)
        self.assertNotIn('git config', workflow)
        self.assertNotIn('git archive', workflow)
        stage = (ROOT/'stage.py').read_text()
        self.assertIn('from materialize import export_blobs', stage)
        self.assertIn('export_blobs(repository, REVISION, destination,', stage)
        self.assertNotIn("'archive'", stage)
        self.assertNotIn('tarfile', stage)
        materialize = (ROOT/'materialize.py').read_text()
        self.assertIn("'ls-tree','-rz'", materialize)
        self.assertIn("'cat-file','--batch'", materialize)
        self.assertIn("hashlib.sha1(('blob %d\\0' % size).encode('ascii')+data)", materialize)
        self.assertIn("target.open('xb')", materialize)

    def test_modified_dm_preprocessor_conditionals_are_balanced(self):
        def check(text):
            stack = []
            for number, line in enumerate(text.splitlines(), 1):
                match = re.match(r'^\s*#\s*(ifdef|ifndef|if|elif|else|endif)\b', line)
                if not match:
                    continue
                directive = match.group(1)
                if directive in ('if', 'ifdef', 'ifndef'):
                    stack.append(number)
                elif not stack:
                    raise ValueError('Unmatched conditional branch/close')
                elif directive == 'endif':
                    stack.pop()
            if stack:
                raise ValueError('Unclosed conditional')
        # Exact regression class from the first native compiler failure.
        with self.assertRaises(ValueError):
            check('#ifdef USE_CUSTOM_ERROR_HANDLER\n#define ERROR_USEFUL_LEN 2\n')
        for path in (ROOT/'changed-source').rglob('*'):
            if path.suffix in ('.dm', '.dme'):
                with self.subTest(source=str(path.relative_to(ROOT))):
                    check(path.read_text())
        stub = (ROOT/'changed-source/code/modules/error_handler/error_handler.dm').read_text()
        self.assertIn('GLOBAL_VAR_INIT(total_runtimes, 0)', stub)
        self.assertIn('GLOBAL_VAR_INIT(total_runtimes_skipped, 0)', stub)
        self.assertNotIn('#ifdef', stub)
        self.assertNotIn('ERROR_USEFUL_LEN', stub)
        self.assertIn('/world/Error(', SCENE)
        self.assertIn('filming_stop(', SCENE.split('/world/Error(', 1)[1].split('\n/', 1)[0])

    def test_startup_diagnostics_preserve_calls_and_bound_exception_fields(self):
        startup = SCENE.split('/world/New()\n', 1)[1]
        unchanged = ''.join(line for line in startup.splitlines(keepends=True)
                            if not line.strip().startswith(('filming_startup_phase =', 'filming_assert_authored_map(', 'filming_prepare_scene()', 'filming_assert_tanning_initial()')))
        for guard in ('filming_check(!!GLOB, "global controller published")', 'filming_check(islist(GLOB.sticker_registry), "sticker registry is a list")', 'filming_check(!length(GLOB.sticker_registry), "sticker registry initially empty")'):
            unchanged = unchanged.replace('\t\t' + guard + '\n', '')
        unchanged = unchanged.replace('filming_exception_detail(E)', 'E.name')
        self.assertEqual(hashlib.sha256(unchanged.encode()).hexdigest(), '9c6becd4b0e7851898fac2296bbb906587c455deeea89c69475a241a3d200fc1')
        for phase in ('movementMachine.New', 'init_sticker_registry', 'movable.initialize [A.type]', 'area.initialize [A.type]', 'time_of_day_change.New', 'time_of_day_change.setup', 'create_lighting Midday', 'apply_restored_lighting', 'open isolated listener', 'startup complete'):
            self.assertIn(phase, startup)
        detail = SCENE.split('/proc/filming_exception_detail(exception/E)\n', 1)[1].split('\n/proc/', 1)[0]
        for field in ('exception_name', 'exception_file', 'exception_line', 'exception_desc', 'desc_available', 'desc_truncated', 'name_truncated', 'file_truncated', 'phase_truncated'):
            self.assertIn('"' + field + '"', detail)
        for bound in ('copytext(filming_startup_phase, 1, 257)', 'copytext(name_text, 1, 257)', 'copytext(file_text, 1, 257)', 'copytext(desc_text, 1, 2049)'):
            self.assertIn(bound, detail)
        self.assertIn('"exception_line" = E.line', detail)
        self.assertIn('filming_stop("startup failed: [filming_exception_detail(E)]")', startup)
        handler = SCENE.split('/world/Error(exception/E)\n', 1)[1].split('\n/proc/', 1)[0]
        self.assertIn('filming_stop("native runtime error: [filming_exception_detail(E)]")', handler)

    def test_only_required_sticker_registry_prerequisite_is_initialized(self):
        globals_source = (ROOT/'changed-source/code/controllers/mc/globals.dm').read_text()
        constructor = globals_source.split('/datum/controller/global_vars/New()\n', 1)[1].split('\n/datum/', 1)[0]
        self.assertEqual(constructor.count('sticker_registry = list()'), 1)
        code = '\n'.join(line for line in constructor.splitlines() if not line.strip().startswith('//'))
        self.assertNotIn('Initialize(', code)
        self.assertNotIn('call(', code)
        self.assertEqual(code.count('GLOB = src'), 1)
        self.assertIn('if(GLOB)\n\t\tCRASH("Multiple instances of global variable controller created")\n\tGLOB = src', code)
        self.assertLess(code.index('GLOB = src'), code.index('sticker_registry = list()'))
        for original in ('all_observable_events = list()', 'moved_event = new', 'dir_set_event = new', 'destroyed_event = new', 'stat_set_event = new', 'name_set_event = new'):
            self.assertIn(original, constructor)
        startup = SCENE.split('/world/New()\n', 1)[1]
        guards = ['filming_check(!!GLOB, "global controller published")', 'filming_check(islist(GLOB.sticker_registry), "sticker registry is a list")', 'filming_check(!length(GLOB.sticker_registry), "sticker registry initially empty")', '\n\t\tinit_sticker_registry()']
        offsets = [startup.index(guard) for guard in guards]
        self.assertEqual(offsets, sorted(offsets))

    def test_original_constructor_publication_contract_is_checked_before_overlay(self):
        from stage import verify_global_publication_source
        caller = '\tif(!GLOB)\n\t\tnew /datum/controller/global_vars'
        publisher = '/datum/controller/global_vars/New()\n\tif(GLOB)\n\t\tCRASH("Multiple instances of global variable controller created")\n\tGLOB = src'
        verify_global_publication_source(caller, publisher)
        with self.assertRaises(ValueError):
            verify_global_publication_source(caller.replace('new ', 'GLOB = new '), publisher)
        with self.assertRaises(ValueError):
            verify_global_publication_source(caller, publisher.replace('GLOB = src', ''))
        source = (ROOT/'stage.py').read_text()
        export = source.index('exported = export_blobs(')
        check = source.index("verify_global_publication_source((destination/'code/controllers/mc/master.dm')")
        overlay = source.index("for relative, expected_hash in derivative['changes'].items():")
        self.assertLess(export, check)
        self.assertLess(check, overlay)

    def test_initial_materials_precede_admission_and_take_follows_capture(self):
        startup = SCENE.split('/world/New()')[1]
        tokens = ['filming_assert_authored_map("after fixture initialization before listener")', 'filming_prepare_scene()', 'filming_assert_tanning_initial()', 'filming_ready = TRUE', 'OpenPort(filming_allowed_port)']
        offsets = [startup.index(t) for t in tokens]
        self.assertEqual(offsets, sorted(offsets))
        callback = SCENE.split('/client/New()\n', 1)[1].split('\n/client/Del()', 1)[0]
        self.assertNotIn('filming_prepare_scene()', callback)
        self.assertLess(callback.index('filming_assert_tanning_initial()'), callback.index('filming_observer_client = src'))
        self.assertLess(callback.index('while (!fexists("cloud-stage-captured.txt"))'), callback.index('filming_take()'))
        controller = (ROOT/'run_scene.py').read_text()
        checkpoints = ["wait_file('cloud-client.txt'", "output/'bakery-before.png'", "(source/'cloud-stage-captured.txt').write_text", "wait_file('filming-ready.txt')", "wait_file('filming-take.json')", "output/'bakery-after.png'"]
        indices = [controller.index(value) for value in checkpoints]
        self.assertEqual(indices, sorted(indices))
        for token in ("'endpoint_identity_and_purpose_verified': False", "'zero_egress': False", "if role == 'server' and listener_required:"):
            self.assertIn(token, controller)

    def test_runtime_source_writes_exclude_production_paths(self):
        changes = ROOT/'changed-source'
        for path in ('code/game/objects/structures/kitchen/oven.dm', 'code/game/objects/structures/table.dm', 'code/modules/reagents/reagent_containers/food/condiment.dm', 'code/_helpers/mobs.dm', 'code/game/objects/farming.dm', 'code/game/objects/structures/wild.dm', 'code/game/turfs/floor_attackby.dm', 'code/modules/reagents/Chemistry-Holder.dm', 'code/modules/gameplay_bridge/bridge.dm'):
            self.assertFalse((changes/path).exists())
        world = (changes/'code/world.dm').read_text()
        for forbidden in ('\tload_configuration()', 'config.load(', 'processScheduler.setup()', 'setup_everything()', 'persistence_restart.detect_startup()', '/world/New()', '/world/Reboot('):
            self.assertNotIn(forbidden, world)


if __name__ == '__main__':
    unittest.main(verbosity=2)
