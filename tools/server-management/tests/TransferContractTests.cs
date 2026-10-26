using System.Collections.Frozen;
using System.Text;
using System.Text.Json;
using Civ13.ServerManagement;
using Civ13.ServerManagement.Transfers;

internal static class TransferContractTests {
    private const string A = "20000000-0000-4000-8000-000000000001";
    private const string B = "20000000-0000-4000-8000-000000000002";
    private const string C = "20000000-0000-4000-8000-000000000003";
    private const string Asset = "30000000-0000-4000-8000-000000000001";
    private static FrozenSet<string> Set(params string[] values) => values.ToFrozenSet(StringComparer.Ordinal);
    private static PeerIdentity Peer(string id, string key) => new(id, "approved-group", 1, key, 50, 1000, false);
    private static TrustSnapshot Trust(IEnumerable<PeerIdentity>? peers = null, bool approved = true, long epoch = 1) =>
        new("approved-group", epoch, approved, peers ?? [Peer(A, "key-a"), Peer(B, "key-b")]);
    private static TransferPolicy Policy(string id, bool source) => new(id, "approved-group", 1, 800,
        source ? Set(B) : Set(), source ? Set() : Set(A), Set("iron"), Set("official"), 100);
    private static TransferManifest Manifest(TransferPolicy? source = null, TransferPolicy? destination = null,
        IEnumerable<ItemClaim>? items = null, long sequence = 1,
        string? actualSource = null, string? actualDestination = null) {
        source ??= Policy(A, true); destination ??= Policy(B, false);
        return new(1, sequence, actualSource ?? source.ServerId, actualDestination ?? destination.ServerId, "approved-group", 1, 1, 1,
            source.ServerId == A ? "key-a" : "key-b", destination.ServerId == A ? "key-a" : "key-b",
            source.Digest(), destination.Digest(), "player-a", "generation-a", 100, 400,
            items ?? [new(Asset, "iron", 1, 7, "official", new string('a', 64))]);
    }
    // Deterministic lookup doubles, not signatures/MACs or proof of production cryptographic safety.
    private sealed class MockSignatures : ITransferSignatureVerifier {
        private readonly Dictionary<string, (string Peer, string Key, string Input)> accepted = new();
        private int counter;
        public SignedReceipt Issue(TransferManifest manifest, TransferState state, ReceiptKind kind,
            Func<TransferReceipt, TransferReceipt>? alter = null, long now = 110) {
            counter++;
            var fromSource = kind is ReceiptKind.Escrow or ReceiptKind.Commit or ReceiptKind.Finalize or ReceiptKind.Abort or ReceiptKind.Return;
            var issuer = fromSource ? manifest.Source : manifest.Destination;
            var recipient = fromSource ? manifest.Destination : manifest.Source;
            var receipt = new TransferReceipt(manifest.TransferId + "-" + (state.Version + 1).ToString(System.Globalization.CultureInfo.InvariantCulture), manifest.TransferId,
                manifest.Digest(), kind, state.Version + 1, issuer, recipient, issuer == A ? "key-a" : "key-b", 1,
                now, now + 30, state.LastReceiptHash);
            if (alter is not null) receipt = alter(receipt);
            var signed = new SignedReceipt(receipt, "Ed25519", "mock-" + counter);
            accepted.Add(signed.Signature, (receipt.Issuer, receipt.KeyId, TransferCanonical.Hash(TransferCanonical.SigningInput(signed))));
            return signed;
        }
        public bool Verify(PeerIdentity peer, ReadOnlySpan<byte> input, string signature) =>
            accepted.TryGetValue(signature, out var proof) && proof.Peer == peer.ServerId && proof.Key == peer.KeyId &&
            proof.Input == TransferCanonical.Hash(input);
        public SignedCheckpoint Checkpoint(TransferChannelFence fence, long now = 110) {
            counter++;
            var payload = new ChannelCheckpoint(fence.Source, fence.Destination, fence.GroupId, 1, fence.Epoch,
                fence.SettledSequence, fence.Source, "key-a", 1, now, now + 30);
            var signed = new SignedCheckpoint(payload, "Ed25519", "checkpoint-" + counter);
            accepted.Add(signed.Signature, (payload.Issuer, payload.KeyId, TransferCanonical.Hash(TransferCanonical.CheckpointSigningInput(signed))));
            return signed;
        }
    }
    private sealed class MockProvenance(TransferManifest allowed, string actualOrigin = "official") : IItemProvenanceVerifier {
        private readonly string admittedManifest = allowed.Digest();
        public bool Verify(TransferManifest manifest, ItemClaim claim) => manifest.Digest() == admittedManifest &&
            claim.OriginAuthority == actualOrigin && claim.ProvenanceDigest == new string('a', 64);
    }
    // Models durable CAS and inventory ownership; there is no disk, network or game backend.
    private sealed class MockStore(TransferState initial) {
        public TransferState Durable { get; private set; } = initial;
        public string Owner { get; private set; } = A;
        public string? EscrowId { get; private set; }
        public int SourceCreditOperations { get; private set; }
        public int SourceUnits => Owner == A ? 7 : 0;
        public int DestinationUnits => Owner == B ? 7 : 0;
        public int TrackedUnits => SourceUnits + DestinationUnits + (Owner == "escrow" ? 7 : 0);
        public bool TryRecord(long expectedVersion, ApplyResult result, ReceiptKind kind) {
            if (Durable.Version != expectedVersion || result.Disposition != ApplyDisposition.Accepted ||
                result.State.Version != expectedVersion + 1 || result.State.TransferId != Durable.TransferId) return false;
            if (kind == ReceiptKind.Escrow) {
                if (Owner != A || EscrowId is not null) return false;
                Owner = "escrow"; EscrowId = result.State.TransferId;
            } else if (kind == ReceiptKind.Import) {
                if (Owner != "escrow" || EscrowId != result.State.TransferId) return false;
                Owner = B;
            } else if (kind == ReceiptKind.Return && Owner == "escrow") {
                Owner = A; EscrowId = null; SourceCreditOperations++;
            }
            Durable = result.State;
            return true;
        }
        public bool ReserveCompetingTransfer(string transferId) => Owner == A && EscrowId is null && transferId != Durable.TransferId;
    }

    public static int Run() {
        var count = 0;
        void Check(bool value, string name) { count++; if (!value) throw new Exception("Transfer contract failed: " + name); }
        void Reject(Action action, string name) {
            var refused = false; try { action(); } catch (ContractException) { refused = true; }
            Check(refused, name);
        }
        var sp = Policy(A, true); var dp = Policy(B, false); var trust = Trust(); var m = Manifest();
        var channel = new TransferChannelFence(A, B, "approved-group", 1).Reserve(m);
        var proofs = new MockProvenance(m); var signatures = new MockSignatures();
        TransferDecision Allow(TransferManifest manifest, TransferPolicy source, TransferPolicy destination,
            TrustSnapshot? peers = null, IItemProvenanceVerifier? provenance = null, long now = 110) =>
            MutualTransferPolicy.Evaluate(manifest, peers ?? trust, source, destination, provenance ?? proofs, now);
        ApplyResult Apply(TransferState state, SignedReceipt signed, TransferPolicy? source = null,
            TransferPolicy? destination = null, TrustSnapshot? peers = null, long now = 110, long? version = null) =>
            TransferTransitions.Apply(state, m, signed, version ?? state.Version, channel, peers ?? trust, source ?? sp,
                destination ?? dp, signatures, proofs, now);
        Check(Allow(m, sp, dp).Allowed, "both directions of one transfer require matching permits");
        var noExport = sp with { ExportsTo = Set() }; var noImport = dp with { ImportsFrom = Set() };
        var deniedExport = Manifest(noExport, dp); var deniedImport = Manifest(sp, noImport);
        Check(Allow(deniedExport, noExport, dp, provenance: new MockProvenance(deniedExport)).Code == "source-export-denied", "source denies export");
        Check(Allow(deniedImport, sp, noImport, provenance: new MockProvenance(deniedImport)).Code == "destination-import-denied", "destination denies import");
        var reverse = Manifest(dp, sp);
        Check(!Allow(reverse, dp, sp, provenance: new MockProvenance(reverse)).Allowed, "forward authorization grants no reverse route");
        var reverseSource = dp with { ExportsTo = Set(A) }; var reverseDestination = sp with { ImportsFrom = Set(B) };
        reverse = Manifest(reverseSource, reverseDestination);
        Check(Allow(reverse, reverseSource, reverseDestination, provenance: new MockProvenance(reverse)).Allowed, "reverse needs its own two permits");
        Check(Allow(m, sp, dp, Trust([Peer(A, "key-a")])).Code == "unknown-peer", "self-signed unknown peer has no membership");
        Check(Allow(m, sp, dp, Trust([Peer(B, "key-b")])).Code == "unknown-peer", "unknown source is denied too");
        Check(Allow(m, sp, dp, Trust(approved: false)).Code == "unapproved-or-changed-trust-group", "local group cannot self-approve");
        Check(Allow(m, sp, dp, Trust(epoch: 2)).Code == "unapproved-or-changed-trust-group", "registry changes fence transfers");
        foreach (var revoked in new[] { A, B })
            Check(Allow(m, sp, dp, Trust([Peer(A, "key-a") with { Revoked = revoked == A }, Peer(B, "key-b") with { Revoked = revoked == B }])).Code == "revoked-peer", "either peer revocation denies");
        Check(Allow(m, sp, dp, Trust([Peer(A, "key-a") with { ExpiresAt = 110 }, Peer(B, "key-b")])).Code == "identity-expired-or-future", "identity expiry boundary");
        Check(Allow(m, sp, dp, Trust([Peer(A, "key-a") with { NotBefore = 111 }, Peer(B, "key-b")])).Code == "identity-expired-or-future", "future identity denied");
        Check(Allow(m, sp, dp, Trust([Peer(A, "rotated") with { IdentityEpoch = 2 }, Peer(B, "key-b")])).Code == "identity-rotated", "rotation changes epoch");
        Check(Allow(m, sp, dp, Trust([Peer(A, "rotated"), Peer(B, "key-b")])).Code == "identity-rotated", "changed key cannot reuse old epoch admission");
        Check(Allow(m, sp with { Revision = 2 }, dp).Code == "policy-changed", "revision change fences pending work");
        Check(Allow(m, sp with { ExportsTo = Set() }, dp).Code == "policy-changed", "same-revision altered policy digest is denied");
        Check(Allow(m, sp with { ExpiresAt = 110 }, dp).Code == "policy-expired", "policy expiration boundary");
        Check(Allow(m, sp, dp, now: 400).Code == "transfer-expired-or-future", "transfer expiry boundary");
        Check(Allow(m, sp, dp, now: 99).Code == "transfer-expired-or-future", "future manifest denied");
        var privateItems = new[] { m.Items[0] with { OriginAuthority = "private" } };
        var privateTransfer = Manifest(items: privateItems);
        Check(Allow(privateTransfer, sp, dp, provenance: new MockProvenance(privateTransfer, "private")).Code == "origin-authority-denied", "trusted intermediary cannot launder private origin");
        Check(Allow(m, sp, dp, provenance: new MockProvenance(m, "private")).Code == "unverified-provenance-or-ownership", "rewritten origin fails independent provenance check");
        var wrongAccountProof = new MockProvenance(Manifest(sequence: 2));
        Check(Allow(m, sp, dp, provenance: wrongAccountProof).Code == "unverified-provenance-or-ownership", "provenance proof binds exact transfer and ownership snapshot");
        var restricted = dp with { ItemKinds = Set("wood") }; var restrictedManifest = Manifest(sp, restricted);
        Check(Allow(restrictedManifest, sp, restricted, provenance: new MockProvenance(restrictedManifest)).Code == "item-kind-denied", "item restrictions intersect");
        var small = sp with { MaxUnits = 6 }; var smallManifest = Manifest(small, dp);
        Check(Allow(smallManifest, small, dp, provenance: new MockProvenance(smallManifest)).Code == "quantity-denied", "quantity caps intersect");
        var initial = TransferState.Begin(m);
        var escrow = signatures.Issue(m, initial, ReceiptKind.Escrow);
        Check(Apply(initial, escrow with { Receipt = escrow.Receipt with { Recipient = C } }).Code == "wrong-issuer-or-recipient", "wrong recipient denied");
        Check(Apply(initial, escrow with { Signature = "tampered" }).Code == "invalid-signature", "tampering rejected by injected verifier");
        Check(Apply(initial, escrow with { Receipt = escrow.Receipt with { KeyId = "other" } }).Code == "wrong-or-rotated-key", "key identifiers are pinned, not remotely fetched");
        Check(Apply(initial, escrow with { Receipt = escrow.Receipt with { ManifestHash = new string('b', 64) } }).Code == "transfer-or-manifest-mismatch", "manifest tampering denied");
        Check(Apply(initial, escrow with { Receipt = escrow.Receipt with { PreviousHash = new string('b', 64) } }).Code == "receipt-chain-mismatch", "chain tampering denied");
        Check(Apply(initial, escrow, now: 140).Code == "receipt-expired-or-future", "receipt expiry denied");
        Reject(() => Apply(initial, escrow with { Algorithm = "none" }), "algorithm downgrade rejected");
        var first = Apply(initial, escrow); Check(first.Disposition == ApplyDisposition.Accepted, "source escrow evidence admitted");
        var store = new MockStore(initial); Check(store.TryRecord(0, first, ReceiptKind.Escrow), "CAS reserves journal and source escrow");
        Check(store.Owner == "escrow" && !store.ReserveCompetingTransfer("other"), "same asset cannot enter a concurrent transfer");
        Check(!store.TryRecord(0, first, ReceiptKind.Escrow), "retried inventory effect cannot apply twice");
        Check(Apply(store.Durable, escrow).Disposition == ApplyDisposition.Replay, "lost reply replay returns prior result without effects");
        Check(Apply(store.Durable, escrow with { Signature = "changed" }).Code == "receipt-id-rebound", "receipt ID cannot be rebound");
        Check(Apply(store.Durable, escrow, peers: Trust([Peer(A, "key-a") with { Revoked = true }, Peer(B, "key-b")])).Disposition == ApplyDisposition.Replay,
            "historical duplicate status has no new effects even after revocation");
        var prepare = signatures.Issue(m, store.Durable, ReceiptKind.Prepare);
        var competing = signatures.Issue(m, store.Durable, ReceiptKind.Prepare);
        var prepared = Apply(store.Durable, prepare); var race = Apply(store.Durable, competing);
        Check(store.TryRecord(1, prepared, ReceiptKind.Prepare), "first concurrent CAS wins");
        Check(!store.TryRecord(1, race, ReceiptKind.Prepare), "second concurrent CAS cannot apply");
        Check(Apply(store.Durable, signatures.Issue(m, store.Durable, ReceiptKind.Commit), version: 1).Code == "state-version-conflict", "stale writer fenced");
        var persisted = store.Durable; // crash/restart retains this immutable durable-model snapshot
        Check(Apply(persisted, prepare).Disposition == ApplyDisposition.Replay, "crash recovery retains replay barrier");
        var commit = signatures.Issue(m, persisted, ReceiptKind.Commit);
        Check(Apply(persisted, commit, destination: dp with { ImportsFrom = Set() }).Code == "policy-changed", "policy changed during prepare holds commit");
        Check(Apply(persisted, commit, peers: Trust([Peer(A, "key-a"), Peer(B, "key-b") with { Revoked = true }])).Code == "revoked-peer", "revocation during prepare holds commit");
        Check(store.TryRecord(2, Apply(persisted, commit), ReceiptKind.Commit), "durable commit decision before import");
        var abortAfterCommit = signatures.Issue(m, store.Durable, ReceiptKind.Abort);
        Check(Apply(store.Durable, abortAfterCommit).Code == "invalid-custody-transition", "no abort/refund after commit decision");
        var import = signatures.Issue(m, store.Durable, ReceiptKind.Import);
        Check(Apply(store.Durable, import, destination: dp with { ImportsFrom = Set() }).Code == "policy-changed", "post-commit policy change holds inventory, never refunds");
        Check(store.Owner == "escrow", "timeout/policy hold retains explicit escrow owner");
        var committedSnapshot = store.Durable;
        Check(store.TryRecord(3, Apply(committedSnapshot, import), ReceiptKind.Import), "destination inventory credited only after commit decision");
        Check(store.Owner == B && !store.TryRecord(3, Apply(committedSnapshot, import), ReceiptKind.Import), "crashed/retried import cannot duplicate inventory");
        var importedSnapshot = store.Durable;
        Check(Apply(store.Durable, import).Disposition == ApplyDisposition.Replay, "recovery queries imported receipt idempotently");
        var finalize = signatures.Issue(m, store.Durable, ReceiptKind.Finalize, now: 410);
        Check(store.TryRecord(4, Apply(store.Durable, finalize, source: noExport, now: 410), ReceiptKind.Finalize),
            "retirement after confirmed import can clean up despite expired/changed transfer policy");
        Check(store.Durable.Phase == CustodyPhase.Committed && store.Owner == B, "one final inventory owner");
        Check(Apply(store.Durable, finalize).Disposition == ApplyDisposition.Replay, "final receipt retained for replay");
        var reboundManifest = Manifest(items: [m.Items[0] with { Quantity = 8 }]);
        Reject(() => channel.Reserve(reboundManifest), "active directional sequence cannot rebind manifest");
        var abortStore = new MockStore(initial); Check(abortStore.TryRecord(0, first, ReceiptKind.Escrow), "independent abort fixture escrow");
        var abort = signatures.Issue(m, abortStore.Durable, ReceiptKind.Abort, now: 410);
        Check(abortStore.TryRecord(1, Apply(abortStore.Durable, abort, source: noExport, now: 410), ReceiptKind.Abort), "uncommitted abort can outlive transfer/policy admission");
        var prematureReturn = signatures.Issue(m, abortStore.Durable, ReceiptKind.Return, now: 410);
        Check(Apply(abortStore.Durable, prematureReturn, now: 410).Code == "invalid-custody-transition", "source return requires destination tombstone");
        var tombstone = signatures.Issue(m, abortStore.Durable, ReceiptKind.Tombstone, now: 410);
        Check(abortStore.TryRecord(2, Apply(abortStore.Durable, tombstone, now: 410), ReceiptKind.Tombstone), "destination durably refuses any later import");
        var returned = signatures.Issue(m, abortStore.Durable, ReceiptKind.Return, now: 410);
        Check(abortStore.TryRecord(3, Apply(abortStore.Durable, returned, now: 410), ReceiptKind.Return), "only then release source escrow");
        Check(abortStore.Owner == A && abortStore.Durable.Phase == CustodyPhase.Aborted, "aborted inventory returns once");
        Check(abortStore.SourceCreditOperations == 1 && abortStore.TrackedUnits == 7, "return after actual escrow credits exactly once");
        Check(Apply(abortStore.Durable, returned, now: 410).Disposition == ApplyDisposition.Replay, "abort/retry cannot double refund");
        var neverEscrowed = new MockStore(initial);
        SignedReceipt? noEscrowReturn = null;
        foreach (var kind in new[] { ReceiptKind.Abort, ReceiptKind.Tombstone, ReceiptKind.Return }) {
            var envelope = signatures.Issue(m, neverEscrowed.Durable, kind);
            var result = Apply(neverEscrowed.Durable, envelope);
            Check(neverEscrowed.TryRecord(neverEscrowed.Durable.Version, result, kind), "requested-to-abort cleanup records without escrow");
            Check(neverEscrowed.SourceCreditOperations == 0 && neverEscrowed.SourceUnits == 7 &&
                neverEscrowed.DestinationUnits == 0 && neverEscrowed.TrackedUnits == 7 && neverEscrowed.EscrowId is null,
                "no-escrow cleanup never credits source or creates items");
            noEscrowReturn = envelope;
        }
        Check(neverEscrowed.Durable.Phase == CustodyPhase.Aborted, "requested-abort-tombstone-return terminates without moving inventory");
        var repeatedNoEscrowReturn = Apply(neverEscrowed.Durable, noEscrowReturn!);
        Check(repeatedNoEscrowReturn.Disposition == ApplyDisposition.Replay &&
            !neverEscrowed.TryRecord(neverEscrowed.Durable.Version, repeatedNoEscrowReturn, ReceiptKind.Return) &&
            neverEscrowed.SourceCreditOperations == 0 && neverEscrowed.TrackedUnits == 7,
            "retry of a no-escrow return cannot credit or mint inventory");
        Check(Apply(store.Durable, escrow).Code == "stale-step-no-effects", "old receipt history is not retained or replayed");
        var settled = channel.Settle(store.Durable);
        var inventoryBoundary = new InventoryTransferBoundary("inventory-generation-a", 10, channel, store.Durable);
        inventoryBoundary.ValidateAgainst("inventory-generation-a", 10);
        var compactedBoundary = inventoryBoundary.CompactSource("inventory-generation-b", 11);
        Check(compactedBoundary.Active is null && compactedBoundary.Channel.SettledSequence == 1,
            "official current-state compaction keeps only inventory-bound watermark, no receipt archive");
        Reject(() => compactedBoundary.ValidateAgainst("inventory-generation-a", 10), "old inventory snapshot cannot validate newer fence boundary");
        Reject(() => (inventoryBoundary with { Active = null }).ValidateAgainst("inventory-generation-a", 10), "active inventory fence cannot lose its current decision");
        Reject(() => (compactedBoundary with { Active = store.Durable }).ValidateAgainst("inventory-generation-b", 11), "closed channel cannot retain a hidden transfer-history row");
        Reject(() => new InventoryTransferBoundary("inventory-generation-a", 10, channel, initial).CompactSource("inventory-generation-b", 11),
            "unresolved current transfer cannot be garbage collected");
        Reject(() => inventoryBoundary.CompactSource("inventory-generation-b", 10), "compaction must advance inventory revision");
        Check(compactedBoundary.Channel.ActiveManifestHash is null && compactedBoundary.InventoryRevision == 11,
            "official settled state carries no manifest, envelope or receipt payload");
        Check(settled.SettledSequence == 1 && settled.ActiveTransferId is null && settled.ActiveManifestHash is null,
            "terminal transfer compacts to watermark without retained receipts");
        Reject(() => settled.Reserve(m), "settled sequence replay denied without archive lookup");
        var checkpoint = signatures.Checkpoint(settled, now: 410);
        var receiverClosed = channel.SettleDestinationFromSourceCheckpoint(m, importedSnapshot, B, checkpoint, trust, signatures, 410);
        Check(receiverClosed.SettledSequence == 1 && receiverClosed.ActiveTransferId is null,
            "lost final receipt recovered from current source watermark without archive");
        Reject(() => channel.SettleDestinationFromSourceCheckpoint(m, persisted, B, checkpoint, trust, signatures, 410),
            "checkpoint cannot invent import for merely prepared destination");
        Reject(() => channel.SettleDestinationFromSourceCheckpoint(m, importedSnapshot, A, checkpoint, trust, signatures, 410),
            "checkpoint recipient must be the local destination");
        Reject(() => channel.SettleDestinationFromSourceCheckpoint(m, importedSnapshot, B,
            checkpoint with { Checkpoint = checkpoint.Checkpoint with { Destination = C } }, trust, signatures, 410), "wrong checkpoint recipient rejected");
        Reject(() => channel.SettleDestinationFromSourceCheckpoint(m, importedSnapshot, B,
            checkpoint with { Signature = "tampered" }, trust, signatures, 410), "checkpoint tampering rejected");
        Reject(() => channel.SettleDestinationFromSourceCheckpoint(m, importedSnapshot, B, checkpoint, trust, signatures, 440),
            "expired checkpoint rejected");
        Reject(() => receiverClosed.SettleDestinationFromSourceCheckpoint(m, importedSnapshot, B, checkpoint, trust, signatures, 410),
            "checkpoint replay cannot advance the watermark twice");
        Reject(() => channel.SettleDestinationFromSourceCheckpoint(m, importedSnapshot, B,
            checkpoint with { Checkpoint = checkpoint.Checkpoint with { TransferEpoch = 2 } }, trust, signatures, 410), "wrong checkpoint epoch rejected");
        Reject(() => settled.Reserve(Manifest(sequence: 3)), "contiguous sequence prevents unbounded out-of-order replay window");
        Reject(() => (settled with { Epoch = 2 }).Reserve(Manifest(sequence: 2)), "sender cannot self-advance channel epoch");
        Reject(() => channel.Settle(initial), "unresolved custody cannot be compacted");
        Check(TransferTransitions.Apply(initial, m, escrow, 0, new TransferChannelFence(A, B, "approved-group", 1), trust,
            sp, dp, signatures, proofs, 110).Code == "channel-not-reserved", "effects need separately reserved minimal inventory state");
        for (var sequence = 2; sequence <= 25; sequence++) {
            var nextManifest = Manifest(sequence: sequence); var active = settled.Reserve(nextManifest);
            var state = TransferState.Begin(nextManifest);
            foreach (var kind in new[] { ReceiptKind.Abort, ReceiptKind.Tombstone, ReceiptKind.Return }) {
                var envelope = signatures.Issue(nextManifest, state, kind);
                var result = TransferTransitions.Apply(state, nextManifest, envelope, state.Version, active, trust, sp, dp,
                    signatures, new MockProvenance(nextManifest), 110);
                Check(result.Disposition == ApplyDisposition.Accepted, "archive-free sequential cleanup transition");
                state = result.State;
            }
            settled = active.Settle(state); // old active record is discarded, not appended to history
        }
        Check(settled.SettledSequence == 25 && settled.ActiveTransferId is null, "bounded per-peer watermark after many transfers");
        Reject(() => Manifest(items: [m.Items[0], m.Items[0]]), "duplicate asset rejected");
        Reject(() => Manifest(items: [m.Items[0] with { Quantity = 0 }]), "invalid quantity rejected");
        Reject(() => Trust(epoch: long.MaxValue), "non-interoperable JSON integer rejected");
        var reordered = sp with { ItemKinds = Set("wood", "iron") };
        Check(reordered.Digest() == (sp with { ItemKinds = Set("iron", "wood") }).Digest(), "canonical set ordering stable");
        var canonicalReceipt = Encoding.UTF8.GetString(TransferCanonical.Receipt(escrow.Receipt));
        using var json = JsonDocument.Parse(canonicalReceipt);
        var names = json.RootElement.EnumerateObject().Select(p => p.Name).ToArray();
        Check(names.SequenceEqual(names.Order(StringComparer.Ordinal)), "canonical receipt property names sorted");
        Check(!canonicalReceipt.Contains(' ') && canonicalReceipt.Contains(TransferReceipt.Schema, StringComparison.Ordinal), "canonical receipt is bounded fixed-schema JSON");
        Check(Encoding.ASCII.GetString(TransferCanonical.SigningInput(escrow)).Count(c => c == '.') == 1, "standard JWS protected-header/payload signing input");
        Console.WriteLine($"PASS {count} mocked mutual-transfer assertions; no keys, certificates, sockets, disk journal or game inventory.");
        return count;
    }
}
