using System.Globalization;
using Civ13.ServerManagement;

namespace Civ13.Launcher.Management;

// Supplied typed data only. No registration, file/IPC reader or process collector.
public sealed record LocalManagementEntry(InstanceManifest Manifest, ProcessTarget? Target,
    LocalProcessObservation? Observation);

public static class LocalManagementPresentation {
    // Compose from the original snapshot at every display; cached entries cannot
    // preserve registration freshness. The injected monotonic clock supplies
    // the scope and current time for this display only.
    public static void WriteRegisteredInstances(TextWriter output, RegistrationSnapshot snapshot,
        IReadOnlyList<SuppliedProcessObservation> supplied, string requestedRegistrationPath, string localHostId,
        IProcessObservationClock clock, long registrationMaximumAgeMilliseconds, long observationMaximumAgeMilliseconds) {
        ArgumentNullException.ThrowIfNull(output);
        ArgumentNullException.ThrowIfNull(clock);
        if (observationMaximumAgeMilliseconds <= 0) throw new ContractException("invalid-management-context");
        var scope = clock.Scope;
        var now = clock.Milliseconds;
        if (clock.Scope != scope) {
            output.WriteLine("Registration status: ClockChanged. Registered instances remain unknown.");
            return;
        }
        var batch = LocalManagementComposition.Compose(snapshot, supplied, requestedRegistrationPath,
            localHostId, scope, now, registrationMaximumAgeMilliseconds);
        if (batch.Status != RegistrationViewStatus.Available) {
            output.WriteLine("Registration status: " + batch.Status + ". Registered instances remain unknown.");
            return;
        }
        WriteInstances(output, batch.Entries, localHostId, scope, now, observationMaximumAgeMilliseconds);
    }

    // Reuses ServerBrowser's TextWriter presentation convention. No Main wiring.
    public static void WriteInstances(TextWriter output, IReadOnlyList<LocalManagementEntry> entries,
        string localHostId, string clockScope, long nowMilliseconds, long maximumAgeMilliseconds) {
        ArgumentNullException.ThrowIfNull(output);
        if (entries is null || entries.Count > InstanceCatalog.MaximumInstances)
            throw new ContractException("invalid-management-entries");
        if (!Token(localHostId) || !Token(clockScope) || nowMilliseconds < 0 || maximumAgeMilliseconds <= 0)
            throw new ContractException("invalid-management-context");
        // Validate the entire supplied cohort before emitting any partial display.
        foreach (var entry in entries) {
            if (entry?.Manifest is null) throw new ContractException("invalid-management-entry");
            entry.Target?.Validate();
        }
        var catalog = new InstanceCatalog(entries.Select(entry => entry.Manifest));
        output.WriteLine("Registered server instances - supplied read-only observations");
        output.WriteLine("Configured local observation host: " + localHostId);
        output.WriteLine("Ownership and backend readiness are unverified. No controls or automatic refresh.");
        if (catalog.Instances.Count == 0) output.WriteLine("No registered instances were supplied.");
        for (var index = 0; index < entries.Count; index++) {
            var entry = entries[index]; var manifest = entry.Manifest; var binding = manifest.Binding;
            output.WriteLine($"{index + 1}: {manifest.Label} | Desired: {manifest.Desired}");
            output.WriteLine($"   Instance: {binding.InstanceId} | Host: {binding.HostId} | Profile: {binding.ProfileId} r{binding.ProfileRevision.ToString(CultureInfo.InvariantCulture)}");
            output.WriteLine("   Kind: " + binding.Kind + (manifest.ShardGroupId is null ? "" : " | Group: " + manifest.ShardGroupId));
            if (binding.HostId != localHostId) {
                output.WriteLine("   Facts: Unknown - registered host is outside this local view.");
                continue;
            }
            if (entry.Target is null) {
                output.WriteLine("   Facts: Unknown - no explicit process target was supplied.");
                continue;
            }
            var view = ProcessFactProjection.Project(manifest, entry.Target, entry.Observation,
                clockScope, nowMilliseconds, maximumAgeMilliseconds);
            var description = (view.Evidence, view.Match) switch {
                (EvidenceKind.Present, ProcessFactMatch.MatchingStart) => "PID present; start time matches registration.",
                (EvidenceKind.Present, ProcessFactMatch.DifferentStart) => "PID present; start time differs from registration.",
                (EvidenceKind.Missing, ProcessFactMatch.Missing) => "Registered PID absent; instance state remains unknown.",
                (EvidenceKind.Denied, _) => "Inspection denied; instance state remains unknown.",
                (EvidenceKind.Unavailable, _) => "Inspection unavailable; instance state remains unknown.",
                _ => "Unknown - " + view.Reason + "."
            };
            output.WriteLine("   Facts: " + description);
            if (view.Evidence == EvidenceKind.Present && view.Match is ProcessFactMatch.MatchingStart or ProcessFactMatch.DifferentStart) {
                // Only the shared projection's admitted, correctly scoped facts can reach these fields.
                var facts = entry.Observation!.Facts!;
                output.WriteLine("   PID: " + facts.Pid.ToString(CultureInfo.InvariantCulture) + " | OS start UTC: " +
                    new DateTime(facts.StartTimeUtcTicks, DateTimeKind.Utc).ToString("O", CultureInfo.InvariantCulture));
            }
        }
    }
    private static bool Token(string? value) => value is { Length: > 0 and <= 64 } &&
        value.All(c => c is >= 'a' and <= 'z' or >= 'A' and <= 'Z' or >= '0' and <= '9' or '_' or '-');
}
