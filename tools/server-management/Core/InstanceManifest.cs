using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Civ13.ServerManagement;

public enum InstanceKind { Process, Shard }
public enum DesiredState { Stopped, Running, Maintenance }

public sealed class ContractException(string code) : Exception(code) {
    public string Code { get; } = code;
}

// Logical zones, map layers and geographic IDs are not process instance IDs.
public sealed record InstanceBinding(string InstanceId, string HostId, string ProfileId,
    long ProfileRevision, string ProfileSha256, InstanceKind Kind) {
    public void Validate() {
        Require(Guid.TryParseExact(InstanceId, "D", out var id) && id != Guid.Empty &&
            id.ToString("D") == InstanceId, "invalid-instance-id");
        Require(Token(HostId) && Token(ProfileId), "invalid-host-or-profile-id");
        Require(ProfileRevision > 0 && Hash(ProfileSha256), "invalid-profile-binding");
        Require(Enum.IsDefined(Kind), "invalid-instance-kind");
    }
    internal static bool Token(string? value) => value is { Length: > 0 and <= 64 } &&
        value.All(c => c is >= 'a' and <= 'z' or >= 'A' and <= 'Z' or >= '0' and <= '9' or '_' or '-');
    internal static bool Hash(string? value) => value is { Length: 64 } &&
        value.All(c => c is >= '0' and <= '9' or >= 'a' and <= 'f');
    internal static void Require(bool condition, string code) {
        if (!condition) throw new ContractException(code);
    }
}

// Metadata only. No path, credentials, endpoint, ownership grant or launch recipe.
public sealed record InstanceManifest(InstanceBinding Binding, string Label,
    string Backend, string RuntimeVersion, string? ShardGroupId, DesiredState Desired) {
    public const string Schema = "civ13.instance.v1";
    public void Validate() {
        if (Binding is null) throw new ContractException("missing-instance-binding");
        Binding.Validate();
        InstanceBinding.Require(Label is { Length: > 0 and <= 96 } &&
            !string.IsNullOrWhiteSpace(Label) && !Label.Any(char.IsControl), "invalid-label");
        InstanceBinding.Require(Backend == "civ13-byond", "unsupported-backend");
        InstanceBinding.Require(RuntimeVersion is { Length: <= 16 } &&
            Regex.IsMatch(RuntimeVersion, @"\A[1-9][0-9]{0,3}\.[1-9][0-9]{0,5}\z", RegexOptions.CultureInvariant), "invalid-runtime-version");
        InstanceBinding.Require(Enum.IsDefined(Desired), "invalid-desired-state");
        InstanceBinding.Require(Binding.Kind == InstanceKind.Shard ? InstanceBinding.Token(ShardGroupId) :
            ShardGroupId is null, "invalid-shard-group");
    }
}

public sealed class InstanceCatalog {
    public const string Schema = "civ13.catalog.v1";
    public const int MaximumInstances = 128;
    public IReadOnlyList<InstanceManifest> Instances { get; }
    public InstanceCatalog(IEnumerable<InstanceManifest> instances) {
        if (instances is null) throw new ContractException("missing-instances");
        var snapshot = new List<InstanceManifest>();
        var ids = new HashSet<string>(StringComparer.Ordinal);
        foreach (var instance in instances) {
            InstanceBinding.Require(snapshot.Count < MaximumInstances, "catalog-capacity");
            if (instance is null) throw new ContractException("missing-instance");
            instance.Validate();
            InstanceBinding.Require(ids.Add(instance.Binding.InstanceId), "duplicate-instance-id");
            snapshot.Add(instance);
        }
        Instances = snapshot.AsReadOnly();
    }
}

public static class ManifestJson {
    public const int MaximumManifestBytes = 16 * 1024;
    public const int MaximumCatalogBytes = 256 * 1024;
    public static InstanceManifest ReadManifest(string json) => Parse(json, MaximumManifestBytes, ReadInstance);
    public static InstanceCatalog ReadCatalog(string json) => Parse(json, MaximumCatalogBytes, root => {
        Fields(root, "schema", "instances");
        InstanceBinding.Require(Text(root, "schema") == InstanceCatalog.Schema, "unsupported-catalog-schema");
        var entries = root.GetProperty("instances");
        InstanceBinding.Require(entries.ValueKind == JsonValueKind.Array, "invalid-instances-array");
        InstanceBinding.Require(entries.GetArrayLength() <= InstanceCatalog.MaximumInstances, "catalog-capacity");
        return new InstanceCatalog(entries.EnumerateArray().Select(ReadInstance));
    });
    private static T Parse<T>(string json, int limit, Func<JsonElement, T> decode) {
        InstanceBinding.Require(json is not null && json.Length <= limit &&
            Encoding.UTF8.GetByteCount(json) <= limit, "json-size-limit");
        try {
            using var document = JsonDocument.Parse(json!, new JsonDocumentOptions { MaxDepth = 8 });
            return decode(document.RootElement);
        } catch (JsonException) { throw new ContractException("invalid-json"); }
        catch (InvalidOperationException) { throw new ContractException("invalid-json-value"); }
    }
    private static InstanceManifest ReadInstance(JsonElement root) {
        Fields(root, "schema", "instanceId", "hostId", "profileId", "profileRevision", "profileSha256",
            "kind", "label", "backend", "runtimeVersion", "shardGroupId", "desired", "registration");
        InstanceBinding.Require(Text(root, "schema") == InstanceManifest.Schema, "unsupported-instance-schema");
        InstanceBinding.Require(Text(root, "registration") == "observe-only", "unsupported-registration");
        var kind = Text(root, "kind") switch {
            "process" => InstanceKind.Process, "shard" => InstanceKind.Shard,
            _ => throw new ContractException("invalid-instance-kind")
        };
        var desired = Text(root, "desired") switch {
            "stopped" => DesiredState.Stopped, "running" => DesiredState.Running,
            "maintenance" => DesiredState.Maintenance, _ => throw new ContractException("invalid-desired-state")
        };
        var revision = root.GetProperty("profileRevision");
        InstanceBinding.Require(revision.ValueKind == JsonValueKind.Number && revision.TryGetInt64(out _), "invalid-profile-revision");
        var group = root.GetProperty("shardGroupId");
        InstanceBinding.Require(group.ValueKind is JsonValueKind.Null or JsonValueKind.String, "invalid-shard-group");
        var binding = new InstanceBinding(Text(root, "instanceId"), Text(root, "hostId"), Text(root, "profileId"),
            revision.GetInt64(), Text(root, "profileSha256"), kind);
        var result = new InstanceManifest(binding, Text(root, "label"), Text(root, "backend"), Text(root, "runtimeVersion"),
            group.ValueKind == JsonValueKind.Null ? null : group.GetString(), desired);
        result.Validate();
        return result;
    }
    private static string Text(JsonElement root, string name) {
        var value = root.GetProperty(name);
        InstanceBinding.Require(value.ValueKind == JsonValueKind.String, "invalid-field-type");
        return value.GetString()!;
    }
    private static void Fields(JsonElement root, params string[] names) {
        InstanceBinding.Require(root.ValueKind == JsonValueKind.Object, "invalid-object");
        var found = new HashSet<string>(StringComparer.Ordinal);
        var aliases = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var property in root.EnumerateObject()) {
            InstanceBinding.Require(aliases.Add(property.Name), "duplicate-field");
            InstanceBinding.Require(names.Contains(property.Name, StringComparer.Ordinal), "unknown-field");
            found.Add(property.Name);
        }
        InstanceBinding.Require(found.Count == names.Length, "missing-field");
    }
}
