using Civ13.Launcher;

static class ByondDetectionTests {
    public static async Task<int> Run(string root, string? installedBin = null) {
        var count = 0;
        void Check(bool value, string message) { count++; if (!value) throw new Exception(message); }
        var requirement = Civ13.Launcher.Program.RequiredByond();
        var target = Version.Parse(requirement.Version);
        var pe = $"5.0.{requirement.Version}";
        Check(requirement.MatchesPeVersion(pe), "compiler target rejected");
        foreach (var bad in new string?[] { null, "", "516.1688", "5.0.516", "5.0.516.1681",
                "5.0.515.1688", "5.0.517.1688", "5.0.516.1689", "5.0.516.01688", "5.0.516.1688 extra" })
            Check(!requirement.MatchesPeVersion(bad), "old, unknown future or malformed engine accepted");
        // A future target is accepted only after the pinned compiler contract changes.
        var reviewedNext = requirement with { Version = $"{target.Major}.{target.Minor + 1}",
            Url = $"https://www.byond.com/download/build/{target.Major}/{target.Major}.{target.Minor + 1}_byond.exe" };
        Check(reviewedNext.Matches(5, 0, target.Major, target.Minor + 1), "reviewed compiler bump rejected");

        var transport = new NoDownload();
        var bin = Path.Combine(root, "custom location", "BYOND", "bin");
        Directory.CreateDirectory(bin);
        var executable = Path.Combine(bin, "dreamseeker.exe");
        File.WriteAllText(executable, "fixture; never executed");
        foreach (var chosen in new[] { bin, Path.GetDirectoryName(bin)!, executable }) {
            var desktop = new DetectionDesktop { Chosen = chosen };
            desktop.Versions[bin] = (pe, pe);
            Check(await Byond.Ensure(requirement, root, transport, desktop) == bin,
                "custom bin/install-root/executable selection rejected");
            Check(desktop.InstallPrompts == 0, "supported custom path prompted for reinstall");
        }
        var found = new DetectionDesktop { Candidate = bin };
        found.Versions[bin] = (pe, pe);
        Check(await Byond.Ensure(requirement, root, transport, found) == bin && found.Choices == 0,
            "discovered supported installation was not reused offline");
        foreach (var versions in new[] { ("5.0.516.1681", "5.0.516.1681"), (pe, "5.0.516.1681"),
                (pe, ""), ("malformed", pe), ("5.0.517.1688", "5.0.517.1688") }) {
            var wrong = new DetectionDesktop { Candidate = bin, Chosen = bin };
            wrong.Versions[bin] = versions;
            var rejected = false;
            try { await Byond.Ensure(requirement, root, transport, wrong); }
            catch (IOException) { rejected = true; }
            Check(rejected && wrong.InstallPrompts == 0, "incompatible/mixed/missing executable accepted");
        }
        var missing = new DetectionDesktop();
        var cancelled = false;
        try { await Byond.Ensure(requirement, root, transport, missing); }
        catch (IOException) { cancelled = true; }
        Check(cancelled && missing.InstallPrompts == 1, "missing installation failed to offer explicit setup");
        Check(transport.Downloads == 0, "detection attempted a download");
        if (OperatingSystem.IsWindows()) {
            var desktop = new WindowsByondDesktop();
            Check(!desktop.Matches(bin, requirement), "non-PE/missing real executable accepted");
            if (installedBin is not null) {
                var stale = requirement with { Version = "516.1681",
                    Url = "https://www.byond.com/download/build/516/516.1681_byond.exe" };
                var rejectedBefore = !desktop.Matches(installedBin, stale);
                var acceptedNow = desktop.Matches(installedBin, requirement);
                Check(rejectedBefore && acceptedNow, "installed-engine before/after reproduction failed");
                Check(desktop.Candidates(root, requirement).Contains(installedBin, StringComparer.OrdinalIgnoreCase),
                    "real installed location was not discovered");
                Console.WriteLine($"REPRO: stale 516.1681 rejected installed engine; shared {requirement.Version} accepted {installedBin}.");
            }
        }
        Console.WriteLine($"PASS: {count} BYOND detection assertions; no downloads, installation or game processes.");
        return count;
    }

    sealed class NoDownload : ITransport {
        public int Downloads { get; private set; }
        public Task<string> Text(string url) => throw new Exception("Unexpected network lookup");
        public Task Download(string url, string destination) { Downloads++; throw new Exception("Unexpected download"); }
    }
    sealed class DetectionDesktop : IByondDesktop {
        public string? Candidate { get; init; }
        public string? Chosen { get; init; }
        public int Choices { get; private set; }
        public int InstallPrompts { get; private set; }
        public Dictionary<string, (string Client, string Seeker)> Versions { get; } = new(StringComparer.OrdinalIgnoreCase);
        public IEnumerable<string> Candidates(string root, ByondRequirement requirement) => Candidate is null ? [] : [Candidate];
        public bool Matches(string path, ByondRequirement requirement) => Versions.TryGetValue(path, out var versions)
            && requirement.MatchesPeVersion(versions.Client) && requirement.MatchesPeVersion(versions.Seeker);
        public string? ChooseExisting() { Choices++; return Chosen; }
        public bool ConfirmInstall(ByondRequirement requirement) { InstallPrompts++; return false; }
        public void ValidateInstaller(string installer, ByondRequirement requirement) => throw new Exception("Unexpected installer validation");
        public Task<int> Install(string installer, string destination) => throw new Exception("Unexpected installation");
    }
}
