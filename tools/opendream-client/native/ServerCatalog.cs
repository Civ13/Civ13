using System.Diagnostics;

namespace Civ13.Launcher;

public static class ServerCatalog {
    public const string OfficialHost = "civ13.com";
    public const string OfficialMenuKey = "2";
    public const string ValZarGamingMenuKey = "3";
    public const string MainMenu = "\nCiv13 - 1: BYOND sign in   " + OfficialMenuKey +
        ": Civ13.com servers   " + ValZarGamingMenuKey + ": ValZarGaming.com servers   4: Exit";
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
    // The port of a provider's gate world, for hosts that route their other worlds
    // through it. ValZarGaming's mainland (Gaia) is the gate on 1714; Rail Yard and
    // the other regions are joined through it, never directly.
    public static int? GatePort(string provider) => provider == "ValZarGaming" ? 1714 : null;

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
        ByondRequirement requirement, Func<string, bool> matchesClient, DateTimeOffset? now = null, string? ticket = null,
        string? voiceKey = null) {
        var server = verified.Status;
        server.Target.Validate();
        requirement.Validate();
        if (!matchesClient(bin)) throw new IOException("Required BYOND " + requirement.Version + " client unavailable.");
        // Client-file verification can block. Sample freshness AFTER it, immediately
        // before constructing the command, without renewing either original clock.
        var current = now ?? DateTimeOffset.UtcNow;
        server.Validate(current);
        if (verified.Recent is { } recent && !recent.IsFresh(current))
            throw new IOException("Recent game status expired. Refresh when request spacing allows.");
        var address = verified.Endpoint.Validate(server.Host);
        var start = new ProcessStartInfo(Path.Combine(bin, "dreamseeker.exe")) {
            UseShellExecute = false, WorkingDirectory = bin
        };
        // An optional Discord sign-in ticket: single use, two minutes, never the Discord token.
        if (ticket != null && !DiscordSignIn.ValidTicket(ticket)) throw new IOException("Discord sign-in ticket is malformed.");
        // An optional launcher voice key: random per join, shared only with that world.
        if (voiceKey != null && !VoiceChat.ValidKey(voiceKey)) throw new IOException("Voice key is malformed.");
        var query = new List<string>();
        if (ticket != null) query.Add("civ13_ticket=" + ticket);
        if (voiceKey != null) query.Add("civ13_voice=" + voiceKey);
        start.ArgumentList.Add($"byond://{address}:{server.Port}" + (query.Count == 0 ? "" : "?" + string.Join("&", query)));
        return start;
    }

    // The voice app for a game just started: same verified address and port,
    // watching that Dream Seeker. The voice key goes on stdin, never argv.
    public static ProcessStartInfo VoiceStart(VerifiedGameServer verified, string voiceExe, int gamePid) {
        var server = verified.Status;
        server.Target.Validate();
        var address = verified.Endpoint.Validate(server.Host);
        var start = new ProcessStartInfo(voiceExe) {
            UseShellExecute = false, CreateNoWindow = true, RedirectStandardInput = true,
            WorkingDirectory = Path.GetDirectoryName(voiceExe)!
        };
        foreach (var arg in new[] { "--host", address.ToString(), "--port", server.Port.ToString(System.Globalization.CultureInfo.InvariantCulture),
            "--watch-pid", gamePid.ToString(System.Globalization.CultureInfo.InvariantCulture) })
            start.ArgumentList.Add(arg);
        return start;
    }
}
