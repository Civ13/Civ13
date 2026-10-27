"""Existing Civ13 offline hash/RNG helpers, copied verbatim; no terrain edits."""
import hashlib
import json

def stable_u64(seed: str, algorithm: str, content: str, profile: str,
               stage: str, layer: str, x: int, y: int, slot: int = 0) -> int:
    """Coordinate-stable draw; JSON array framing prevents concatenation collisions."""
    payload = json.dumps([seed, algorithm, content, profile, stage, layer, x, y, slot],
                         ensure_ascii=True, separators=(",", ":")).encode("ascii")
    return int.from_bytes(hashlib.sha256(payload).digest()[:8], "big")

def canonical_hash(document: dict) -> str:
    return hashlib.sha256(json.dumps(document, sort_keys=True, separators=(",", ":"),
                                     allow_nan=False).encode()).hexdigest()
