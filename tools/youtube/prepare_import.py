"""Credential-free, manual import of two exact reviewed historical clips.

This packages existing bytes. It never records a game, transforms footage, grants
OAuth access or uploads to YouTube. Media transport uses public GitHub attachment
URLs only. Both clips are pinned by their complete reviewed material digest;
PR3081 still requires an exact human approval comment before upload inspection.
"""
import argparse
import json
import os
from pathlib import Path
import re
import sys
import urllib.parse

import upload as u

WORKFLOW_PATH = ".github/workflows/youtube-prepare-import.yml"
PILOT_ID = "pr3031-power-public"
ARTIFACT_NAME = "gameplay-video-pr3031-power-public"
IMPORTS = {PILOT_ID: "pr3031.json", "pr3081-attachments-public": "pr3081.json"}


def specification(manifest_id=PILOT_ID):
    u.require(manifest_id in IMPORTS, "Historical clip not enrolled")
    return u.parse_json((Path(__file__).parent / "imports" / IMPORTS[manifest_id]).read_bytes())


def material(spec, run):
    m = {k: spec[k] for k in ("repository", "channel_id", "channel_handle", "privacy", "source", "clip", "metadata", "review")}
    approval = ({"authorization_id": spec["authorization_id"]} if "authorization_id" in spec
                else dict(spec["approval"]))
    m.update(schema_version=2, approval=approval)
    m["import"] = dict(spec["original"], run_id=run["id"], run_attempt=run["run_attempt"],
                       workflow_id=run["workflow_id"], workflow_path=WORKFLOW_PATH, commit=run["head_sha"])
    return m


def policy(m):
    p = {k: m[k] for k in ("repository", "channel_id", "channel_handle")}
    p.update(schema_version=2, repository_id=u.REPO_ID, approvers=["valzargaming"],
        producers=[{k: m["source"][k] for k in ("workflow_id", "workflow_path")}],
        importers=[{k: m["import"][k] for k in ("workflow_id", "workflow_path")}])
    u.validate_policy(p)
    u.validate_import_spec(m, p)
    if m["source"]["pr"] == 3031:
        u.validate_approval(None, m, p)
    return p


def select_material(spec, run, approval_comment_id):
    m = material(spec, run)
    if m["source"]["pr"] == 3081:
        u.integer(approval_comment_id)
        m["approval"]["comment_id"] = approval_comment_id
    else:
        u.require(approval_comment_id is None, "Pilot approval cannot be replaced")
    return m


def public_media(transport, url, expected_bytes, expected_sha):
    u.require(isinstance(url, str) and re.fullmatch(
        r"https://github\.com/user-attachments/assets/[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}", url),
        "Select only a public GitHub attachment containing the exact reviewed masked bytes")
    u.integer(expected_bytes, 1024, u.MAX_CLIP)
    current = url
    for _ in range(3):
        # Deliberately no Authorization header or cookies, including redirects.
        status, headers, raw = transport.request("GET", current, limit=u.MAX_CLIP)
        if status == 200:
            u.require(u.header(headers, "Content-Type").split(";")[0].lower() in
                {"video/mp4", "application/octet-stream"} and len(raw) == expected_bytes and
                u.digest(raw) == expected_sha, "Attachment MIME/size/hash differs from approved media")
            return raw
        u.require(status == 302, "Attachment request stopped; no retry")
        current = u.header(headers, "Location")
        parsed = urllib.parse.urlsplit(current)
        host = parsed.hostname or ""
        u.require(parsed.scheme == "https" and parsed.port in {None, 443} and
            not parsed.username and not parsed.password and
            (host.endswith(".githubusercontent.com") or re.fullmatch(
                r"github-production-user-asset-[a-z0-9]+\.s3\.amazonaws\.com", host)),
            "Untrusted attachment redirect")
    raise u.Refused("Attachment redirect cap reached")


def resolve_pilot(gh, run_id, trusted_commit, manifest_id=PILOT_ID, approval_comment_id=None):
    u.integer(run_id)
    u.sha(trusted_commit, 40)
    run = gh.repo(f"/actions/runs/{run_id}")
    workflow = gh.repo("/actions/workflows/youtube-prepare-import.yml")
    u.require(workflow["path"] == WORKFLOW_PATH and workflow["state"] == "active" and
        workflow["id"] == run["workflow_id"] and run["head_sha"] == trusted_commit,
        "Import must use the current trusted dispatch commit and actual enrolled workflow identity")
    m = select_material(specification(manifest_id), run, approval_comment_id)
    p = policy(m)
    artifacts = gh.repo(f"/actions/runs/{run_id}/artifacts?per_page=10")
    u.require(artifacts["total_count"] <= 10 and len(artifacts["artifacts"]) == artifacts["total_count"],
        "Unexpected import artifact inventory")
    selected = [a for a in artifacts["artifacts"] if a["name"] == "gameplay-video-" + manifest_id]
    u.require(len(selected) == 1, "Require one exact pilot artifact")
    item = selected[0]
    u.require(item["digest"].startswith("sha256:"), "Artifact digest missing")
    m["artifact"] = {"id": item["id"], "name": item["name"],
        "archive_sha256": item["digest"][7:], "bytes": item["size_in_bytes"]}
    # Full structural and API provenance validation happens before any OAuth.
    u.validate_manifest(m, p)
    u.validate_provenance(gh, m, p)
    return p, m


def resolve_pilot_receipt(gh, run_id, manifest_id=PILOT_ID, approval_comment_id=None):
    # Known-ID readback must survive artifact expiry and later master commits.
    u.integer(run_id)
    u.validate_repository(gh)
    spec = specification(manifest_id)
    records = [r for r in u.Ledger(gh).data["records"].values()
        if r["clip_sha256"] == spec["clip"]["sha256"] and r["channel_id"] == u.CHANNEL]
    u.require(len(records) == 1, "No unique pilot receipt")
    record = records[0]
    item = record.get("historical_import", {})
    u.require(item.get("run_id") == run_id, "Pilot receipt importer mismatch")
    m = select_material(spec, {"id": item["run_id"], "run_attempt": item["run_attempt"],
        "workflow_id": item["workflow_id"], "head_sha": item["commit"]}, approval_comment_id)
    u.require(m["import"] == item, "Pilot receipt source provenance mismatch")
    p = policy(m)
    m["artifact"] = {"id": record["artifact_id"], "name": record["artifact_name"],
        "archive_sha256": record["artifact_sha256"], "bytes": record["artifact_bytes"]}
    u.validate_manifest(m, p)
    u.existing_receipt(m, u.Ledger(gh))
    return p, m


def prepare(gh, transport, spec, run_id, run_attempt, trusted_commit, url, destination):
    run = gh.repo(f"/actions/runs/{run_id}")
    u.require(run["id"] == run_id and run["run_attempt"] == run_attempt and
        run["head_sha"] == trusted_commit and run["head_branch"] == "master" and
        run["event"] == "workflow_dispatch" and run["path"] == WORKFLOW_PATH and
        run["repository"]["id"] == u.REPO_ID and run["head_repository"]["id"] == u.REPO_ID,
        "Only the trusted master packaging job may prepare a historical import")
    m = material(spec, run)
    p = policy(m)
    u.validate_source_provenance(gh, m, p)
    u.validate_import_attestation(gh, m)
    # Verify the original source bytes as well as the approved review copy.
    original = spec["original"]
    public_media(transport, original["original_url"], original["original_bytes"], original["original_sha256"])
    clip = public_media(transport, url, m["clip"]["bytes"], m["clip"]["sha256"])
    u.probe_media(clip, m["clip"]["duration_seconds"])
    u.require(destination.is_absolute() and not destination.exists(), "Use a fresh absolute import output directory")
    destination.mkdir(mode=0o700)
    (destination / "gameplay.mp4").write_bytes(clip)
    (destination / "evidence.json").write_bytes(u.canonical(u.expected_evidence(m)))
    return m


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("prepare", "probe-smoke", "approval"))
    args = parser.parse_args()
    manifest_id = os.environ.get("MANIFEST_ID", PILOT_ID)
    spec = specification(manifest_id)
    if args.mode == "approval":
        # Offline preview only: no assertion that the human has approved it.
        m = material(spec, {"id": 1, "run_attempt": 1, "workflow_id": 1, "head_sha": "0" * 40})
        policy(m)
        print(u.approval_text(m))
        return
    if args.mode == "probe-smoke":
        original = spec["original"]
        clip = public_media(u.Transport(), original["original_url"], original["original_bytes"], original["original_sha256"])
        duration = 40.56 if manifest_id == PILOT_ID else spec["clip"]["duration_seconds"]
        u.probe_media(clip, duration)
        print("Real public source MP4 parsed with pinned runner MediaInfo; no game, grant or upload")
        return
    u.require(os.environ.get("GITHUB_REPOSITORY") == u.REPO and
        os.environ.get("GITHUB_REF") == "refs/heads/master" and
        os.environ.get("GITHUB_EVENT_NAME") == "workflow_dispatch" and
        os.environ.get("GITHUB_WORKFLOW_REF") == u.REPO + "/" + WORKFLOW_PATH + "@refs/heads/master",
        "Historical packaging is manual and default-branch only")
    run_id, attempt = int(os.environ["GITHUB_RUN_ID"]), int(os.environ["GITHUB_RUN_ATTEMPT"])
    u.integer(run_id)
    u.integer(attempt)
    commit = os.environ["GITHUB_SHA"]
    u.sha(commit, 40)
    transport = u.Transport()
    gh = u.GitHub(transport, os.environ["GITHUB_TOKEN"])
    prepare(gh, transport, spec, run_id, attempt, commit, os.environ["REVIEWED_MEDIA_URL"],
        Path(os.environ["RUNNER_TEMP"]) / "youtube-import-bundle")
    print("Exact owner-approved masked bytes prepared; source CI and packaging provenance remain separate")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("Historical import stopped; values redacted; no upload performed", file=sys.stderr)
        sys.exit(1)
