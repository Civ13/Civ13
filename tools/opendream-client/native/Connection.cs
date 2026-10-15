using System.Diagnostics;
using System.Net;
using System.Net.Sockets;

namespace Civ13.Launcher;

public static class Connection {
    public const string Host = "valzargaming.com";
    public const string ApprovedEndpoint = "72.218.249.221";
    public const string ExcludedEndpoint = "192.64.119.81";
    public static async Task<string[]> Resolve(Func<string, Task<IPAddress[]>>? resolver = null) {
        try {
            var addresses = await (resolver ?? (name => Dns.GetHostAddressesAsync(name)))(Host).WaitAsync(TimeSpan.FromSeconds(10));
            var result = addresses.Where(address => address.AddressFamily is AddressFamily.InterNetwork or AddressFamily.InterNetworkV6)
                .Select(address => address.ToString()).Distinct(StringComparer.Ordinal).Order(StringComparer.Ordinal).ToArray();
            if (result.Length == 0) throw new IOException("No IP addresses returned.");
            var eligible = result.Where(address => address != ExcludedEndpoint).ToArray();
            if (eligible.Length != 1 || eligible[0] != ApprovedEndpoint)
                throw new IOException("DNS changed to an unverified game endpoint. Connection blocked pending endpoint verification.");
            return eligible;
        } catch (Exception e) when (e is SocketException or IOException or TimeoutException) {
            throw new IOException("Could not verify " + Host + ": " + e.Message + " No game was started. Try Play again after the endpoint is verified.", e);
        }
    }
    public static int Port(string mode, string? explicitPort = null) {
        if (mode is not ("Nomads" or "TDM")) throw new ArgumentException("Unknown game mode.");
        if (explicitPort == null) return mode == "Nomads" ? 1715 : 1714;
        if (!int.TryParse(explicitPort, out var port) || port is < 1 or > 65535)
            throw new IOException("Server port must be between 1 and 65535.");
        return port;
    }
    public static ProcessStartInfo Start(string destination, string mode, string endpoint, string? explicitPort = null) {
        if (mode is not ("Nomads" or "TDM")) throw new ArgumentException("Unknown game mode.");
        if (endpoint != ApprovedEndpoint || endpoint == ExcludedEndpoint) throw new IOException("Unverified game endpoint rejected.");
        var port = Port(mode, explicitPort);
        var runtime = Path.Combine(destination, "dotnet", "dotnet.exe");
        var client = Path.Combine(destination, "RobustToolbox", "bin", "ClientAuth", "Robust.Client.dll");
        var content = Path.Combine(destination, "Content.Client.zip");
        foreach (var file in new[] { runtime, client, content })
            if (!File.Exists(file)) throw new IOException("Client connection file is missing: " + file);
        var start = new ProcessStartInfo(runtime) {
            UseShellExecute = false, WorkingDirectory = Path.GetDirectoryName(client)!
        };
        start.Environment["DOTNET_ROOT"] = Path.Combine(destination, "dotnet");
        start.Environment["ROBUST_MODULE_ROBUST_CLIENT_WEBVIEW"] = Path.Combine(destination, "webview");
        foreach (var arg in new[] { client, "--self-contained", "--mount-zip", content, "--connect", "--connect-address", $"udp://{endpoint}:{port}", "+launchauth" }) start.ArgumentList.Add(arg);
        return start;
    }
}
