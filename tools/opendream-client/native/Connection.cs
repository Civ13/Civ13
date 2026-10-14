using System.Diagnostics;
using System.Net;
using System.Net.Sockets;

namespace Civ13.Launcher;

public static class Connection {
    public const string Host = "valzargaming.com";
    public static async Task<string[]> Resolve(Func<string, Task<IPAddress[]>>? resolver = null) {
        try {
            var addresses = await (resolver ?? (name => Dns.GetHostAddressesAsync(name)))(Host).WaitAsync(TimeSpan.FromSeconds(10));
            var result = addresses.Where(address => address.AddressFamily is AddressFamily.InterNetwork or AddressFamily.InterNetworkV6)
                .Select(address => address.ToString()).Distinct(StringComparer.Ordinal).Order(StringComparer.Ordinal).ToArray();
            if (result.Length == 0) throw new IOException("No IP addresses returned.");
            return result;
        } catch (Exception e) when (e is SocketException or IOException or TimeoutException) {
            throw new IOException("Could not resolve " + Host + ". Check your connection and try Play again. No game was started.", e);
        }
    }
    public static ProcessStartInfo Start(string destination, string mode) {
        if (mode is not ("Nomads" or "TDM")) throw new ArgumentException("Unknown game mode.");
        var script = Path.Combine(destination, "Connect.ps1");
        if (!File.Exists(script)) throw new IOException("Client connection script is missing.");
        var start = new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell", "v1.0", "powershell.exe")) {
            UseShellExecute = true, WorkingDirectory = destination
        };
        foreach (var arg in new[] { "-NoProfile", "-File", script, "-Mode", mode, "-ServerAddress", Host }) start.ArgumentList.Add(arg);
        return start;
    }
}
