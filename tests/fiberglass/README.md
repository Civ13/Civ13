# Fiberglass

On Linux, load the pinned BYOND libraries first:

```bash
source '<pinned BYOND bin directory>/byondsetup'
```

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/fiberglass/probe.dm
```

The probe runs `code/modules/1713/fiberglass.dm` in the shared resource-extraction fixture. It stands in for the layup table's `do_after` wait and the probe mob's hands, and calls the bakelizer's per-step product proc directly.

It checks the following:

- **Epoxy:** the bakelizer's epoxy setting makes epoxy to draw off, and waits for the Cold War.
- **Layup table:** no epoxy lays up nothing, epoxy pours into the pans, an interrupted layup uses nothing, three glass cloth and 10 epoxy set two fiberglass, three Kevlar sheets bond into two aramid laminate, and plain cloth is refused.
- **Materials:** glass cloth, fiberglass and aramid laminate are materials.
