# Unsupported shell compatibility

Run with the pinned BYOND version (`tools/byond/version.json`) and a verified Python executable:

```powershell
<python> tests/opendream_shell/run.py --byond-bin <bin> --output <evidence>
<python> tests/opendream_shell/run.py --byond-bin <bin> --output <dispatch-control> --negative-control dispatch
```

The fixture extracts the production script dispatch body. It tests the pinned
compiler's native and OpenDream preprocessing branches with counted adapters,
without executing a real script. The dispatch negative control proves the
fixture detects the old unsupported OpenDream shell path. Chat speech is now
client-only and is tested separately in the chat browser workflow.
