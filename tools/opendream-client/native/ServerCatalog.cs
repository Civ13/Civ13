using System.Diagnostics;

namespace Civ13.Launcher;

public static class ServerCatalog {
    public const string OfficialHost = "civ13.com";
    public const string OfficialMenuKey = "2";
    public const string ValZarGamingMenuKey = "3";
    public const string OpenDreamMenuKey = "9";
    public const string DirectoryPath = "/.well-known/civ13/servers.json";
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
    public static Uri DirectoryUrl(string provider) => new("https://" + OfficialHost + DirectoryPath + "?provider=" + Host(provider));
    public static int OpenDreamPort(string mode, string? operatorPort) {
        if (operatorPort == null)
            throw new IOException("OpenDream game service is not configured. An operator must supply --server-port for a verified OpenDream service.");
        return Connection.Port(mode, operatorPort);
    }

    public static async Task<PublicEndpoint> NativeEndpoint(GameServer server,
        Func<string, Task<System.Net.IPAddress[]>>? resolver = null, DateTimeOffset? now = null,
        Func<System.Net.IPAddress, int, CancellationToken, Task<ReadOnlyMemory<byte>>>? statusProbe = null,
        Func<DateTimeOffset>? clock = null, TimeSpan? timeout = null, CancellationToken cancellationToken = default) {
        return await ByondStatus.Select(server, resolver, statusProbe, clock ?? (() => now ?? DateTimeOffset.UtcNow), timeout, cancellationToken);
    }

    public static ProcessStartInfo NativeStart(GameServer server, string bin, PublicEndpoint endpoint,
        ByondRequirement requirement, Func<string, bool> matchesClient, DateTimeOffset? now = null) {
        server.Validate(now ?? DateTimeOffset.UtcNow);
        var address = endpoint.Validate(server.Host);
        requirement.Validate();
        if (!matchesClient(bin)) throw new IOException("Required BYOND " + requirement.Version + " client unavailable.");
        var start = new ProcessStartInfo(Path.Combine(bin, "dreamseeker.exe")) {
            UseShellExecute = false, WorkingDirectory = bin
        };
        start.ArgumentList.Add($"byond://{address}:{server.Port}");
        return start;
    }
}
