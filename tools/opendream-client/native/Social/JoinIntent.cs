using System.Text;
using System.Text.Json;

namespace Civ13.Launcher.Social;

public sealed class JoinIntent {
    public const int MaxBytes = 512;
    private static readonly UTF8Encoding StrictUtf8 = new(false, true);
    public string TargetKey { get; }
    public GameTarget Target { get; }
    public string? Map { get; }
    public string? Mode { get; }
    public string? Round { get; }
    private JoinIntent(string key, string? map, string? mode, string? round) {
        TargetKey = key;
        Target = key switch {
            "official-1714" => new("Civ13.com", 1714), "official-1715" => new("Civ13.com", 1715),
            "vzg-1714" => new("ValZarGaming", 1714), "vzg-1715" => new("ValZarGaming", 1715),
            _ => throw new FormatException("Unknown catalog key.")
        };
        Target.Validate();
        Map = map; Mode = mode; Round = round;
    }
    public static JoinIntent Parse(ReadOnlySpan<byte> payload) {
        if (payload.Length is 0 or > MaxBytes) throw new FormatException("Invalid join-intent size.");
        try {
            _ = StrictUtf8.GetCharCount(payload);
            using var json = JsonDocument.Parse(payload.ToArray(), new JsonDocumentOptions { MaxDepth = 2 });
            if (json.RootElement.ValueKind != JsonValueKind.Object) throw new FormatException("Expected join-intent object.");
            var seen = new HashSet<string>(StringComparer.Ordinal);
            string? key = null, map = null, mode = null, round = null;
            foreach (var property in json.RootElement.EnumerateObject()) {
                if (!seen.Add(property.Name)) throw new FormatException("Duplicate join-intent field.");
                switch (property.Name) {
                    case "v":
                        if (property.Value.ValueKind != JsonValueKind.Number || property.Value.GetRawText() != "1")
                            throw new FormatException("Unsupported join-intent version.");
                        break;
                    case "target": key = Text(property.Value); break;
                    case "map": map = Text(property.Value); break;
                    case "mode": mode = Text(property.Value); break;
                    case "round": round = Text(property.Value); break;
                    default: throw new FormatException("Unknown join-intent field.");
                }
            }
            if (!seen.Contains("v") || key == null) throw new FormatException("Incomplete join intent.");
            return new JoinIntent(key, map, mode, round);
        } catch (Exception error) when (error is JsonException or DecoderFallbackException or InvalidOperationException or ArgumentException) {
            throw new FormatException("Malformed join intent.", error);
        }
    }
    private static string Text(JsonElement element) {
        if (element.ValueKind != JsonValueKind.String) throw new FormatException("Expected join-intent text.");
        var value = element.GetString()!;
        // Deliberately small identity grammar, never a URL/path/command grammar.
        // All text is compared as data; no field is interpolated into arguments.
        if (StrictUtf8.GetByteCount(value) is < 1 or > 96 || value.Trim() != value || value[0] == '-' ||
            value.Any(c => !(char.IsLetterOrDigit(c) || c is ' ' or '_' or '-')))
            throw new FormatException("Invalid join-intent identity text.");
        return value;
    }
    internal bool Matches(GameServer status) => Target == status.Target &&
        (Map == null || Map == status.Map) && (Mode == null || Mode == status.Mode) && (Round == null || Round == status.RoundId);
}

// Generation and ID come from the local adapter, never from wire credentials.
public sealed record JoinIntentEnvelope(long Generation, Guid IntentId, JoinIntent Value);
