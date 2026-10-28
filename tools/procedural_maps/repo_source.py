"""Read-only pinned source access. Never downloads or launches an engine."""
import hashlib
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
SOURCE_COMMIT = "067478b82c7ad9f1b83759a221e6f22080ba865a"


def read_pinned(relative, expected_blob, root=None, source_commit=SOURCE_COMMIT):
    root = Path(root) if root is not None else REPOSITORY_ROOT
    path = root / relative
    # Git may materialize CRLF on Windows. The pinned source blobs use LF.
    data = path.read_bytes().replace(b"\r\n", b"\n")
    actual = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
    if actual != expected_blob:
        raise ValueError("CATALOG_SOURCE_MISMATCH: " + relative +
                         "; use a clean catalog checkout at " + source_commit)
    return data
