using System.ComponentModel;
using System.Text;
using Civ13.ServerManagement;

namespace Civ13.Launcher.Management;

// The caller injects an operator-authorized source. Its implementation must
// reject an unconfigured stream before I/O. A stream ID is not a path, access
// grant, ownership receipt or permission to enumerate other sources.
public interface IRegisteredLogSource {
    IRegisteredLogSession Open(InstanceBinding binding, string streamId);
}
public interface IRegisteredLogSession : IDisposable {
    // Generation must change on replacement, truncation or rewriting existing
    // bytes, including truncate-and-regrow; append alone may retain it. A real
    // provider must establish that property independently, not infer it here.
    LogSourceStamp Capture();
    int Read(long offset, byte[] destination, int destinationOffset, int count);
}
public sealed record LogSourceStamp(InstanceBinding Binding, string StreamId, string Generation, long Length);
public enum RegisteredLogSelection { Admitted, RegistrationUnknown, NotRegistered, NotLocal }
// Observation is raw evidence. Render only a fresh LogProjection and use its
// NextCursor; the raw cursor may skip text withheld by the display budget.
public sealed record RegisteredLogResult(RegistrationViewStatus Registration, RegisteredLogSelection Selection, LogObservation? Observation);

// One explicitly selected page only. No concrete filesystem provider, watcher,
// path resolution, process query or implicit log-source registration is supplied.
public sealed class RegisteredLogReader(IRegisteredLogSource source, IProcessObservationClock clock,
    long maximumReadMilliseconds = 1000) {
    private const int MaximumReadCalls = 256;
    private readonly IRegisteredLogSource reader = source ?? throw new ArgumentNullException(nameof(source));
    private readonly IProcessObservationClock timer = clock ?? throw new ArgumentNullException(nameof(clock));
    private readonly long budget = maximumReadMilliseconds is > 0 and <= 5000 ? maximumReadMilliseconds :
        throw new ContractException("invalid-log-read-budget");

    public RegisteredLogResult Read(RegistrationSnapshot registration, string requestedRegistrationPath,
        string localHostId, LogRequest request, long maximumRegistrationAgeMilliseconds) {
        if (request is null) throw new ContractException("missing-log-request");
        request.Validate();
        var scope = timer.Scope; var start = timer.Milliseconds;
        var selection = Select(registration, requestedRegistrationPath, localHostId, request, scope, start, maximumRegistrationAgeMilliseconds);
        if (selection.Selection != RegisteredLogSelection.Admitted) return selection;
        RawPage page;
        try { page = ReadPage(request); }
        catch (UnauthorizedAccessException) { page = new(LogReadKind.Denied); }
        catch (System.Security.SecurityException) { page = new(LogReadKind.Denied); }
        catch (Win32Exception error) when (OperatingSystem.IsWindows() ? error.NativeErrorCode == 5 :
            OperatingSystem.IsLinux() && error.NativeErrorCode is 1 or 13) { page = new(LogReadKind.Denied); }
        catch (Win32Exception) { page = new(LogReadKind.Unavailable); }
        catch (IOException) { page = new(LogReadKind.Unavailable); }
        catch (InvalidOperationException) { page = new(LogReadKind.Unavailable); }
        catch (ArgumentException) { page = new(LogReadKind.Unavailable); }
        catch (NotSupportedException) { page = new(LogReadKind.Unavailable); }
        var end = timer.Milliseconds;
        if (scope != timer.Scope || end < start)
            return new(RegistrationViewStatus.ClockChanged, RegisteredLogSelection.RegistrationUnknown, null);
        selection = Select(registration, requestedRegistrationPath, localHostId, request, scope, end, maximumRegistrationAgeMilliseconds);
        if (selection.Selection != RegisteredLogSelection.Admitted) return selection;
        if (end - start > budget) page = new(LogReadKind.ReadTooSlow);
        return new(RegistrationViewStatus.Available, RegisteredLogSelection.Admitted,
            new(request, scope, start, end, page.Kind, page.Lines, page.HasEarlier, page.InputTruncated,
                page.HasMore, page.PendingFragment, page.NextCursor));
    }

    private static RegisteredLogResult Select(RegistrationSnapshot registration, string path, string localHostId,
        LogRequest request, string scope, long now, long maximumAge) {
        var batch = LocalManagementComposition.Compose(registration, [], path, localHostId, scope, now, maximumAge);
        if (batch.Status != RegistrationViewStatus.Available)
            return new(batch.Status, RegisteredLogSelection.RegistrationUnknown, null);
        if (request.Binding.HostId != localHostId)
            return new(batch.Status, RegisteredLogSelection.NotLocal, null);
        if (!batch.Entries.Any(entry => entry.Manifest.Binding == request.Binding))
            return new(batch.Status, RegisteredLogSelection.NotRegistered, null);
        return new(batch.Status, RegisteredLogSelection.Admitted, null);
    }

    private sealed record RawPage(LogReadKind Kind, IReadOnlyList<string>? Lines = null, bool HasEarlier = false,
        bool InputTruncated = false, bool HasMore = false, bool PendingFragment = false, LogCursor? NextCursor = null);

    private RawPage ReadPage(LogRequest request) {
        IRegisteredLogSession session;
        try { session = reader.Open(request.Binding, request.StreamId); }
        catch (FileNotFoundException) { return new(LogReadKind.Missing); }
        catch (DirectoryNotFoundException) { return new(LogReadKind.Missing); }
        if (session is null) return new(LogReadKind.Unavailable);
        using (session) {
            var before = session.Capture();
            if (!ValidStamp(before, request)) return new(LogReadKind.Invalid);
            var startOffset = request.Cursor?.Offset ?? 0;
            if (request.Cursor is not null && (request.Cursor.Generation != before.Generation || startOffset > before.Length))
                return new(LogReadKind.ResetRequired);
            var length = (int)Math.Min(request.MaximumBytes, before.Length - startOffset);
            var bytes = new byte[length]; var count = 0; var calls = 0;
            while (count < length) {
                if (++calls > MaximumReadCalls) return new(LogReadKind.Unavailable);
                var read = session.Read(startOffset + count, bytes, count, length - count);
                if (read <= 0 || read > length - count) return new(LogReadKind.Unavailable);
                count += read;
            }
            var after = session.Capture();
            if (!ValidStamp(after, request)) return new(LogReadKind.Unavailable);
            if (after.Generation != before.Generation || after.Length < before.Length)
                return new(request.Cursor is null ? LogReadKind.Unavailable : LogReadKind.ResetRequired);

            var lines = new List<string>(); var consumed = 0; var lineStart = 0; var clipped = false;
            try {
                for (var index = 0; index < bytes.Length && lines.Count < request.MaximumLines; index++) {
                    if (bytes[index] != (byte)'\n') continue;
                    var lineLength = index - lineStart;
                    if (lineLength > 0 && bytes[index - 1] == (byte)'\r') lineLength--;
                    var line = new UTF8Encoding(false, true).GetString(bytes, lineStart, lineLength);
                    if (line.Length > LogRequest.InputLineLimit) {
                        var cut = LogRequest.InputLineLimit;
                        if (char.IsHighSurrogate(line[cut - 1]) && char.IsLowSurrogate(line[cut])) cut--;
                        line = line[..cut]; clipped = true;
                    }
                    lines.Add(line); consumed = index + 1; lineStart = consumed;
                }
            } catch (DecoderFallbackException) { return new(LogReadKind.Invalid); }
            if (consumed == 0 && bytes.Length > 0 && length < before.Length - startOffset)
                return new(LogReadKind.LimitExceeded);
            var pending = consumed < bytes.Length && startOffset + bytes.Length == before.Length &&
                !bytes.AsSpan(consumed).Contains((byte)'\n');
            var cursor = new LogCursor(request.Binding, request.StreamId, before.Generation, startOffset + consumed);
            return new(LogReadKind.Available, lines.AsReadOnly(), startOffset > 0, clipped,
                cursor.Offset < after.Length, pending, cursor);
        }
    }
    private static bool ValidStamp(LogSourceStamp? stamp, LogRequest request) => stamp is not null &&
        stamp.Binding == request.Binding && stamp.StreamId == request.StreamId && stamp.Length >= 0 &&
        stamp.Generation is { Length: > 0 and <= 64 } &&
        stamp.Generation.All(c => c is >= 'a' and <= 'z' or >= 'A' and <= 'Z' or >= '0' and <= '9' or '_' or '-');
}
