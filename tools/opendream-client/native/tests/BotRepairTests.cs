using System.Diagnostics;
using Civ13.Launcher;

// Repair and update against real temporary Git repositories (no network, no bot, no PHP): a bot checkout
// that is detached, dirty, has untracked files, a hidden-index composer.lock edit and a local commit
// comes back to a clean main equal to origin/main, and nothing is lost.
static class BotRepairTests {
    public static int Run(string root) {
        var assertions = 0;
        void Require(bool condition, string message) {
            assertions++;
            if (!condition) throw new Exception("Bot repair contract: " + message);
        }
        string Git(string dir, params string[] args) {
            var step = new ProcessStartInfo("git") { UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true };
            foreach (var a in new[] { "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "-C", dir }.Concat(args)) step.ArgumentList.Add(a);
            using var p = Process.Start(step)!;
            var output = p.StandardOutput.ReadToEnd(); p.StandardError.ReadToEnd(); p.WaitForExit();
            if (p.ExitCode != 0) throw new Exception("fixture git " + string.Join(' ', args) + " failed");
            return output.Trim();
        }
        var dir = Path.Combine(root, "bot-repair");
        if (Directory.Exists(dir)) Directory.Delete(dir, true);
        Directory.CreateDirectory(dir);
        var origin = Path.Combine(dir, "origin.git"); var seed = Path.Combine(dir, "seed"); var repo = Path.Combine(dir, "bot");
        Git(dir, "init", "--bare", "--initial-branch=main", origin);
        Git(dir, "clone", origin, seed);
        File.WriteAllText(Path.Combine(seed, "bot.php"), "first"); File.WriteAllText(Path.Combine(seed, "composer.lock"), "{\"lock\":\"upstream\"}");
        Git(seed, "add", "."); Git(seed, "commit", "-m", "first"); Git(seed, "push", "origin", "main");
        Git(dir, "clone", origin, repo);
        // Local trouble: a commit only here, detached HEAD, an edit, an untracked file, a hidden composer.lock edit.
        File.WriteAllText(Path.Combine(repo, "bot.php"), "local commit"); Git(repo, "commit", "-am", "local"); var local = Git(repo, "rev-parse", "HEAD");
        Git(repo, "switch", "--detach", "HEAD");
        File.WriteAllText(Path.Combine(repo, "bot.php"), "uncommitted"); File.WriteAllText(Path.Combine(repo, "scratch.txt"), "untracked");
        File.WriteAllText(Path.Combine(repo, "composer.lock"), "{\"lock\":\"local path override\"}"); Git(repo, "update-index", "--skip-worktree", "composer.lock");
        File.WriteAllText(Path.Combine(seed, "bot.php"), "second"); Git(seed, "commit", "-am", "second"); Git(seed, "push", "origin", "main");
        var second = Git(seed, "rev-parse", "HEAD");

        var bot = new HostBot("php.exe", repo, Path.Combine(dir, "profile.json"), 25565);
        var result = BotRepair.Run(bot, LocalHosting.RunCaptured, new DateTime(2026, 11, 13, 14, 0, 0, DateTimeKind.Utc));
        Require(result.Ok, "repair failed: " + result.Summary);
        Require(Git(repo, "symbolic-ref", "--short", "HEAD") == "main" && Git(repo, "rev-parse", "HEAD") == second, "not on current main");
        Require(Git(repo, "rev-parse", "--abbrev-ref", "main@{upstream}") == "origin/main", "upstream not origin/main");
        Require(File.ReadAllText(Path.Combine(repo, "bot.php")) == "second" && !File.Exists(Path.Combine(repo, "scratch.txt")), "worktree not clean main");
        Require(result.Stash == "Civ13 launcher repair 20261113-140000" && Git(repo, "stash", "list").Contains(result.Stash!), "edits not stashed");
        Require(Git(repo, "show", "stash@{0}^3:scratch.txt") == "untracked", "untracked file not kept in the stash");
        Require(result.BackupBranch == "civilizationbot-backup-20261113-140000" && Git(repo, "rev-parse", result.BackupBranch!) == local, "local commit not kept");
        Require(result.RestoredLock && File.ReadAllText(Path.Combine(repo, "composer.lock")) == "{\"lock\":\"local path override\"}", "local composer.lock not restored");
        Require(Git(repo, "status", "--porcelain") == "M composer.lock" && !Git(repo, "ls-files", "-v").Split('\n').Any(l => l.StartsWith("S ") || (l.Length > 0 && char.IsLower(l[0]))), "only the lock edit should remain, unhidden");
        Require(result.Summary.Contains(second[..7]) && result.Summary.Contains(result.Stash!), "summary: " + result.Summary);

        // Upstream changing composer.lock: the local lock stays in the stash and upstream's is used.
        File.WriteAllText(Path.Combine(seed, "composer.lock"), "{\"lock\":\"upstream v2\"}"); Git(seed, "commit", "-am", "lock"); Git(seed, "push", "origin", "main");
        result = BotRepair.Run(bot, LocalHosting.RunCaptured, new DateTime(2026, 11, 13, 15, 0, 0, DateTimeKind.Utc));
        Require(result is { Ok: true, RestoredLock: false, UpstreamLockChanged: true, BackupBranch: null } && File.ReadAllText(Path.Combine(repo, "composer.lock")) == "{\"lock\":\"upstream v2\"}"
            && Git(repo, "status", "--porcelain") == "" && result.Summary.Contains("composer install"), "upstream lock change: " + result.Summary);
        // Already clean and current: nothing set aside.
        result = BotRepair.Run(bot, LocalHosting.RunCaptured, DateTime.UtcNow);
        Require(result is { Ok: true, Stash: null, BackupBranch: null }, "clean repair set something aside");
        // No origin to fetch from: stops before touching anything.
        File.WriteAllText(Path.Combine(repo, "bot.php"), "kept"); Directory.Move(origin, origin + ".offline");
        result = BotRepair.Run(bot, LocalHosting.RunCaptured, DateTime.UtcNow);
        Require(!result.Ok && File.ReadAllText(Path.Combine(repo, "bot.php")) == "kept" && result.Summary.Contains("Nothing was deleted"), "offline repair touched the checkout");

        Require(BotRepair.Fixes("Default branch guard refused: local source edits retained") && BotRepair.Fixes("local edits retained (update needs a clean checkout): M composer.lock")
            && !BotRepair.Fixes("Profile unreadable"), "Fixes() classification");
        Console.WriteLine("PASS bot repair: " + assertions + " assertions; detached/dirty/untracked/hidden lock/local commit repaired without loss, upstream lock change, offline stop.");
        return assertions;
    }
}
