Civ13 Windows TLS diagnostic

1. Extract this ZIP into a folder.
2. Open Civ13-TLS-Diagnostic.exe normally. Administrator rights are not needed.
3. Wait for RESULT PASS or RESULT FAIL. The release download is about 35 MB.
4. Send the newly created Civ13-TLS-Diagnostic-*.txt file from this folder.
5. Press Enter to close the window.

If a Windows security prompt blocks the diagnostic, stop and report the prompt.
Do not disable certificate validation, antivirus, a firewall, or proxy settings.

This self-contained .NET 8 diagnostic uses the launcher's unchanged 1.0.2
HTTP transport against the stable feed and the published 1.0.3 download.
It checks the downloaded file's SHA256 and deletes its temporary copy.
It never runs the downloaded launcher, installs software, starts BYOND,
or changes network/security settings.

The report includes runtime/Windows versions, UTC time, endpoint host names,
HTTP and certificate-chain status codes, redacted exception classifications,
and whether proxy environment variables/default proxy routing are present.
It excludes certificate identities, proxy addresses/credentials, environment
values, exception messages, stack traces, and signed download URLs.

A supplemental header-only trace keeps certificate validation enabled and
rejects every reported certificate error. The trace may succeed after an
initial request fails; the report keeps both results separately.
