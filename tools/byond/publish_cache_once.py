"""Resume only the fixed verified BYOND draft. Never create, upload or retry."""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

REPO = "Civ13/Civ13"
BRANCH = "automation/publish-byond-516.1688-16278f318cde-v3"
TAG = "byond-toolchain-cache-516.1688-linux-16278f318cde"
NAME = "516.1688_byond_linux.zip"
SIZE = 4887281
SHA256 = "16278f318cdeb4b77c57868dd7135032fde717ea6226269d22b2a1a50968e7f9"
SOURCE = "https://cmss13-devs.github.io/byond-build-mirror/download/build/516/" + NAME
TARGET = "3f3dd47f614f4659031a793dc590346f5e4de3e6"
GUARDS = {
    ".github/workflows/native-launcher-release.yml": "4028c3f38e37d4cd8e9bd9a86eacab713af4fe92",
    "tools/opendream-client/native/release.py": "eeac336e13faa5a7fdb5cf61f5947a7532d4f1d9",
}
FEED_SHA = "1763916155ed4841f694f6ee806af0384c2f474b"
LAUNCHER_SHA = "49eb03c1351ba984758a9f8426a5f678dbb91131a7a0da929da1a5f8a4d232d3"
LATEST_ASSETS = {
    "Civ13.exe": (664081527, 35160628, "sha256:" + LAUNCHER_SHA),
    "Civ13.exe.sha256": (664081524, 77, "sha256:257fd596a7e24461c6e85f92765d32fbfeb635855f2766d069ce728299b52c44"),
    "native-launcher-release.json": (664081526, 436, "sha256:b49dd393846ed3985c6fb5b66d5ac6b25ba21f8d76adf2373dfd01f08b9822b4"),
}
TITLE = "BYOND 516.1688 Linux toolchain archive cache (unchanged upstream bytes)"
BODY = f"""Toolchain archive cache only. This is not a Civ13 game or launcher release.

Unchanged BYOND 516.1688 Linux compiler/server archive, including all original
embedded legal, readme and third-party notices. Linux is a hosting/development
platform, not a DreamSeeker client distribution.

Original source: https://www.byond.com/download/build/516/{NAME}
Transfer source: {SOURCE}
Bytes: {SIZE}
SHA-256: {SHA256}
Provenance: observed official HTTPS bytes on 2026-10-24, also matched against the
unchanged community mirror. This is not a vendor-published checksum or signature.

This prerelease is explicitly not latest. No game or launcher assets, feed change,
or compatibility claim is included. BYOND's included agreement and notices apply;
the Civ13 source-code license does not replace those terms.
"""
API_ROOT = "https://api.github.com/repos/" + REPO
API = API_ROOT + "/"
PUBLIC_ASSET = f"https://github.com/{REPO}/releases/download/{TAG}/{NAME}"
RELEASE_ID = 423087014
ASSET_ID = 673801489
DRAFT_ASSET = f"https://github.com/{REPO}/releases/download/untagged-c4ad3051b9503d217c19/{NAME}"
PUBLISH_FIELDS = {"draft": False, "prerelease": True, "make_latest": "false"}


class Refusal(RuntimeError):
    """A fixed, non-sensitive validation diagnostic."""


def require(condition, reason):
    if not condition:
        raise Refusal(reason)


def verify_bytes(data):
    require(len(data) == SIZE, "Archive size differs")
    require(hashlib.sha256(data).hexdigest() == SHA256, "Archive SHA-256 differs")
    return data


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class TransportError(RuntimeError):
    """Sanitized: never carries response bodies, credentials or signed URLs."""


class GitHub:
    def __init__(self, token):
        self.token = token
        self.opener = build_opener(NoRedirect())

    def request(self, method, url, body=None, authenticated=False, accept="application/vnd.github+json", limit=2000000):
        require((method == "GET" and body is None) or
                (method == "PATCH" and url == API + f"releases/{RELEASE_ID}"
                 and authenticated is True and body == PUBLISH_FIELDS),
                "Transport permits only reads and the exact resume publication PATCH")
        headers = {"Accept": accept, "User-Agent": "Civ13-fixed-toolchain-cache"}
        if authenticated:
            require(url == API_ROOT or url.startswith(API), "Refuse credential destination")
            headers["Authorization"] = "Bearer " + self.token
            headers["X-GitHub-Api-Version"] = "2022-11-28"
        if body is not None:
            headers["Content-Type"] = "application/json"
            body = json.dumps(body).encode()
        try:
            response = self.opener.open(Request(url, data=body, headers=headers, method=method), timeout=60)
        except HTTPError as error:
            response = error
        except (OSError, URLError):
            raise TransportError("Network request failed; mutating outcome may be uncertain") from None
        with response:
            status = response.code
            if status in (301, 302, 303, 307, 308):
                return status, response.headers.get("Location", ""), b""
            payload = response.read(limit + 1)
            require(len(payload) <= limit, "Response exceeds bounded size")
            return status, "", payload

    def api(self, endpoint, method="GET", body=None, missing=False):
        require((method == "GET" and body is None) or
                (method == "PATCH" and endpoint == f"releases/{RELEASE_ID}" and body == PUBLISH_FIELDS),
                "Resume permits only reads and the one exact release publication PATCH")
        status, _, payload = self.request(method, API_ROOT if endpoint == "" else API + endpoint, body, authenticated=True)
        if status == 404 and missing:
            return None
        require(status == 200, f"GitHub API rejected {method} with status {status}")
        return json.loads(payload)

    def readback(self, url, authenticated=False):
        status, location, data = self.request("GET", url, authenticated=authenticated, accept="application/octet-stream", limit=SIZE)
        if status == 302:
            parsed = urlsplit(location)
            require(parsed.scheme == "https" and parsed.netloc == "release-assets.githubusercontent.com"
                    and parsed.path.startswith("/github-production-release-asset/141349998/")
                    and not parsed.fragment, "Unexpected asset redirect destination")
            # The signed query is used only in memory. No Authorization header leaves GitHub API.
            status, _, data = self.request("GET", location, accept="application/octet-stream", limit=SIZE)
        require(status == 200, "Asset readback requires 200 or one approved CDN redirect")
        return verify_bytes(data)

    def asset_bytes(self, asset_id):
        return self.readback(API + f"releases/assets/{asset_id}", authenticated=True)

    def public_asset_bytes(self):
        return self.readback(PUBLIC_ASSET)


def check_event(event, env):
    require(re.fullmatch(r"[0-9a-f]{40}", TARGET) is not None, "Target is not assigned after guard merge")
    require(env.get("GITHUB_EVENT_NAME") == "push" and env.get("GITHUB_REPOSITORY") == REPO
            and env.get("GITHUB_REF") == "refs/heads/" + BRANCH and env.get("GITHUB_RUN_ATTEMPT") == "1", "Wrong workflow context or rerun")
    require(event.get("repository", {}).get("full_name") == REPO
            and event.get("ref") == "refs/heads/" + BRANCH and event.get("created") is True
            and event.get("deleted") is False and event.get("forced") is False
            and event.get("before") == "0" * 40 and event.get("after") == env.get("GITHUB_SHA")
            and re.fullmatch(r"[0-9a-f]{40}", event.get("after", "")), "Not the initial fixed branch push")


def check_guard(api):
    repository = api.api("")
    require(repository.get("id") == 141349998 and repository.get("default_branch") == "master", "Repository identity/default branch changed")
    master = api.api("git/ref/heads/master")["object"]["sha"]
    require(re.fullmatch(r"[0-9a-f]{40}", master) is not None, "Invalid master commit identity")
    compare = api.api(f"compare/{TARGET}...{master}")
    require(compare.get("status") in ("ahead", "identical"), "Guard target is not on master")
    for ref in (TARGET, master):
        for path, blob in GUARDS.items():
            require(api.api(f"contents/{path}?ref={ref}").get("sha") == blob, "Reviewed launcher guard differs")
    # GITHUB_TOKEN cannot release a target whose workflows differ from default branch.
    def workflow_tree(ref):
        rows = api.api(f"contents/.github/workflows?ref={ref}")
        return sorted((row["name"], row["sha"], row["type"]) for row in rows)
    require(workflow_tree(TARGET) == workflow_tree(master), "Target workflows differ from default branch")


def check_launcher(api):
    latest = api.api("releases/latest")
    require(latest.get("id") == 420150025 and latest.get("tag_name") == "launcher-v1.0.7"
            and latest.get("draft") is False and latest.get("prerelease") is False, "Latest launcher changed")
    assets = latest.get("assets", [])
    actual = {a["name"]: (a["id"], a["size"], a.get("digest")) for a in assets}
    require(len(assets) == 3 and actual == LATEST_ASSETS and all(a.get("state") == "uploaded" for a in assets), "Launcher asset inventory changed")
    ref = api.api("git/ref/heads/native-launcher-updates")
    require(ref["object"]["sha"] == FEED_SHA, "Launcher feed reference changed")
    feed = api.api("contents/native-launcher-channel.json?ref=" + FEED_SHA)
    value = json.loads(base64.b64decode(feed["content"]))
    require(value == {"schema": 1, "version": "1.0.7", "sha256": LAUNCHER_SHA,
                      "url": f"https://github.com/{REPO}/releases/download/launcher-v1.0.7/Civ13.exe"}, "Launcher feed content changed")


def check_tag(api, may_be_absent=False):
    ref = api.api("git/ref/tags/" + TAG, missing=True)
    if ref is None:
        require(may_be_absent, "Published cache tag is missing")
    else:
        require(api.api("commits/" + TAG)["sha"] == TARGET, "Cache tag target differs")
    return ref


def check_release(release, draft):
    require(type(release.get("id")) is int and release["id"] == RELEASE_ID
            and release.get("tag_name") == TAG and release.get("target_commitish") == TARGET
            and release.get("draft") is draft and release.get("prerelease") is True
            and release.get("name") == TITLE and release.get("body") == BODY,
            "Cache release identity, target, metadata or state differs")


def check_asset(api, draft):
    assets = api.api(f"releases/{RELEASE_ID}/assets?per_page=100")
    require(len(assets) == 1, "Cache must contain only the single expected ZIP")
    asset = assets[0]
    require(type(asset.get("id")) is int and asset["id"] == ASSET_ID and asset.get("name") == NAME
            and asset.get("state") == "uploaded" and asset.get("size") == SIZE
            and asset.get("content_type") == "application/zip"
            and asset.get("digest") == "sha256:" + SHA256
            and asset.get("browser_download_url") == (DRAFT_ASSET if draft else PUBLIC_ASSET),
            "Bound draft or published asset metadata differs")
    verify_bytes(api.asset_bytes(ASSET_ID))


def publish(api, receipt):
    def phase(value):
        receipt["phase"] = value
        print(json.dumps(receipt, sort_keys=True), flush=True)

    check_guard(api)
    check_launcher(api)
    release = api.api(f"releases/{RELEASE_ID}")
    draft = release.get("draft")
    require(type(draft) is bool, "Unexpected release state")
    check_release(release, draft)
    receipt["release_id"] = RELEASE_ID
    receipt["asset_id"] = ASSET_ID
    phase("draft-verification-pending" if draft else "published-verification-pending")
    check_tag(api, may_be_absent=draft)
    check_asset(api, draft)
    receipt["authenticated_readback"] = "verified"
    check_release(api.api(f"releases/{RELEASE_ID}"), draft)
    check_guard(api)
    check_launcher(api)
    check_tag(api, may_be_absent=draft)
    if draft:
        check_asset(api, True)
        check_release(api.api(f"releases/{RELEASE_ID}"), True)
        phase("publish-requested-outcome-uncertain")
        release = api.api(f"releases/{RELEASE_ID}", "PATCH", PUBLISH_FIELDS)
        phase("published-verification-pending")
        check_release(release, False)
    check_release(api.api(f"releases/{RELEASE_ID}"), False)
    check_tag(api)
    check_asset(api, False)
    verify_bytes(api.public_asset_bytes())
    receipt["anonymous_readback"] = "verified"
    check_release(api.api(f"releases/{RELEASE_ID}"), False)
    check_tag(api)
    check_launcher(api)
    phase("published-and-verified" if draft else "already-published-verified")


def main():
    receipt = {"repository": REPO, "tag": TAG, "target": TARGET, "asset": NAME,
               "bytes": SIZE, "sha256": SHA256, "source": SOURCE, "url": PUBLIC_ASSET,
               "feed_ref": FEED_SHA, "phase": "preflight", "writes_retried": False, "resume_only": True}
    result = 0
    try:
        require(len(sys.argv) == 1, "No command-line overrides supported")
        check_event(json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text()), os.environ)
        token = os.environ.get("GH_TOKEN")
        require(bool(token), "Missing existing job token")
        publish(GitHub(token), receipt)
    except Exception as error:
        # Never echo untrusted exception text, response bodies, signed queries or credentials.
        receipt["result"] = "stopped-review-required"
        receipt["error_type"] = type(error).__name__
        if isinstance(error, (Refusal, TransportError)):
            receipt["reason"] = str(error)
        result = 1
    else:
        receipt["result"] = "verified"
    Path("cache-publication-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps(receipt, sort_keys=True), flush=True)
    return result


if __name__ == "__main__":
    sys.exit(main())
