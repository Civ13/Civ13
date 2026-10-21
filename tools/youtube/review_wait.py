"""Eight-hour manual review admission; never opens controls or sends media."""
from datetime import datetime, timezone
import os
from pathlib import Path
import re
import time

import upload as u
from deferred import ControlReader, cancel_overdue_run

REVIEW_SECONDS = 8 * 3600
HANDOFF_SECONDS = 120
EXECUTION_SECONDS = 900
ARTIFACT_MARGIN = 300
TITLE = "YouTube eight-hour review"


def stamp(value):
    u.require(isinstance(value, str), "Missing GitHub timestamp")
    try:
        parsed = datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
        return int(parsed.timestamp())
    except ValueError:
        raise u.Refused("Invalid GitHub UTC timestamp") from None


def enabled():
    value = os.environ.get("REVIEW_HOURS", "0")
    u.require(value in {"0", "8"}, "Review period must be legacy zero or eight hours")
    return value == "8"


def request(gh, now, admission=True):
    u.require_trusted_dispatch()
    u.require(enabled() and os.environ.get("GITHUB_RUN_ATTEMPT") == "1" and
              not os.environ.get("DEFERRED_ID") and not os.environ.get("DEFERRED_TOKEN") and
              os.environ.get("VERIFY_ONLY", "false") == "false",
              "Eight-hour requests are new manual uploads only; reruns/queue claims cannot transfer review")
    run_id = os.environ.get("GITHUB_RUN_ID", "")
    u.require(run_id.isdigit(), "Missing review run identity")
    run = gh.repo("/actions/runs/" + run_id)
    u.require(run["id"] == int(run_id) and run["repository"]["id"] == u.REPO_ID and
              run["event"] == "workflow_dispatch" and run["head_branch"] == "master" and
              run["status"] == "in_progress" and run["conclusion"] is None and
              run["path"] == ".github/workflows/youtube-upload.yml" and run["run_attempt"] == 1 and
              run["display_title"] == TITLE and run["head_sha"] == os.environ["GITHUB_SHA"] and
              gh.repo("/commits/master")["sha"] == run["head_sha"],
              "Review run or current trusted source changed")
    created = stamp(run["created_at"])
    deadline = created + REVIEW_SECONDS
    u.require(created <= now < deadline + (0 if admission else HANDOFF_SECONDS + EXECUTION_SECONDS),
              "Eight-hour review admission expired; create a fresh protected request")
    return deadline


def artifact_coverage(gh, manifest, deadline):
    item = gh.repo(f'/actions/artifacts/{manifest["artifact"]["id"]}')
    u.require(item["id"] == manifest["artifact"]["id"] and item["expired"] is False and
              item["name"] == manifest["artifact"]["name"] and
              item["digest"] == "sha256:" + manifest["artifact"]["archive_sha256"] and
              stamp(item["expires_at"]) >= deadline + HANDOFF_SECONDS + EXECUTION_SECONDS + ARTIFACT_MARGIN,
              "Pinned artifact cannot cover eight-hour review and execution; reimport the same approved bytes first")


def closed_baseline(reader):
    repo, env = reader.variables("repository"), reader.variables("environment")
    u.require(all(values.get("YOUTUBE_UPLOAD_ENABLED") == "false" and
                  values.get("YOUTUBE_UPLOAD_STOP_USE") == "true" and
                  values.get("YOUTUBE_ZERO_COST_CONFIRMED") == "false" for values in (repo, env)) and
              repo.get("YOUTUBE_DEFERRED_ARMED_UNTIL") == "0" and
              repo.get("YOUTUBE_DEFERRED_ENABLED") == "false",
              "Review handoff requires all six controls OFF, arm zero and controller disabled")


def execution_controls(now, reader):
    # This manual request must not enable the dispatcher for another queued clip.
    repo, env = reader.variables("repository"), reader.variables("environment")
    u.require(repo.get("YOUTUBE_DEFERRED_ENABLED") == "false", "Manual review requires controller disabled")
    until = repo.get("YOUTUBE_DEFERRED_ARMED_UNTIL", "")
    return (all(values.get("YOUTUBE_UPLOAD_ENABLED") == "true" and
                values.get("YOUTUBE_UPLOAD_STOP_USE") == "false" and
                values.get("YOUTUBE_ZERO_COST_CONFIRMED") == "true" for values in (repo, env)) and
            bool(re.fullmatch(r"[0-9]{1,12}", until)) and now < int(until) <= now + EXECUTION_SECONDS)


def admit(gh, reader, clock=time.time):
    deadline = request(gh, int(clock()))
    closed_baseline(reader)
    started = int(clock())
    u.require(started < deadline, "Eight-hour review expired during admission checks")
    return {"review_started_at": started, "review_deadline": deadline}


def await_arm(gh, reader, clock=time.time, sleep=time.sleep, admitted=None):
    admitted = admit(gh, reader, clock) if admitted is None else admitted
    started, deadline = admitted["review_started_at"], admitted["review_deadline"]
    u.require(request(gh, int(clock()), admission=False) == deadline and started < deadline and
              started <= int(clock()) < started + HANDOFF_SECONDS, "Same-job admission is missing or expired")
    print(f"Review admitted for this run; operator handoff expires at {started + HANDOFF_SECONDS} UTC epoch", flush=True)
    while int(clock()) < started + HANDOFF_SECONDS:
        now = int(clock())
        # Expected closed gates may wait; service/auth/validation failures never retry.
        if execution_controls(now, reader):
            arm = reader.metadata("repository", "YOUTUBE_DEFERRED_ARMED_UNTIL")
            until = int(arm["value"])
            u.require(stamp(arm.get("updated_at")) >= started and now < until <= now + EXECUTION_SECONDS,
                      "Execution arm must be newly created after this protected review")
            request(gh, now, admission=False)
            current = int(clock())
            u.require(started <= current < started + HANDOFF_SECONDS and current < until,
                      "Review handoff or arm expired during service checks")
            return {"review_started_at": started, "review_deadline": deadline, "execution_until": until}
        sleep(5)
    raise u.Refused("Protected review approved, but no fresh short operator arm arrived; no upload started")


def execution_gate(gh, reader, clock=time.time):
    now = int(clock())
    deadline = request(gh, now, admission=False)
    values = [os.environ.get(name, "") for name in ("REVIEW_STARTED_AT", "REVIEW_DEADLINE", "REVIEW_EXECUTION_UNTIL")]
    u.require(all(value.isdigit() for value in values), "Missing same-job review handoff")
    started, recorded_deadline, until = map(int, values)
    u.require(recorded_deadline == deadline and started < deadline and
              started <= now < until <= started + HANDOFF_SECONDS + EXECUTION_SECONDS and
              execution_controls(now, reader), "Review execution expired or fresh stop controls closed")
    arm = reader.metadata("repository", "YOUTUBE_DEFERRED_ARMED_UNTIL")
    u.require(arm["value"] == str(until) and stamp(arm.get("updated_at")) >= started,
              "Execution arm changed; a later arm cannot extend this request")
    current = int(clock())
    u.require(started <= current < until and current < deadline + HANDOFF_SECONDS + EXECUTION_SECONDS,
              "Execution expired during fresh service checks")
    return current


def expire(gh, now):
    """Cancel unstarted expired reviews; native job timeout bounds started work."""
    for status in ("queued", "in_progress", "waiting", "pending", "requested"):
        data = gh.repo(f"/actions/workflows/youtube-upload.yml/runs?branch=master&status={status}&per_page=100")
        u.require(data["total_count"] <= 100 and len(data["workflow_runs"]) == data["total_count"],
                  "Review cleanup inventory incomplete")
        for run in data["workflow_runs"]:
            if run.get("display_title") != TITLE:
                continue
            u.require(run["repository"]["id"] == u.REPO_ID and run["event"] == "workflow_dispatch" and
                      run["head_branch"] == "master" and run["path"] == ".github/workflows/youtube-upload.yml",
                      "Review cleanup run identity differs")
            deadline = stamp(run["created_at"]) + REVIEW_SECONDS
            if now < deadline:
                continue
            jobs = gh.repo(f'/actions/runs/{run["id"]}/jobs?per_page=100')
            u.require(jobs["total_count"] <= 100 and len(jobs["jobs"]) == jobs["total_count"],
                      "Review cleanup job inventory incomplete")
            started = any(j.get("steps") for j in jobs["jobs"] if j["name"].endswith("/ upload"))
            # An approved job may be reading back a durable video ID within its
            # native runner budget after the short media arm has closed. Do not
            # truncate that safe readback with a competing cleanup deadline.
            if not started:
                cancel_overdue_run(gh, run["id"])
                print(f'Expired eight-hour review run {run["id"]}; receipt reconciliation remains required')


def main():
    gh = u.GitHub(u.Transport(), os.environ["GITHUB_TOKEN"])
    if os.environ.get("REVIEW_OPERATION") == "expire":
        u.require(os.environ.get("GITHUB_REPOSITORY") == u.REPO and
                  os.environ.get("GITHUB_REF") == "refs/heads/master" and
                  os.environ.get("GITHUB_WORKFLOW_REF") == u.REPO + "/.github/workflows/youtube-deferred.yml@refs/heads/master" and
                  os.environ.get("GITHUB_EVENT_NAME") in {"schedule", "workflow_dispatch"}, "Untrusted review cleanup")
        expire(gh, int(time.time()))
    else:
        reader = ControlReader.from_environment()
        if os.environ.get("REVIEW_OPERATION") == "admit":
            result = admit(gh, reader)
        else:
            values = [os.environ.get(name, "") for name in ("REVIEW_STARTED_AT", "REVIEW_DEADLINE")]
            u.require(all(value.isdigit() for value in values), "Missing same-job admission outputs")
            result = await_arm(gh, reader, admitted=dict(zip(("review_started_at", "review_deadline"), map(int, values))))
        with Path(os.environ["GITHUB_OUTPUT"]).open("a", encoding="utf-8") as output:
            for key, value in result.items():
                output.write(f"{key}={value}\n")


if __name__ == "__main__":
    try:
        main()
    except u.Refused as error:
        raise SystemExit("Review stopped: " + str(error)) from None
    except Exception:
        raise SystemExit("Review stopped: validation/service failure; no automatic media retry") from None
