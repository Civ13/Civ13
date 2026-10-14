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
    public static ProcessStartInfo Start(string destination, string mode, string endpoint) {
        if (mode is not ("Nomads" or "TDM")) throw new ArgumentException("Unknown game mode.");
        if (endpoint != ApprovedEndpoint || endpoint == ExcludedEndpoint) throw new IOException("Unverified game endpoint rejected.");
        var script = Path.Combine(destination, "Connect.ps1");
        if (!File.Exists(script)) throw new IOException("Client connection script is missing.");
        var start = new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell", "v1.0", "powershell.exe")) {
            UseShellExecute = true, WorkingDirectory = destination
        };
        foreach (var arg in new[] { "-NoProfile", "-File", script, "-Mode", mode, "-ServerAddress", endpoint }) start.ArgumentList.Add(arg);
        return start;
    }
}
