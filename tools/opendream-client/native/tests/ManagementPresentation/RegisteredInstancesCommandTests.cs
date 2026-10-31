using System.Text;
using System.Text.Json;
using Civ13.Launcher.Management;
using Civ13.ServerManagement;

static class RegisteredInstancesCommandTests {
    public static async Task<int> Run() {
        var count = 0;
        void Check(bool ok, string name) { count++; if (!ok) throw new Exception("Registered view: " + name); }
        var instance = new {
            schema = "civ13.instance.v1", instanceId = "20000000-0000-4000-8000-000000000001",
            hostId = "host-a", profileId = "profile-a", profileRevision = 1,
            profileSha256 = new string('a', 64), kind = "process", label = "Example world",
            backend = "civ13-byond", runtimeVersion = "516.1688", shardGroupId = (string?)null,
            desired = "running", registration = "observe-only"
        };
        var bytes = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(new { schema = "civ13.catalog.v1", instances = new[] { instance } }));
        var source = new StubReader { Result = new(RegistrationReadKind.Available, bytes) };
        var clock = new StubClock();
        string[] args = [RegisteredInstancesCommand.Option, @"D:\trusted", @"D:\trusted\catalog.json", "host-a"];
        int factories = 0;
        string? requestedRoot = null;
        IRegistrationFileReader Factory(string root) { factories++; requestedRoot = root; return source; }
        (int Code, string Text) Invoke(string[] input) {
            using var output = new StringWriter();
            var code = RegisteredInstancesCommand.Run(input, output, Factory, clock);
            return (code, output.ToString());
        }
        var shown = Invoke(args);
        Check(shown.Code == 0 && shown.Text.Contains("Example world") && shown.Text.Contains("Desired: Running"), "selected registration rendered");
        Check(shown.Text.Contains("no explicit process target") && shown.Text.Contains("Ownership and backend readiness are unverified"), "no process or ownership inferred");
        Check(!shown.Text.Contains("PID:") && !shown.Text.Contains(@"D:\trusted"), "no manufactured PID or private path output");
        Check(factories == 1 && source.Calls == 1 && requestedRoot == args[1] && source.Path == args[2] && source.Limit == ManifestJson.MaximumCatalogBytes, "one explicitly bounded registration request");
        foreach (var state in new[] { RegistrationReadKind.Missing, RegistrationReadKind.Denied, RegistrationReadKind.Unavailable, RegistrationReadKind.Invalid }) {
            source.Result = new(state, null);
            var result = Invoke(args);
            Check(result.Code == 1 && result.Text.Contains(state.ToString()) && result.Text.Contains("remain unknown"), "unavailable states stay unknown");
            Check(!result.Text.Contains("No registered instances") && !result.Text.Contains(@"D:\trusted"), "failure neither claims empty nor leaks path");
        }
        source.Result = new(RegistrationReadKind.Available, Encoding.UTF8.GetBytes("{bad"));
        Check(Invoke(args).Text.Contains("Registration status: Invalid"), "malformed catalog remains unknown");
        source.Result = new(RegistrationReadKind.Available, Encoding.UTF8.GetBytes("{\"schema\":\"civ13.catalog.v1\",\"instances\":[]}"));
        Check(Invoke(args).Text.Contains("No registered instances were supplied"), "available empty catalog remains distinct");
        var calls = source.Calls;
        var factoryCalls = factories;
        foreach (var bad in new[] {
            new[] { RegisteredInstancesCommand.Option },
            new[] { RegisteredInstancesCommand.Option, @"C:\wrong", args[2], args[3] },
            new[] { RegisteredInstancesCommand.Option, args[1], @"D:\trusted-other\catalog.json", args[3] },
            new[] { RegisteredInstancesCommand.Option, args[1], @"D:\trusted\..\catalog.json", args[3] },
            new[] { RegisteredInstancesCommand.Option, args[1], args[2], "bad/host" },
            new[] { RegisteredInstancesCommand.Option, args[1], args[2], args[3], "extra" }
        }) Check(Invoke(bad).Code == 1, "bad selection rejected");
        Check(source.Calls == calls && factories == factoryCalls, "invalid selections do not access a reader");
        source.Result = new(RegistrationReadKind.Available, bytes);
        source.OnRead = () => clock.Now = 1200;
        var slow = Invoke(args);
        Check(slow.Text.Contains("ReadTooSlow") && slow.Code == 1, "slow read remains unknown");
        clock.Now = 100; source.OnRead = () => clock.Scope = "other";
        var changedClock = Invoke(args);
        Check(changedClock.Code == 1 && changedClock.Text.Contains("ClockChanged"), "changed clock remains unknown");
        source.OnRead = null; clock.Scope = "fixture"; clock.Now = 100;
        clock.Samples = new Queue<long>([100, 100, 5101]);
        var stale = Invoke(args);
        Check(stale.Text.Contains("Registration status: Stale") && !stale.Text.Contains("Example world"), "stale registration does not display old entries");
        clock.Samples = null;
        var original = Console.Out;
        using var console = new StringWriter();
        try {
            Console.SetOut(console);
            var exit = await Civ13.Launcher.Program.Main([RegisteredInstancesCommand.Option]);
            Check(exit == 1 && console.ToString().Contains(RegisteredInstancesCommand.Usage), "real entry point rejects malformed command before normal startup");
        } finally { Console.SetOut(original); }
        Console.WriteLine($"PASS {count} registered-instance command assertions; injected files and clock, no process access or network.");
        return count;
    }
    private sealed class StubClock : IProcessObservationClock {
        public string Scope { get; set; } = "fixture";
        public long Now = 100;
        public Queue<long>? Samples;
        public long Milliseconds => Samples is { Count: > 0 } ? Samples.Dequeue() : Now;
    }
    private sealed class StubReader : IRegistrationFileReader {
        public RegistrationRead Result = new(RegistrationReadKind.Unavailable, null);
        public int Calls, Limit;
        public string? Path;
        public Action? OnRead;
        public RegistrationRead Read(string absolutePath, int maximumBytes) {
            Calls++; Path = absolutePath; Limit = maximumBytes; OnRead?.Invoke(); return Result;
        }
    }
}
