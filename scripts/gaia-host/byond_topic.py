"""BYOND Topic request framing shared by host-side clients."""

import struct


def frame_query(query):
    """Frame already-encoded query bytes, leaving query policy to the caller."""
    payload = b'\0' * 5 + query + b'\0'
    return b'\x00\x83' + struct.pack('>H', len(payload)) + payload
