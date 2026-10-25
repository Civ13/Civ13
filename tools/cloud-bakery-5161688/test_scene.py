"""Offline source gates only. No native process, socket, account or capture."""
import hashlib
import io
import json
from pathlib import Path
import re
import unittest
import zipfile

ROOT = Path(__file__).resolve().parent
SCENE = (ROOT/'changed-source/filming/scene.dm').read_text()


class SceneContracts(unittest.TestCase):
    def test_exact_manifest_and_allowlist(self):
        old = json.loads((ROOT/'v4-source-manifest.json').read_text())
        current = json.loads((ROOT/'derived-source.json').read_text())
        self.assertEqual(old['revision'], '58404f5bd16e3fed80f1d9844c5db3edd144942c')
        self.assertEqual(len(old['materialization_allowlist']), 3673)
        for row in old['materialization_allowlist']:
            name = row['path']
            self.assertFalse(name.startswith('/') or '\\' in name or '..' in name.split('/'))
            self.assertTrue(name == 'civ13.dme' or name.startswith(('code/', 'icons/', 'sound/', 'UI/', 'interface/', 'config/names/')))
        for name, expected in current['changes'].items():
            self.assertEqual(hashlib.sha256((ROOT/'changed-source'/name).read_bytes()).hexdigest(), expected, name)

    def test_real_guest_not_user_impersonation(self):
        for required in ('filming_observer_client ||', 'copytext(key, 1, 7) != "Guest-"', 'address != "127.0.0.1"', 'byond_build != 1688', 'guest=[is_guest];version=[byond_version];build=[byond_build]'):
            self.assertIn(required, SCENE)
        for forbidden in ('.key =', '.ckey =', 'holder =', 'fake_client', 'observer_ckey'):
            self.assertNotIn(forbidden, SCENE)
        self.assertIn('verbs = list() // Fixed cloud sequence only', SCENE)

    def test_preserved_real_oven_take(self):
        take = SCENE.split('/proc/filming_take()')[1].split('/proc/filming_lighting_loop()')[0]
        for forbidden in ('new ', '.process(', '.finish_work(', 'forceMove(', 'add_reagent('):
            self.assertNotIn(forbidden, take)
        self.assertFalse(re.search(r'\.(?:loc|fuel|cooking_time|ckey|client)\s*=(?!=)', take))
        for required in ('filming_oven.attackby(', 'filming_oven.attack_hand(', 'filming_counter.attackby(', 'filming_pickup(filming_customer, bread)', 'world.time - cook_started >= filming_oven.cooking_time'):
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

    def test_windows_checkout_conversion_does_not_relax_committed_pins(self):
        workflow_path = ROOT/'cloud-bakery-5161688.yml'
        if not workflow_path.exists():
            workflow_path = ROOT.parents[1]/'.github/workflows/cloud-bakery-5161688.yml'
        workflow = workflow_path.read_text()
        archive_command = 'git -C "$env:GITHUB_WORKSPACE" archive --format=zip "--output=$archive" $env:GITHUB_SHA .github/workflows/cloud-bakery-5161688.yml tools/cloud-bakery-5161688'
        self.assertIn(archive_command, workflow)
        self.assertIn('Expand-Archive -LiteralPath $archive -DestinationPath $tooling -ErrorAction Stop', workflow)
        self.assertLess(workflow.index(archive_command), workflow.index('python -B -m unittest'))
        self.assertEqual(workflow.count('working-directory: ${{ runner.temp }}/bakery-tooling'), 4)
        self.assertNotIn('git config', workflow)
        # Synthetic Windows checkout shape: working-tree CRLF does not match
        # immutable pins. A byte-preserving archive retains the committed LF.
        names = ['vendor.json', 'derived-source.json', 'changed-source/filming/scene.dm']
        payload = io.BytesIO()
        with zipfile.ZipFile(payload, 'w') as archive:
            for name in names:
                original = (ROOT/name).read_bytes()
                checkout = original.replace(b'\n', b'\r\n')
                self.assertNotEqual(hashlib.sha256(checkout).digest(), hashlib.sha256(original).digest())
                archive.writestr(name, original)
        with zipfile.ZipFile(io.BytesIO(payload.getvalue())) as archive:
            for name in names:
                self.assertEqual(archive.read(name), (ROOT/name).read_bytes())

    def test_runtime_source_writes_exclude_production_paths(self):
        changes = ROOT/'changed-source'
        for path in ('code/game/objects/structures/kitchen/oven.dm', 'code/game/objects/structures/table.dm', 'code/modules/reagents/reagent_containers/food/condiment.dm', 'code/_helpers/mobs.dm', 'code/modules/gameplay_bridge/bridge.dm'):
            self.assertFalse((changes/path).exists())
        world = (changes/'code/world.dm').read_text()
        for forbidden in ('\tload_configuration()', 'config.load(', 'processScheduler.setup()', 'setup_everything()', 'persistence_restart.detect_startup()', '/world/New()', '/world/Reboot('):
            self.assertNotIn(forbidden, world)


if __name__ == '__main__':
    unittest.main(verbosity=2)
