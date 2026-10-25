"""Injected resume-only controls. No network, credentials or publisher main execution."""
import base64
import contextlib
import copy
import hashlib
import io
import json
import socket
import unittest
from unittest.mock import patch
import publish_cache_once as p

DATA = b"unchanged test archive"


class Fake:
    def __init__(self):
        self.release = {"id": p.RELEASE_ID, "tag_name": p.TAG, "target_commitish": p.TARGET,
                        "name": p.TITLE, "body": p.BODY, "draft": True, "prerelease": True}
        self.assets = [{"id": p.ASSET_ID, "name": p.NAME, "state": "uploaded", "size": p.SIZE,
                        "digest": "sha256:" + p.SHA256, "content_type": "application/zip",
                        "browser_download_url": p.DRAFT_ASSET}]
        self.tag = None
        self.writes = []
        self.readback = DATA
        self.public_payload = DATA
        self.feed = p.FEED_SHA
        self.latest_tag = "launcher-v1.0.7"
        self.guard = True
        self.workflow_match = True
        self.fail_publish = False
        self.fail_readback = False
        self.after_readback = lambda: None
        self.after_publish = lambda: None
        self.auth_reads = 0
        self.public_reads = 0

    def make_published(self):
        self.release["draft"] = False
        self.assets[0]["browser_download_url"] = p.PUBLIC_ASSET
        self.tag = p.TARGET

    def api(self, endpoint, method="GET", body=None, missing=False):
        if method != "GET":
            assert method == "PATCH" and endpoint == f"releases/{p.RELEASE_ID}" and body == p.PUBLISH_FIELDS
            assert self.auth_reads >= 1
            self.writes.append((method, endpoint, copy.deepcopy(body)))
            self.make_published()
            if self.fail_publish:
                raise p.TransportError("uncertain publish")
            self.after_publish()
            return copy.deepcopy(self.release)
        if endpoint == "":
            return {"id": 141349998, "default_branch": "master"}
        if endpoint == "git/ref/heads/master":
            return {"object": {"sha": "a" * 40}}
        if endpoint.startswith("compare/"):
            return {"status": "ahead"}
        for path, sha in p.GUARDS.items():
            if endpoint.startswith("contents/" + path + "?ref="):
                return {"sha": sha if self.guard else "bad"}
        if endpoint.startswith("contents/.github/workflows?"):
            sha = "workflow-tree" if self.workflow_match or endpoint.endswith(p.TARGET) else "changed"
            return [{"name": "native-launcher-release.yml", "sha": sha, "type": "file"}]
        if endpoint == "releases/latest":
            return {"id": 420150025, "tag_name": self.latest_tag, "draft": False, "prerelease": False,
                    "assets": [{"name": n, "id": v[0], "size": v[1], "digest": v[2], "state": "uploaded"}
                               for n, v in p.LATEST_ASSETS.items()]}
        if endpoint == "git/ref/heads/native-launcher-updates":
            return {"object": {"sha": self.feed}}
        if endpoint.startswith("contents/native-launcher-channel.json?"):
            value = {"schema": 1, "version": "1.0.7", "sha256": p.LAUNCHER_SHA,
                     "url": f"https://github.com/{p.REPO}/releases/download/launcher-v1.0.7/Civ13.exe"}
            return {"content": base64.b64encode(json.dumps(value).encode()).decode()}
        if endpoint == "git/ref/tags/" + p.TAG:
            return None if self.tag is None else {"object": {"sha": self.tag}}
        if endpoint == "commits/" + p.TAG:
            return {"sha": self.tag}
        if endpoint == f"releases/{p.RELEASE_ID}/assets?per_page=100":
            return copy.deepcopy(self.assets)
        if endpoint == f"releases/{p.RELEASE_ID}":
            if self.release is None:
                raise p.Refusal("GitHub API rejected GET with status 404")
            return copy.deepcopy(self.release)
        raise AssertionError("Unexpected read: " + endpoint)

    def asset_bytes(self, asset_id):
        assert asset_id == p.ASSET_ID
        self.auth_reads += 1
        if self.fail_readback:
            raise p.TransportError("readback failed")
        self.after_readback()
        return self.readback

    def public_asset_bytes(self):
        assert self.release["draft"] is False
        self.public_reads += 1
        return self.public_payload


class Controls(unittest.TestCase):
    def setUp(self):
        self.enterContext(patch.object(socket, "create_connection", side_effect=AssertionError("Network forbidden in tests")))
        self.enterContext(patch.object(p, "SIZE", len(DATA)))
        self.enterContext(patch.object(p, "SHA256", hashlib.sha256(DATA).hexdigest()))
        self.enterContext(contextlib.redirect_stdout(io.StringIO()))
        self.api = Fake()
        self.receipt = {}

    def run_publish(self):
        p.publish(self.api, self.receipt)

    def test_resume_exact_draft_then_verify_existing_without_any_duplicate_write(self):
        self.run_publish()
        self.assertEqual(self.api.writes, [("PATCH", f"releases/{p.RELEASE_ID}", p.PUBLISH_FIELDS)])
        self.assertEqual(self.receipt["phase"], "published-and-verified")
        self.assertEqual(self.receipt["authenticated_readback"], "verified")
        self.assertEqual(self.receipt["anonymous_readback"], "verified")
        self.api.writes.clear()
        self.run_publish()
        self.assertEqual(self.api.writes, [])
        self.assertEqual(self.receipt["phase"], "already-published-verified")

    def test_wrong_release_id_target_tag_title_body_or_prerelease_stops(self):
        for field, value in (("id", p.RELEASE_ID + 1), ("target_commitish", "b" * 40),
                             ("tag_name", "wrong"), ("name", "different"), ("body", "different"), ("prerelease", False)):
            self.api = Fake()
            self.api.release[field] = value
            with self.subTest(field=field), self.assertRaises(p.Refusal):
                self.run_publish()
            self.assertEqual(self.api.writes, [])

    def test_missing_release_or_missing_extra_asset_stops_without_create_or_upload(self):
        self.api.release = None
        with self.assertRaises(p.Refusal):
            self.run_publish()
        self.assertEqual(self.api.writes, [])
        for extra in (False, True):
            self.api = Fake()
            self.api.assets = self.api.assets * 2 if extra else []
            with self.subTest(extra=extra), self.assertRaises(p.Refusal):
                self.run_publish()
            self.assertEqual(self.api.writes, [])

    def test_wrong_asset_id_metadata_size_digest_and_content_type_stop(self):
        for field, value in (("id", p.ASSET_ID + 1), ("name", "other.zip"), ("state", "starter"),
                             ("size", len(DATA) + 1), ("digest", "sha256:wrong"),
                             ("digest", None), ("content_type", "application/octet-stream")):
            self.api = Fake()
            self.api.assets[0][field] = value
            with self.subTest(field=field, value=value), self.assertRaises(p.Refusal):
                self.run_publish()
            self.assertEqual(self.api.writes, [])

    def test_exact_draft_url_before_publish_and_final_url_after_publish(self):
        for url in (p.PUBLIC_ASSET, p.DRAFT_ASSET.replace("untagged-c4ad3051b9503d217c19", "untagged-other")):
            self.api = Fake()
            self.api.assets[0]["browser_download_url"] = url
            with self.subTest(url=url), self.assertRaises(p.Refusal):
                self.run_publish()
            self.assertEqual(self.api.writes, [])
        self.api = Fake()
        self.api.after_publish = lambda: self.api.assets[0].update(browser_download_url=p.DRAFT_ASSET)
        with self.assertRaises(p.Refusal):
            self.run_publish()
        self.assertEqual(len(self.api.writes), 1)
        self.assertEqual(self.receipt["phase"], "published-verification-pending")

    def test_authenticated_readback_size_hash_or_transport_failure_prevents_patch(self):
        for data in (DATA + b"bad", b"x" * len(DATA)):
            self.api = Fake()
            self.api.readback = data
            with self.subTest(data=data), self.assertRaises(p.Refusal):
                self.run_publish()
            self.assertEqual(self.api.writes, [])
            self.assertTrue(self.api.release["draft"])
        self.api = Fake()
        self.api.fail_readback = True
        with self.assertRaises(p.TransportError):
            self.run_publish()
        self.assertEqual(self.api.writes, [])

    def test_wrong_tag_target_and_missing_published_tag_stop(self):
        self.api.tag = "b" * 40
        with self.assertRaises(p.Refusal):
            self.run_publish()
        self.assertEqual(self.api.writes, [])
        self.api = Fake()
        self.api.make_published()
        self.api.tag = None
        with self.assertRaises(p.Refusal):
            self.run_publish()
        self.assertEqual(self.api.writes, [])

    def test_guard_latest_and_feed_drift_before_or_during_readback_stop_patch(self):
        for field, value in (("guard", False), ("workflow_match", False),
                             ("latest_tag", "launcher-v1.0.8"), ("feed", "b" * 40)):
            for late in (False, True):
                self.api = Fake()
                if late:
                    self.api.after_readback = lambda: setattr(self.api, field, value)
                else:
                    setattr(self.api, field, value)
                with self.subTest(field=field, late=late), self.assertRaises(p.Refusal):
                    self.run_publish()
                self.assertEqual(self.api.writes, [])

    def test_late_extra_asset_or_release_change_before_patch_is_rejected(self):
        self.api.after_readback = lambda: self.api.assets.append(copy.deepcopy(self.api.assets[0]))
        with self.assertRaises(p.Refusal):
            self.run_publish()
        self.assertEqual(self.api.writes, [])
        self.api = Fake()
        self.api.after_readback = lambda: self.api.release.update(body="changed concurrently")
        with self.assertRaises(p.Refusal):
            self.run_publish()
        self.assertEqual(self.api.writes, [])

    def test_uncertain_publication_has_one_patch_no_retry_or_rollback(self):
        self.api.fail_publish = True
        with self.assertRaises(p.TransportError):
            self.run_publish()
        self.assertEqual(len(self.api.writes), 1)
        self.assertEqual(self.receipt["phase"], "publish-requested-outcome-uncertain")

    def test_anonymous_failure_after_publish_or_on_existing_release_is_not_verified(self):
        self.api.public_payload = DATA + b"bad"
        with self.assertRaises(p.Refusal):
            self.run_publish()
        self.assertFalse(self.api.release["draft"])
        self.assertEqual(len(self.api.writes), 1)
        self.assertEqual(self.receipt["phase"], "published-verification-pending")
        self.api.writes.clear()
        with self.assertRaises(p.Refusal):
            self.run_publish()
        self.assertEqual(self.api.writes, [])
        self.assertEqual(self.receipt["phase"], "published-verification-pending")

    def test_no_create_upload_delete_or_other_patch_can_reach_transport(self):
        client = p.GitHub("unused-fake-token")
        self.assertFalse(hasattr(client, "upload"))
        self.assertFalse(hasattr(client, "source"))
        cases = (("releases", "POST", {}), (f"releases/{p.RELEASE_ID}", "DELETE", None),
                 (f"releases/{p.RELEASE_ID + 1}", "PATCH", p.PUBLISH_FIELDS),
                 (f"releases/{p.RELEASE_ID}", "PATCH", {**p.PUBLISH_FIELDS, "make_latest": "true"}))
        for endpoint, method, body in cases:
            with self.subTest(endpoint=endpoint, method=method), patch.object(client, "request") as request, self.assertRaises(p.Refusal):
                client.api(endpoint, method, body)
            request.assert_not_called()
        with patch.object(client.opener, "open") as opened, self.assertRaises(p.Refusal):
            client.request("POST", p.API + "releases", {}, authenticated=True)
        opened.assert_not_called()

    def test_fixed_v3_initial_branch_only_and_no_rerun(self):
        self.assertEqual(p.BRANCH, "automation/publish-byond-516.1688-16278f318cde-v3")
        event = {"repository": {"full_name": p.REPO}, "ref": "refs/heads/" + p.BRANCH,
                 "created": True, "deleted": False, "forced": False, "before": "0" * 40, "after": "c" * 40}
        env = {"GITHUB_EVENT_NAME": "push", "GITHUB_REPOSITORY": p.REPO, "GITHUB_REF": event["ref"],
               "GITHUB_SHA": event["after"], "GITHUB_RUN_ATTEMPT": "1"}
        p.check_event(event, env)
        for key, value in (("ref", event["ref"].replace("-v3", "-v2")), ("created", False),
                           ("forced", True), ("before", "a" * 40), ("after", "bad")):
            with self.subTest(key=key), self.assertRaises(p.Refusal):
                p.check_event({**event, key: value}, env)
        with self.assertRaises(p.Refusal):
            p.check_event(event, {**env, "GITHUB_RUN_ATTEMPT": "2"})

    def test_real_api_url_construction_uses_canonical_root_and_slash_paths(self):
        client = p.GitHub("unused-fake-token")
        class Response(io.BytesIO):
            code = 200
            headers = {}
        for endpoint, expected in (("", "https://api.github.com/repos/Civ13/Civ13"),
                                   ("releases/latest", "https://api.github.com/repos/Civ13/Civ13/releases/latest")):
            with self.subTest(endpoint=endpoint), patch.object(client.opener, "open", return_value=Response(b"{}")) as opened:
                self.assertEqual(client.api(endpoint), {})
            request = opened.call_args.args[0]
            self.assertEqual(request.full_url, expected)
            self.assertEqual(request.get_header("Authorization"), "Bearer unused-fake-token")

    def test_exact_root_and_repo_paths_are_the_only_credential_destinations(self):
        client = p.GitHub("unused-fake-token")
        class Response(io.BytesIO):
            code = 200
            headers = {}
        allowed = ("https://api.github.com/repos/Civ13/Civ13",
                   "https://api.github.com/repos/Civ13/Civ13/releases/latest")
        for url in allowed:
            with self.subTest(url=url), patch.object(client.opener, "open", return_value=Response(b"{}")) as opened:
                client.request("GET", url, authenticated=True)
            self.assertEqual(opened.call_count, 1)
            self.assertEqual(opened.call_args.args[0].get_header("Authorization"), "Bearer unused-fake-token")
        denied = ("https://uploads.github.com/repos/Civ13/Civ13/releases/71/assets?name=" + p.NAME,
                  "https://api.github.com/repos/Civ13/Civ13-other/releases",
                  "https://api.github.com/repos/Civ13/Civ130/releases",
                  "https://api.github.com/repos/Civ13/Other/releases",
                  "https://api.github.com/repos/Civ13/Civ13?redirect=elsewhere",
                  "https://api.github.com.evil.invalid/repos/Civ13/Civ13/releases",
                  "https://api.github.com@evil.invalid/repos/Civ13/Civ13/releases",
                  "http://api.github.com/repos/Civ13/Civ13/releases",
                  "https://uploads.github.com/repos/Civ13/Civ13-other/releases/71/assets",
                  "https://uploads.github.com/repos/Civ13/Civ130/releases/71/assets",
                  "https://uploads.github.com.evil.invalid/repos/Civ13/Civ13/releases/71/assets",
                  "https://release-assets.githubusercontent.com/github-production-release-asset/141349998/asset",
                  p.SOURCE, p.PUBLIC_ASSET)
        for url in denied:
            with self.subTest(url=url), patch.object(client.opener, "open") as opened, self.assertRaisesRegex(p.Refusal, "Refuse credential destination"):
                client.request("GET", url, authenticated=True)
            opened.assert_not_called()

    def test_production_transport_headers_and_no_redirect_handler(self):
        client = p.GitHub("unused-fake-token")
        class Response(io.BytesIO):
            code = 200
            headers = {}
        with patch.object(client.opener, "open", return_value=Response(b"{}")) as opened:
            client.request("GET", p.API + "releases/latest", authenticated=True)
        request = opened.call_args.args[0]
        self.assertEqual(request.get_header("Authorization"), "Bearer unused-fake-token")
        with self.assertRaises(p.Refusal):
            client.request("GET", "https://evil.invalid/", authenticated=True)
        self.assertIsNone(p.NoRedirect().redirect_request(None, None, 302, "", {}, "https://evil.invalid"))
        for status in (301, 302, 303, 307, 308):
            response = Response()
            response.code = status
            response.headers = {"Location": "https://evil.invalid/"}
            with patch.object(client.opener, "open", return_value=response) as opened:
                self.assertEqual(client.request("GET", p.SOURCE), (status, "https://evil.invalid/", b""))
            self.assertEqual(opened.call_count, 1)

    def test_anonymous_exact_url_success_failure_and_wrong_redirect(self):
        client = p.GitHub("unused-fake-token")
        allowed = "https://release-assets.githubusercontent.com/github-production-release-asset/141349998/asset?secret=signed"
        for responses in ([(200, "", DATA)], [(302, allowed, b""), (200, "", DATA)]):
            with self.subTest(responses=responses), patch.object(client, "request", side_effect=responses) as request:
                self.assertEqual(client.public_asset_bytes(), DATA)
            self.assertEqual(request.call_args_list[0].args, ("GET", p.PUBLIC_ASSET))
            self.assertTrue(all(not call.kwargs.get("authenticated", False) for call in request.call_args_list))
        for responses in ([(404, "", b"not found")], [(200, "", DATA + b"bad")],
                          [(302, "https://evil.invalid/asset?secret=signed", b"")],
                          [(302, "https://release-assets.githubusercontent.com/github-production-release-asset/99/asset", b"")],
                          [(302, allowed, b""), (302, allowed, b"")]):
            with self.subTest(responses=responses), patch.object(client, "request", side_effect=responses) as request, self.assertRaises(p.Refusal):
                client.public_asset_bytes()
            self.assertEqual(request.call_args_list[0].args, ("GET", p.PUBLIC_ASSET))
            self.assertTrue(all(not call.kwargs.get("authenticated", False) for call in request.call_args_list))

    def test_readback_redirect_is_one_hop_github_cdn_without_token(self):
        client = p.GitHub("unused-fake-token")
        allowed = "https://release-assets.githubusercontent.com/github-production-release-asset/141349998/asset?secret=signed"
        with patch.object(client, "request", side_effect=[(302, allowed, b""), (200, "", DATA)]) as request:
            self.assertEqual(client.asset_bytes(81), DATA)
        self.assertIs(request.call_args_list[0].kwargs["authenticated"], True)
        self.assertNotIn("authenticated", request.call_args_list[1].kwargs)
        for wrong in ("http://release-assets.githubusercontent.com/github-production-release-asset/141349998/a",
                      "https://evil.invalid/github-production-release-asset/141349998/a",
                      "https://release-assets.githubusercontent.com/github-production-release-asset/99/a"):
            with patch.object(client, "request", return_value=(302, wrong, b"")) as request, self.assertRaises(p.Refusal):
                client.asset_bytes(81)
            self.assertEqual(request.call_count, 1)
        with patch.object(client, "request", side_effect=[(302, allowed, b""), (302, allowed, b"")]), self.assertRaises(p.Refusal):
            client.asset_bytes(81)


if __name__ == "__main__":
    unittest.main()
