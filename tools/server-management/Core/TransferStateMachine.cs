namespace Civ13.ServerManagement.Transfers;

public sealed record TransferDecision(bool Allowed, string Code);
public static class MutualTransferPolicy {
    public static TransferDecision Evaluate(TransferManifest manifest, TrustSnapshot trust,
        TransferPolicy sourcePolicy, TransferPolicy destinationPolicy, IItemProvenanceVerifier provenance, long now) {
        manifest.Validate(); sourcePolicy.Validate(); destinationPolicy.Validate(); TransferRules.Positive(now);
        var peers = Enrolled(manifest, trust, now);
        if (!peers.Allowed) return peers;
        if (now < manifest.CreatedAt || now >= manifest.ExpiresAt) return Deny("transfer-expired-or-future");
        if (sourcePolicy.ServerId != manifest.Source || destinationPolicy.ServerId != manifest.Destination ||
            sourcePolicy.GroupId != manifest.GroupId || destinationPolicy.GroupId != manifest.GroupId)
            return Deny("policy-identity");
        if (sourcePolicy.ExpiresAt <= now || destinationPolicy.ExpiresAt <= now) return Deny("policy-expired");
        if (sourcePolicy.Digest() != manifest.SourcePolicyHash || destinationPolicy.Digest() != manifest.DestinationPolicyHash)
            return Deny("policy-changed");
        if (!sourcePolicy.ExportsTo.Contains(manifest.Destination)) return Deny("source-export-denied");
        if (!destinationPolicy.ImportsFrom.Contains(manifest.Source)) return Deny("destination-import-denied");
        long units = 0;
        foreach (var item in manifest.Items) {
            units += item.Quantity;
            if (units > sourcePolicy.MaxUnits || units > destinationPolicy.MaxUnits) return Deny("quantity-denied");
            if (!sourcePolicy.ItemKinds.Contains(item.Kind) || !destinationPolicy.ItemKinds.Contains(item.Kind)) return Deny("item-kind-denied");
            if (!sourcePolicy.OriginAuthorities.Contains(item.OriginAuthority) || !destinationPolicy.OriginAuthorities.Contains(item.OriginAuthority))
                return Deny("origin-authority-denied");
            if (!provenance.Verify(manifest, item)) return Deny("unverified-provenance-or-ownership");
        }
        return new(true, "mutual-direction-permitted");
    }
    internal static TransferDecision Enrolled(TransferManifest manifest, TrustSnapshot trust, long now) {
        if (!trust.OperatorApproved || trust.GroupId != manifest.GroupId || trust.Epoch != manifest.TrustEpoch)
            return Deny("unapproved-or-changed-trust-group");
        if (!trust.Peers.TryGetValue(manifest.Source, out var source) || !trust.Peers.TryGetValue(manifest.Destination, out var destination))
            return Deny("unknown-peer");
        if (source.Revoked || destination.Revoked) return Deny("revoked-peer");
        if (source.NotBefore > now || destination.NotBefore > now || source.ExpiresAt <= now || destination.ExpiresAt <= now)
            return Deny("identity-expired-or-future");
        if (source.IdentityEpoch != manifest.SourceIdentityEpoch || destination.IdentityEpoch != manifest.DestinationIdentityEpoch ||
            source.KeyId != manifest.SourceKeyId || destination.KeyId != manifest.DestinationKeyId)
            return Deny("identity-rotated");
        return new(true, "enrolled-peers");
    }
    private static TransferDecision Deny(string reason) => new(false, reason);
}

public enum CustodyPhase { Requested, Escrowed, Prepared, CommitDecided, Imported, Committed, AbortDecided, DestinationAborted, Aborted }
public enum ApplyDisposition { Accepted, Replay, Rejected }

// Minimal ACTIVE custody state, not a receipt archive. Settle the channel then discard this record.
// A real authoritative inventory store must CAS these fields atomically with inventory/outbox effects.
public sealed class TransferState {
    public string TransferId { get; }
    public string ManifestHash { get; }
    public long Version { get; }
    public CustodyPhase Phase { get; }
    public string LastReceiptHash { get; }
    public string? LastReceiptId => Version == 0 ? null : TransferId + "-" + Version.ToString(System.Globalization.CultureInfo.InvariantCulture);
    private TransferState(string transferId, string manifestHash, long version, CustodyPhase phase,
        string lastHash) {
        TransferId = transferId; ManifestHash = manifestHash; Version = version; Phase = phase;
        LastReceiptHash = lastHash;
    }
    public static TransferState Begin(TransferManifest manifest) =>
        new(manifest.TransferId, manifest.Digest(), 0, CustodyPhase.Requested, new string('0', 64));
    internal TransferState Append(SignedReceipt receipt, string hash, CustodyPhase phase) =>
        new(TransferId, ManifestHash, Version + 1, phase, hash);
}

// Constant-size state per explicitly enrolled directional channel. No completed transfer rows.
// One active sequence permits contiguous settlement; a channel epoch cannot be self-advanced by a sender.
public sealed record TransferChannelFence(string Source, string Destination, string GroupId, long Epoch,
    long SettledSequence = 0, string? ActiveTransferId = null, string? ActiveManifestHash = null) {
    public void Validate() {
        TransferRules.Id(Source); TransferRules.Id(Destination); TransferRules.Token(GroupId); TransferRules.Positive(Epoch);
        TransferRules.Require(Source != Destination && SettledSequence >= 0 && SettledSequence <= TransferRules.MaximumInteger, "invalid-channel");
        TransferRules.Require((ActiveTransferId is null) == (ActiveManifestHash is null), "invalid-active-channel");
        if (ActiveTransferId is not null) { TransferRules.Hash(ActiveTransferId); TransferRules.Hash(ActiveManifestHash!); }
    }
    public TransferChannelFence Reserve(TransferManifest manifest) {
        Validate(); manifest.Validate();
        TransferRules.Positive(Epoch); TransferRules.Require(SettledSequence >= 0 && SettledSequence < TransferRules.MaximumInteger, "channel-sequence-limit");
        TransferRules.Require(Source == manifest.Source && Destination == manifest.Destination &&
            GroupId == manifest.GroupId && Epoch == manifest.TransferEpoch, "channel-scope-or-epoch");
        TransferRules.Require(manifest.TransferSequence > SettledSequence, "sequence-already-settled-no-archive");
        TransferRules.Require(manifest.TransferSequence == SettledSequence + 1, "channel-sequence-gap");
        TransferRules.Require((ActiveTransferId is null) == (ActiveManifestHash is null), "invalid-active-channel");
        TransferRules.Require(ActiveTransferId is null || ActiveTransferId == manifest.TransferId && ActiveManifestHash == manifest.Digest(), "channel-busy-or-rebound");
        return this with { ActiveTransferId = manifest.TransferId, ActiveManifestHash = manifest.Digest() };
    }
    public TransferChannelFence Settle(TransferState state) {
        Validate();
        TransferRules.Require(SettledSequence < TransferRules.MaximumInteger, "channel-sequence-limit");
        var nextSequence = SettledSequence + 1;
        TransferRules.Require(ActiveTransferId == TransferCanonical.Id(Source, Destination, GroupId, Epoch, nextSequence),
            "channel-active-id-mismatch");
        TransferRules.Require(state.TransferId == ActiveTransferId && state.ManifestHash == ActiveManifestHash &&
            state.Phase is CustodyPhase.Committed or CustodyPhase.Aborted, "channel-not-settled");
        return this with { SettledSequence = nextSequence, ActiveTransferId = null, ActiveManifestHash = null };
    }
    public TransferChannelFence SettleDestinationFromSourceCheckpoint(TransferManifest manifest, TransferState state,
        string localServerId, SignedCheckpoint signed, TrustSnapshot trust, ITransferSignatureVerifier signatures, long now) {
        Reserve(manifest); TransferRules.Positive(now); signed.Checkpoint.Validate();
        var c = signed.Checkpoint;
        TransferRules.Require(localServerId == manifest.Destination && state.TransferId == ActiveTransferId &&
            state.ManifestHash == ActiveManifestHash && state.Phase is CustodyPhase.Imported or CustodyPhase.Committed or
                CustodyPhase.DestinationAborted or CustodyPhase.Aborted, "destination-custody-not-settled");
        TransferRules.Require(c.Source == Source && c.Destination == Destination && c.Issuer == Source && c.GroupId == GroupId &&
            c.GroupEpoch == manifest.TrustEpoch && c.TransferEpoch == Epoch && c.ClosedThrough >= manifest.TransferSequence, "checkpoint-scope");
        TransferRules.Require(MutualTransferPolicy.Enrolled(manifest, trust, now).Allowed, "checkpoint-peer-unavailable");
        var peer = trust.Peers[c.Issuer];
        TransferRules.Require(c.KeyId == peer.KeyId && c.KeyEpoch == peer.IdentityEpoch && c.IssuedAt <= now && c.ExpiresAt > now &&
            c.IssuedAt >= peer.NotBefore && c.ExpiresAt <= peer.ExpiresAt, "checkpoint-key-or-time");
        TransferRules.Require(signed.Signature is { Length: > 0 and <= 128 } &&
            signatures.Verify(peer, TransferCanonical.CheckpointSigningInput(signed), signed.Signature), "checkpoint-signature");
        return this with { SettledSequence = SettledSequence + 1, ActiveTransferId = null, ActiveManifestHash = null };
    }
}
// Permitted official storage boundary: current inventory metadata + bounded active/fence state only.
// No receipts, signatures, history rows or archive hooks. This DTO does not make storage atomic.
public sealed record InventoryTransferBoundary(string InventoryGeneration, long InventoryRevision,
    TransferChannelFence Channel, TransferState? Active) {
    public void ValidateAgainst(string expectedGeneration, long expectedRevision) {
        TransferRules.Token(InventoryGeneration); TransferRules.Positive(InventoryRevision); Channel.Validate();
        TransferRules.Require(InventoryGeneration == expectedGeneration && InventoryRevision == expectedRevision, "inventory-boundary-mismatch");
        TransferRules.Require(Channel.ActiveTransferId is null ? Active is null : Active is not null &&
            Active.TransferId == Channel.ActiveTransferId && Active.ManifestHash == Channel.ActiveManifestHash, "active-inventory-boundary-mismatch");
    }
    // The real backend must persist this result with its inventory generation/revision in one commit.
    public InventoryTransferBoundary CompactSource(string nextGeneration, long nextRevision) {
        ValidateAgainst(InventoryGeneration, InventoryRevision);
        TransferRules.Require(Active is not null && nextRevision > InventoryRevision, "unsafe-active-compaction");
        var result = new InventoryTransferBoundary(nextGeneration, nextRevision, Channel.Settle(Active!), null);
        result.ValidateAgainst(nextGeneration, nextRevision);
        return result;
    }
}
public sealed record ApplyResult(ApplyDisposition Disposition, string Code, TransferState State);

public static class TransferTransitions {
    // Accepts evidence of completed server transactions. Never performs inventory/network effects.
    public static ApplyResult Apply(TransferState state, TransferManifest manifest, SignedReceipt signed,
        long expectedVersion, TransferChannelFence channelFence, TrustSnapshot trust, TransferPolicy sourcePolicy, TransferPolicy destinationPolicy,
        ITransferSignatureVerifier signatures, IItemProvenanceVerifier provenance, long now) {
        ApplyResult Reject(string code) => new(ApplyDisposition.Rejected, code, state);
        var receipt = signed.Receipt;
        receipt.Validate(); manifest.Validate(); TransferRules.Positive(now);
        channelFence.Reserve(manifest);
        if (channelFence.ActiveTransferId != manifest.TransferId || channelFence.ActiveManifestHash != manifest.Digest())
            return Reject("channel-not-reserved");
        if (state.TransferId != manifest.TransferId || state.ManifestHash != manifest.Digest() ||
            receipt.TransferId != state.TransferId || receipt.ManifestHash != state.ManifestHash)
            return Reject("transfer-or-manifest-mismatch");
        var digest = TransferCanonical.EnvelopeDigest(signed);
        if (receipt.ReceiptId == state.LastReceiptId)
            return state.LastReceiptHash == digest ? new(ApplyDisposition.Replay, "last-step-already-applied-no-effects", state) : Reject("receipt-id-rebound");
        if (receipt.Sequence <= state.Version) return Reject("stale-step-no-effects");
        if (state.Version != expectedVersion) return Reject("state-version-conflict");
        if (receipt.Sequence != state.Version + 1 || receipt.PreviousHash != state.LastReceiptHash) return Reject("receipt-chain-mismatch");
        var next = Next(state.Phase, receipt.Kind);
        if (next is null) return Reject("invalid-custody-transition");
        var fromSource = receipt.Kind is ReceiptKind.Escrow or ReceiptKind.Commit or ReceiptKind.Finalize or ReceiptKind.Abort or ReceiptKind.Return;
        if (receipt.Issuer != (fromSource ? manifest.Source : manifest.Destination) ||
            receipt.Recipient != (fromSource ? manifest.Destination : manifest.Source)) return Reject("wrong-issuer-or-recipient");
        var enrollment = MutualTransferPolicy.Enrolled(manifest, trust, now);
        if (!enrollment.Allowed) return Reject(enrollment.Code);
        var peer = trust.Peers[receipt.Issuer];
        if (receipt.KeyId != peer.KeyId || receipt.KeyEpoch != peer.IdentityEpoch) return Reject("wrong-or-rotated-key");
        if (receipt.IssuedAt > now || receipt.ExpiresAt <= now || receipt.IssuedAt < peer.NotBefore || receipt.ExpiresAt > peer.ExpiresAt)
            return Reject("receipt-expired-or-future");
        if (!signatures.Verify(peer, TransferCanonical.SigningInput(signed), signed.Signature)) return Reject("invalid-signature");
        // Cleanup grants no new destination inventory and may outlive transfer/policy expiry.
        // Finalize needs an admitted Import; return still needs the signed destination tombstone.
        if (receipt.Kind is not (ReceiptKind.Finalize or ReceiptKind.Abort or ReceiptKind.Tombstone or ReceiptKind.Return)) {
            var permission = MutualTransferPolicy.Evaluate(manifest, trust, sourcePolicy, destinationPolicy, provenance, now);
            if (!permission.Allowed) return Reject(permission.Code);
        }
        return new(ApplyDisposition.Accepted, "record-after-durable-server-evidence", state.Append(signed, digest, next.Value));
    }
    private static CustodyPhase? Next(CustodyPhase phase, ReceiptKind kind) => (phase, kind) switch {
        (CustodyPhase.Requested, ReceiptKind.Escrow) => CustodyPhase.Escrowed,
        (CustodyPhase.Escrowed, ReceiptKind.Prepare) => CustodyPhase.Prepared,
        (CustodyPhase.Prepared, ReceiptKind.Commit) => CustodyPhase.CommitDecided,
        (CustodyPhase.CommitDecided, ReceiptKind.Import) => CustodyPhase.Imported,
        (CustodyPhase.Imported, ReceiptKind.Finalize) => CustodyPhase.Committed,
        (CustodyPhase.Requested or CustodyPhase.Escrowed or CustodyPhase.Prepared, ReceiptKind.Abort) => CustodyPhase.AbortDecided,
        (CustodyPhase.AbortDecided, ReceiptKind.Tombstone) => CustodyPhase.DestinationAborted,
        (CustodyPhase.DestinationAborted, ReceiptKind.Return) => CustodyPhase.Aborted,
        _ => null
    };
}
