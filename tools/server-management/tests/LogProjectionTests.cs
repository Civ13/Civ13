using Civ13.ServerManagement;

internal static class LogProjectionTests {
    public static int Run() {
        var count = 0;
        void Check(bool condition, string name) { count++; if (!condition) throw new Exception("Log projection failed: " + name); }
        void Reject(Action action, string name) {
            var rejected = false; try { action(); } catch (ContractException) { rejected = true; }
            Check(rejected, name);
        }
        var binding = new InstanceBinding("20000000-0000-4000-8000-000000000001", "host-a", "profile-a", 1, new string('a', 64), InstanceKind.Process);
        var request = new LogRequest(binding, "world-log", 4, 128);
        var lines = new List<string> { "startup", "player \U0001F642" };
        var observation = new LogObservation(request, "clock-a", 100, 102, LogReadKind.Available, lines, true);
        LogView View(LogObservation? data = null, LogRequest? req = null, string scope = "clock-a", long now = 105, long age = 10) =>
            LogProjection.Project(req ?? request, data ?? observation, scope, now, age);
        var result = View();
        Check(result.Status == LogViewStatus.Available && result.Lines.SequenceEqual(lines) && result.HasEarlier && !result.Truncated, "bounded supplied page");
        lines[0] = "changed";
        Check(result.Lines[0] == "startup", "view is detached from supplied collection");
        Check(LogProjection.Project(request, null, "clock-a", 105, 10).Status == LogViewStatus.ScopeMismatch, "no observation is unknown");
        foreach (var changed in new[] { binding with { InstanceId = "20000000-0000-4000-8000-000000000002" },
            binding with { HostId = "host-b" }, binding with { ProfileId = "profile-b" }, binding with { ProfileRevision = 2 },
            binding with { ProfileSha256 = new string('b', 64) }, binding with { Kind = InstanceKind.Shard } })
            Check(View(observation with { Request = request with { Binding = changed } }).Status == LogViewStatus.ScopeMismatch,
                "present evidence remains instance/host/profile-bound");
        foreach (var item in new[] { (LogReadKind.Missing, LogViewStatus.Missing), (LogReadKind.Denied, LogViewStatus.Denied),
            (LogReadKind.Unavailable, LogViewStatus.Unavailable) }) {
            var page = observation with { Kind = item.Item1, Lines = null, HasEarlier = false };
            var view = View(page);
            Check(view.Status == item.Item2 && view.Lines.Count == 0, "failure states distinct and no text");
            foreach (var changed in new[] { binding with { InstanceId = "20000000-0000-4000-8000-000000000002" },
                binding with { HostId = "host-b" }, binding with { ProfileId = "profile-b" }, binding with { ProfileRevision = 2 },
                binding with { ProfileSha256 = new string('b', 64) }, binding with { Kind = InstanceKind.Shard } })
                Check(View(page with { Request = request with { Binding = changed } }).Status == LogViewStatus.ScopeMismatch,
                    "all absent evidence remains instance/host/profile-bound");
        }
        Check(View(observation with { Request = request with { StreamId = "other-log" } }).Status == LogViewStatus.ScopeMismatch, "stream binding");
        Check(View(observation with { Request = request with { MaximumCharacters = 127 } }).Status == LogViewStatus.ScopeMismatch, "budget binding");
        Check(View(observation with { ClockScope = "old-clock" }).Status == LogViewStatus.ClockChanged, "clock scope mismatch");
        Check(View(observation with { SampleMilliseconds = -1 }).Status == LogViewStatus.Invalid, "negative sample");
        Check(View(observation with { CompletedMilliseconds = 99 }).Status == LogViewStatus.Invalid, "regressed clock");
        Check(View(observation with { CompletedMilliseconds = 106 }).Status == LogViewStatus.Invalid, "future sample");
        Check(View(now: 111).Status == LogViewStatus.Stale && View(now: 111).Lines.Count == 0, "stale page withheld");
        Check(View(now: 110).Status == LogViewStatus.Available, "exact freshness boundary");
        foreach (var bad in new[] { observation with { Kind = (LogReadKind)99 }, observation with { Lines = null },
            observation with { Kind = LogReadKind.Missing }, observation with { Kind = LogReadKind.Denied, Lines = null },
            observation with { Lines = new string[] { null! } }, observation with { Lines = [new string('a', 1025)] },
            observation with { Lines = ["\uD800"] }, observation with { Lines = ["\uDC00"] },
            observation with { Lines = ["1", "2", "3", "4", "5"] } })
            Check(View(bad).Status == LogViewStatus.Invalid && View(bad).Lines.Count == 0, "malformed page withheld");
        var controls = observation with { Lines = ["a\u001b[31m\u000d\u000a\u0085\u202e\u2028\U000E0001z"] };
        var safe = View(controls);
        Check(safe.Lines.Single() == "a\\u001B[31m\\u000D\\u000A\\u0085\\u202E\\u2028\\U000E0001z", "terminal and format controls escaped");
        var ambiguous = View(observation with { Lines = ["\\u001B", "\u001b"] });
        Check(ambiguous.Lines[0] == "\\\\u001B" && ambiguous.Lines[1] == "\\u001B", "literal escape text differs from escaped control");
        var tinyRequest = request with { MaximumCharacters = 6 };
        var tiny = LogProjection.Project(tinyRequest, observation with { Request = tinyRequest, Lines = ["\u001bX"] }, "clock-a", 105, 10);
        Check(tiny.Lines.Single() == "\\u001B" && tiny.Truncated, "escapes never split at output budget");
        var one = request with { MaximumCharacters = 1 };
        var emoji = LogProjection.Project(one, observation with { Request = one, Lines = ["\U0001F642"] }, "clock-a", 105, 10);
        Check(emoji.Lines.Count == 0 && emoji.Truncated, "supplementary scalar never split");
        var corruptAfterBudget = observation with { Request = one, Lines = ["abc\uD800"] };
        Check(LogProjection.Project(one, corruptAfterBudget, "clock-a", 105, 10).Status == LogViewStatus.Invalid,
            "entire bounded page validated after truncation");
        var max = request with { MaximumLines = 64, MaximumCharacters = 8192 };
        var large = observation with { Request = max, Lines = Enumerable.Repeat(new string('a', 1024), 9).ToArray() };
        var capped = LogProjection.Project(max, large, "clock-a", 105, 10);
        Check(capped.Truncated && capped.Lines.Count == 8 && capped.Lines.Sum(x => x.Length) == 8192, "total output remains bounded");
        Check(View(observation with { Lines = [] }).Status == LogViewStatus.Available && View(observation with { Lines = [] }).Lines.Count == 0,
            "empty available page differs from missing");
        foreach (var invalid in new[] { request with { StreamId = "D:\\private" }, request with { StreamId = "" },
            request with { MaximumLines = 0 }, request with { MaximumLines = 65 }, request with { MaximumCharacters = 0 },
            request with { MaximumCharacters = 8193 }, request with { Binding = binding with { ProfileRevision = 0 } } })
            Reject(() => View(req: invalid), "invalid request before admission");
        Reject(() => View(scope: ""), "invalid clock scope");
        Reject(() => View(now: -1), "invalid now");
        Reject(() => View(age: 0), "invalid max age");
        Console.WriteLine($"PASS {count} bounded log projection assertions; synthetic lines only, no file or process access.");
        return count;
    }
}
