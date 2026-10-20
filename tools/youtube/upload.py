"""Trusted, bounded, manual-only YouTube upload. Standard library only.

Never execute artifacts, source checkouts, metadata, or commands from producers.
YouTube I/O uses the pinned YoutubePHP adapter; no-live tests inject every boundary.
"""
import argparse
import base64
import hashlib
import io
import json
import math
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile

REPO = "Civ13/Civ13"
REPO_ID = 141349998
HANDLE = "@valzartech8995"
CHANNEL = "UCFRx_n3Mh3FfvL9yOUfG-yw"
MAX_CLIP = 32 * 1024 * 1024
MAX_ARCHIVE = MAX_CLIP + 1024 * 1024
MAX_JSON = 1024 * 1024
SCOPES = {"https://www.googleapis.com/auth/youtube.upload",
          "https://www.googleapis.com/auth/youtube.readonly"}
LEDGER_BRANCH = "youtube-upload-receipts"
LEDGER_PATH = "receipts.json"
PILOT_AUTHORIZATION_ID = "owner-approved-pr3031-public-20261020"
PILOT_APPROVAL_DIGEST = "57f205c2d5692f95aced89237d7ae64faae09257040fa7e77fde8c7778eb0413"


class Refused(Exception):
    """Safe diagnostic, with no upstream response bodies or credentials."""


def require(ok, message):
    if not ok:
        raise Refused(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=True, allow_nan=False).encode()


def parse_json(data):
    require(len(data) <= MAX_JSON, "JSON exceeds cap")
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, "Duplicate JSON field")
            result[key] = value
        return result
    def constant(_):
        raise Refused("Non-finite JSON number")
    return json.loads(data, object_pairs_hook=pairs, parse_constant=constant)


def keys(value, expected):
    require(isinstance(value, dict) and set(value) == set(expected.split()),
            "Unexpected or missing fields")


def text(value, minimum, maximum):
    require(isinstance(value, str) and minimum <= len(value) <= maximum and
            all(32 <= ord(c) <= 126 and c not in "<>" for c in value),
            "Metadata must be bounded printable ASCII without angle brackets")


def integer(value, minimum=1, maximum=10**15):
    require(type(value) is int and minimum <= value <= maximum, "Invalid integer")


def sha(value, length=64):
    require(isinstance(value, str) and re.fullmatch(r"[0-9a-f]{%d}" % length, value),
            "Invalid SHA")


def validate_policy(p):
    fields = "schema_version repository repository_id channel_handle channel_id approvers producers"
    keys(p, fields + (" importers" if p.get("schema_version") == 2 else ""))
    require(p["schema_version"] in {1, 2} and p["repository"] == REPO and
            p["repository_id"] == REPO_ID and p["channel_handle"] == HANDLE and
            p["channel_id"] == CHANNEL, "Policy destination mismatch")
    require(isinstance(p["approvers"], list) and 1 <= len(p["approvers"]) <= 10,
            "Enroll human approvers through a reviewed policy PR")
    for name in p["approvers"]:
        require(isinstance(name, str) and re.fullmatch(r"[A-Za-z0-9-]{1,39}", name),
                "Invalid approver")
    require(isinstance(p["producers"], list) and 1 <= len(p["producers"]) <= 10,
            "Enroll a reviewed producer workflow before use")
    for producer in p["producers"]:
        keys(producer, "workflow_id workflow_path")
        integer(producer["workflow_id"])
        require(re.fullmatch(r"\.github/workflows/[a-z0-9_-]+\.yml", producer["workflow_path"]),
                "Invalid producer workflow path")
    if p["schema_version"] == 2:
        require(isinstance(p["importers"], list) and 1 <= len(p["importers"]) <= 10,
                "Enroll a trusted historical importer separately from the original test workflow")
        for importer in p["importers"]:
            keys(importer, "workflow_id workflow_path")
            integer(importer["workflow_id"])
            require(importer["workflow_path"] == ".github/workflows/youtube-prepare-import.yml",
                    "Only the reviewed default-branch import workflow is eligible")


def validate_manifest(m, p):
    fields = "schema_version repository channel_id channel_handle privacy source artifact clip metadata review approval"
    keys(m, fields + (" import" if m.get("schema_version") == 2 else ""))
    require(m["schema_version"] in {1, 2} and m["repository"] == REPO and
            m["channel_id"] == CHANNEL and m["channel_handle"] == HANDLE and
            m["privacy"] == "public", "Manifest destination must be fixed and public")
    source = m["source"]
    keys(source, "run_id run_attempt workflow_id workflow_path event head_branch commit pr owner")
    for key in ("run_id", "run_attempt", "workflow_id", "pr"):
        integer(source[key])
    sha(source["commit"], 40)
    text(source["head_branch"], 1, 128)
    text(source["owner"], 1, 80)
    require(source["event"] in {"pull_request", "workflow_dispatch", "push"}, "Ineligible producer event")
    require({k: source[k] for k in ("workflow_id", "workflow_path")} in p["producers"],
            "Producer not allowlisted")
    artifact = m["artifact"]
    keys(artifact, "id name archive_sha256 bytes")
    integer(artifact["id"])
    integer(artifact["bytes"], maximum=MAX_ARCHIVE)
    sha(artifact["archive_sha256"])
    require(re.fullmatch(r"gameplay-video-[a-z0-9-]{1,64}", artifact["name"]), "Invalid artifact name")
    clip = m["clip"]
    keys(clip, "path sha256 bytes duration_seconds content_type")
    require(clip["path"] == "gameplay.mp4" and clip["content_type"] == "video/mp4",
            "Only a flat gameplay.mp4 is accepted")
    sha(clip["sha256"])
    integer(clip["bytes"], 1024, MAX_CLIP)
    require(type(clip["duration_seconds"]) in {int, float} and
            math.isfinite(clip["duration_seconds"]) and 15 <= clip["duration_seconds"] <= 180,
            "Clip duration must be 15-180 seconds")
    keys(m["metadata"], "title description made_for_kids contains_synthetic_media")
    text(m["metadata"]["title"], 10, 90)
    text(m["metadata"]["description"], 30, 2000)
    require(m["metadata"]["made_for_kids"] is False and
            m["metadata"]["contains_synthetic_media"] is False,
            "Only reviewed real gameplay for the adult development audience is eligible")
    keys(m["review"], "classification reproduction capture_context known_limits content_review")
    require(m["review"]["classification"] == "genuine-gameplay", "Fixtures/synthetic media are ineligible")
    for field in ("reproduction", "capture_context", "known_limits", "content_review"):
        text(m["review"][field], 20, 1000)
    if m["schema_version"] == 2:
        validate_import_spec(m, p)
    if m["schema_version"] == 2:
        keys(m["approval"], "authorization_id")
        require(m["approval"]["authorization_id"] == PILOT_AUTHORIZATION_ID and
                approval_hash(m) == PILOT_APPROVAL_DIGEST and p["approvers"] == ["valzargaming"],
                "Historical pilot differs from exact owner-approved public material")
    else:
        keys(m["approval"], "issue_number comment_id")
        integer(m["approval"]["issue_number"])
        integer(m["approval"]["comment_id"])


def validate_import_spec(m, p):
    require(p["schema_version"] == 2, "Historical import requires its reviewed policy")
    item = m["import"]
    keys(item, "run_id run_attempt workflow_id workflow_path commit original_url original_sha256 original_bytes source_comment_id source_comment_sha256 transformation")
    for field in ("run_id", "run_attempt", "workflow_id", "source_comment_id"):
        integer(item[field])
    sha(item["commit"], 40)
    sha(item["original_sha256"])
    sha(item["source_comment_sha256"])
    integer(item["original_bytes"], 1024, MAX_CLIP)
    require({k: item[k] for k in ("workflow_id", "workflow_path")} in p["importers"],
            "Historical packager not allowlisted")
    # Initial import is intentionally bounded to the exact reviewed pilot, not
    # a general URL fetch or a claim that old CI generated a local recording.
    require(m["source"]["pr"] == 3031 and
            m["source"]["commit"] == "861a04010f2819493d5c37d0adf542eea9b78988" and
            m["source"]["owner"] == "valzargaming" and
            item["original_url"] == "https://github.com/user-attachments/assets/7fee86f7-834c-44cd-a974-c6b269935c6d" and
            item["original_sha256"] == "e5531e7848fe47ce02f0dad8b60ceb2f8b07f9147a75a610ae7f5cf5cea55392" and
            item["original_bytes"] == 1080430 and item["source_comment_id"] == 6107609332 and
            item["transformation"] == "mask-game-id-pr3031-v1" and
            m["clip"]["sha256"] == "7a0605e3e4c799beaf76fbd5b9b02ddf27a80fb9e5c4df28853248b742851456" and
            m["clip"]["bytes"] == 1308770 and m["clip"]["duration_seconds"] == 41,
            "Historical import differs from the approved masked PR3031 media")


def approval_hash(m):
    if m["schema_version"] == 2:
        payload = {k: m[k] for k in ("repository", "channel_id", "channel_handle", "privacy", "source", "clip", "metadata", "review")}
        payload["original"] = {k: v for k, v in m["import"].items()
            if k not in {"run_id", "run_attempt", "workflow_id", "workflow_path", "commit"}}
        # Only transport run/artifact identifiers are learned later. Exact media,
        # metadata, public visibility, source attestation and limits are pinned
        # to the owner's already received approval, never arbitrary chat text.
        return digest(b"civ13-youtube-approval-v2\n" + canonical(payload))
    payload = {k: v for k, v in m.items() if k != "approval"}
    return digest(b"civ13-youtube-approval-v1\n" + canonical(payload))


def approval_text(m):
    return (f"I approve Civ13 YouTube upload {approval_hash(m)} to "
            f"{HANDLE} ({CHANNEL}) as public.")


def receipt_key(m):
    return digest(("civ13-youtube-v1\n" + REPO + "\n" +
                   m["source"]["commit"] + "\n" + m["clip"]["sha256"]).encode())


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class Transport:
    def __init__(self):
        self.opener = urllib.request.build_opener(NoRedirect())

    def request(self, method, url, headers=None, body=None, limit=MAX_JSON):
        # No retries: mutation failures may have succeeded remotely. No raw errors.
        try:
            response = self.opener.open(urllib.request.Request(
                url, data=body, headers=headers or {}, method=method), timeout=120)
        except urllib.error.HTTPError as error:
            if error.code == 302:
                return 302, dict(error.headers), b""
            raise Refused(f"HTTP {error.code}; stop and inspect sanitized service status") from None
        except (OSError, ValueError):
            raise Refused("Network outcome uncertain; do not retry an upload") from None
        with response:
            data = response.read(limit + 1)
            require(len(data) <= limit, "Response exceeds cap")
            return response.status, dict(response.headers), data


def header(headers, name):
    return next((v for k, v in headers.items() if k.lower() == name.lower()), "")


class GitHub:
    def __init__(self, transport, token):
        self.transport, self.token = transport, token

    def request(self, path, method="GET", value=None):
        require(path.startswith("/") and ".." not in path and "\n" not in path, "Invalid API path")
        status, headers, raw = self.transport.request(method, "https://api.github.com" + path,
            {"Authorization": "Bearer " + self.token, "Accept": "application/vnd.github+json",
             "X-GitHub-Api-Version": "2022-11-28", "Content-Type": "application/json"},
            canonical(value) if value is not None else None)
        require(status in {200, 201}, "Unexpected GitHub response")
        return parse_json(raw)

    def repo(self, path, **kwargs):
        return self.request("/repos/" + REPO + path, **kwargs)

    def archive(self, artifact_id):
        status, headers, raw = self.transport.request("GET",
            f"https://api.github.com/repos/{REPO}/actions/artifacts/{artifact_id}/zip",
            {"Authorization": "Bearer " + self.token})
        require(status == 302, "Artifact download must use a signed redirect")
        url = header(headers, "Location")
        parsed = urllib.parse.urlsplit(url)
        require(parsed.scheme == "https" and parsed.port in {None, 443} and
                not parsed.username and not parsed.password and parsed.hostname and
                (parsed.hostname.endswith(".blob.core.windows.net") or
                 parsed.hostname.endswith(".actions.githubusercontent.com")),
                "Untrusted artifact redirect")
        # New request has NO GitHub Authorization header, even to signed storage.
        status, headers, raw = self.transport.request("GET", url, limit=MAX_ARCHIVE)
        require(status == 200 and header(headers, "Content-Type").split(";")[0].lower()
                in {"application/zip", "application/octet-stream", "application/x-zip-compressed"},
                "Artifact is not a ZIP response")
        return raw


def validate_repository(gh):
    repo = gh.repo("")
    require(repo["id"] == REPO_ID and repo["full_name"] == REPO and
            repo["visibility"] == "public" and repo["default_branch"] == "master",
            "Require the public repository/default branch; stop if billing assumptions change")


def validate_source_provenance(gh, m, p):
    validate_repository(gh)
    s = m["source"]
    run = gh.repo(f'/actions/runs/{s["run_id"]}')
    require(run["id"] == s["run_id"] and run["repository"]["id"] == REPO_ID and
            run["head_repository"]["id"] == REPO_ID and run["status"] == "completed" and
            run["conclusion"] == "success" and run["run_attempt"] == s["run_attempt"] and
            run["workflow_id"] == s["workflow_id"] and run["path"] == s["workflow_path"] and
            run["head_sha"] == s["commit"] and run["head_branch"] == s["head_branch"] and
            run["event"] == s["event"], "Producer run provenance mismatch")
    pr = gh.repo(f'/pulls/{s["pr"]}')
    require(pr["base"]["repo"]["id"] == REPO_ID and pr["head"]["repo"]["id"] == REPO_ID,
            "Fork PR artifacts are not initially eligible")
    if s["event"] == "pull_request":
        if m["schema_version"] == 2 and run["pull_requests"] == []:
            # Historical merged runs can have an empty Actions association.
            # Keep this alternative confined to the pinned historical pilot:
            # both the PR and GitHub's commit association must prove exact head.
            associated = gh.repo(f'/commits/{s["commit"]}/pulls?per_page=100')
            require(pr["merged"] is True and pr["head"]["sha"] == s["commit"] and
                    any(item["number"] == s["pr"] and item["head"]["sha"] == s["commit"] and
                        item["base"]["repo"]["id"] == REPO_ID and
                        item["head"]["repo"]["id"] == REPO_ID for item in associated),
                    "Historical commit is not the exact merged PR head")
        else:
            require(any(item["number"] == s["pr"] for item in run["pull_requests"]),
                    "Run does not belong to the selected PR")
    else:
        require(pr["merged"] is True and pr["merge_commit_sha"] == s["commit"],
                "Non-PR capture must test the exact merged PR commit")


def validate_import_attestation(gh, m):
    s, item = m["source"], m["import"]
    comment = gh.repo(f'/issues/comments/{item["source_comment_id"]}')
    require(comment["user"]["type"] == "User" and comment["user"]["login"] == s["owner"] and
            comment["issue_url"] == f'https://api.github.com/repos/{REPO}/issues/{s["pr"]}' and
            digest(comment["body"].encode()) == item["source_comment_sha256"] and
            item["original_url"] in comment["body"] and s["commit"] in comment["body"],
            "Original owner attachment attestation changed or belongs to another PR")


def validate_provenance(gh, m, p):
    validate_source_provenance(gh, m, p)
    s, a = m["source"], m["artifact"]
    origin = s
    if m["schema_version"] == 2:
        item = m["import"]
        validate_import_attestation(gh, m)
        imported = gh.repo(f'/actions/runs/{item["run_id"]}')
        require(imported["id"] == item["run_id"] and imported["repository"]["id"] == REPO_ID and
                imported["head_repository"]["id"] == REPO_ID and imported["status"] == "completed" and
                imported["conclusion"] == "success" and imported["run_attempt"] == item["run_attempt"] and
                imported["workflow_id"] == item["workflow_id"] and imported["path"] == item["workflow_path"] and
                imported["head_sha"] == item["commit"] and imported["head_branch"] == "master" and
                imported["event"] == "workflow_dispatch",
                "Historical packaging run must be its own trusted successful master dispatch")
        origin = item
    artifact = gh.repo(f'/actions/artifacts/{a["id"]}')
    require(artifact["id"] == a["id"] and artifact["name"] == a["name"] and
            artifact["expired"] is False and artifact["size_in_bytes"] == a["bytes"] and
            artifact["digest"] == "sha256:" + a["archive_sha256"] and
            artifact["workflow_run"]["id"] == origin["run_id"] and
            artifact["workflow_run"]["head_sha"] == origin["commit"] and
            artifact["workflow_run"]["repository_id"] == REPO_ID and
            artifact["workflow_run"]["head_repository_id"] == REPO_ID,
            "Artifact provenance/digest mismatch")
    # Artifact attempts cannot be inferred from its name. Require creation inside
    # the approved attempt's timestamps, and verify that exact attempt separately.
    attempt = gh.repo(f'/actions/runs/{origin["run_id"]}/attempts/{origin["run_attempt"]}')
    require(attempt["run_attempt"] == origin["run_attempt"] and attempt["conclusion"] == "success" and
            attempt["status"] == "completed" and attempt["head_sha"] == origin["commit"] and
            attempt["run_started_at"] <= artifact["created_at"] <= attempt["updated_at"],
            "Artifact not from approved successful attempt")
    validate_approval(gh, m, p)


def validate_approval(gh, m, p):
    if m["schema_version"] == 2:
        require(m["approval"] == {"authorization_id": PILOT_AUTHORIZATION_ID} and
                approval_hash(m) == PILOT_APPROVAL_DIGEST and p["approvers"] == ["valzargaming"],
                "Missing exact recorded owner approval for the public pilot")
        return
    approval = gh.repo(f'/issues/comments/{m["approval"]["comment_id"]}')
    require(approval["user"]["type"] == "User" and approval["user"]["login"] in p["approvers"] and
            approval["issue_url"] == f'https://api.github.com/repos/{REPO}/issues/{m["approval"]["issue_number"]}' and
            approval["body"] == approval_text(m) and
            isinstance(approval.get("created_at"), str) and
            re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z", approval["created_at"]) and
            approval.get("updated_at") == approval["created_at"],
            "Missing exact human per-clip approval without edit evidence")


def inspect_archive(raw, m):
    require(len(raw) == m["artifact"]["bytes"] and digest(raw) == m["artifact"]["archive_sha256"],
            "Downloaded archive digest/size mismatch")
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        entries = archive.infolist()
        require(len(entries) == 2 and {e.filename for e in entries} == {"gameplay.mp4", "evidence.json"},
                "Archive must contain exactly two flat files; no paths or duplicates")
        for entry in entries:
            mode = entry.external_attr >> 16
            require(not entry.is_dir() and not entry.flag_bits & 1 and
                    stat.S_IFMT(mode) in {0, stat.S_IFREG} and
                    entry.compress_type in {zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED},
                    "Unsupported archive entry")
            cap = MAX_CLIP if entry.filename == "gameplay.mp4" else 16384
            require(0 < entry.file_size <= cap, "Expanded file exceeds cap")
        clip = archive.read("gameplay.mp4")
        evidence = parse_json(archive.read("evidence.json"))
    require(len(clip) == m["clip"]["bytes"] and digest(clip) == m["clip"]["sha256"],
            "Media digest/size mismatch")
    require(len(clip) >= 16 and clip[4:8] == b"ftyp" and clip[8:12] in
            {b"isom", b"iso2", b"mp41", b"mp42", b"avc1"}, "Not an allowed MP4 header")
    require(evidence == expected_evidence(m), "Embedded evidence mismatch")
    return clip


def expected_evidence(m):
    s = m["source"]
    evidence = {"schema_version": 1, "tested_commit": s["commit"],
        "run_id": s["run_id"], "run_attempt": s["run_attempt"],
        "clip_sha256": m["clip"]["sha256"], "result": "success", "classification": "genuine-gameplay"}
    if m["schema_version"] == 2:
        item = m["import"]
        evidence = {"schema_version": 2, "tested_commit": s["commit"],
            "source_ci_run_id": s["run_id"], "source_ci_run_attempt": s["run_attempt"],
            "packaging_run_id": item["run_id"], "packaging_run_attempt": item["run_attempt"],
            "packaging_commit": item["commit"], "original_sha256": item["original_sha256"],
            "source_comment_id": item["source_comment_id"], "transformation": item["transformation"],
            "clip_sha256": m["clip"]["sha256"], "result": "success", "classification": "genuine-gameplay",
            "capture_provenance": "historical-owner-attested; CI did not record this video"}
    return evidence


def probe_media(clip, expected_duration):
    # This function runs ONLY in the job without YouTube secrets. Do not add it
    # to the secret-bearing upload command; decoders consume untrusted bytes.
    version = subprocess.run(["mediainfo", "--Version"], capture_output=True, timeout=10, check=True)
    require(b"MediaInfoLib - v24.01" in version.stdout, "MediaInfo version drift; stop for review")
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "gameplay.mp4"
        path.write_bytes(clip)
        result = subprocess.run(["mediainfo", "--Output=JSON", "--ParseSpeed=0.5", str(path)],
            capture_output=True, timeout=30, check=True)
    info = parse_json(result.stdout)
    tracks = info["media"]["track"]
    general = [s for s in tracks if s["@type"] == "General"]
    require(len(general) == 1 and general[0]["Format"] == "MPEG-4" and
            abs(float(general[0]["Duration"]) - expected_duration) <= 1,
            "Container duration/type mismatch")
    video = [s for s in tracks if s["@type"] == "Video"]
    require(len(video) == 1 and video[0]["Format"] == "AVC" and
            320 <= int(video[0]["Width"]) <= 1920 and 240 <= int(video[0]["Height"]) <= 1080 and
            len(tracks) <= 3 and all(s["@type"] in {"General", "Video", "Audio"} for s in tracks) and
            all(s["Format"] == "AAC" for s in tracks if s["@type"] == "Audio"),
            "Only bounded H.264/AAC gameplay is eligible")


class Ledger:
    def __init__(self, gh):
        self.gh = gh
        file = gh.repo(f"/contents/{LEDGER_PATH}?ref={LEDGER_BRANCH}")
        self.sha = file["sha"]
        require(file["encoding"] == "base64" and file["size"] <= MAX_JSON, "Invalid ledger encoding/size")
        self.data = parse_json(base64.b64decode(file["content"], validate=False))
        keys(self.data, "schema_version channel_id imports_complete records")
        require(self.data["schema_version"] == 1 and self.data["channel_id"] == CHANNEL and
                self.data["imports_complete"] is True and isinstance(self.data["records"], dict) and
                len(self.data["records"]) <= 1000, "Ledger not initialized/reconciled or is full")
        for key, record in self.data["records"].items():
            sha(key)
            require(record["channel_id"] == CHANNEL and record["state"] in
                    {"reserved", "uploaded", "verified", "imported", "uncertain"}, "Invalid ledger record")
            sha(record["clip_sha256"])
            sha(record["commit"], 40)
            integer(record["reserved_at"], 0)
            if "video_id" in record:
                require(re.fullmatch(r"[A-Za-z0-9_-]{11}", record["video_id"]), "Invalid receipt video ID")

    def save(self):
        raw = canonical(self.data)
        require(len(raw) <= MAX_JSON, "Ledger cap reached; stop for reviewed archival plan")
        result = self.gh.repo(f"/contents/{LEDGER_PATH}", method="PUT", value={
            "message": "Record bounded YouTube upload state [skip ci]", "branch": LEDGER_BRANCH,
            "sha": self.sha, "content": base64.b64encode(raw).decode()})
        self.sha = result["content"]["sha"]

    def find(self, m):
        # Global destination+media hash guard also catches different commits and
        # imported one-off uploads. A title/manifest change cannot bypass it.
        matches = [r for r in self.data["records"].values()
                   if r["clip_sha256"] == m["clip"]["sha256"] and r["channel_id"] == CHANNEL]
        require(len(matches) <= 1, "Conflicting duplicate receipts require reconciliation")
        return matches[0] if matches else None

    def reserve(self, m, now):
        require(self.find(m) is None and len(self.data["records"]) < 1000, "Already reserved or ledger full")
        require(sum(r["reserved_at"] >= now - 86400 for r in self.data["records"].values()) < 2,
                "Two-upload rolling 24-hour cap reached; stop-use")
        record = {"channel_id": CHANNEL, "clip_sha256": m["clip"]["sha256"],
                  "commit": m["source"]["commit"], "approval_sha256": approval_hash(m),
                  "artifact_id": m["artifact"]["id"], "artifact_sha256": m["artifact"]["archive_sha256"],
                  "artifact_name": m["artifact"]["name"], "artifact_bytes": m["artifact"]["bytes"],
                  "run_id": m["source"]["run_id"], "run_attempt": m["source"]["run_attempt"],
                  "privacy": m["privacy"], "state": "reserved", "reserved_at": now}
        if m["schema_version"] == 2:
            record["historical_import"] = dict(m["import"])
        self.data["records"][receipt_key(m)] = record
        self.save()  # MUST succeed before initiating ANY YouTube mutation.
        return record


class PhpYouTube:
    """YoutubePHP owns OAuth and video API I/O; Python owns approval/receipts."""
    def call(self, mode, **values):
        adapter = Path(__file__).with_name("adapter.php")
        try:
            result = subprocess.run(["php", "-d", "display_errors=0", "-d", "memory_limit=256M", str(adapter)],
                input=canonical({"mode": mode, **values}), capture_output=True, timeout=240)
        except (OSError, subprocess.TimeoutExpired):
            raise Refused("YoutubePHP outcome uncertain; inspect durable receipt before retry") from None
        require(result.returncode == 0, "YoutubePHP stopped; inspect durable receipt before retry")
        return parse_json(result.stdout)

    def channel(self):
        require(self.call("channel") == {"channel_id": CHANNEL}, "Wrong OAuth channel")

    def upload(self, m, clip):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "gameplay.mp4"
            path.write_bytes(clip)
            path.chmod(0o600)
            result = self.call("upload", media_path=str(path), clip=m["clip"], metadata=m["metadata"])
        video_id = result.get("video_id")
        require(isinstance(video_id, str) and re.fullmatch(r"[A-Za-z0-9_-]{11}", video_id),
                "YoutubePHP returned no valid video ID; inspect reservation")
        return video_id

    def verify(self, video_id):
        require(self.call("verify", video_id=video_id) == {"verified": True},
                "YoutubePHP did not verify processing/public visibility")


def publish(m, clip, ledger, youtube, now):
    youtube.channel()  # Same grant's read scope proves upload destination first.
    record = ledger.find(m)
    if record is None:
        record = ledger.reserve(m, now)
        record["video_id"] = youtube.upload(m, clip)
        record["state"] = "uploaded"
        ledger.save()  # If this fails, durable reservation still blocks a retry.
    else:
        require(record["state"] != "uncertain", "Uncertain outcome requires explicit owner reconciliation")
        require("video_id" in record, "Uncertain/reserved outcome: reconcile before any retry")
        require(record.get("privacy") == m["privacy"],
                "Existing receipt privacy requires owner reconciliation; never change old videos automatically")
    youtube.verify(record["video_id"])
    record["state"], record["verified_at"] = "verified", now
    ledger.save()
    return "https://youtu.be/" + record["video_id"]


def load_inputs(root, manifest_id):
    require(re.fullmatch(r"[a-z0-9][a-z0-9-]{0,63}", manifest_id), "Invalid manifest ID")
    policy_path = root / "tools/youtube/policy.json"
    manifest_path = root / "tools/youtube/approved" / (manifest_id + ".json")
    for path in (policy_path, manifest_path):
        require(path.is_file() and not path.is_symlink() and root in path.resolve().parents,
                "Reviewed policy/manifest absent or unsafe")
    p, m = parse_json(policy_path.read_bytes()), parse_json(manifest_path.read_bytes())
    validate_policy(p)
    validate_manifest(m, p)
    return p, m


def existing_receipt(m, ledger):
    record = ledger.find(m)
    require(record is not None and record["state"] in {"uploaded", "verified", "imported"} and
            "video_id" in record and record.get("privacy") == m["privacy"],
            "Verification-only requires a reconciled receipt with matching privacy and a known video ID")
    return record


def verify_existing(m, ledger, youtube, now):
    # No clip/archive, upload call or reservation path exists in this operation.
    record = existing_receipt(m, ledger)
    youtube.channel()
    youtube.verify(record["video_id"])
    record["state"], record["verified_at"] = "verified", now
    ledger.save()
    return "https://youtu.be/" + record["video_id"]


def require_upload_gate():
    require(os.environ.get("YOUTUBE_UPLOAD_ENABLED") == "true" and
            os.environ.get("YOUTUBE_UPLOAD_STOP_USE") == "false" and
            os.environ.get("YOUTUBE_ZERO_COST_CONFIRMED") == "true",
            "Upload disabled or budget/stop-use gate closed")


def require_trusted_dispatch():
    require(os.environ.get("GITHUB_REPOSITORY") == REPO and
            os.environ.get("GITHUB_REF") == "refs/heads/master" and
            os.environ.get("GITHUB_EVENT_NAME") == "workflow_dispatch" and
            os.environ.get("GITHUB_WORKFLOW_REF") ==
            REPO + "/.github/workflows/youtube-upload.yml@refs/heads/master",
            "Only the trusted default-branch manual workflow may run")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("inspect", "upload", "approval", "dry-run"))
    parser.add_argument("--manifest", default=os.environ.get("MANIFEST_ID", ""))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    import_run = os.environ.get("IMPORT_RUN_ID", "")
    if import_run:
        require(args.mode in {"inspect", "upload"} and args.manifest == "pr3031-power-public" and
                re.fullmatch(r"[1-9][0-9]{0,14}", import_run), "Invalid historical pilot selection")
        require_trusted_dispatch()
        from prepare_import import resolve_pilot, resolve_pilot_receipt
        pilot_gh = GitHub(Transport(), os.environ["GITHUB_TOKEN"])
        if os.environ.get("VERIFY_ONLY", "false") == "true":
            p, m = resolve_pilot_receipt(pilot_gh, int(import_run))
        else:
            p, m = resolve_pilot(pilot_gh, int(import_run), os.environ["GITHUB_SHA"])
    else:
        p, m = load_inputs(root, args.manifest)
    if args.mode == "approval":
        print(approval_text(m))
        return
    if args.mode == "dry-run":
        # Deliberately has no network, OAuth, receipt writes or upload call.
        print("No-live dry run: reviewed manifest valid; approval digest " + approval_hash(m))
        return
    require_trusted_dispatch()
    transport = Transport()
    gh = GitHub(transport, os.environ["GITHUB_TOKEN"])
    verify_only = os.environ.get("VERIFY_ONLY", "false")
    require(verify_only in {"true", "false"}, "Invalid verification-only flag")
    if verify_only == "true":
        # Expired/deleted artifacts and a rerun producer cannot prevent readback
        # of an already durable video ID. Current human approval still applies.
        validate_repository(gh)
        validate_approval(gh, m, p)
        ledger = Ledger(gh)
        existing_receipt(m, ledger)
        if args.mode == "inspect":
            print("Approved durable receipt checked; verification-only cannot insert media")
            return
        require_upload_gate()
        print("Verified public upload: " + verify_existing(m, ledger, PhpYouTube(), int(time.time())))
        return
    validate_provenance(gh, m, p)
    clip = inspect_archive(gh.archive(m["artifact"]["id"]), m)
    if args.mode == "inspect":
        probe_media(clip, m["clip"]["duration_seconds"])
        print("Approved source provenance, bounded media and per-clip approval checked")
        return
    require_upload_gate()
    ledger = Ledger(gh)  # Missing ledger is an error, never initialize on the fly.
    youtube = PhpYouTube()
    url = publish(m, clip, ledger, youtube, int(time.time()))
    print("Verified public upload: " + url)


if __name__ == "__main__":
    try:
        main()
    except Refused as error:
        print("Upload stopped: " + str(error), file=sys.stderr)
        sys.exit(1)
    except Exception:
        # No traceback or upstream response payloads: they may contain OAuth or
        # signed session URLs. Receipt state explains whether reconciliation is needed.
        print("Upload stopped: validation/service failure; inspect durable receipt before retry", file=sys.stderr)
        sys.exit(1)
