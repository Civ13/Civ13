"""Injected offline controls only. Never invokes publisher main or a network request."""
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
        self.release = None
        self.assets = []
        self.tag = None
        self.writes = []
        self.payload = DATA
        self.readback = DATA
        self.public_payload = DATA
        self.public_fetches = 0
        self.feed = p.FEED_SHA
        self.latest_tag = "launcher-v1.0.7"
        self.guard = True
        self.workflow_match = True
        self.fail_at = None
        self.after_upload = lambda: None
        self.after_publish = lambda: None
        self.list_override = None

    def api(self, endpoint, method="GET", body=None, missing=False):
        if method != "GET":
            self.writes.append((method, endpoint, body))
            if method == "POST" and endpoint == "releases":
                self.release = {**body, "id": 71}
                if self.fail_at == "create":
                    raise p.TransportError("uncertain create")
                return copy.deepcopy(self.release)
            if method == "PATCH" and endpoint == "releases/71":
                self.release.update(body)
                self.tag = p.TARGET
                if self.fail_at == "publish":
                    raise p.TransportError("uncertain publish")
                self.after_publish()
                return copy.deepcopy(self.release)
            raise AssertionError("Unexpected mutation: " + endpoint)
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
        if endpoint.startswith("releases?per_page="):
            return self.list_override if self.list_override is not None else ([] if self.release is None else [copy.deepcopy(self.release)])
        if endpoint == "releases/71/assets?per_page=100":
            return copy.deepcopy(self.assets)
        if endpoint == "releases/71":
            return copy.deepcopy(self.release)
        raise AssertionError("Unexpected read: " + endpoint)

    def source(self):
        return self.payload

    def upload(self, release_id, data):
        assert release_id == 71 and data == DATA
        self.writes.append(("UPLOAD", 71, data))
        self.assets = [{"id": 81, "name": p.NAME, "state": "uploaded", "size": p.SIZE,
                        "digest": "sha256:" + p.SHA256, "browser_download_url": p.PUBLIC_ASSET}]
        self.after_upload()
        if self.fail_at == "upload":
            raise p.TransportError("uncertain upload")
        return copy.deepcopy(self.assets[0])

    def asset_bytes(self, asset_id):
        assert asset_id == 81
        return self.readback

    def public_asset_bytes(self):
        self.public_fetches += 1
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

    def test_fresh_publish_and_existing_exact_asset_no_duplicate(self):
        self.run_publish()
        self.assertEqual(self.receipt["phase"], "published-and-verified")
        self.assertEqual([v[0] for v in self.api.writes], ["POST", "UPLOAD", "PATCH"])
        for method, endpoint, body in (self.api.writes[0], self.api.writes[2]):
            self.assertEqual(body["make_latest"], "false")
            self.assertIs(body["prerelease"], True)
        self.api.writes.clear()
        self.run_publish()
        self.assertEqual(self.api.writes, [])
        self.assertEqual(self.receipt["phase"], "already-published-verified")
        self.assertEqual(self.api.public_fetches, 2)

    def test_anonymous_bytes_failure_leaves_new_or_existing_publication_unverified(self):
        self.api.public_payload = DATA + b"bad-public-bytes"
        with self.assertRaises(p.Refusal):
            self.run_publish()
        self.assertFalse(self.api.release["draft"])
        self.assertEqual(self.receipt["phase"], "published-verification-pending")
        self.assertEqual(len(self.api.writes), 3)
        self.api.writes.clear()
        with self.assertRaises(p.Refusal):
            self.run_publish()
        self.assertEqual(self.api.writes, [])
        self.assertEqual(self.receipt["phase"], "published-verification-pending")

    def test_wrong_size_and_hash_stop_before_any_write(self):
        for data in (DATA + b"x", b"x" * len(DATA)):
            with self.subTest(data=data), self.assertRaises(p.Refusal):
                self.api.payload = data
                self.run_publish()
            self.assertEqual(self.api.writes, [])

    def test_guard_workflow_latest_and_feed_drift_stop_before_writes(self):
        for field, value in (("guard", False), ("workflow_match", False),
                             ("latest_tag", "launcher-v1.0.8"), ("feed", "b" * 40)):
            self.api = Fake()
            setattr(self.api, field, value)
            with self.subTest(field=field), self.assertRaises(p.Refusal):
                self.run_publish()
            self.assertEqual(self.api.writes, [])

    def test_orphan_and_wrong_target_tag_stop(self):
        for target in (p.TARGET, "b" * 40):
            self.api.tag = target
            with self.subTest(target=target), self.assertRaises(p.Refusal):
                self.run_publish()
            self.assertEqual(self.api.writes, [])

    def test_existing_different_target_metadata_or_assets_stop_without_mutation(self):
        self.run_publish()
        original_release = copy.deepcopy(self.api.release)
        original_assets = copy.deepcopy(self.api.assets)
        self.api.writes.clear()
        for field, value in (("target_commitish", "b" * 40), ("tag_name", "wrong-tag"),
                             ("prerelease", False), ("body", "different")):
            self.api.release = {**original_release, field: value}
            with self.subTest(field=field), self.assertRaises(p.Refusal):
                self.run_publish()
            self.assertEqual(self.api.writes, [])
        self.api.release = original_release
        for assets in ([], original_assets * 2, [{**original_assets[0], "name": "Civ13.exe"}],
                       [{**original_assets[0], "digest": "sha256:wrong"}]):
            self.api.assets = assets
            with self.subTest(assets=assets), self.assertRaises(p.Refusal):
                self.run_publish()
            self.assertEqual(self.api.writes, [])

    def test_existing_draft_is_read_back_but_never_automatically_resumed(self):
        self.run_publish()
        self.api.release["draft"] = True
        self.api.tag = None
        self.api.writes.clear()
        with self.assertRaisesRegex(p.Refusal, "Existing draft verified"):
            self.run_publish()
        self.assertEqual(self.api.writes, [])

    def test_duplicate_release_inventory_fails_closed(self):
        self.run_publish()
        self.api.list_override = [self.api.release, self.api.release]
        self.api.writes.clear()
        with self.assertRaisesRegex(p.Refusal, "Duplicate"):
            self.run_publish()
        self.assertEqual(self.api.writes, [])

    def test_partial_uncertain_write_is_not_retried_or_rolled_back(self):
        for stage, count in (("create", 1), ("upload", 2), ("publish", 3)):
            self.api = Fake()
            self.api.fail_at = stage
            with self.subTest(stage=stage), self.assertRaises(p.TransportError):
                self.run_publish()
            self.assertEqual(len(self.api.writes), count)
            self.assertIn("outcome-uncertain", self.receipt["phase"])

    def test_failed_readback_never_publishes(self):
        self.api.readback = DATA + b"corrupt"
        with self.assertRaises(p.Refusal):
            self.run_publish()
        self.assertTrue(self.api.release["draft"])
        self.assertEqual(len(self.api.writes), 2)

    def test_feed_changed_during_upload_stops_before_publish(self):
        self.api.after_upload = lambda: setattr(self.api, "feed", "b" * 40)
        with self.assertRaises(p.Refusal):
            self.run_publish()
        self.assertEqual(len(self.api.writes), 2)

    def test_drift_after_publication_is_reported_not_rolled_back(self):
        self.api.after_publish = lambda: setattr(self.api, "latest_tag", "wrong")
        with self.assertRaises(p.Refusal):
            self.run_publish()
        self.assertFalse(self.api.release["draft"])
        self.assertEqual(len(self.api.writes), 3)
        self.assertEqual(self.receipt["phase"], "published-verification-pending")

    def test_fixed_initial_branch_event_only_and_no_rerun(self):
        event = {"repository": {"full_name": p.REPO}, "ref": "refs/heads/" + p.BRANCH,
                 "created": True, "deleted": False, "forced": False, "before": "0" * 40, "after": "c" * 40}
        env = {"GITHUB_EVENT_NAME": "push", "GITHUB_REPOSITORY": p.REPO, "GITHUB_REF": event["ref"],
               "GITHUB_SHA": event["after"], "GITHUB_RUN_ATTEMPT": "1"}
        p.check_event(event, env)
        for key, value in (("ref", "refs/heads/master"), ("created", False), ("forced", True), ("after", "bad")):
            with self.subTest(key=key), self.assertRaises(p.Refusal):
                p.check_event({**event, key: value}, env)
        with self.assertRaises(p.Refusal):
            p.check_event(event, {**env, "GITHUB_RUN_ATTEMPT": "2"})

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

    def test_exact_source_no_redirects_wrong_size_and_hash(self):
        client = p.GitHub("unused-fake-token")
        for response in ((302, "https://wrong.invalid/", b""), (200, "", DATA + b"x"), (200, "", b"x" * len(DATA))):
            with self.subTest(response=response), patch.object(client, "request", return_value=response) as request, self.assertRaises(p.Refusal):
                client.source()
            self.assertEqual(request.call_args.args, ("GET", p.SOURCE))
            self.assertNotIn("authenticated", request.call_args.kwargs)

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
