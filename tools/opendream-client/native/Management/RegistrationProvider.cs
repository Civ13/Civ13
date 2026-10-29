using System.Text;
using Civ13.ServerManagement;

namespace Civ13.Launcher.Management;

public enum RegistrationReadKind { Available, Missing, Denied, Unavailable, Invalid }
// Implementations must enforce the byte limit while reading.
public sealed record RegistrationRead(RegistrationReadKind Kind, byte[]? Content);
public interface IRegistrationFileReader { RegistrationRead Read(string absolutePath, int maximumBytes); }
public enum RegistrationStatus { Available, Missing, Denied, Unavailable, Invalid, ClockChanged, ReadTooSlow }
public sealed record RegistrationSnapshot(string SourcePath, string ClockScope, long SampleMilliseconds, long CompletedMilliseconds,
    RegistrationStatus Status, InstanceCatalog? Catalog);

// Declarations only: never proves ownership, process state, host locality or readiness.
public sealed class RegistrationProvider(IRegistrationFileReader reader, IProcessObservationClock clock, long maximumReadMilliseconds = 1000) {
    private readonly IRegistrationFileReader source = reader ?? throw new ArgumentNullException(nameof(reader));
    private readonly IProcessObservationClock timer = clock ?? throw new ArgumentNullException(nameof(clock));
    private readonly long budget = maximumReadMilliseconds is > 0 and <= 5000 ? maximumReadMilliseconds : throw new ContractException("invalid-registration-budget");

    public RegistrationSnapshot Read(string absolutePath) {
        ValidatePath(absolutePath);
        var scope = timer.Scope; var start = timer.Milliseconds;
        if (!Token(scope) || start < 0) throw new ContractException("invalid-registration-clock");
        RegistrationRead? read;
        try { read = source.Read(absolutePath, ManifestJson.MaximumCatalogBytes); }
        catch (UnauthorizedAccessException) { read = new(RegistrationReadKind.Denied, null); }
        catch (IOException) { read = new(RegistrationReadKind.Unavailable, null); }
        var end = timer.Milliseconds;
        if (timer.Scope != scope || end < start) return new(absolutePath, scope, start, end, RegistrationStatus.ClockChanged, null);
        if (end - start > budget) return new(absolutePath, scope, start, end, RegistrationStatus.ReadTooSlow, null);
        if (read is null || !Enum.IsDefined(read.Kind) || (read.Kind == RegistrationReadKind.Available) != (read.Content is not null))
            return new(absolutePath, scope, start, end, RegistrationStatus.Invalid, null);
        if (read.Kind != RegistrationReadKind.Available)
            return new(absolutePath, scope, start, end, read.Kind switch { RegistrationReadKind.Missing => RegistrationStatus.Missing,
                RegistrationReadKind.Denied => RegistrationStatus.Denied, RegistrationReadKind.Invalid => RegistrationStatus.Invalid,
                _ => RegistrationStatus.Unavailable }, null);
        if (read.Content!.Length > ManifestJson.MaximumCatalogBytes) return new(absolutePath, scope, start, end, RegistrationStatus.Invalid, null);
        try {
            var json = new UTF8Encoding(false, true).GetString(read.Content);
            return new(absolutePath, scope, start, end, RegistrationStatus.Available, ManifestJson.ReadCatalog(json));
        } catch (DecoderFallbackException) { return new(absolutePath, scope, start, end, RegistrationStatus.Invalid, null); }
        catch (ContractException) { return new(absolutePath, scope, start, end, RegistrationStatus.Invalid, null); }
    }
    // Lexical admission only. A future real reader must separately verify canonical
    // resolution, reparse points, ownership and access at open time before use.
    public static void ValidatePath(string? path) {
        if (path is null || path.Length > 260 || path.Length < 4 || !path.StartsWith("D:\\", StringComparison.OrdinalIgnoreCase) ||
            path.Contains('/') || path.Any(char.IsControl)) throw new ContractException("invalid-registration-path");
        var segments = path[3..].Split('\\');
        foreach (var segment in segments) {
            var stem = segment.Split('.')[0];
            if (segment.Length == 0 || segment is "." or ".." || segment.EndsWith(' ') || segment.EndsWith('.') ||
                segment.IndexOfAny([':', '*', '?', '"', '<', '>', '|']) >= 0 ||
                stem.Equals("CON", StringComparison.OrdinalIgnoreCase) || stem.Equals("PRN", StringComparison.OrdinalIgnoreCase) ||
                stem.Equals("AUX", StringComparison.OrdinalIgnoreCase) || stem.Equals("NUL", StringComparison.OrdinalIgnoreCase) ||
                IsDevice(stem, "COM") || IsDevice(stem, "LPT")) throw new ContractException("invalid-registration-path");
        }
    }
    private static bool IsDevice(string value, string prefix) => value.Length == 4 && value.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) &&
        value[3] is >= '1' and <= '9' or '\u00b9' or '\u00b2' or '\u00b3';
    private static bool Token(string? value) => value is { Length: > 0 and <= 64 } && value.All(c => c is >= 'a' and <= 'z' or >= 'A' and <= 'Z' or >= '0' and <= '9' or '_' or '-');
}
