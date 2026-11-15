using System.Diagnostics;

namespace Civ13.Launcher;

// "Repair and update" for the Civilizationbot tab (and Civ13.exe --bot repair). Whatever the bot's
// default-branch check refused for (local edits, a modified composer.lock, another branch, a detached
// HEAD, local commits), this brings the bot checkout back to a clean main equal to origin/main using
// git directly, so it also works on a bot checkout too old to know how to repair itself. Nothing is
// deleted: local edits and untracked files go to a labelled stash, local commits stay on a
// civilizationbot-backup-* branch, and a local composer.lock is put back when upstream did not change it.
public static class BotRepair {
    public sealed record Result(bool Ok, string Summary, string? Stash, string? BackupBranch, bool RestoredLock, bool UpstreamLockChanged);

    public static ProcessStartInfo Git(HostBot bot, params string[] arguments) {
        var step = new ProcessStartInfo("git") { UseShellExecute = false, CreateNoWindow = true, WorkingDirectory = bot.Root,
            RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true };
        step.Environment["GIT_TERMINAL_PROMPT"] = "0";
        step.Environment["GCM_INTERACTIVE"] = "Never";
        foreach (var argument in new[] { "-C", bot.Root }.Concat(arguments)) step.ArgumentList.Add(argument);
        return step;
    }

    // run executes one git command and returns (exit code, combined output); tests pass a fake.
    public static Result Run(HostBot bot, Func<ProcessStartInfo, (int Exit, string Output)> run, DateTime now) {
        var stamp = now.ToUniversalTime().ToString("yyyyMMdd-HHmmss");
        (int Exit, string Output) Git(params string[] arguments) {
            var (exit, output) = run(BotRepair.Git(bot, arguments));
            return (exit, output.Trim());
        }
        Result Fail(string why) => new(false, "Repair stopped: " + why + ". Nothing was deleted.", null, null, false, false);

        // A merge or rebase left half way blocks every other step; these are no-ops otherwise.
        foreach (var operation in new[] { "merge", "rebase", "cherry-pick" }) Git(operation, "--abort");
        Git("config", "core.sparseCheckout", "false");
        var (listExit, listing) = Git("ls-files", "-v");
        if (listExit == 0)
            foreach (var line in listing.Split('\n').Select(text => text.TrimEnd('\r'))) {
                if (line.Length < 3 || line[1] != ' ') continue;
                var flag = line[0];
                var path = line[2..];
                if (char.IsLower(flag)) Git("update-index", "--no-assume-unchanged", "--", path);
                if (flag is 'S' or 's') Git("update-index", "--no-skip-worktree", "--", path);
            }

        var (fetchExit, fetchOutput) = Git("fetch", "--no-tags", "origin", "+refs/heads/main:refs/remotes/origin/main");
        if (fetchExit != 0) return Fail("could not fetch origin main (" + LastLine(fetchOutput) + ")");
        var (targetExit, target) = Git("rev-parse", "--verify", "refs/remotes/origin/main^{commit}");
        if (targetExit != 0) return Fail("origin main not found");
        var (_, oldHead) = Git("rev-parse", "--verify", "HEAD^{commit}");
        var (_, oldLock) = Git("rev-parse", "--verify", "HEAD:composer.lock");
        var (_, newLock) = Git("rev-parse", "--verify", target + ":composer.lock");

        string? stash = null;
        var (_, dirty) = Git("status", "--porcelain=v1", "--untracked-files=all");
        if (dirty.Length > 0) {
            stash = "Civ13 launcher repair " + stamp;
            var (stashExit, stashOutput) = Git("stash", "push", "--include-untracked", "-m", stash);
            if (stashExit != 0) return Fail("could not set local edits aside (" + LastLine(stashOutput) + ")");
        }

        var backups = new List<string>();
        var (_, localMain) = Git("rev-parse", "--verify", "refs/heads/main^{commit}");
        foreach (var tip in new[] { oldHead, localMain }.Where(IsSha).Distinct()) {
            if (Git("merge-base", "--is-ancestor", tip, target).Exit != 1) continue;
            var name = "civilizationbot-backup-" + stamp + (backups.Count > 0 ? "-" + (backups.Count + 1) : "");
            if (Git("branch", name, tip).Exit != 0) return Fail("could not keep local commits on a backup branch");
            backups.Add(name);
        }

        var (checkoutExit, checkoutOutput) = Git("checkout", "-f", "-B", "main", target);
        if (checkoutExit != 0) return Fail("could not switch to main (" + LastLine(checkoutOutput) + ")");
        Git("branch", "--set-upstream-to=origin/main", "main");
        Git("symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main");

        // A local dependency lock (for example a path override) comes back unless upstream changed it.
        var restored = false;
        var upstreamLockChanged = IsSha(oldLock) && IsSha(newLock) && oldLock != newLock;
        if (stash != null && !upstreamLockChanged && Git("diff", "--name-only", "stash@{0}^1", "stash@{0}").Output.Split('\n').Any(name => name.Trim() == "composer.lock")) {
            restored = Git("checkout", "stash@{0}", "--", "composer.lock").Exit == 0;
            if (restored) Git("reset", "-q", "--", "composer.lock");
        }

        var summary = "Civilizationbot source repaired: main is now " + Short(target) + ".";
        if (stash != null) summary += $" Local edits were set aside in the git stash \"{stash}\"" + (restored ? " (composer.lock was put back)." : ".");
        if (backups.Count > 0) summary += " Local commits are kept on " + string.Join(", ", backups) + ".";
        if (upstreamLockChanged) summary += " composer.lock changed upstream; run composer install in the bot folder if the bot reports missing classes.";
        return new Result(true, summary, stash, backups.Count > 0 ? string.Join(", ", backups) : null, restored, upstreamLockChanged);
    }

    // The refusals Repair and update fixes: the bot's default-branch check and its update refusals.
    public static bool Fixes(string failure) => failure.Contains("Default branch guard refused") || failure.Contains("local edits retained")
        || failure.Contains("local source edits") || failure.Contains("main behind");

    private static bool IsSha(string text) => text.Length == 40 && text.All(Uri.IsHexDigit);
    private static string Short(string sha) => sha.Length >= 7 ? sha[..7] : sha;
    private static string LastLine(string text) => text.Split('\n').Select(line => line.Trim()).LastOrDefault(line => line.Length > 0) ?? "no output";
}
