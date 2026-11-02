using System.Text;
using System.Text.Json;
using Civ13.Launcher;
using Civ13.Launcher.Management;
using Civ13.ServerManagement;

static class RegisteredInstancesMenuTests {
    public static async Task<int> Run() {
        var count = 0;
        void Check(bool ok, string name) { count++; if (!ok) throw new Exception("Management menu: " + name); }
        using (var help = new StringWriter()) {
            Civ13.Launcher.Program.WriteHelp(help);
            Check(help.ToString().Contains("--manage-servers") && help.ToString().Contains("without updates or BYOND setup"),
                "help documents the early management option");
        }
        var originalInput = Console.In;
        var originalOutput = Console.Out;
        using (var output = new StringWriter()) {
            try {
                Console.SetIn(new StringReader("\n"));
                Console.SetOut(output);
                var exit = await Civ13.Launcher.Program.Main([RegisteredInstancesMenu.Option]);
                Check(exit == 0 && output.ToString().Contains("Server management cancelled."),
                    "early option opens the menu and exits on cancellation");
                Check(output.ToString().Contains("unavailable in this view") && !output.ToString().Contains("Checking for launcher updates"),
                    "early option presents read-only state without normal startup");
            } finally {
                Console.SetIn(originalInput);
                Console.SetOut(originalOutput);
            }
        }
        var entry = new {
            schema = "civ13.instance.v1", instanceId = "20000000-0000-4000-8000-000000000001",
            hostId = "host-a", profileId = "profile-a", profileRevision = 1,
            profileSha256 = new string('a', 64), kind = "process", label = "Example world",
            backend = "civ13-byond", runtimeVersion = "516.1688", shardGroupId = (string?)null,
            desired = "running", registration = "observe-only"
        };
        var bytes = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(new { schema = "civ13.catalog.v1", instances = new[] { entry } }));
        var reader = new StubReader { Result = new(RegistrationReadKind.Available, bytes) };
        var clock = new StubClock();
        int factories = 0, clocks = 0;
        IRegistrationFileReader Factory(string root) { factories++; Check(root == @"D:\trusted", "explicit trusted root forwarded"); return reader; }
        IProcessObservationClock Clock() { clocks++; return clock; }
        using (var menu = new StringWriter()) {
            Civ13.Launcher.Program.WriteMainMenu(menu);
            Check(menu.ToString().Contains(RegisteredInstancesMenu.Menu), "read-only operator option visible without hosting configuration");
            Check(!menu.ToString().Contains(LocalHosting.Menu), "host option remains independently configured");
        }
        using (var menu = new StringWriter()) {
            Civ13.Launcher.Program.WriteMainMenu(menu, true);
            Check(menu.ToString().Contains(LocalHosting.Menu) && menu.ToString().Contains(RegisteredInstancesMenu.Menu), "existing host option is preserved");
        }
        using (var output = new StringWriter()) {
            var handled = RegisteredInstancesMenu.TryHandle("m",
                new StringReader("D:\\trusted\nD:\\trusted\\catalog.json\nhost-a\n"), output, Factory, Clock);
            var text = output.ToString();
            Check(handled && factories == 1 && clocks == 1 && reader.Calls == 1, "one explicit selection makes one bounded read");
            Check(reader.Path == @"D:\trusted\catalog.json" && reader.Limit == ManifestJson.MaximumCatalogBytes, "exact catalog and byte limit forwarded");
            Check(text.Contains("Example world") && text.Contains("no explicit process target was supplied"), "registered entry shown with unknown facts");
            Check(text.Contains("Ownership and backend readiness are unverified"), "view does not assert ownership or readiness");
            Check(text.Contains("Start / stop / save / update / restart: unavailable"), "lifecycle actions explicitly unavailable");
            Check(!text.Contains(@"D:\trusted\catalog.json") && !text.Contains("PID:"), "no path echoed or process facts fabricated");
        }
        foreach (var input in new[] { "", "\n", "D:\\trusted\n\n", "D:\\trusted\nD:\\trusted\\catalog.json\n\n" }) {
            var before = reader.Calls; var beforeFactories = factories; var beforeClocks = clocks;
            using var output = new StringWriter();
            Check(RegisteredInstancesMenu.TryHandle("M", new StringReader(input), output, Factory, Clock), "cancel is handled");
            Check(output.ToString().Contains("cancelled") && reader.Calls == before && factories == beforeFactories && clocks == beforeClocks,
                "cancel never reads a catalog or creates adapters");
        }
        foreach (var other in new string?[] { null, "", "1", "2", "3", "4", "5", "9", "H", "unknown", "MM" }) {
            var before = reader.Calls;
            using var output = new StringWriter();
            Check(!RegisteredInstancesMenu.TryHandle(other, new FailOnRead(), output, Factory, Clock) && output.ToString().Length == 0 &&
                reader.Calls == before, "non-management choice is not intercepted");
        }
        var readsBeforeRefresh = reader.Calls;
        using (var output = new StringWriter()) {
            Check(RegisteredInstancesMenu.TryHandle("M", new StringReader("D:\\trusted\nD:\\trusted\\catalog.json\nhost-a\n"), output, Factory, Clock) &&
                reader.Calls == readsBeforeRefresh + 1, "explicit second selection reads a fresh snapshot");
        }
        clock.Samples = new Queue<long>([100, 100, 5101]);
        using (var output = new StringWriter()) {
            Check(RegisteredInstancesMenu.TryHandle("M", new StringReader("D:\\trusted\nD:\\trusted\\catalog.json\nhost-a\n"), output, Factory, Clock), "stale registration selection handled");
            Check(output.ToString().Contains("Registration status: Stale") && output.ToString().Contains("remain unknown") &&
                !output.ToString().Contains("Example world"), "stale registration never displays old entries or implies readiness");
        }
        clock.Samples = null;
        reader.Result = new(RegistrationReadKind.Denied, null);
        using (var output = new StringWriter()) {
            Check(RegisteredInstancesMenu.TryHandle("M", new StringReader("D:\\trusted\nD:\\trusted\\catalog.json\nhost-a\n"), output, Factory, Clock), "denied selection handled");
            Check(output.ToString().Contains("Registration status: Denied") && output.ToString().Contains("remain unknown") &&
                !output.ToString().Contains("No registered instances were supplied"), "denied is unknown, not empty");
        }
        var callCount = reader.Calls; var factoryCount = factories;
        using (var output = new StringWriter()) {
            Check(RegisteredInstancesMenu.TryHandle("M", new StringReader("D:\\trusted\nD:\\outside\\catalog.json\nhost-a\n"), output, Factory, Clock), "invalid selection handled");
            Check(output.ToString().Contains("remain unknown") && reader.Calls == callCount && factories == factoryCount, "out-of-root path never reaches reader");
        }
        Console.WriteLine($"PASS {count} registered-instance menu assertions; injected reader and clock only.");
        return count;
    }
    private sealed class StubClock : IProcessObservationClock {
        public string Scope => "menu-fixture";
        public Queue<long>? Samples;
        public long Milliseconds => Samples is { Count: > 0 } ? Samples.Dequeue() : 100;
    }
    private sealed class StubReader : IRegistrationFileReader {
        public RegistrationRead Result = new(RegistrationReadKind.Unavailable, null);
        public int Calls, Limit;
        public string? Path;
        public RegistrationRead Read(string absolutePath, int maximumBytes) {
            Calls++; Path = absolutePath; Limit = maximumBytes; return Result;
        }
    }
    private sealed class FailOnRead : TextReader {
        public override string? ReadLine() => throw new Exception("unexpected input read");
    }
}