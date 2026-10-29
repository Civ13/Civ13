using System.Collections.Frozen;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace Civ13.ServerManagement.Transfers;

// Inert proposal DTOs. Registry/policy data must come from authenticated operator configuration.
public sealed record PeerIdentity(string ServerId, string GroupId, long IdentityEpoch,
    string KeyId, long NotBefore, long ExpiresAt, bool Revoked) {
    public void Validate() {
        TransferRules.Id(ServerId); TransferRules.Token(GroupId); TransferRules.Token(KeyId);
        TransferRules.Positive(IdentityEpoch); TransferRules.Window(NotBefore, ExpiresAt);
    }
}

public sealed class TrustSnapshot {
    public string GroupId { get; }
    public long Epoch { get; }
    public bool OperatorApproved { get; }
    public FrozenDictionary<string, PeerIdentity> Peers { get; }
    public TrustSnapshot(string groupId, long epoch, bool operatorApproved, IEnumerable<PeerIdentity> peers) {
        TransferRules.Token(groupId); TransferRules.Positive(epoch);
        GroupId = groupId; Epoch = epoch; OperatorApproved = operatorApproved;
        var entries = peers.Take(129).ToArray();
        TransferRules.Require(entries.Length <= 128, "peer-capacity");
        foreach (var peer in entries) { peer.Validate(); TransferRules.Require(peer.GroupId == groupId, "peer-group"); }
        TransferRules.Require(entries.Select(p => p.ServerId).Distinct(StringComparer.Ordinal).Count() == entries.Length, "duplicate-peer");
        Peers = entries.ToFrozenDictionary(p => p.ServerId, StringComparer.Ordinal);
    }
}

public sealed record TransferPolicy(string ServerId, string GroupId, long Revision, long ExpiresAt,
    FrozenSet<string> ExportsTo, FrozenSet<string> ImportsFrom, FrozenSet<string> ItemKinds,
    FrozenSet<string> OriginAuthorities, long MaxUnits) {
    public void Validate() {
        TransferRules.Id(ServerId); TransferRules.Token(GroupId); TransferRules.Positive(Revision);
        TransferRules.Positive(ExpiresAt); TransferRules.Positive(MaxUnits);
        TransferRules.Require(MaxUnits <= 1_000_000_000, "quantity-limit");
        foreach (var set in new[] { ExportsTo, ImportsFrom, ItemKinds, OriginAuthorities })
            TransferRules.Require(set is not null && set.Count <= 128, "policy-set-limit");
        foreach (var id in ExportsTo.Concat(ImportsFrom)) TransferRules.Id(id);
        foreach (var token in ItemKinds.Concat(OriginAuthorities)) TransferRules.Token(token);
    }
    public string Digest() { Validate(); return TransferCanonical.Hash(TransferCanonical.Policy(this)); }
}

// Origin authority is immutable lineage, not the last server that signed a message.
public sealed record ItemClaim(string AssetId, string Kind, long Revision, long Quantity,
    string OriginAuthority, string ProvenanceDigest) {
    public void Validate() {
        TransferRules.Id(AssetId); TransferRules.Token(Kind); TransferRules.Positive(Revision);
        TransferRules.Positive(Quantity); TransferRules.Require(Quantity <= 1_000_000_000, "quantity-limit");
        TransferRules.Token(OriginAuthority); TransferRules.Hash(ProvenanceDigest);
    }
}

public sealed class TransferManifest {
    public const string Schema = "civ13.transfer-manifest.v1";
    public string TransferId { get; }
    public long TransferEpoch { get; }
    public long TransferSequence { get; }
    public string Source { get; }
    public string Destination { get; }
    public string GroupId { get; }
    public long TrustEpoch { get; }
    public long SourceIdentityEpoch { get; }
    public long DestinationIdentityEpoch { get; }
    public string SourceKeyId { get; }
    public string DestinationKeyId { get; }
    public string SourcePolicyHash { get; }
    public string DestinationPolicyHash { get; }
    public string AccountId { get; }
    public string SourceGeneration { get; }
    public long CreatedAt { get; }
    public long ExpiresAt { get; }
    public IReadOnlyList<ItemClaim> Items { get; }
    public TransferManifest(long transferEpoch, long transferSequence, string source, string destination, string groupId,
        long trustEpoch, long sourceIdentityEpoch, long destinationIdentityEpoch, string sourceKeyId, string destinationKeyId, string sourcePolicyHash,
        string destinationPolicyHash, string accountId, string sourceGeneration, long createdAt,
        long expiresAt, IEnumerable<ItemClaim> items) {
        TransferEpoch = transferEpoch; TransferSequence = transferSequence;
        Source = source; Destination = destination; GroupId = groupId;
        TransferId = TransferCanonical.Id(source, destination, groupId, transferEpoch, transferSequence);
        TrustEpoch = trustEpoch; SourceIdentityEpoch = sourceIdentityEpoch; DestinationIdentityEpoch = destinationIdentityEpoch;
        SourceKeyId = sourceKeyId; DestinationKeyId = destinationKeyId;
        SourcePolicyHash = sourcePolicyHash; DestinationPolicyHash = destinationPolicyHash;
        AccountId = accountId; SourceGeneration = sourceGeneration; CreatedAt = createdAt; ExpiresAt = expiresAt;
        Items = Array.AsReadOnly(items.Take(33).OrderBy(i => i.AssetId, StringComparer.Ordinal).ToArray());
        Validate();
    }
    public void Validate() {
        TransferRules.Hash(TransferId); TransferRules.Positive(TransferEpoch); TransferRules.Positive(TransferSequence);
        TransferRules.Id(Source); TransferRules.Id(Destination);
        TransferRules.Require(Source != Destination, "same-peer"); TransferRules.Token(GroupId);
        TransferRules.Positive(TrustEpoch); TransferRules.Positive(SourceIdentityEpoch); TransferRules.Positive(DestinationIdentityEpoch);
        TransferRules.Token(SourceKeyId); TransferRules.Token(DestinationKeyId);
        TransferRules.Hash(SourcePolicyHash); TransferRules.Hash(DestinationPolicyHash);
        TransferRules.Token(AccountId); TransferRules.Token(SourceGeneration); TransferRules.Window(CreatedAt, ExpiresAt);
        TransferRules.Require(ExpiresAt - CreatedAt <= 300, "transfer-lifetime");
        TransferRules.Require(Items.Count is > 0 and <= 32, "item-capacity");
        foreach (var item in Items) item.Validate();
        TransferRules.Require(Items.Select(i => i.AssetId).Distinct(StringComparer.Ordinal).Count() == Items.Count, "duplicate-asset");
    }
    public string Digest() => TransferCanonical.Hash(TransferCanonical.Manifest(this));
}

public enum ReceiptKind { Escrow, Prepare, Commit, Import, Finalize, Abort, Tombstone, Return }
public sealed record TransferReceipt(string ReceiptId, string TransferId, string ManifestHash,
    ReceiptKind Kind, long Sequence, string Issuer, string Recipient, string KeyId, long KeyEpoch,
    long IssuedAt, long ExpiresAt, string PreviousHash) {
    public const string Schema = "civ13.transfer-receipt.v1";
    public void Validate() {
        TransferRules.Hash(TransferId); TransferRules.Hash(ManifestHash);
        TransferRules.Require(Enum.IsDefined(Kind), "receipt-kind"); TransferRules.Positive(Sequence);
        TransferRules.Require(ReceiptId == TransferId + "-" + Sequence.ToString(System.Globalization.CultureInfo.InvariantCulture), "receipt-id-binding");
        TransferRules.Id(Issuer); TransferRules.Id(Recipient); TransferRules.Token(KeyId); TransferRules.Positive(KeyEpoch);
        TransferRules.Window(IssuedAt, ExpiresAt); TransferRules.Require(ExpiresAt - IssuedAt <= 300, "receipt-lifetime");
        TransferRules.Hash(PreviousHash);
    }
}

// This is not a JWS parser or cryptographic implementation. The adapter must supply a vetted verifier.
public sealed record SignedReceipt(TransferReceipt Receipt, string Algorithm, string Signature);
// Current bounded channel state, produced on demand; no historical transfer/receipt lookup.
public sealed record ChannelCheckpoint(string Source, string Destination, string GroupId, long GroupEpoch,
    long TransferEpoch, long ClosedThrough, string Issuer, string KeyId, long KeyEpoch, long IssuedAt, long ExpiresAt) {
    public void Validate() {
        TransferRules.Id(Source); TransferRules.Id(Destination); TransferRules.Id(Issuer);
        TransferRules.Require(Source != Destination, "same-peer"); TransferRules.Token(GroupId); TransferRules.Token(KeyId);
        TransferRules.Positive(GroupEpoch); TransferRules.Positive(TransferEpoch); TransferRules.Positive(ClosedThrough);
        TransferRules.Positive(KeyEpoch); TransferRules.Window(IssuedAt, ExpiresAt);
        TransferRules.Require(ExpiresAt - IssuedAt <= 300, "checkpoint-lifetime");
    }
}
public sealed record SignedCheckpoint(ChannelCheckpoint Checkpoint, string Algorithm, string Signature);
public interface ITransferSignatureVerifier {
    bool Verify(PeerIdentity enrolledPeer, ReadOnlySpan<byte> jwsSigningInput, string signature);
}
public interface IItemProvenanceVerifier {
    // Bind authoritative origin/taint, generation, owner, revision and quantity without an archive dependency.
    bool Verify(TransferManifest transfer, ItemClaim claim);
}

internal static class TransferRules {
    internal const long MaximumInteger = 9_007_199_254_740_991;
    internal static void Require(bool condition, string code) { if (!condition) throw new ContractException(code); }
    internal static void Token(string value) => Require(InstanceBinding.Token(value), "transfer-token");
    internal static void Hash(string value) => Require(InstanceBinding.Hash(value), "transfer-hash");
    internal static void Positive(long value) => Require(value > 0 && value <= MaximumInteger, "transfer-integer");
    internal static void Window(long start, long end) { Positive(start); Positive(end); Require(end > start, "transfer-window"); }
    internal static void Id(string value) => Require(Guid.TryParseExact(value, "D", out var id) &&
        id != Guid.Empty && id.ToString("D") == value, "transfer-id");
}

// Restricted RFC8785-compatible output: fixed sorted ASCII keys, ASCII tokens and safe integers.
// No general JSON input canonicalizer, arbitrary Unicode, floats, duplicate keys or wire decoder.
public static class TransferCanonical {
    private static byte[] Write(Action<Utf8JsonWriter> emit) {
        using var stream = new MemoryStream();
        using (var writer = new Utf8JsonWriter(stream)) { writer.WriteStartObject(); emit(writer); writer.WriteEndObject(); }
        return stream.ToArray();
    }
    private static void Set(Utf8JsonWriter w, string name, IEnumerable<string> values) {
        w.WriteStartArray(name); foreach (var v in values.Order(StringComparer.Ordinal)) w.WriteStringValue(v); w.WriteEndArray();
    }
    internal static string Id(string source, string destination, string group, long epoch, long sequence) => Hash(Write(w => {
        w.WriteString("destination", destination); w.WriteNumber("epoch", epoch); w.WriteString("groupId", group);
        w.WriteString("schema", "civ13.transfer-id.v1"); w.WriteNumber("sequence", sequence); w.WriteString("source", source);
    }));
    internal static byte[] Policy(TransferPolicy p) => Write(w => {
        Set(w, "authorityOrigins", p.OriginAuthorities); w.WriteNumber("expiresAt", p.ExpiresAt);
        Set(w, "exportsTo", p.ExportsTo); w.WriteString("groupId", p.GroupId); Set(w, "importsFrom", p.ImportsFrom);
        Set(w, "itemKinds", p.ItemKinds); w.WriteNumber("maxUnits", p.MaxUnits); w.WriteNumber("revision", p.Revision);
        w.WriteString("schema", "civ13.transfer-policy.v1"); w.WriteString("serverId", p.ServerId);
    });
    public static byte[] Manifest(TransferManifest p) {
        p.Validate();
        return Write(w => {
            w.WriteString("accountId", p.AccountId); w.WriteNumber("createdAt", p.CreatedAt); w.WriteString("destination", p.Destination);
            w.WriteNumber("destinationIdentityEpoch", p.DestinationIdentityEpoch); w.WriteString("destinationKeyId", p.DestinationKeyId);
            w.WriteString("destinationPolicyHash", p.DestinationPolicyHash);
            w.WriteNumber("expiresAt", p.ExpiresAt); w.WriteString("groupId", p.GroupId); w.WriteStartArray("items");
            foreach (var item in p.Items) {
                w.WriteStartObject(); w.WriteString("assetId", item.AssetId); w.WriteString("kind", item.Kind);
                w.WriteString("originAuthority", item.OriginAuthority); w.WriteString("provenanceDigest", item.ProvenanceDigest);
                w.WriteNumber("quantity", item.Quantity); w.WriteNumber("revision", item.Revision); w.WriteEndObject();
            }
            w.WriteEndArray(); w.WriteString("schema", TransferManifest.Schema);
            w.WriteString("source", p.Source); w.WriteString("sourceGeneration", p.SourceGeneration);
            w.WriteNumber("sourceIdentityEpoch", p.SourceIdentityEpoch); w.WriteString("sourceKeyId", p.SourceKeyId);
            w.WriteString("sourcePolicyHash", p.SourcePolicyHash);
            w.WriteNumber("transferEpoch", p.TransferEpoch); w.WriteString("transferId", p.TransferId);
            w.WriteNumber("transferSequence", p.TransferSequence); w.WriteNumber("trustEpoch", p.TrustEpoch);
        });
    }
    public static byte[] Receipt(TransferReceipt p) {
        p.Validate();
        return Write(w => {
            w.WriteNumber("expiresAt", p.ExpiresAt); w.WriteNumber("issuedAt", p.IssuedAt); w.WriteString("issuer", p.Issuer);
            w.WriteNumber("keyEpoch", p.KeyEpoch); w.WriteString("keyId", p.KeyId); w.WriteString("kind", p.Kind.ToString().ToLowerInvariant());
            w.WriteString("manifestHash", p.ManifestHash); w.WriteString("previousHash", p.PreviousHash); w.WriteString("receiptId", p.ReceiptId);
            w.WriteString("recipient", p.Recipient); w.WriteString("schema", TransferReceipt.Schema);
            w.WriteNumber("sequence", p.Sequence); w.WriteString("transferId", p.TransferId);
        });
    }
    public static byte[] SigningInput(SignedReceipt p) {
        TransferRules.Require(p.Algorithm == "Ed25519", "signature-algorithm");
        return JwsInput(p.Receipt.KeyId, "civ13-transfer-v1", Receipt(p.Receipt));
    }
    public static byte[] CheckpointSigningInput(SignedCheckpoint p) {
        p.Checkpoint.Validate(); TransferRules.Require(p.Algorithm == "Ed25519", "signature-algorithm");
        var c = p.Checkpoint;
        var payload = Write(w => {
            w.WriteNumber("closedThrough", c.ClosedThrough); w.WriteString("destination", c.Destination);
            w.WriteNumber("expiresAt", c.ExpiresAt); w.WriteNumber("groupEpoch", c.GroupEpoch); w.WriteString("groupId", c.GroupId);
            w.WriteNumber("issuedAt", c.IssuedAt); w.WriteString("issuer", c.Issuer); w.WriteNumber("keyEpoch", c.KeyEpoch);
            w.WriteString("keyId", c.KeyId); w.WriteString("schema", "civ13.channel-checkpoint.v1");
            w.WriteString("source", c.Source); w.WriteNumber("transferEpoch", c.TransferEpoch);
        });
        return JwsInput(c.KeyId, "civ13-channel-checkpoint-v1", payload);
    }
    private static byte[] JwsInput(string key, string type, byte[] payload) {
        var header = Write(w => { w.WriteString("alg", "Ed25519"); w.WriteString("kid", key); w.WriteString("typ", type); });
        return Encoding.ASCII.GetBytes(Base64Url(header) + "." + Base64Url(payload));
    }
    private static string Base64Url(byte[] bytes) => Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
    public static string Hash(ReadOnlySpan<byte> bytes) => Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();
    public static string EnvelopeDigest(SignedReceipt p) {
        TransferRules.Require(p.Signature is { Length: > 0 and <= 128 } &&
            p.Signature.All(c => c is >= 'a' and <= 'z' or >= 'A' and <= 'Z' or >= '0' and <= '9' or '_' or '-'), "signature-size-or-format");
        return Hash(Encoding.ASCII.GetBytes(Encoding.ASCII.GetString(SigningInput(p)) + "." + p.Signature));
    }
}
