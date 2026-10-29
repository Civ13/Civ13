using System.Buffers.Binary;
using System.Globalization;
using System.Text;

namespace Civ13.Launcher.Social;

// Explicit host configuration only. There is no default application or discovery.
public sealed class CompanionProfile {
    public GameTarget Target { get; }
    public string ApplicationId { get; }
    public CompanionProfile(GameTarget target, string applicationId) {
        ArgumentNullException.ThrowIfNull(target);
        ArgumentNullException.ThrowIfNull(applicationId);
        target.Validate();
        if (applicationId.Length is < 1 or > 20 ||
            applicationId[0] == '0' || applicationId.Any(c => c is < '0' or > '9') ||
            !ulong.TryParse(applicationId, NumberStyles.None, CultureInfo.InvariantCulture, out var value) || value == 0)
            throw new ArgumentException("Invalid explicit companion profile.");
        Target = target; ApplicationId = applicationId;
    }
}

// Future implementation uses private inherited pipes. No listener/process/stream
// implementation is supplied. Calls must return promptly, without blocking/retry.
public interface ICompanionPresenceChannel : IDisposable {
    bool IsOpen { get; }
    // Atomic frame admission: false admits zero bytes. No unbounded write queue.
    bool TryWrite(ReadOnlySpan<byte> frame);
    // 0 means no bytes presently available; IsOpen=false means EOF/failure.
    int Read(Span<byte> destination);
}

internal enum CompanionOp : byte { Hello = 1, Ready, Publish, Result, Clear, Pulse, Stop }
internal sealed record CompanionFrame(CompanionOp Op, ulong Id, byte[] Payload);
internal static class CompanionWire {
    internal const int HeaderBytes = 20, MaxPayload = 256, MaxFrame = HeaderBytes + MaxPayload;
    private static readonly UTF8Encoding Utf8 = new(false, true);
    internal static byte[] Encode(CompanionOp op, ulong id, ReadOnlySpan<byte> payload) {
        if (!Enum.IsDefined(op) || id == 0 || payload.Length > MaxPayload) throw new FormatException("Invalid companion frame.");
        var bytes = new byte[HeaderBytes + payload.Length];
        "C13S"u8.CopyTo(bytes); bytes[4] = 1; bytes[5] = (byte)op;
        BinaryPrimitives.WriteUInt64LittleEndian(bytes.AsSpan(8), id);
        BinaryPrimitives.WriteUInt32LittleEndian(bytes.AsSpan(16), (uint)payload.Length);
        payload.CopyTo(bytes.AsSpan(HeaderBytes)); return bytes;
    }
    internal static (CompanionOp Op, ulong Id, int PayloadBytes) Header(ReadOnlySpan<byte> bytes) {
        if (bytes.Length < HeaderBytes || !bytes[..4].SequenceEqual("C13S"u8) || bytes[4] != 1 ||
            bytes[6] != 0 || bytes[7] != 0 || !Enum.IsDefined((CompanionOp)bytes[5]))
            throw new FormatException("Unsupported companion header.");
        var id = BinaryPrimitives.ReadUInt64LittleEndian(bytes[8..]);
        var length = BinaryPrimitives.ReadUInt32LittleEndian(bytes[16..]);
        if (id == 0 || length > MaxPayload) throw new FormatException("Invalid companion frame bounds.");
        return ((CompanionOp)bytes[5], id, (int)length);
    }
    internal static byte[] Profile(CompanionProfile profile) {
        var provider = Encoding.ASCII.GetBytes(profile.Target.Provider);
        var app = Encoding.ASCII.GetBytes(profile.ApplicationId);
        var result = new byte[4 + provider.Length + app.Length];
        BinaryPrimitives.WriteUInt16LittleEndian(result, checked((ushort)profile.Target.Port));
        result[2] = checked((byte)provider.Length); result[3] = checked((byte)app.Length);
        provider.CopyTo(result, 4); app.CopyTo(result, 4 + provider.Length); return result;
    }
    internal static byte[] Presence(LauncherPresence presence) {
        static void Check(string text) {
            if (string.IsNullOrEmpty(text) || text.Any(char.IsControl)) throw new FormatException("Invalid companion text.");
        }
        Check(presence.Details); Check(presence.State);
        var details = Utf8.GetBytes(presence.Details); var state = Utf8.GetBytes(presence.State);
        if (details.Length > 96 || state.Length > 96) throw new FormatException("Companion text exceeds bounds.");
        var result = new byte[2 + details.Length + state.Length];
        result[0] = (byte)details.Length; result[1] = (byte)state.Length;
        details.CopyTo(result, 2); state.CopyTo(result, 2 + details.Length); return result;
    }
}

// At most one bounded partial frame, including when a peer fragments every byte.
internal sealed class CompanionFrameReader {
    private readonly byte[] buffer = new byte[CompanionWire.MaxFrame];
    private int used, needed = CompanionWire.HeaderBytes;
    internal bool Read(ICompanionPresenceChannel channel, out CompanionFrame? frame) {
        frame = null;
        var read = channel.Read(buffer.AsSpan(used, needed - used));
        if (read < 0 || read > needed - used) throw new IOException("Invalid companion read count.");
        used += read;
        if (used < needed) return false;
        var header = CompanionWire.Header(buffer);
        needed = CompanionWire.HeaderBytes + header.PayloadBytes;
        if (used < needed) return false;
        frame = new(header.Op, header.Id, buffer.AsSpan(CompanionWire.HeaderBytes, header.PayloadBytes).ToArray());
        used = 0; needed = CompanionWire.HeaderBytes; return true;
    }
}
