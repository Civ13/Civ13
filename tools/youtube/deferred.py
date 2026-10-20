"""Default-off durable deferral. Never opens gates, uploads media or grants access."""
import argparse
import base64
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
import os
from pathlib import Path
import re
import time

import upload as u

QUEUE_PATH = "deferred.json"
WORKFLOW = ".github/workflows/youtube-deferred.yml"
MAX_ATTEMPTS = 6
MAX_LIFETIME = 7 * 86400
DISPATCH_GRACE = 900
STATES = {"waiting", "dispatching", "running", "completed", "cancelled", "expired", "blocked", "exhausted"}
TERMINAL = {"completed", "cancelled", "expired", "blocked", "exhausted"}
# PR3031 has a separate exact reviewed masked transport. Original capture bytes
# remain provenance data and can never substitute for the approved clip.
REVIEWED_TRANSPORTS = {
    "7a0605e3e4c799beaf76fbd5b9b02ddf27a80fb9e5c4df28853248b742851456":
        "https://github.com/user-attachments/assets/ac354200-2525-4ea4-857e-eaf0c7b86f2d"}
FIELDS = ("manifest_id approval_sha256 approval_comment_id created_at expires_at next_eligible_at "
          "attempts generation state reason hold_reason stage token active_run_id dispatch_started_at "
          "import_run_id trusted_commit updated_at video_id channel_id clip_sha256")


def utc(value):
    return datetime.fromtimestamp(value, timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")


def rolling_eligible_at(records, now):
    """Existing reserve guard is inclusive: a timestamp ages out at t+86401."""
    u.integer(now, 0)
    active = []
    for record in records:
        stamp = record["reserved_at"]
        u.integer(stamp, 0)
        u.require(stamp <= now + 300, "Future reservation clock skew; stop for reconciliation")
        if stamp >= now - 86400:
            active.append(stamp)
    return sorted(active)[-2] + 86401 if len(active) >= 2 else now


def retry_after_at(raw, now):
    """A valid bounded Retry-After is a positive secondary-limit signal."""
    value = None
    if re.fullmatch(r"[0-9]{1,7}", raw):
        value = now + int(raw)
    elif 1 <= len(raw) <= 80:
        try:
            date = parsedate_to_datetime(raw)
            if date.tzinfo is not None:
                value = int(date.timestamp())
        except (TypeError, ValueError, OverflowError):
            pass
    return value if value is not None and now <= value <= now + MAX_LIFETIME else None


def retry_at(headers, now, attempt=0):
    """Only sanitized TLS-provider headers, never response bodies or URLs."""
    u.integer(now, 0)
    u.integer(attempt, 0, MAX_ATTEMPTS)
    values = {str(k).lower(): str(v) for k, v in headers.items()}
    after = retry_after_at(values.get("retry-after", ""), now)
    candidates = [after] if after is not None else []
    reset = values.get("x-ratelimit-reset", "")
    if re.fullmatch(r"[0-9]{1,12}", reset):
        candidates.append(int(reset))
    candidates = [v for v in candidates if now <= v <= now + MAX_LIFETIME]
    # Unknown limits get a conservative finite backoff; no zero-delay spinning.
    return max([now + 60, *candidates]) if candidates else now + min(86400, 3600 * 2 ** attempt)


def key(m):
    return u.digest((u.CHANNEL + "\n" + m["clip"]["sha256"]).encode())


def reviewed_transport(m):
    if m["clip"]["sha256"] == m["import"]["original_sha256"]:
        return m["import"]["original_url"]
    u.require(m["clip"]["sha256"] in REVIEWED_TRANSPORTS and u.approval_hash(m) == u.PILOT_APPROVAL_DIGEST,
              "Reviewed derivative transport absent; never substitute unmasked original")
    return REVIEWED_TRANSPORTS[m["clip"]["sha256"]]


class Queue:
    def __init__(self, gh):
        self.gh = gh
        item = gh.repo(f"/contents/{QUEUE_PATH}?ref={u.LEDGER_BRANCH}")
        u.require(item["encoding"] == "base64" and item["size"] <= u.MAX_JSON,
                  "Deferred queue missing or too large; owner initialization required")
        self.sha = item["sha"]
        self.data = u.parse_json(base64.b64decode(item["content"]))
        u.keys(self.data, "schema_version channel_id records")
        u.require(self.data["schema_version"] == 1 and self.data["channel_id"] == u.CHANNEL and
                  isinstance(self.data["records"], dict) and len(self.data["records"]) <= 100,
                  "Invalid deferred queue")
        for ident, entry in self.data["records"].items():
            u.sha(ident)
            validate_entry(ident, entry)

    def save(self):
        raw = u.canonical(self.data)
        u.require(len(raw) <= u.MAX_JSON, "Deferred queue exceeds cap")
        result = self.gh.repo(f"/contents/{QUEUE_PATH}", method="PUT", value={
            "message": "Record reviewed YouTube deferral [skip ci]", "branch": u.LEDGER_BRANCH,
            "sha": self.sha, "content": base64.b64encode(raw).decode()})
        self.sha = result["content"]["sha"]

    def enqueue(self, manifest_id, m, import_run_id, now, next_time, reason):
        from prepare_import import IMPORTS
        u.require(manifest_id in IMPORTS, "Only enrolled immutable historical clips can be deferred")
        ident = key(m)
        previous = self.data["records"].get(ident)
        if previous is not None:
            u.require(previous["approval_sha256"] == u.approval_hash(m),
                      "Existing queue material differs; explicit owner reconciliation required")
            return ident, previous  # Never revive cancelled/blocked/expired or reset attempts.
        u.require(len(self.data["records"]) < 100, "Deferred queue full")
        self.data["records"][ident] = {
            "manifest_id": manifest_id, "approval_sha256": u.approval_hash(m),
            "approval_comment_id": m["approval"].get("comment_id"), "created_at": now,
            "expires_at": now + MAX_LIFETIME, "next_eligible_at": next_time,
            "attempts": 0, "generation": 0, "state": "waiting", "reason": reason,
            "hold_reason": "", "stage": "upload", "token": "", "active_run_id": None,
            "dispatch_started_at": 0, "import_run_id": import_run_id,
            "trusted_commit": "", "updated_at": now, "video_id": None,
            "channel_id": u.CHANNEL, "clip_sha256": m["clip"]["sha256"]}
        self.save()  # An uncertain CAS means no dispatch or media mutation follows.
        return ident, self.data["records"][ident]


def validate_entry(ident, entry):
    u.keys(entry, FIELDS)
    u.require(re.fullmatch(r"[a-z0-9][a-z0-9-]{0,63}", entry["manifest_id"]) and
              entry["channel_id"] == u.CHANNEL and entry["state"] in STATES and
              entry["stage"] in {"import", "upload", "verify"}, "Invalid deferred entry")
    u.sha(entry["clip_sha256"])
    u.sha(entry["approval_sha256"])
    u.require(ident == u.digest((u.CHANNEL + "\n" + entry["clip_sha256"]).encode()), "Queue key mismatch")
    for name in ("created_at", "expires_at", "next_eligible_at", "dispatch_started_at", "updated_at"):
        u.integer(entry[name], 0)
    u.require(entry["created_at"] < entry["expires_at"] <= entry["created_at"] + MAX_LIFETIME,
              "Deferred lifetime exceeds cap")
    for name in ("attempts", "generation"):
        u.integer(entry[name], 0, MAX_ATTEMPTS)
    for name in ("approval_comment_id", "import_run_id", "active_run_id"):
        if entry[name] is not None:
            u.integer(entry[name])
    for name in ("reason", "hold_reason"):
        u.require(re.fullmatch(r"[a-z0-9_-]{0,80}", entry[name]), "Invalid deferred reason")
    if entry["token"]:
        u.sha(entry["token"])
    if entry["trusted_commit"]:
        u.sha(entry["trusted_commit"], 40)
    if entry["video_id"]:
        u.require(re.fullmatch(r"[A-Za-z0-9_-]{11}", entry["video_id"]), "Invalid queued video ID")


def controls(gh, now):
    """Read BOTH scopes freshly. This module has no variable-write operation."""
    repo = gh.repo("/actions/variables?per_page=100")
    env = gh.repo("/environments/youtube-unlisted/variables?per_page=100")
    values = []
    for data in (repo, env):
        u.require(data["total_count"] <= 100 and len(data["variables"]) == data["total_count"],
                  "Variable inventory exceeds bounded page")
        values.append({v["name"]: v["value"] for v in data["variables"]})
    if values[0].get("YOUTUBE_DEFERRED_ENABLED") != "true":
        return "feature_disabled"
    if any(v.get("YOUTUBE_UPLOAD_STOP_USE") != "false" for v in values):
        return "emergency_stop"
    if any(v.get("YOUTUBE_UPLOAD_ENABLED") != "true" or v.get("YOUTUBE_ZERO_COST_CONFIRMED") != "true" for v in values):
        return "gates_closed"
    armed = values[0].get("YOUTUBE_DEFERRED_ARMED_UNTIL", "")
    if not re.fullmatch(r"[0-9]{1,12}", armed) or not now < int(armed) <= now + 900:
        return "arm_window_closed"
    return ""


def core_material(gh, entry, current_commit):
    from prepare_import import specification, select_material, policy
    workflow = gh.repo("/actions/workflows/youtube-prepare-import.yml")
    u.require(workflow["path"] == ".github/workflows/youtube-prepare-import.yml" and
              workflow["state"] == "active", "Importer unavailable")
    m = select_material(specification(entry["manifest_id"]), {
        "id": entry["import_run_id"] or 1, "run_attempt": 1,
        "workflow_id": workflow["id"], "head_sha": current_commit}, entry["approval_comment_id"])
    p = policy(m)
    u.require(key(m) == u.digest((u.CHANNEL + "\n" + entry["clip_sha256"]).encode()) and
              u.approval_hash(m) == entry["approval_sha256"], "Deferred approved material changed")
    u.validate_source_provenance(gh, m, p)
    u.validate_import_attestation(gh, m)
    u.validate_approval(gh, m, p)
    return p, m


def resolve_artifact(gh, entry, current_commit):
    from prepare_import import resolve_pilot
    if entry["import_run_id"] is None:
        return False
    run = gh.repo(f'/actions/runs/{entry["import_run_id"]}')
    if run["head_sha"] != current_commit:
        return False
    inventory = gh.repo(f'/actions/runs/{entry["import_run_id"]}/artifacts?per_page=10')
    u.require(inventory["total_count"] <= 10 and len(inventory["artifacts"]) == inventory["total_count"],
              "Importer artifact inventory is not bounded")
    selected = [a for a in inventory["artifacts"] if a["name"] == "gameplay-video-" + entry["manifest_id"]]
    if not selected or (len(selected) == 1 and selected[0]["expired"]):
        return False
    u.require(len(selected) == 1, "Conflicting importer artifacts")
    resolve_pilot(gh, entry["import_run_id"], current_commit, entry["manifest_id"], entry["approval_comment_id"])
    return True


def dispatch(gh, path, inputs):
    """One bounded native dispatch; an exception leaves the durable claim intact."""
    u.require(path in {"youtube-prepare-import.yml", "youtube-upload.yml"}, "Untrusted dispatch target")
    status, _, raw = gh.transport.request("POST", f"https://api.github.com/repos/{u.REPO}/actions/workflows/{path}/dispatches",
        {"Authorization": "Bearer " + gh.token, "Accept": "application/vnd.github+json",
         "X-GitHub-Api-Version": "2022-11-28", "Content-Type": "application/json"},
        u.canonical({"ref": "master", "inputs": inputs}))
    u.require(status == 204 and raw == b"", "Workflow dispatch outcome requires reconciliation")


def cancel_overdue_run(gh, run_id):
    status, _, _ = gh.transport.request("POST", f"https://api.github.com/repos/{u.REPO}/actions/runs/{run_id}/cancel",
        {"Authorization": "Bearer " + gh.token, "Accept": "application/vnd.github+json",
         "X-GitHub-Api-Version": "2022-11-28"})
    u.require(status in {202, 409}, "Native cancellation outcome requires owner reconciliation")


def _receipt(entry, ledger):
    matches = [r for r in ledger.data["records"].values() if
               r["channel_id"] == u.CHANNEL and r["clip_sha256"] == entry["clip_sha256"]]
    u.require(len(matches) <= 1, "Conflicting media receipts")
    return matches[0] if matches else None


def receipt_material(gh, entry, record):
    """Use the receipt's importer, not a later queued/manual reimport identity."""
    from prepare_import import resolve_pilot_receipt
    run_id = record.get("historical_import", {}).get("run_id")
    u.integer(run_id)
    _, m = resolve_pilot_receipt(gh, run_id, entry["manifest_id"], entry["approval_comment_id"])
    u.require(key(m) == u.digest((u.CHANNEL + "\n" + entry["clip_sha256"]).encode()),
              "Receipt queue identity mismatch")
    u.require(u.approval_hash(m) == entry["approval_sha256"], "Receipt approval digest mismatch")
    u.require(record.get("approval_sha256") == entry["approval_sha256"] and
              record.get("commit") == m["source"]["commit"] and
              record.get("run_id") == m["source"]["run_id"] and
              record.get("run_attempt") == m["source"]["run_attempt"] and
              record.get("privacy") == m["privacy"], "Durable receipt source/approval binding differs")
    entry["import_run_id"] = run_id
    return m


def _finish(entry, state, reason, now):
    entry.update(state=state, reason=reason, updated_at=now, hold_reason="")


def provider_wait(entry, error, now):
    u.require(error.media_attempted is False, "Media outcome cannot become provider retry eligibility")
    entry.update(reason="provider_limit", next_eligible_at=max(now + 60, error.retry_at),
                 attempts=min(MAX_ATTEMPTS, entry["attempts"] + 1), updated_at=now)


def runs_path(entry):
    workflow = "youtube-prepare-import.yml" if entry["stage"] == "import" else "youtube-upload.yml"
    since = datetime.fromtimestamp(max(0, entry["dispatch_started_at"] - 300), timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return f"/actions/workflows/{workflow}/runs?event=workflow_dispatch&branch=master&created=%3E%3D{since}&per_page=100"


def destination_busy(gh):
    # Includes manual uploads outside the queue; do not enqueue another pending review.
    for status in ("queued", "in_progress", "waiting", "pending", "requested"):
        data = gh.repo(f"/actions/workflows/youtube-upload.yml/runs?branch=master&status={status}&per_page=100")
        u.require(data["total_count"] <= 100 and len(data["workflow_runs"]) == data["total_count"],
                  "Active destination inventory is not bounded")
        if data["workflow_runs"]:
            return True
    return False


def reconcile(gh, entry, ledger, now):
    """A dispatch claim is never blindly retried, even when its HTTP outcome is lost."""
    if entry["active_run_id"] is None:
        data = gh.repo(runs_path(entry))
        u.require(data["total_count"] <= 100 and len(data["workflow_runs"]) == data["total_count"],
                  "Dispatch inventory exceeds bounded reconciliation; owner required")
        title = ("YouTube import " if entry["stage"] == "import" else "YouTube deferred ") + entry["token"]
        matches = [r for r in data["workflow_runs"] if r.get("display_title") == title and
                   r["head_sha"] == entry["trusted_commit"]]
        u.require(len(matches) <= 1, "Duplicate deferred dispatches require owner reconciliation")
        if not matches:
            if now >= entry["dispatch_started_at"] + DISPATCH_GRACE:
                _finish(entry, "blocked", "dispatch_outcome_unknown", now)
            return
        entry["active_run_id"] = matches[0]["id"]
    run = gh.repo(f'/actions/runs/{entry["active_run_id"]}')
    u.require(run["repository"]["id"] == u.REPO_ID and run["head_sha"] == entry["trusted_commit"] and
              run["event"] == "workflow_dispatch" and run["head_branch"] == "master" and
              run["run_attempt"] == 1, "Deferred run identity mismatch")
    if run["status"] != "completed":
        if now >= entry["dispatch_started_at"] + DISPATCH_GRACE:
            # Any media reservation remains untouched; cancellation never grants retry.
            _finish(entry, "blocked", "run_deadline_requires_reconciliation", now)
            cancel_overdue_run(gh, run["id"])
        return
    if entry["stage"] == "import":
        if run["conclusion"] == "success":
            entry.update(import_run_id=run["id"], active_run_id=None, state="waiting", reason="import_ready",
                         next_eligible_at=now, stage="upload", updated_at=now)
        else:
            entry.update(active_run_id=None, state="waiting", reason="import_failed",
                         next_eligible_at=retry_at({}, now, entry["attempts"]), updated_at=now)
        return
    record = _receipt(entry, ledger)
    if record:
        if record.get("video_id"):
            receipt_material(gh, entry, record)
        if record["state"] == "verified" and record.get("video_id"):
            entry["video_id"] = record["video_id"]
            _finish(entry, "completed", "verified_public", now)
        elif record["state"] in {"uploaded", "imported"} and record.get("video_id"):
            entry.update(video_id=record["video_id"], active_run_id=None, state="waiting", stage="verify",
                         reason="verify_known_id", next_eligible_at=retry_at({}, now, entry["attempts"]), updated_at=now)
        else:
            _finish(entry, "blocked", "media_outcome_uncertain", now)
    elif entry["reason"] in {"provider_limit", "rolling_cap"} and entry["state"] == "waiting":
        entry["active_run_id"] = None  # Worker positively recorded a pre-insert deferral.
    else:
        jobs = gh.repo(f'/actions/runs/{run["id"]}/jobs?per_page=100')
        u.require(jobs["total_count"] <= 100, "Job inventory too large")
        upload_jobs = [j for j in jobs["jobs"] if j["name"].endswith("/ upload")]
        if len(upload_jobs) == 1 and upload_jobs[0]["conclusion"] == "skipped":
            entry.update(active_run_id=None, state="waiting", reason="gates_closed", next_eligible_at=now, updated_at=now)
        else:
            _finish(entry, "blocked", "failed_run_requires_reconciliation", now)


def tick(gh, now, current_commit):
    u.validate_repository(gh)
    u.sha(current_commit, 40)
    u.require(gh.repo("/commits/master")["sha"] == current_commit, "Default branch moved; next scheduled tick must refresh source")
    queue, ledger = Queue(gh), u.Ledger(gh)
    # Lifetimes and retry budgets do not depend on destination inventory access.
    # A provider outage must never extend an expired item's authority.
    for entry in queue.data["records"].values():
        if entry["state"] in TERMINAL:
            continue
        if now >= entry["expires_at"]:
            _finish(entry, "expired", "queue_expired", now)
            queue.save()
            if entry["active_run_id"] is not None:
                cancel_overdue_run(gh, entry["active_run_id"])
        elif entry["active_run_id"] is None and entry["state"] == "waiting" and entry["attempts"] >= MAX_ATTEMPTS:
            _finish(entry, "exhausted", "retry_budget_exhausted", now)
            queue.save()
    # Reconcile every owner before considering another item. A controller lock is
    # separate from destination upload lock so overdue reviews can be cancelled.
    for entry in queue.data["records"].values():
        if entry["state"] not in TERMINAL and (entry["active_run_id"] is not None or
                entry["state"] in {"dispatching", "running"}):
            try:
                reconcile(gh, entry, ledger, now)
            finally:
                queue.save()
    busy = any(e["state"] in {"dispatching", "running"} or
        e["state"] == "waiting" and e["active_run_id"] is not None or
        e["state"] == "blocked" and e["reason"] == "dispatch_outcome_unknown"
        for e in queue.data["records"].values())
    candidates = [e for e in queue.data["records"].values() if e["state"] == "waiting" and
                  e["active_run_id"] is None and
                  not (e["reason"] == "provider_limit" and now < e["next_eligible_at"])]
    if not busy and not candidates:
        return queue
    try:
        busy = busy or destination_busy(gh)
    except u.RateLimited as error:
        for entry in candidates:
            provider_wait(entry, error, now)
        queue.save()
        return queue
    if busy:
        for entry in queue.data["records"].values():
            if entry["state"] == "waiting" and entry["active_run_id"] is None:
                entry.update(hold_reason="destination_busy", updated_at=now)
                queue.save()
        return queue
    for ident, entry in sorted(queue.data["records"].items(), key=lambda pair: pair[1]["created_at"]):
        if entry["state"] in TERMINAL:
            continue
        if now >= entry["expires_at"]:
            _finish(entry, "expired", "queue_expired", now)
            queue.save()
            if entry["active_run_id"] is not None:
                cancel_overdue_run(gh, entry["active_run_id"])
            continue
        if entry["active_run_id"] is not None or entry["state"] in {"dispatching", "running"}:
            try:
                reconcile(gh, entry, ledger, now)
            finally:
                queue.save()
            continue
        if entry["attempts"] >= MAX_ATTEMPTS:
            _finish(entry, "exhausted", "retry_budget_exhausted", now)
            queue.save()
            continue
        if entry["reason"] == "provider_limit" and now < entry["next_eligible_at"]:
            continue
        try:
            _, m = core_material(gh, entry, current_commit)
        except u.RateLimited as error:
            provider_wait(entry, error, now)
            queue.save()
            continue
        except u.Refused:
            _finish(entry, "blocked", "approval_or_source_invalid", now)
            queue.save()
            continue
        receipt = _receipt(entry, ledger)
        if receipt:
            if receipt.get("video_id"):
                receipt_material(gh, entry, receipt)
            if receipt["state"] == "verified" and receipt.get("video_id"):
                entry["video_id"] = receipt["video_id"]
                _finish(entry, "completed", "verified_public", now)
                queue.save()
                continue
            if receipt["state"] in {"uploaded", "imported"} and receipt.get("video_id"):
                entry.update(stage="verify", video_id=receipt["video_id"])
            else:
                _finish(entry, "blocked", "media_outcome_uncertain", now)
                queue.save()
                continue
        if entry["stage"] != "verify":
            eligible = rolling_eligible_at(ledger.data["records"].values(), now)
            if eligible > now:
                entry.update(next_eligible_at=max(entry["next_eligible_at"], eligible), reason="rolling_cap")
        try:
            entry["hold_reason"] = controls(gh, now)
        except u.RateLimited as error:
            provider_wait(entry, error, now)
            queue.save()
            continue
        entry["updated_at"] = now
        if entry["hold_reason"] or now < entry["next_eligible_at"]:
            queue.save()
            continue
        if entry["attempts"] >= MAX_ATTEMPTS:
            _finish(entry, "exhausted", "retry_budget_exhausted", now)
            queue.save()
            continue
        if entry["stage"] != "verify":
            try:
                entry["stage"] = "upload" if resolve_artifact(gh, entry, current_commit) else "import"
            except u.RateLimited as error:
                provider_wait(entry, error, now)
                queue.save()
                continue
        entry["generation"] += 1
        entry["attempts"] += 1
        entry.update(state="dispatching", reason="dispatch_pending", trusted_commit=current_commit,
                     dispatch_started_at=now, active_run_id=None,
                     token=u.digest(f'{ident}\n{entry["generation"]}\n{entry["stage"]}\n{current_commit}'.encode()))
        queue.save()  # Claim must durably win CAS BEFORE a dispatch.
        if entry["stage"] == "import":
            dispatch(gh, "youtube-prepare-import.yml", {"manifest_id": entry["manifest_id"],
                "attachment_url": reviewed_transport(m), "deferred_token": entry["token"]})
        else:
            dispatch(gh, "youtube-upload.yml", {"manifest_id": entry["manifest_id"],
                "import_run_id": str(entry["import_run_id"]),
                "approval_comment_id": str(entry["approval_comment_id"] or ""),
                "execute_upload": "true", "verify_only": "true" if entry["stage"] == "verify" else "false",
                "deferred_id": ident, "deferred_token": entry["token"]})
        break  # One dispatch per bounded tick; destination-wide concurrency remains shared.
    return queue


def worker_guard(gh, ident, token, run_id, now, commit, upload_step=False):
    u.sha(ident)
    u.sha(token)
    queue = Queue(gh)
    entry = queue.data["records"].get(ident)
    u.require(entry is not None and entry["state"] in {"dispatching", "running"} and
              entry["stage"] in {"upload", "verify"} and
              entry["token"] == token and entry["trusted_commit"] == commit and
              now < entry["expires_at"] and entry["active_run_id"] in {None, run_id},
              "Deferred ownership, expiry or cancellation changed; stop")
    if upload_step:
        u.require(controls(gh, now) == "", "Deferred arm or emergency gates closed")
        u.require(gh.repo("/commits/master")["sha"] == commit, "Deferred trusted source changed")
        entry.update(state="running", active_run_id=run_id, updated_at=now)
        queue.save()
    return entry


def defer_upload(gh, manifest_id, m, import_run_id, now, provider=None):
    """Called only after approval/provenance validation and before any media send."""
    if os.environ.get("YOUTUBE_DEFERRED_ENABLED") != "true":
        return False
    variables = gh.repo("/actions/variables?per_page=100")
    u.require(variables["total_count"] <= 100 and len(variables["variables"]) == variables["total_count"] and
              {v["name"]: v["value"] for v in variables["variables"]}.get("YOUTUBE_DEFERRED_ENABLED") == "true",
              "Deferred feature is not explicitly enabled in repository metadata")
    ledger = u.Ledger(gh)
    if ledger.find(m) is not None:
        return False  # Never turn a reserved/uncertain insertion into a retry grant.
    next_time = rolling_eligible_at(ledger.data["records"].values(), now)
    reason = "rolling_cap"
    if provider is not None:
        u.keys(provider, "kind status retry_at media_attempted")
        u.require(provider["kind"] == "rate_limit" and provider["media_attempted"] is False,
                  "Only positively pre-insert rate limits can defer")
        u.integer(provider["status"], 100, 599)
        next_time = max(next_time, retry_at({"x-ratelimit-reset": str(provider["retry_at"])}, now))
        reason = "provider_limit"
    elif next_time <= now:
        return False
    queue = Queue(gh)
    ident, entry = queue.enqueue(manifest_id, m, import_run_id, now, next_time, reason)
    if entry["state"] not in TERMINAL:
        entry.update(state="waiting", reason=reason, next_eligible_at=max(entry["next_eligible_at"], next_time), updated_at=now)
        queue.save()
    print(f'Deferred {ident}: {reason}; next eligible {utc(entry["next_eligible_at"])}; human environment review still required')
    return True


def summary(queue):
    lines = ["| Clip | State | Waiting reason | Hold | Next eligible (UTC) | Attempts |", "|---|---|---|---|---|---|"]
    for entry in queue.data["records"].values():
        lines.append(f'| {entry["manifest_id"]} | {entry["state"]} | {entry["reason"]} | {entry["hold_reason"]} | {utc(entry["next_eligible_at"])} | {entry["attempts"]}/{MAX_ATTEMPTS} |')
    return "\n".join(lines) + "\n"


def capability_probe(gh):
    """Harmless CI proof; only HTTP outcomes are emitted, never variable values."""
    result = {}
    for label, path in (("repository_variables", "/actions/variables?per_page=100"),
                        ("environment_variables", "/environments/youtube-unlisted/variables?per_page=100")):
        try:
            data = gh.repo(path)
            result[label] = {"supported": isinstance(data.get("variables"), list), "status": 200}
        except u.Refused:
            result[label] = {"supported": False, "status": "denied_or_unavailable"}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("tick", "cancel", "status", "capability-probe"))
    parser.add_argument("--queue-id", default=os.environ.get("DEFERRED_ID", ""))
    args = parser.parse_args()
    if args.mode == "capability-probe":
        u.require(os.environ.get("GITHUB_REPOSITORY") == u.REPO and
                  os.environ.get("GITHUB_EVENT_NAME") == "workflow_dispatch",
                  "Capability proof is manual and credential-free")
        print(u.canonical(capability_probe(u.GitHub(u.Transport(), os.environ["GITHUB_TOKEN"]))).decode())
        return
    u.require(os.environ.get("GITHUB_REPOSITORY") == u.REPO and os.environ.get("GITHUB_REF") == "refs/heads/master" and
              os.environ.get("GITHUB_EVENT_NAME") in {"schedule", "workflow_dispatch"} and
              os.environ.get("GITHUB_WORKFLOW_REF") == u.REPO + "/" + WORKFLOW + "@refs/heads/master",
              "Deferred controller is trusted default-branch only")
    gh = u.GitHub(u.Transport(), os.environ["GITHUB_TOKEN"])
    now = int(time.time())
    if args.mode == "tick":
        queue = tick(gh, now, os.environ["GITHUB_SHA"])
    else:
        queue = Queue(gh)
        if args.mode == "cancel":
            u.sha(args.queue_id)
            entry = queue.data["records"].get(args.queue_id)
            u.require(entry is not None, "Queue item missing")
            _finish(entry, "cancelled", "owner_cancelled", now)
            queue.save()
            if entry["active_run_id"] is not None:
                cancel_overdue_run(gh, entry["active_run_id"])
    result = summary(queue)
    print(result)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        Path(os.environ["GITHUB_STEP_SUMMARY"]).write_text(result, encoding="utf-8")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("Deferred controller stopped; preserve claim/receipts and inspect bounded metadata", file=__import__("sys").stderr)
        raise SystemExit(1)
