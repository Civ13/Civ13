using System.Diagnostics;

namespace Civ13.Launcher;

public static class ServerCatalog {
    public const string OfficialHost = "civ13.com";
    public const string OfficialMenuKey = "2";
    public const string ValZarGamingMenuKey = "3";
    public const string OpenDreamMenuKey = "9";
    public const string MainMenu = "\nCiv13 - 1: BYOND sign in   " + OfficialMenuKey +
        ": Civ13.com servers   " + ValZarGamingMenuKey + ": ValZarGaming.com servers   4: Exit";
    public const string OpenDreamMenu = OpenDreamMenuKey + ": OpenDream (experimental)";
    public static string? MenuServer(string? choice) => choice switch {
        OfficialMenuKey => "Civ13.com",
        ValZarGamingMenuKey => "ValZarGaming",
        _ => null
    };
    public static string Host(string provider) => provider switch {
        "Civ13.com" => OfficialHost,
        "ValZarGaming" => Connection.Host,
        _ => throw new IOException("Unknown server provider.")
    };
    public static IReadOnlyList<GameTarget> Candidates(string provider) {
        _ = Host(provider); // Reject unknown providers before constructing targets.
        // Explicit pre-existing native game ports. No ranges or arbitrary overrides.
        return Array.AsReadOnly(new[] { new GameTarget(provider, 1714), new GameTarget(provider, 1715) });
    }
    public static int OpenDreamPort(string mode, string? operatorPort) {
        if (operatorPort == null)
            throw new IOException("OpenDream game service is not configured. An operator must supply --server-port for a verified OpenDream service.");
        return Connection.Port(mode, operatorPort);
    }

    public static async Task<VerifiedGameServer> NativeEndpoint(GameServer server,
        Func<string, Task<System.Net.IPAddress[]>>? resolver = null, DateTimeOffset? now = null,
        StatusProbe? statusProbe = null,
        Func<DateTimeOffset>? clock = null, TimeSpan? timeout = null, CancellationToken cancellationToken = default) {
        var currentClock = clock ?? (() => now ?? DateTimeOffset.UtcNow);
        // Menu status may be old after a pause; the direct recheck is authoritative.
        server.Target.Validate();
        return await ByondStatus.Query(server.Target, resolver, statusProbe, currentClock, timeout, cancellationToken, server);
    }

    public static ProcessStartInfo NativeStart(VerifiedGameServer verified, string bin,
        ByondRequirement requirement, Func<string, bool> matchesClient, DateTimeOffset? now = null) {
        var server = verified.Status;
        server.Validate(now ?? DateTimeOffset.UtcNow);
        var address = verified.Endpoint.Validate(server.Host);
        requirement.Validate();
        if (!matchesClient(bin)) throw new IOException("Required BYOND " + requirement.Version + " client unavailable.");
        var start = new ProcessStartInfo(Path.Combine(bin, "dreamseeker.exe")) {
            UseShellExecute = false, WorkingDirectory = bin
        };
        start.ArgumentList.Add($"byond://{address}:{server.Port}");
        return start;
    }
}
