using Civ13.Launcher;

static class LauncherLogWriterTests {
    private sealed class Clock : TimeProvider {
        public DateTimeOffset Now = new(2026, 11, 28, 4, 59, 59, TimeSpan.Zero);
        public override DateTimeOffset GetUtcNow() => Now;
        public override TimeZoneInfo LocalTimeZone => TimeZoneInfo.CreateCustomTimeZone("fixture", TimeSpan.FromHours(-5), "fixture", "fixture");
    }

    public static int Run() {
        var lines = new List<string>();
        var clock = new Clock();
        using var writer = TextWriter.Synchronized(new LauncherLogWriter(lines.Add, clock));
        writer.Write("Build");
        if (lines.Count != 0) throw new Exception("The launcher log published an incomplete line.");
        writer.WriteLine(" started\r\n  next step\n\nDone.");
        clock.Now = clock.Now.AddSeconds(1);
        writer.WriteLine("Host ready");
        string[] expected = [
            "[2026-11-27 23:59:59 -05:00] Build started",
            "[2026-11-27 23:59:59 -05:00]   next step",
            "",
            "[2026-11-27 23:59:59 -05:00] Done.",
            "[2026-11-28 00:00:00 -05:00] Host ready",
        ];
        if (!lines.SequenceEqual(expected)) throw new Exception("Launcher log lost its timestamps, line breaks or indentation.");
        return 2;
    }
}
