using System.Diagnostics;

namespace Civ13.Launcher;

public sealed record GameServer(string Name, string Mode, int Port, string Engine);

public static class ServerCatalog {
    public const string OfficialHost = "civ13.com";
    public static int OpenDreamPort(string mode, string? operatorPort) {
        if (operatorPort == null)
            throw new IOException("OpenDream game service is not configured. An operator must supply --server-port for a verified OpenDream service.");
        return Connection.Port(mode, operatorPort);
    }

    public static GameServer Select(string server, string mode) {
        if (server is not ("ValZarGaming" or "Civ13.com") || mode is not ("Nomads" or "TDM"))
            throw new IOException("Unknown game server or mode.");
        // The official site publishes the opposite port mapping to ValZarGaming.
        var port = server == "Civ13.com"
            ? (mode == "Nomads" ? 1715 : 1714)
            : (mode == "Nomads" ? 1714 : 1715);
        return new GameServer(server, mode, port, "BYOND");
    }

    public static async Task<string> NativeEndpoint(GameServer server,
        Func<string, Task<System.Net.IPAddress[]>>? resolver = null) {
        Validate(server);
        // Use the published official hostname; do not borrow ValZarGaming's IP pin.
        return server.Name == "Civ13.com" ? OfficialHost : (await Connection.Resolve(resolver)).Single();
    }

    private static void Validate(GameServer server) {
        if (server != Select(server.Name, server.Mode) || server.Engine != "BYOND")
            throw new IOException("Server engine or port differs from the catalog.");
    }

    public static ProcessStartInfo NativeStart(GameServer server, string bin, string endpoint,
        ByondRequirement requirement, Func<string, bool> matchesClient) {
        Validate(server);
        var expectedEndpoint = server.Name == "Civ13.com" ? OfficialHost : Connection.ApprovedEndpoint;
        if (endpoint != expectedEndpoint)
            throw new IOException("Unverified game endpoint rejected.");
        requirement.Validate();
        if (!matchesClient(bin)) throw new IOException("Required BYOND " + requirement.Version + " client unavailable.");
        var start = new ProcessStartInfo(Path.Combine(bin, "dreamseeker.exe")) {
            UseShellExecute = false, WorkingDirectory = bin
        };
        start.ArgumentList.Add($"byond://{endpoint}:{server.Port}");
        return start;
    }
}
