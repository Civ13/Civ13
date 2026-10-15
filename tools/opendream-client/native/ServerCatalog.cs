using System.Diagnostics;

namespace Civ13.Launcher;

public sealed record GameServer(string Name, string Mode, int Port, string Engine);

public static class ServerCatalog {
    public static int OpenDreamPort(string mode, string? operatorPort) {
        if (operatorPort == null)
            throw new IOException("OpenDream game service is not configured. An operator must supply --server-port for a verified OpenDream service.");
        return Connection.Port(mode, operatorPort);
    }

    public static GameServer Select(string server, string mode) {
        if (server != "ValZarGaming" || mode is not ("Nomads" or "TDM"))
            throw new IOException("Unknown game server or mode.");
        return new GameServer(server, mode, mode == "Nomads" ? 1714 : 1715, "BYOND");
    }

    public static ProcessStartInfo NativeStart(GameServer server, string bin, string endpoint,
        ByondRequirement requirement, Func<string, bool> matchesClient) {
        if (server != Select(server.Name, server.Mode) || server.Engine != "BYOND")
            throw new IOException("Server engine or port differs from the catalog.");
        if (endpoint != Connection.ApprovedEndpoint || endpoint == Connection.ExcludedEndpoint)
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
