"""Read-only reader for Civ13 stream level files (level format 5).

Decodes the file format documented in tools/savestream/src/savestream_format.h
as data: no helper process, no BYOND and no value is ever evaluated. File blobs
(icons, sounds) and raw savefile text values are returned as opaque markers.
"""
from __future__ import annotations

import bisect
import struct

MAGIC = b"C13STRM\0"
INDEX_MAGIC = b"C13SIDX\0"
MAX_PATH_BYTES = 1 << 20


class StreamError(ValueError):
    """A fixed reason code; never carries saved values."""


class TypePath(str):
    """A saved type path value ('p')."""


class Opaque:
    """A value kept out of the export: file data or raw savefile text."""

    def __init__(self, kind):
        self.kind = kind

    def __repr__(self):
        return f"Opaque({self.kind!r})"


def _varint(data, pos):
    result = shift = 0
    while True:
        if pos >= len(data) or shift > 63:
            raise StreamError("truncated_varint")
        byte = data[pos]
        pos += 1
        result |= (byte & 0x7F) << shift
        shift += 7
        if not byte & 0x80:
            return result, pos


class StreamFile:
    """Index of one stream file; values are decoded on demand."""

    def __init__(self, path):
        with open(path, "rb") as stream:
            self.data = stream.read()
        data = self.data
        if len(data) < 16 + 24 or data[:8] != MAGIC:
            raise StreamError("not_a_stream_save")
        version, flags = struct.unpack_from("<II", data, 8)
        if version != 1 or flags != 0:
            raise StreamError("unsupported_stream_version")
        index_offset, count = struct.unpack_from("<QQ", data, len(data) - 24)
        if data[-8:] != INDEX_MAGIC or not 16 <= index_offset <= len(data) - 24:
            raise StreamError("incomplete_stream")
        listed, pos = _varint(data, index_offset)
        if listed != count:
            raise StreamError("index_count_mismatch")
        paths = []
        offsets = []
        previous = b""
        for _ in range(count):
            shared, pos = _varint(data, pos)
            rest, pos = _varint(data, pos)
            if shared > len(previous) or rest > MAX_PATH_BYTES or pos + rest > len(data):
                raise StreamError("bad_index_entry")
            path = previous[:shared] + data[pos:pos + rest]
            pos += rest
            offset, pos = _varint(data, pos)
            if not 16 <= offset < index_offset:
                raise StreamError("bad_value_offset")
            if paths and path <= previous:
                raise StreamError("unsorted_index")
            paths.append(path)
            offsets.append(offset)
            previous = path
        self.paths = paths
        self.offsets = offsets
        self.positions = {path: number for number, path in enumerate(paths)}

    def get(self, path):
        """The value at an absolute path, or KeyError when absent."""
        number = self.positions.get(path.encode("utf-8"))
        if number is None:
            raise KeyError(path)
        value, _ = self._value(self.offsets[number], 0)
        return value

    def has(self, path):
        return path.encode("utf-8") in self.positions

    def children(self, path):
        """Immediate child names below a path, in index order."""
        prefix = path.rstrip("/").encode("utf-8") + b"/"
        start = bisect.bisect_left(self.paths, prefix)
        names = []
        for number in range(start, len(self.paths)):
            candidate = self.paths[number]
            if not candidate.startswith(prefix):
                break
            name = candidate[len(prefix):].split(b"/", 1)[0].decode("utf-8")
            if not names or names[-1] != name:
                names.append(name)
        return names

    def _value(self, pos, depth):
        if depth > 64:
            raise StreamError("value_too_deep")
        data = self.data
        if pos >= len(data):
            raise StreamError("truncated_value")
        kind = chr(data[pos])
        pos += 1
        if kind == "n":
            return None, pos
        if kind == "f":
            if pos + 4 > len(data):
                raise StreamError("truncated_value")
            return struct.unpack_from("<f", data, pos)[0], pos + 4
        if kind in "spx":
            size, pos = _varint(data, pos)
            if pos + size > len(data):
                raise StreamError("truncated_value")
            raw = data[pos:pos + size]
            pos += size
            if kind == "x":
                return Opaque("savefile_text"), pos
            text = raw.decode("utf-8", errors="strict")
            return (TypePath(text) if kind == "p" else text), pos
        if kind in "dy":
            _, pos = _varint(data, pos)
            return Opaque("file"), pos
        if kind == "l":
            count, pos = _varint(data, pos)
            if count > len(data):
                raise StreamError("bad_list")
            items = []
            for _ in range(count):
                key, pos = self._value(pos, depth + 1)
                if pos >= len(data):
                    raise StreamError("truncated_value")
                has_assoc = data[pos]
                pos += 1
                if has_assoc == 1:
                    value, pos = self._value(pos, depth + 1)
                    items.append((key, value))
                elif has_assoc == 0:
                    items.append((key,))
                else:
                    raise StreamError("bad_list")
            return items, pos
        raise StreamError("unknown_value_kind")
