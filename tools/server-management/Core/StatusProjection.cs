namespace Civ13.ServerManagement;

public enum EvidenceKind { Present, Missing, Unavailable, Denied }
public enum ObservedState { Unknown, Stopped, AliveUnready, Ready, Held }
public enum ReceiptMatch { Unverified, External, MatchingReceipt, Mismatch }

// Evidence supplied by a future adapter, never proof reconstructed from public status/cache.
public sealed record ProcessIdentity(string BootId, int Pid, string StartToken,
    string ExecutableSha256, string RunId) {
    internal bool IsValid => InstanceBinding.Token(BootId) && Pid > 0 && InstanceBinding.Token(StartToken) &&
        InstanceBinding.Hash(ExecutableSha256) && InstanceBinding.Token(RunId);
}

// Scope and requested identity apply to every kind, including Missing/Denied/Unavailable.
// ExpectedIdentity labels which receipt was inspected, not the process found by inspection.
public sealed record Observation(InstanceBinding Binding, ProcessIdentity? ExpectedIdentity,
    string ClockScope, long SampleMilliseconds, EvidenceKind Kind,
    ProcessIdentity? ObservedIdentity, bool BackendReady);
public sealed record StatusView(DesiredState Desired, ObservedState Observed, ReceiptMatch Receipt, string Reason);

// Pure display projection. No ownership/capability grant or action recommendation.
public static class StatusProjection {
    public static StatusView Project(InstanceManifest manifest, ProcessIdentity? expected,
        Observation? observation, string clockScope, long nowMilliseconds, long maxAgeMilliseconds) {
        if (manifest is null) throw new ContractException("missing-manifest");
        manifest.Validate();
        if (!InstanceBinding.Token(clockScope) || nowMilliseconds < 0 || maxAgeMilliseconds <= 0)
            throw new ContractException("invalid-clock-context");
        StatusView Unknown(string reason) => new(manifest.Desired, ObservedState.Unknown, ReceiptMatch.Unverified, reason);
        if (expected is not null && !expected.IsValid) return Unknown("invalid-expected-identity");
        if (observation is null) return Unknown("no-observation");
        if (observation.Binding != manifest.Binding || observation.ExpectedIdentity != expected)
            return Unknown("observation-scope-mismatch");
        if (observation.ClockScope != clockScope) return Unknown("clock-scope-changed");
        if (observation.SampleMilliseconds < 0 || observation.SampleMilliseconds > nowMilliseconds)
            return Unknown("invalid-sample-time");
        if (nowMilliseconds - observation.SampleMilliseconds > maxAgeMilliseconds)
            return Unknown("stale-observation");
        if (!Enum.IsDefined(observation.Kind)) return Unknown("invalid-evidence-kind");
        if (observation.Kind != EvidenceKind.Present &&
            (observation.ObservedIdentity is not null || observation.BackendReady))
            return Unknown("contradictory-observation");
        if (observation.Kind == EvidenceKind.Denied) return Unknown("inspection-denied");
        if (observation.Kind == EvidenceKind.Unavailable) return Unknown("inspection-unavailable");
        if (observation.Kind == EvidenceKind.Missing)
            return expected is null ? Unknown("absence-without-receipt") :
                new(manifest.Desired, ObservedState.Stopped, ReceiptMatch.Unverified, "process-confirmed-missing");
        if (observation.ObservedIdentity is null || !observation.ObservedIdentity.IsValid)
            return Unknown("invalid-observed-identity");
        if (expected is null)
            return new(manifest.Desired, ObservedState.AliveUnready, ReceiptMatch.External, "external-process-no-adoption");
        if (expected != observation.ObservedIdentity)
            return new(manifest.Desired, ObservedState.Held, ReceiptMatch.Mismatch, "identity-mismatch");
        return new(manifest.Desired, observation.BackendReady ? ObservedState.Ready : ObservedState.AliveUnready,
            ReceiptMatch.MatchingReceipt, observation.BackendReady ? "backend-ready-evidence" : "backend-readiness-unconfirmed");
    }
}
