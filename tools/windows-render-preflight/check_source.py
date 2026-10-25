"""Offline source contracts only. Does not run Windows APIs or establish native acceptance."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
CS = (ROOT / 'tools/windows-render-preflight/OwnedScreenProbe.cs').read_text()
PS = (ROOT / 'tools/windows-render-preflight/Run.ps1').read_text()
WF = (ROOT / '.github/workflows/windows-render-preflight.yml').read_text()


class SourceContracts(unittest.TestCase):
    def test_trigger_and_read_only_runner(self):
        self.assertIn('branches: [ci/windows-render-preflight-20261025]', WF)
        self.assertIn("github.run_attempt == 1", WF)
        self.assertIn("github.event.head_commit.message == 'ci: one-shot owned Windows screen preflight (2026-10-25)'", WF)
        self.assertIn('3f3dd47f614f4659031a793dc590346f5e4de3e6', WF)
        self.assertIn('$parents.Count -ne 2', WF)
        self.assertIn('$parents[1] -ne $base', WF)
        self.assertIn('runs-on: windows-2022', WF)
        self.assertIn('timeout-minutes: 4', WF)
        self.assertIn('timeout-minutes: 2', WF)
        self.assertIn('permissions:\n  contents: read', WF)
        self.assertIn('persist-credentials: false', WF)
        self.assertNotRegex(WF, r'(?m)^  (workflow_dispatch|pull_request|schedule):')
        self.assertNotIn('continue-on-error', WF)

    def test_only_existing_pinned_actions(self):
        self.assertEqual(re.findall(r'uses: (\S+)', WF), [
            'actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683',
            'actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02'])
        self.assertIn("always() && steps.probe.outputs.evidence_ready == 'true'", WF)
        self.assertIn('retention-days: 7', WF)

    def test_no_install_download_or_security_changes(self):
        for source in (CS, PS, WF):
            for token in ('Invoke-WebRequest', 'DownloadFile(', 'Start-Process', 'Set-ItemProperty',
                          'reg add', 'netsh', 'SetThreadDesktop(', 'SwitchDesktop(',
                          'SetProcessWindowStation(', 'AttachThreadInput(', 'SendInput(',
                          'PrintWindow(', 'DrawToBitmap(', 'self-hosted', 'secrets.',
                          'setup-python@', 'setup-dotnet@', 'pip install', 'dotnet restore'):
                self.assertNotIn(token, source)
        self.assertIn('RegistryView]::Registry32', PS)
        self.assertIn("OpenSubKey('SOFTWARE\\Microsoft\\EdgeUpdate\\Clients\\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', $false)", PS)
        self.assertIn("[System.IO.FileAccess]::Read", PS)

    def test_input_denial_is_terminal(self):
        self.assertEqual(CS.count('input = OpenInputDesktop('), 1)
        self.assertIn('input = OpenInputDesktop(0, false, 0x0001)', CS)
        self.assertIn('error == 5 ? "input_desktop_access_denied"', CS)
        self.assertLess(CS.index('input = OpenInputDesktop('), CS.index('form = new PatternWindow('))
        self.assertIn('ObjectInteger(input, 6) == 1 && ObjectInteger(desktop, 6) == 1', CS)

    def test_owned_capture_and_all_pixel_validation(self):
        self.assertIn('owner == pid', CS)
        self.assertIn('actualTitle.ToString() == title', CS)
        self.assertIn('GetForegroundWindow() == window', CS)
        self.assertIn('WindowFromPoint(new Point(start.X + x, start.Y + y)) == window', CS)
        self.assertEqual(CS.count('pixels.CopyFromScreen('), 1)
        self.assertIn('pixels.CopyFromScreen(before.Left, before.Top, 0, 0, before.Size, CopyPixelOperation.SourceCopy)', CS)
        self.assertIn('for (int y = 0; y < FrameHeight; y++)', CS)
        self.assertIn('for (int x = 0; x < FrameWidth; x++)', CS)
        self.assertIn('Require(ValidateFrame(frame, inverted)', CS)
        self.assertIn('second = Capture(window, pid, title, input, desktop, screen, true, clock)', CS)
        self.assertIn('first = Capture(window, pid, title, input, desktop, screen, false, clock)', CS)
        self.assertLess(CS.index('second = Capture('), CS.index('first.Save('))
        self.assertLess(CS.index('form.Close(); form.Dispose();'), CS.index('first.Save('))

    def test_bounded_outputs_and_failure_is_not_success(self):
        self.assertIn('clock.ElapsedMilliseconds < 30000', CS)
        self.assertIn('result["status"] = "capability_unavailable"', CS)
        self.assertIn('"owned_cleanup_unconfirmed"', CS)
        self.assertIn('$json.Length -gt 32768', PS)
        self.assertIn('$file.Length -gt 65536', PS)
        self.assertIn("$allowed = @('receipt.json', 'probe.log', 'red-blue.png', 'cyan-yellow.png')", PS)
        self.assertIn("if ($receipt.probe.status -ne 'passed_owned_screen_capture') { exit 2 }", PS)
        self.assertLess(PS.index("$file.Name -notin $allowed"), PS.index("-Value 'evidence_ready=true'"))

    def test_native_validator_negative_controls_are_wired(self):
        self.assertEqual(CS.count('checks++;'), 7)
        for name in ('blank', 'single_color', 'red_blue', 'stale', 'one_pixel', 'inverse', 'size'):
            self.assertIn('"selftest_' + name + '"', CS)
        self.assertIn('$controls = [OwnedScreenProbe]::SelfTest()', PS)
        self.assertIn("if ($controls -ne 7)", PS)
        self.assertLess(PS.index('if ($SelfTestOnly)'), PS.index('[OwnedScreenProbe]::Run($output)'))


if __name__ == '__main__':
    unittest.main(verbosity=2)
