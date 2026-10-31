using Civ13.Launcher.Management;
using Civ13.ServerManagement;

internal static class LogViewLauncherTests {
    internal static void Run(Action<bool, string> check) {
        var binding = new InstanceBinding("20000000-0000-4000-8000-000000000001", "host-a", "profile-a", 1, new string('a', 64), InstanceKind.Process);
        var manifest = new InstanceManifest(binding, "Synthetic", "civ13-byond", "516.1688", null, DesiredState.Running);
        const string path = @"D:\synthetic\catalog.json";
        var registration = new RegistrationSnapshot(path, "clock-a", 100, 100, RegistrationStatus.Available, new InstanceCatalog([manifest]));
        var clock = new Clock(); var request = new LogRequest(binding, "world-log", 1, 32);
        using (var output = new StringWriter()) {
            var page = new RegisteredLogViewSession(clock).ReadAndWrite(output, registration, path, "host-a", request, 1000, 1000);
            check(page.View?.Status == LogViewStatus.Unavailable && output.ToString().Contains("Unavailable"), "default source remains disabled");
        }
        var source = new FakeSource(); source.Set("alpha\u001b\nbeta\n");
        var view = new RegisteredLogViewSession(source, clock); LogCursor cursor;
        using (var output = new StringWriter()) {
            var before = source.Opens; var foreign = request with { Binding = binding with { ProfileRevision = 2 } };
            var page = view.ReadAndWrite(output, registration, path, "host-a", foreign, 1000, 1000);
            check(page.Observation?.Selection == RegisteredLogSelection.NotRegistered && page.View is null && source.Opens == before,
                "foreign profile withheld before source access");
        }
        using (var output = new StringWriter()) {
            var page = view.ReadAndWrite(output, registration, path, "host-a", request, 1000, 1000);
            check(page.View is { Status: LogViewStatus.Available, HasMore: true, NextCursor: not null } &&
                output.ToString().Contains("alpha\\u001B") && !output.ToString().Contains('\u001b'), "bounded control-escaped display");
            cursor = page.View!.NextCursor!;
        }
        using (var output = new StringWriter()) {
            var page = view.ReadAndWrite(output, registration, path, "host-a", request with { Cursor = cursor }, 1000, 1000);
            check(page.View?.Lines.SequenceEqual(["beta"]) == true && page.View.NextCursor is not null, "issued cursor continues");
            cursor = page.View!.NextCursor!;
        }
        using (var output = new StringWriter()) {
            var limited = new RegisteredLogViewSession(source, clock);
            var page = limited.ReadAndWrite(output, registration, path, "host-a", request with { MaximumCharacters = 3 }, 1000, 1000);
            check(page.View is { Status: LogViewStatus.Available, Truncated: true, NextCursor: null } &&
                output.ToString().Contains("alp") && output.ToString().Contains("Log output truncated.") && !output.ToString().Contains("alpha"),
                "truncated display withholds continuation cursor");
        }
        var reference = new RegisteredLogViewSession(source, clock).Read(registration, path, "host-a", request, 1000, 1000);
        var failedView = new RegisteredLogViewSession(source, clock); var writeFailed = false;
        try { failedView.ReadAndWrite(new FailingWriter(), registration, path, "host-a", request, 1000, 1000); }
        catch (IOException) { writeFailed = true; }
        using (var output = new StringWriter()) {
            var page = failedView.ReadAndWrite(output, registration, path, "host-a", request with { Cursor = reference.View!.NextCursor }, 1000, 1000);
            check(writeFailed && page.RequiresReset && output.ToString().Contains("ResetRequired"), "failed output invalidates continuation");
        }
        var toggle = new ToggleClock(); var interrupted = new RegisteredLogViewSession(source, toggle);
        var beforeFailure = interrupted.Read(registration, path, "host-a", request, 1000, 1000); toggle.Fail = true; var readFailed = false;
        try { interrupted.Read(registration, path, "host-a", request with { Cursor = beforeFailure.View!.NextCursor }, 1000, 1000); }
        catch (InvalidOperationException) { readFailed = true; }
        toggle.Fail = false;
        check(readFailed && interrupted.Read(registration, path, "host-a", request with { Cursor = beforeFailure.View!.NextCursor }, 1000, 1000).RequiresReset,
            "unexpected read failure invalidates continuation");
        source.Set("new\n"); source.Generation = "generation-b";
        using (var output = new StringWriter()) {
            var page = view.ReadAndWrite(output, registration, path, "host-a", request with { Cursor = cursor }, 1000, 1000);
            check(page.RequiresReset && page.View?.Status == LogViewStatus.ResetRequired && !output.ToString().Contains("new"), "generation change requires explicit reset");
        }
        using (var output = new StringWriter()) {
            var page = view.ReadAndWrite(output, registration, path, "host-a", request, 1000, 1000);
            check(page.View?.Lines.SequenceEqual(["new"]) == true, "fresh request displays new generation");
        }
        using (var output = new StringWriter()) {
            var before = source.Opens; var page = view.ReadAndWrite(output, registration, path, "host-a", request, 1, 1000);
            check(page.Observation?.Registration == RegistrationViewStatus.Stale && page.View is null && source.Opens == before, "stale registration withheld before I/O");
        }
        using (var output = new StringWriter()) {
            var advanced = new RegisteredLogViewSession(source, new AdvanceClock());
            var expected = new RegisteredLogViewSession(source, clock).Read(registration, path, "host-a", request, 1000, 1000).View!.NextCursor;
            var page = advanced.ReadAndWrite(output, registration, path, "host-a", request, 10, 1000);
            check(page.Observation?.Registration == RegistrationViewStatus.Stale && page.View is null && !output.ToString().Contains("new") &&
                advanced.Read(registration, path, "host-a", request with { Cursor = expected }, 1000, 1000).RequiresReset,
                "registration rechecked at display and stale cursor invalidated");
        }
        using (var output = new StringWriter()) {
            var page = new RegisteredLogViewSession(source, new AdvanceClock()).ReadAndWrite(output, registration, path, "host-a", request, 1000, 10);
            check(page.View?.Status == LogViewStatus.Stale && page.View.Lines.Count == 0 && !output.ToString().Contains("new"), "stale observation withheld at display");
        }
        source.OpenError = new UnauthorizedAccessException("synthetic");
        using (var output = new StringWriter()) {
            var page = view.ReadAndWrite(output, registration, path, "host-a", request, 1000, 1000);
            check(page.View?.Status == LogViewStatus.Denied && output.ToString().Contains("Denied") && !output.ToString().Contains("new"), "denied stays distinct");
        }
        source.OpenError = new IOException("synthetic-fence");
        using (var output = new StringWriter()) {
            var page = view.ReadAndWrite(output, registration, path, "host-a", request, 1000, 1000);
            check(page.View?.Status == LogViewStatus.Unavailable && output.ToString().Contains("Unavailable") && !output.ToString().Contains("new"), "fenced source remains unavailable");
        }
        var multi = new FakeSource { AllowAnyStream = true }; multi.Set("x\n"); var bounded = new RegisteredLogViewSession(multi, clock); LogCursor? first = null;
        for (var i = 0; i < RegisteredLogViewSession.MaximumCursorKeys; i++) {
            var page = bounded.Read(registration, path, "host-a", new LogRequest(binding, "stream-" + i, 1, 32), 1000, 1000);
            if (i == 0) first = page.View?.NextCursor;
            check(page.View is { Status: LogViewStatus.Available, NextCursor: not null }, "bounded cursor key accepted");
        }
        var count = multi.Opens; var refused = false;
        try { bounded.Read(registration, path, "host-a", new LogRequest(binding, "overflow", 1, 32), 1000, 1000); }
        catch (ContractException error) when (error.Code == "log-session-capacity") { refused = true; }
        check(refused && multi.Opens == count, "capacity rejects new key before source I/O");
        check(first is not null && bounded.Read(registration, path, "host-a", new LogRequest(binding, "stream-0", 1, 32) { Cursor = first }, 1000, 1000).View?.Status == LogViewStatus.Available,
            "capacity preserves existing cursor");
        check(new RegisteredLogViewSession(multi, clock).Read(registration, path, "host-a", new LogRequest(binding, "overflow", 1, 32), 1000, 1000).View?.Status == LogViewStatus.Available,
            "fresh session has independent capacity");
    }
    private sealed class Clock : IProcessObservationClock { public string Scope => "clock-a"; public long Milliseconds => 105; }
    private sealed class AdvanceClock : IProcessObservationClock { private int reads; public string Scope => "clock-a"; public long Milliseconds => ++reads >= 4 ? 200 : 105; }
    private sealed class ToggleClock : IProcessObservationClock { internal bool Fail; public string Scope => "clock-a"; public long Milliseconds => Fail ? throw new InvalidOperationException("synthetic") : 105; }
    private sealed class FailingWriter : TextWriter { public override System.Text.Encoding Encoding => System.Text.Encoding.UTF8; public override void WriteLine(string? value) => throw new IOException("synthetic"); }
}
