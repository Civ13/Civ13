# Jungle hiding probe

On Windows, with maintainer authorization for trusted DreamDaemon execution:

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/jungle_hiding/probe.dm
```

The isolated probe checks stale persistence admission, competing occupants,
clientless release and destruction. It does not establish connected-client
perspective behavior or live gameplay. Offline source contracts are registered
as the `jungle_hiding` baseline suite.
