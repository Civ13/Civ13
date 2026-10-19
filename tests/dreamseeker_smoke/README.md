# Guest renderer feasibility only

This separate Windows CI experiment asks whether the hosted x64 desktop can show
and capture actual DreamSeeker 516.1681 map pixels. It does NOT test the Civ13
compositor, oversized trees, native visibility, weather or persistence. No smoke
receipt may satisfy `light_plane_composition/verify_render.py`.

The official portable archive and all executable/DLL bytes are SHA256 pinned in
`vendor.json`. The workflow uses a disposable windows-2022 runner, read-only token,
no checkout credentials, no user secrets, no account/pager startup, no firewall,
registry, security-policy or display-driver changes. The guest URL uses the
vendor-documented `##guest` option. A login/permission dialog is never accepted.

Each compiler, daemon and client starts suspended in its own kill-on-close Job
with one active process allowed, so no pager or other child can start. These are
three distinct Jobs; the visible client is deliberately NOT the hidden/no-socket
HUD test. Each process has a 512MiB memory cap and a monitored 60 CPU-second cap;
the harness has a 150-second deadline and workflow a ten-minute outer bound.
Retained process handles are used for cleanup and socket ownership checks.
The fresh environment excludes inherited user credentials/configuration.

The daemon is explicitly started with `-ip 127.0.0.1`, invisible, safe and no
webclient. Its exact loopback-only listener must be observed before client launch.
Only one loopback guest is admitted. An unexpected local address, remote peer,
listener, UDP endpoint, child, window or prompt fails the run. Socket polling is
an observation/control, not an OS network sandbox or proof against transient
connections between samples. No security settings are changed to strengthen it.
The parent must review this limitation before publication.

A generated white tile is an INPUT sprite. The native fixture tints tiles red,
then blue after the first capture, retaining a green actor in the center. The
harness captures the actual foreground client rectangle from the desktop twice
per phase and requires stable pixel bytes with the expected phase/actor colors.
It saves those unmodified PNGs, exact source/vendor hashes and owned cleanup
receipts. Synthetic unit images only test the color oracle. They are never saved
as native captures. No renderer compatibility is established before CI runs.

Only evidence-directory logs (1MiB monitored bound each), two bounded PNGs and
JSON receipts are uploaded, not compiled resource caches or vendor binaries.
Any failure stops here; do not use account login, administrator overrides,
firewall changes, RDP or the user's desktop to make this smoke pass.
