# Local BYOND CID reader and comparison

`get-cid.ps1` obtains the decimal CID from the same native BYOND library used by
DreamSeeker. It loads that library in a separate 32-bit PowerShell process and
calls its existing fingerprint and CRC routines. It does not inject into another
process, install hooks, modify the CID, or detect spoofing.

[BYONDHook](https://github.com/ECToo/BYONDHook/blob/101833da3561f6291889d9c9eeaa2817eb4e9b59/BYONDHook/dllmain.cpp)
was the reference for finding the `GetVersionExW` and `GetVolumeInformationA`
inputs. The reviewed BYOND 516.1681 binary additionally uses its own drive
identity routines before the volume-serial fallback. Reading a Windows volume
serial alone is therefore insufficient.

## Supported library

This implementation supports only the Windows x86 BYOND 516.1681
`byondcore.dll` with SHA-256
`55cf268a4f054f02d556d2ed3c26ab01b7b0318bb3c5419e85f88e4e3b9e5898`.
The fingerprint routine is at RVA `0x29ab20`, with two stack arguments and
callee stack cleanup. The CRC routine is at RVA `0x244cc0` and uses cdecl.
The native guest-CID path parses the fingerprint into 16 bytes, renders lowercase
hex without trailing zero bytes, and hashes that text with initial CRC
`0xffffffff`. The reader reproduces this formatting and calls BYOND's CRC.

These functions are private implementation details. The library hash check
prevents calling these offsets in an incompatible binary; it is an ABI guard,
not a claim that a CID is authentic. Other builds must be reviewed and tested
before adding support. This is a Windows tool, not an OpenDream implementation.

## Obtain the CID

Run in 32-bit Windows PowerShell with the absolute path to the supported BYOND
installation:

```powershell
& "$env:WINDIR/SysWOW64/WindowsPowerShell/v1.0/powershell.exe" -NoProfile -File ./tools/cid/get-cid.ps1 -ByondBin 'C:/path/to/byond/bin'
```

The only successful output is the decimal CID as text.

## Compare with a local DreamDaemon

```powershell
./tools/cid/run-local.ps1 -ByondBin 'C:/path/to/byond/bin'
./tools/cid/run-local.ps1 -ByondBin 'C:/path/to/byond/bin' -NegativeControl
```

The runner compiles a standalone 1x1x1 world, starts an invisible DreamDaemon,
and connects a fresh local DreamSeeker. The server reads `client.computer_id`
directly and records its exact text comparison with the independently obtained
value. The negative control supplies `0` and must reject that comparison while
still observing the acquired CID. This tests the comparison, not spoofing.

The fixture rejects non-loopback clients, has no game includes or hub listing,
and shuts down after a receipt or 60 seconds. DreamDaemon's listener is not
restricted to loopback by this tool. The runner allows 15 seconds for readiness
and 35 seconds for the receipt, then stops only its own server and client.
DreamSeeker uses the current BYOND login state. Local networking and desktop
process launches must be available. No production server or save data is used.

Evidence stays in a unique temporary directory, or beneath `-OutputRoot`:
`compile.log`, `runtime.log`, `result.json`, `verification.json` and
`cleanup.json`. Receipts contain the machine CID and should remain local.

The positive comparison and incorrect-expected-value control passed locally on Windows with BYOND 516.1681 on
2026-10-14. This establishes equality for that client and binary on that host;
it does not establish hardware authenticity or compatibility with other builds.
