using System.Globalization;

namespace Civ13.Launcher;

public static class ServerBrowser {
    public static void WriteServers(TextWriter output, string provider, ServerSnapshot snapshot) {
        output.WriteLine($"{provider} - direct BYOND status. Checked again before joining.");
        if (snapshot.PacingPaused) output.WriteLine("Public checks paused: shared request timing could not be verified. No automatic retry; local timing state needs review.");
        foreach (var deferred in snapshot.Deferred ?? [])
            output.WriteLine($"{deferred.Target.Name}: request spacing active; try Refresh in {deferred.Seconds} seconds. Requests are deferred.");
        if (snapshot.Unverified > 0) output.WriteLine($"{snapshot.Unverified} configured endpoint(s) unreachable or not returning valid BYOND status.");
        if (snapshot.Servers.Count == 0) output.WriteLine("No verified online servers are available.");
        for (var index = 0; index < snapshot.Servers.Count; index++) {
            var server = snapshot.Servers[index];
            var duration = "unavailable";
            if (server.RoundDurationSeconds is { } seconds) {
                var elapsed = TimeSpan.FromSeconds(seconds);
                duration = $"{(int)elapsed.TotalHours}:{elapsed.Minutes:00}:{elapsed.Seconds:00}";
            }
            output.WriteLine($"{index + 1}: {server.Name} | Players: {server.Players} | {server.Engine}");
            output.WriteLine($"   Map: {Display(server.Map)} | Mode: {Display(server.Mode)}" + (server.Epoch.Length == 0 ? "" : " | Epoch: " + server.Epoch));
            output.WriteLine($"   Round: {Display(server.RoundId)} | Elapsed: {duration}");
            output.WriteLine($"   {server.Host}:{server.Port} | Checked: {server.CheckedAt:HH:mm:ss} UTC");
        }
        output.WriteLine("R: Refresh   B: Back");
    }

    private static string Display(string value) => value.Length == 0 ? "unavailable" : value;
    public static async Task Run(string provider, IServerDiscovery discovery, TextReader input,
        TextWriter output, Func<VerifiedGameServer, Task> launch) {
        while (true) {
            ServerSnapshot? snapshot = null;
            try { snapshot = await discovery.Fetch(provider); }
            catch (IOException) {
                output.WriteLine($"{provider} status checks failed. No servers can be verified. Try Refresh shortly.");
                output.WriteLine("R: Refresh   B: Back");
            }
            if (snapshot != null) WriteServers(output, provider, snapshot);
            GameServer? pending = null;
            while (true) {
                output.Write(pending == null ? "Choose a server, R or B: " : "J: Recheck selected server when ready   R: Refresh   B: Cancel/Back: ");
                var choice = input.ReadLine()?.Trim();
                if (choice == null || choice.Equals("B", StringComparison.OrdinalIgnoreCase)) return;
                if (choice.Equals("R", StringComparison.OrdinalIgnoreCase)) break;
                GameServer selected;
                if (pending != null && choice.Equals("J", StringComparison.OrdinalIgnoreCase)) selected = pending;
                else {
                    if (snapshot == null || !int.TryParse(choice, NumberStyles.None, CultureInfo.InvariantCulture, out var number) ||
                        number < 1 || number > snapshot.Servers.Count) {
                        output.WriteLine("Choose one of the listed online servers, R or B.");
                        continue;
                    }
                    selected = snapshot.Servers[number - 1];
                }
                try {
                    var verified = await discovery.Recheck(selected);
                    await launch(verified);
                    return;
                } catch (TopicWaitException wait) {
                    pending = selected;
                    output.WriteLine($"Wait {wait.Seconds} seconds before rechecking {selected.Name}. Press J when ready, or B to cancel.");
                    output.WriteLine("No automatic check will run. Wall-clock spacing cannot prove server game time advanced or clear a ban.");
                } catch (TopicPacingException) {
                    pending = null; snapshot = null;
                    output.WriteLine("Public checks paused: shared request timing could not be verified. Local timing state needs review. B: Back");
                } catch (IOException) {
                    output.WriteLine("The selected server could not be verified or started. Refresh and choose again.");
                    // Do not turn a failed recheck into another immediate status sweep.
                    // Some servers rate-limit Topic queries; only explicit Refresh probes again.
                    snapshot = null;
                    pending = null;
                    output.WriteLine("No automatic retry. R: Refresh   B: Back");
                }
            }
        }
    }
}
