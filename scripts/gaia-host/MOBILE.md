# Mobile LAN host companion (draft)

`mobile_host.py` is an opt-in phone browser interface to the same `Host.request`
and detached workers used by the launcher's Host tab. It is never started by the
launcher, doorman or installer. No default configuration enables it.

The first version handles **one existing host configuration**, including a
region's generated host configuration. It shows state, player count (unknown
when the world cannot answer), the current operation, and the last 20 mobile
control requests. Start, save-and-stop and restart each require an explicit
confirmation. Start/restart fetch the configured branch and may compile newer
source. A failed fetch or build leaves the server stopped. No force-stop,
arbitrary command, path, group-wide deployment or config-edit API is exposed.

## Transport and pairing prerequisites

Provision these separately before enabling this draft; this source PR does not
authorize activation, credential creation, firewall changes or trust installation.

- An existing server certificate/key whose IP SAN matches the exact private
  IPv4 address. The phone must already trust its issuer through an independently
  verified trust setup. Never bypass a browser certificate warning.
- A dedicated client CA bundle, and a client certificate/private key installed
  securely on each approved phone. The operator verifies each leaf certificate's
  SHA-256 DER fingerprint out of band and lists it in `devices`. Possession of a
  listed certificate's private key is the device login; CA membership alone is
  insufficient. There is no public pairing endpoint or shared lifecycle token.
- An existing private directory for mobile receipts, separate from the host's
  state directory. Its OS permissions, config and TLS private key must be limited
  to the operator. This tool does not alter ACLs or install certificates.
- An exact LAN interface IPv4 address and explicit RFC1918 /24 through /30 subnet.
  Only peers in that subnet are admitted. No wildcard, public, IPv6, DNS bind,
  forwarded-header trust, proxy mode or HTTP fallback is supported. Do not forward
  the port through a router, tunnel, proxy or the game's public doorman.

Client-certificate selection varies by phone/browser. Verify it on the intended
device before relying on this interface. TLS failures stop access; the companion
does not repair trust automatically. Removing a fingerprint and restarting only
the companion revokes that device. Existing host workers continue independently.
The certificate chain must validate and be unexpired on each new TLS connection;
automatic CA revocation-list fetching is not implemented, so remove compromised
leaf fingerprints promptly. All paired devices have the same operator capability.

## Explicit operator configuration

Keep the config outside the checkout. The following is **disabled**, contains no
credentials, and cannot start a listener without replacing the paths and pairing
list with independently provisioned material:

```json
{
  "enabled": false,
  "bind": "192.168.1.8",
  "lan_cidr": "192.168.1.0/24",
  "port": 8443,
  "certificate": "D:/private/mobile/server-chain.pem",
  "private_key": "D:/private/mobile/server-key.pem",
  "client_ca": "D:/private/mobile/client-ca.pem",
  "devices": [],
  "host_config": "D:/private/gaia-host.json",
  "state_dir": "D:/private/mobile/receipts"
}
```

After a separately authorized setup, the operator runs a verified Python 3.10+
interpreter with `-I -B scripts/gaia-host/mobile_host.py --config <absolute-config>`.
Only that explicit invocation opens HTTPS. It loads all TLS material before
binding. The terminal prints the configured address, which can be bookmarked on
the phone. Optional `"mobile_url": "https://192.168.1.8:8443"` in the launcher's
`host.json` displays the address in its Host tab; `control` must also be configured.
That display neither starts the service nor asserts it is reachable. It must name
the same companion/configured host. QR codes and automated setup are deferred.

## Disconnects, logs and replay

The existing host action lock and detached worker remain the lifecycle authority.
Mobile confirmations expire after 60 seconds and bind the paired device and exact
action. A durable receipt is reserved before dispatch. Repeated submissions of
the same confirmation return that receipt without another lifecycle request,
including after companion restart. A socket disconnect cannot cancel the worker.
Refresh/reopen the page to recover the current operation and recent receipts.

The companion is deliberately single-request-at-a-time, with a bounded accept
queue, five-second socket inactivity timeout, 512-byte action bodies, 30 requests
per device per minute, at most 16 devices and 100 durable receipts. It is a small
trusted-LAN operator service, not an internet-facing or high-availability server.
Slow host prechecks can delay refresh. There are no automatic action retries.
Busy/refused actions use the existing host checks; paths, upstream errors,
backup names, lifecycle/control tokens, player identities and raw game/chat logs
are never serialized to the phone. The displayed logs are sanitized control
receipts, not a general log-file browser.

Only the host's latest operation is authoritative. Observed progress is retained
in its mobile receipt; if another desktop operation replaces the record before a
refresh, an older mobile entry remains `accepted`, **not proof of completion**.
Unknown phases are shown as unknown. Inspect private desktop diagnostics on a
failure or uncertain result. An uncertain reservation blocks all new mobile
actions until the operator reconciles it offline. Never delete a receipt to retry
an action whose outcome is unknown.

After 100 requests, use desktop controls until an operator stops the companion,
reconciles uncertain receipts and archives its receipt files. The service lock
refuses a second instance using that directory; after a crash, only remove
`mobile.lock` after verifying no companion uses it. Never remove the host action
lock as part of mobile cleanup. Failures while persisting a reservation fail
closed; power-loss guarantees still depend on filesystem durability.

## Verification and draft limits

`python -I -B -m unittest discover -s tests/gaia_host -p test_mobile_host.py`
uses inert TLS/host/socket adapters and temporary files. It does not generate
credentials, listen on a port, start BYOND or contact a live host. The suite is
also registered in the offline `gaia_host` CI suite. Tests cover missing/disabled
configuration, TLS policy, LAN peer filtering, approved device fingerprints,
Origin/Host checks, bounded bodies, duplicate submissions, concurrent actions,
reconnect, uncertain reservations and output allowlisting.

Real phone client-certificate selection, end-to-end HTTPS, visual/accessibility
acceptance, live save/restart and crash/power-loss recovery require separate
isolated acceptance. This draft does not claim those have passed. There is no
new password flow, QR enrollment, background service installer or group-wide UI.
