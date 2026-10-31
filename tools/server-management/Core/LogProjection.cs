using System.Buffers;
using System.Globalization;
using System.Text;

namespace Civ13.ServerManagement;

// The opaque stream ID names an operator-selected source; it is never a path or
// an ownership grant. The producer is responsible for obtaining a bounded page.
public sealed record LogRequest(InstanceBinding Binding, string StreamId, int MaximumLines, int MaximumCharacters) {
    public const int LineLimit = 64;
    public const int CharacterLimit = 8192;
    public const int InputLineLimit = 1024;
    public const int ByteLimit = 65536;
    public int MaximumBytes { get; init; } = 8192;
    public LogCursor? Cursor { get; init; }
    public void Validate() {
        if (Binding is null) throw new ContractException("missing-log-binding");
        Binding.Validate();
        InstanceBinding.Require(InstanceBinding.Token(StreamId), "invalid-log-stream");
        InstanceBinding.Require(MaximumLines is > 0 and <= LineLimit && MaximumCharacters is > 0 and <= CharacterLimit,
            "invalid-log-budget");
        InstanceBinding.Require(MaximumBytes is >= 4 and <= ByteLimit, "invalid-log-byte-budget");
        Cursor?.Validate();
        InstanceBinding.Require(Cursor is null || Cursor.Binding == Binding && Cursor.StreamId == StreamId, "log-cursor-scope");
    }
}

// Byte offset belongs to one source-supplied generation, never to another stream.
public sealed record LogCursor(InstanceBinding Binding, string StreamId, string Generation, long Offset) {
    public void Validate() {
        if (Binding is null) throw new ContractException("missing-log-cursor-binding");
        Binding.Validate();
        InstanceBinding.Require(InstanceBinding.Token(StreamId) && InstanceBinding.Token(Generation) && Offset >= 0, "invalid-log-cursor");
    }
}
// The producer must keep the supplied line collection stable during projection.
public enum LogReadKind { Available, Missing, Denied, Unavailable, ResetRequired, LimitExceeded, Invalid, ClockChanged, ReadTooSlow }
public sealed record LogObservation(LogRequest Request, string ClockScope, long SampleMilliseconds,
    long CompletedMilliseconds, LogReadKind Kind, IReadOnlyList<string>? Lines, bool HasEarlier,
    bool InputTruncated = false, bool HasMore = false, bool PendingFragment = false, LogCursor? NextCursor = null);
public enum LogViewStatus { Available, Missing, Denied, Unavailable, ScopeMismatch, ClockChanged, Stale, Invalid, ResetRequired, LimitExceeded, ReadTooSlow }
public sealed record LogView(LogViewStatus Status, IReadOnlyList<string> Lines, bool HasEarlier, bool Truncated,
    bool InputTruncated = false, bool HasMore = false, bool PendingFragment = false, LogCursor? NextCursor = null);

// Pure display projection. It reads no file or process, never follows a path,
// authenticates no source, and does not imply ownership, completeness or health.
public static class LogProjection {
    public static LogView Project(LogRequest request, LogObservation? observation, string clockScope,
        long nowMilliseconds, long maximumAgeMilliseconds) {
        if (request is null) throw new ContractException("missing-log-request");
        request.Validate();
        InstanceBinding.Require(InstanceBinding.Token(clockScope) && nowMilliseconds >= 0 && maximumAgeMilliseconds > 0,
            "invalid-log-clock");
        LogView Empty(LogViewStatus status) => new(status, Array.Empty<string>(), false, false);
        if (observation is null || observation.Request != request) return Empty(LogViewStatus.ScopeMismatch);
        if (observation.ClockScope != clockScope) return Empty(LogViewStatus.ClockChanged);
        if (observation.SampleMilliseconds < 0 || observation.CompletedMilliseconds < observation.SampleMilliseconds ||
            observation.CompletedMilliseconds > nowMilliseconds) return Empty(LogViewStatus.Invalid);
        if (nowMilliseconds - observation.SampleMilliseconds > maximumAgeMilliseconds) return Empty(LogViewStatus.Stale);
        if (!Enum.IsDefined(observation.Kind) || (observation.Kind == LogReadKind.Available) != (observation.Lines is not null) ||
            (observation.Kind != LogReadKind.Available && (observation.HasEarlier || observation.InputTruncated ||
                observation.HasMore || observation.PendingFragment || observation.NextCursor is not null)) ||
            (observation.Kind == LogReadKind.ResetRequired && request.Cursor is null)) return Empty(LogViewStatus.Invalid);
        if (observation.Kind != LogReadKind.Available) return Empty(observation.Kind switch {
            LogReadKind.Missing => LogViewStatus.Missing,
            LogReadKind.Denied => LogViewStatus.Denied,
            LogReadKind.ResetRequired => LogViewStatus.ResetRequired,
            LogReadKind.LimitExceeded => LogViewStatus.LimitExceeded,
            LogReadKind.Invalid => LogViewStatus.Invalid,
            LogReadKind.ClockChanged => LogViewStatus.ClockChanged,
            LogReadKind.ReadTooSlow => LogViewStatus.ReadTooSlow,
            _ => LogViewStatus.Unavailable
        });
        try { observation.NextCursor?.Validate(); }
        catch (ContractException) { return Empty(LogViewStatus.Invalid); }
        if (observation.NextCursor is not null && (observation.NextCursor.Binding != request.Binding || observation.NextCursor.StreamId != request.StreamId) ||
            (observation.HasMore || observation.PendingFragment) && observation.NextCursor is null ||
            request.Cursor is not null && observation.NextCursor is not null &&
            (observation.NextCursor.Generation != request.Cursor.Generation || observation.NextCursor.Offset < request.Cursor.Offset))
            return Empty(LogViewStatus.Invalid);
        var input = observation.Lines!;
        var lineCount = input.Count;
        if (lineCount < 0 || lineCount > request.MaximumLines) return Empty(LogViewStatus.Invalid);
        var output = new List<string>(lineCount);
        var remaining = request.MaximumCharacters;
        var truncated = false;
        for (var lineIndex = 0; lineIndex < lineCount; lineIndex++) {
            var line = input[lineIndex];
            if (line is null || line.Length > LogRequest.InputLineLimit) return Empty(LogViewStatus.Invalid);
            var safe = new StringBuilder();
            for (var i = 0; i < line.Length;) {
                if (Rune.DecodeFromUtf16(line.AsSpan(i), out var rune, out var consumed) != OperationStatus.Done)
                    return Empty(LogViewStatus.Invalid);
                i += consumed;
                var category = Rune.GetUnicodeCategory(rune);
                var display = rune.Value == '\\' ? "\\\\" : category is UnicodeCategory.Control or UnicodeCategory.Format or UnicodeCategory.LineSeparator or UnicodeCategory.ParagraphSeparator
                    ? rune.Value <= 0xffff ? "\\u" + rune.Value.ToString("X4", CultureInfo.InvariantCulture)
                        : "\\U" + rune.Value.ToString("X8", CultureInfo.InvariantCulture)
                    : rune.ToString();
                if (!truncated && display.Length <= remaining) { safe.Append(display); remaining -= display.Length; }
                else truncated = true;
            }
            if (!truncated || safe.Length > 0) output.Add(safe.ToString());
        }
        return new(LogViewStatus.Available, output.AsReadOnly(), observation.HasEarlier, truncated,
            observation.InputTruncated, observation.HasMore || truncated, observation.PendingFragment,
            truncated ? null : observation.NextCursor);
    }
}
