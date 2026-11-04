using System.Diagnostics;
using System.Net;
using System.Net.Sockets;

namespace Civ13.Launcher;

// An immutable DNS result for one approved hostname, never a game-status-supplied IP.
public sealed class PublicEndpoint {
    public string Host { get; }
    public string Address { get; }
    private readonly long checkedAt;
    private readonly Func<long> monotonicClock;
    internal PublicEndpoint(string host, IPAddress address, Func<long> monotonicClock) {
        this.monotonicClock = monotonicClock;
        checkedAt = monotonicClock();
        Host = host;
        Address = address.ToString();
    }
    internal string Validate(string expectedHost) {
        if (Host != expectedHost || !Connection.IsApprovedHost(Host) ||
            !IPAddress.TryParse(Address, out var address) || !Connection.IsPublicIPv4(address) ||
            monotonicClock() - checkedAt is < 0 or > 15000)
            throw new IOException("Game endpoint verification expired or does not match the approved hostname. Try joining again.");
        return Address;
    }
}

public static class Connection {
    public const string Host = "valzargaming.com";
    public static bool IsApprovedHost(string host) => host is "civ13.com" or Host;
    public static Task<PublicEndpoint> Resolve(Func<string, Task<IPAddress[]>>? resolver = null) => ResolveHost(Host, resolver);
    public static async Task<PublicEndpoint> ResolveHost(string host, Func<string, Task<IPAddress[]>>? resolver = null, Func<long>? monotonicClock = null) {
        var addresses = await ResolveAddresses(host, resolver);
        return new PublicEndpoint(host, addresses[0], monotonicClock ?? (() => Environment.TickCount64));
    }
    internal static async Task<IPAddress[]> ResolveAddresses(string host, Func<string, Task<IPAddress[]>>? resolver = null,
        CancellationToken cancellationToken = default) {
        if (!IsApprovedHost(host)) throw new IOException("Unapproved game hostname.");
        try {
            // This candidate uses IPv4 literals for verified BYOND dispatch.
            // Resolving A records explicitly avoids an unchecked second client-side lookup.
            var addresses = await (resolver ?? (name => Dns.GetHostAddressesAsync(name, AddressFamily.InterNetwork)))(host)
                .WaitAsync(TimeSpan.FromSeconds(10), cancellationToken);
            if (addresses.Length is 0 or > 32 || addresses.Any(address => !IsPublicIPv4(address)))
                throw new IOException("DNS must return only public IPv4 game addresses; private, loopback, reserved or unsupported answers are rejected.");
            return addresses.Select(address => address.ToString()).Distinct(StringComparer.Ordinal)
                .Order(StringComparer.Ordinal).Select(IPAddress.Parse).ToArray();
        } catch (Exception e) when (e is SocketException or IOException or TimeoutException) {
            throw new IOException("Could not verify the public game address for " + host + ". No game was started. Try joining again after DNS is available.", e);
        }
    }
    public static bool IsPublicIPv4(IPAddress address) {
        if (address.AddressFamily != AddressFamily.InterNetwork) return false;
        var bytes = address.GetAddressBytes();
        var a = bytes[0]; var b = bytes[1]; var c = bytes[2];
        // Conservative exclusion of IANA special-purpose ranges, plus multicast.
        // No production server IP is pinned here. See SERVER-DISCOVERY.md for sources.
        return !(a is 0 or 10 or 127 || a >= 224 ||
            (a == 100 && b is >= 64 and <= 127) || (a == 169 && b == 254) ||
            (a == 172 && b is >= 16 and <= 31) ||
            (a == 192 && ((b == 0 && c is 0 or 2) || (b == 31 && c == 196) ||
                (b == 52 && c == 193) || (b == 88 && c == 99) || b == 168 || (b == 175 && c == 48))) ||
            (a == 198 && (b is 18 or 19 || (b == 51 && c == 100))) ||
            (a == 203 && b == 0 && c == 113));
    }
}
