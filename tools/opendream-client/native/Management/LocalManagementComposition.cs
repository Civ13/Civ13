using Civ13.ServerManagement;

namespace Civ13.Launcher.Management;

// Explicitly supplied facts; neither a target nor an observation is an ownership grant.
public sealed record SuppliedProcessObservation(ProcessTarget Target, LocalProcessObservation? Observation);
public enum RegistrationViewStatus { Available, Missing, Denied, Unavailable, Invalid, ClockChanged, ReadTooSlow, Stale }
public sealed record LocalManagementBatch(RegistrationViewStatus Status, IReadOnlyList<LocalManagementEntry> Entries);

// Pure composition only: never reads files, obtains processes or creates targets.
public static class LocalManagementComposition {
    public static LocalManagementBatch Compose(RegistrationSnapshot snapshot, IReadOnlyList<SuppliedProcessObservation> supplied,
        string requestedRegistrationPath, string localHostId, string clockScope, long nowMilliseconds, long maximumAgeMilliseconds) {
        if (snapshot is null || supplied is null || supplied.Count > InstanceCatalog.MaximumInstances ||
            !Token(localHostId) || !Token(clockScope) || nowMilliseconds < 0 || maximumAgeMilliseconds <= 0)
            throw new ContractException("invalid-management-composition");
        LocalManagementBatch Empty(RegistrationViewStatus status) => new(status, Array.Empty<LocalManagementEntry>());
        RegistrationProvider.ValidatePath(requestedRegistrationPath);
        if (snapshot.SourcePath != requestedRegistrationPath) return Empty(RegistrationViewStatus.Invalid);
        if (!Enum.IsDefined(snapshot.Status) ||
            (snapshot.Status == RegistrationStatus.Available) != (snapshot.Catalog is not null))
            return Empty(RegistrationViewStatus.Invalid);
        if (snapshot.Status == RegistrationStatus.ClockChanged) return Empty(RegistrationViewStatus.ClockChanged);
        if (snapshot.ClockScope != clockScope) return Empty(RegistrationViewStatus.ClockChanged);
        if (snapshot.SampleMilliseconds < 0 || snapshot.CompletedMilliseconds < snapshot.SampleMilliseconds ||
            snapshot.CompletedMilliseconds > nowMilliseconds) return Empty(RegistrationViewStatus.Invalid);
        if (nowMilliseconds - snapshot.SampleMilliseconds > maximumAgeMilliseconds) return Empty(RegistrationViewStatus.Stale);
        if (snapshot.Status != RegistrationStatus.Available)
            return Empty(snapshot.Status switch {
                RegistrationStatus.Missing => RegistrationViewStatus.Missing,
                RegistrationStatus.Denied => RegistrationViewStatus.Denied,
                RegistrationStatus.Unavailable => RegistrationViewStatus.Unavailable,
                RegistrationStatus.ClockChanged => RegistrationViewStatus.ClockChanged,
                RegistrationStatus.ReadTooSlow => RegistrationViewStatus.ReadTooSlow,
                _ => RegistrationViewStatus.Invalid
            });

        var manifests = snapshot.Catalog!.Instances.ToDictionary(x => x.Binding.InstanceId, StringComparer.Ordinal);
        var explicitFacts = new Dictionary<string, SuppliedProcessObservation>(StringComparer.Ordinal);
        foreach (var item in supplied) {
            if (item?.Target is null) throw new ContractException("missing-supplied-target");
            item.Target.Validate();
            var binding = item.Target.Binding;
            if (binding.HostId != localHostId || !manifests.TryGetValue(binding.InstanceId, out var manifest) || manifest.Binding != binding)
                throw new ContractException("supplied-target-scope-mismatch");
            if (!explicitFacts.TryAdd(binding.InstanceId, item)) throw new ContractException("duplicate-supplied-target");
        }
        var entries = snapshot.Catalog.Instances.Select(manifest => {
            explicitFacts.TryGetValue(manifest.Binding.InstanceId, out var item);
            return new LocalManagementEntry(manifest, item?.Target, item?.Observation);
        }).ToArray();
        return new(RegistrationViewStatus.Available, Array.AsReadOnly(entries));
    }
    private static bool Token(string? value) => value is { Length: > 0 and <= 64 } &&
        value.All(c => c is >= 'a' and <= 'z' or >= 'A' and <= 'Z' or >= '0' and <= '9' or '_' or '-');
}
