"""Private publisher for the gateway's paired verified-access snapshot.

This is a local deployment component, not a network handler. The operating
system must already restrict writes to the front-door directory and input
pipe to the trusted gateway publisher; region consumers need read access.
"""
from contextlib import contextmanager
import json
import os
import stat
from pathlib import Path
import re
import tempfile

MAX_WIRE = 8_388_608
MAX_REVISION = 8_000_000  # exactly representable by BYOND's numeric type
FIELDS = {"schema", "group", "revision", "approved", "whitelist"}
ROW = re.compile(r"([a-z0-9]{1,256})=([1-9][0-9]{16,19})", re.ASCII)


def validate_access(value):
    # The bot's canonical projection leaves exactly one newline for an empty
    # set. Empty/unreadable/partial output is never interpreted as that state.
    if type(value) is not str or not value.endswith("\n"):
        raise ValueError("access list must be complete")
    if value == "\n":
        return
    keys, ids = set(), set()
    for line in value[:-1].split("\n"):
        match = ROW.fullmatch(line)
        if not match or match[1] in keys or match[2] in ids:
            raise ValueError("invalid or duplicate access row")
        keys.add(match[1])
        ids.add(match[2])


def validate_bundle(value, group):
    if (type(value) is not dict or set(value) != FIELDS or value["group"] != group
            or type(value["schema"]) is not int or value["schema"] != 1
            or type(value["revision"]) is not int or not 1 <= value["revision"] <= MAX_REVISION):
        raise ValueError("invalid gateway access snapshot")
    validate_access(value["approved"])
    validate_access(value["whitelist"])


@contextmanager
def publisher_lock(path):
    # Held across read, increment and replace. The OS releases it on process
    # exit, so a crashed publisher doesn't strand a lock directory.
    if path.is_symlink():
        raise ValueError("gateway access lock is a symlink")
    fd = os.open(path, os.O_RDWR | os.O_CREAT | getattr(os, "O_NOFOLLOW", 0), 0o600)
    with os.fdopen(fd, "r+b") as stream:
        if os.name == "nt":
            import msvcrt
            msvcrt.locking(stream.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        yield


def unique_object(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise ValueError("duplicate object field")
        value[key] = item
    return value


def read_snapshot(path, group):
    if path.is_symlink():
        raise ValueError("gateway access snapshot is a symlink")
    try:
        with path.open("rb") as stream:
            wire = stream.read(MAX_WIRE + 1)
    except FileNotFoundError:
        return None
    if len(wire) > MAX_WIRE:
        raise ValueError("gateway access snapshot exceeds its byte budget")
    value = json.loads(wire, object_pairs_hook=unique_object)
    validate_bundle(value, group)
    return value


def publish(group, approved=None, whitelist=None, *, inbox=False):
    """Commit both validated projections or neither. Return metadata only."""
    if (group.get("gateway_verified_access") is not True or not group.get("relay_port")
            or not any(r["id"] == group.get("gate") and r["kind"] == "GATEWAY" for r in group["regions"])):
        raise ValueError("gateway access publishing is not enabled for this group")
    if inbox is not (group.get("gateway_verified_access_inbox") is True):
        raise ValueError("select the configured gateway access input mode")
    authority = Path(group["root"]).resolve() / "front-door"
    directory = authority / "SQL"
    if authority.is_symlink() or directory.is_symlink() or not directory.is_dir():
        raise ValueError("protected gateway access directory is unavailable")
    target = directory / "verified-access.json"
    with publisher_lock(directory / ".verified-access.lock"):
        proposal_path = authority / "access-inbox" / "proposal.json"
        proposal_stamp = None
        if inbox:
            pair = read_proposal(authority / "access-inbox", group["group"])
            if pair is None:
                return {"changed": False, "proposal": "absent"}
            approved, whitelist, proposal_stamp = pair
        validate_access(approved)
        validate_access(whitelist)
        previous = read_snapshot(target, group["group"])
        if previous and previous["approved"] == approved and previous["whitelist"] == whitelist:
            return {"revision": previous["revision"], "changed": False}
        candidate = {"schema": 1, "group": group["group"],
                     "revision": previous["revision"] + 1 if previous else 1,
                     "approved": approved, "whitelist": whitelist}
        validate_bundle(candidate, group["group"])
        wire = (json.dumps(candidate, ensure_ascii=True, separators=(",", ":")) + "\n").encode("ascii")
        if len(wire) > MAX_WIRE:
            raise ValueError("gateway access snapshot exceeds its byte budget")
        with tempfile.NamedTemporaryFile(mode="wb", dir=directory, prefix=".verified-access-", delete=False) as stream:
            temporary = Path(stream.name)
            try:
                if os.name != "nt":
                    os.fchmod(stream.fileno(), 0o640)
                stream.write(wire)
                stream.flush()
                os.fsync(stream.fileno())
            except BaseException:
                stream.close()
                temporary.unlink(missing_ok=True)
                raise
        try:
            if inbox and proposal_stamp != file_stamp(proposal_path.lstat()):
                raise ValueError("gateway proposal superseded during preparation")
            os.replace(temporary, target)
            if os.name != "nt":
                dir_fd = os.open(directory, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
                try:
                    os.fsync(dir_fd)
                finally:
                    os.close(dir_fd)
        finally:
            temporary.unlink(missing_ok=True)
        return {"revision": candidate["revision"], "changed": True}


def publish_input(group, wire):
    """Operator pipe: exact paired payload, no store or region paths from input."""
    if type(wire) is not bytes or len(wire) > MAX_WIRE:
        raise ValueError("gateway input exceeds its byte budget")
    value = json.loads(wire, object_pairs_hook=unique_object)
    if type(value) is not dict or set(value) != {"approved", "whitelist"}:
        raise ValueError("both canonical access lists are required")
    return publish(group, value["approved"], value["whitelist"])


def file_stamp(record):
    return record.st_dev, record.st_ino, record.st_size, record.st_mtime_ns, record.st_ctime_ns


def read_proposal(directory, group):
    """Read only the fixed protected producer path; no caller-selected paths."""
    if directory.is_symlink() or not directory.is_dir():
        raise ValueError("protected gateway input directory unavailable")
    path = directory / "proposal.json"
    try:
        before = path.lstat()
        if not stat.S_ISREG(before.st_mode) or path.is_symlink() or before.st_size > MAX_WIRE:
            raise ValueError("unsafe gateway proposal")
        fd = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0)
                     | getattr(os, "O_BINARY", 0))
    except FileNotFoundError:
        return None
    with os.fdopen(fd, "rb") as stream:
        opened = os.fstat(stream.fileno())
        if not stat.S_ISREG(opened.st_mode) or file_stamp(before) != file_stamp(opened):
            raise ValueError("gateway proposal changed before read")
        wire = stream.read(MAX_WIRE + 1)
        if len(wire) != before.st_size or file_stamp(opened) != file_stamp(path.lstat()):
            raise ValueError("gateway proposal changed during read")
    value = json.loads(wire, object_pairs_hook=unique_object)
    if type(value) is not dict or set(value) != {"group", "approved", "whitelist"} or value["group"] != group:
        raise ValueError("gateway proposal does not match this group")
    return value["approved"], value["whitelist"], file_stamp(opened)
