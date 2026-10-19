using System.Globalization;

namespace Civ13.Launcher;

public static class ServerBrowser {
    public static void WriteServers(TextWriter output, string provider, ServerDirectory directory) {
        output.WriteLine($"{provider} - live directory checked {directory.GeneratedAt:HH:mm:ss} UTC");
        output.WriteLine($"Snapshot expires {directory.ExpiresAt:HH:mm:ss} UTC. Server status is checked again before joining.");
        if (directory.Servers.Count == 0) output.WriteLine("No verified online servers are available.");
        for (var index = 0; index < directory.Servers.Count; index++) {
            var server = directory.Servers[index];
            var elapsed = TimeSpan.FromSeconds(server.RoundDurationSeconds);
            var duration = $"{(int)elapsed.TotalHours}:{elapsed.Minutes:00}:{elapsed.Seconds:00}";
            output.WriteLine($"{index + 1}: {server.Name} | Players: {server.Players} | {server.Engine}");
            output.WriteLine($"   Map: {server.Map} | Mode: {server.Mode}" + (server.Epoch.Length == 0 ? "" : " | Epoch: " + server.Epoch));
            output.WriteLine($"   Round: {(server.RoundId.Length == 0 ? "unavailable" : server.RoundId)} | Elapsed: {duration}" +
                (server.RoundState.Length == 0 ? "" : " | State: " + server.RoundState));
            output.WriteLine($"   {server.Host}:{server.Port} | Checked: {server.CheckedAt:HH:mm:ss} UTC");
        }
        output.WriteLine("R: Refresh   B: Back");
    }

    public static async Task Run(string provider, IServerDirectoryTransport transport, TextReader input,
        TextWriter output, Func<GameServer, Task> launch, Func<DateTimeOffset>? clock = null) {
        clock ??= () => DateTimeOffset.UtcNow;
        async Task<ServerDirectory> Fetch() => ServerDirectory.Read(provider, await transport.Fetch(provider), clock());
        while (true) {
            ServerDirectory? directory = null;
            try { directory = await Fetch(); }
            catch (IOException) {
                output.WriteLine($"{provider} live directory is unavailable. No servers can be verified. Try Refresh shortly.");
                output.WriteLine("R: Refresh   B: Back");
            }
            if (directory != null) WriteServers(output, provider, directory);
            while (true) {
                output.Write("Choose a server, R or B: ");
                var choice = input.ReadLine()?.Trim();
                if (choice == null || choice.Equals("B", StringComparison.OrdinalIgnoreCase)) return;
                if (choice.Equals("R", StringComparison.OrdinalIgnoreCase)) break;
                if (directory == null || !int.TryParse(choice, NumberStyles.None, CultureInfo.InvariantCulture, out var number) ||
                    number < 1 || number > directory.Servers.Count) {
                    output.WriteLine("Choose one of the listed online servers, R or B.");
                    continue;
                }
                var selected = directory.Servers[number - 1];
                try {
                    // Fetch again before connecting, including after a long pause at the menu.
                    var fresh = await Fetch();
                    var current = fresh.Servers.SingleOrDefault(server => server.Id == selected.Id);
                    if (current == null || !current.SameTarget(selected))
                        throw new IOException("The selected server went offline or changed endpoint. Refresh and choose again.");
                    current.Validate(clock());
                    await launch(current);
                    return;
                } catch (IOException) {
                    output.WriteLine("The selected server could not be verified or started. Refresh and choose again.");
                    break;
                }
            }
        }
    }
}
