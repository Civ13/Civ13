# Rubber trees

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/rubber_tapping/probe.dm
```

The probe runs `code/modules/1713/rubber_tapping.dm` in the shared resource-extraction fixture. It stands in for the `do_after` waits and for the probe mob's other hand.

It checks the following:

- **Tapping in a rubber land:** in Africa, a jungle tree is a rubber tree.
  - Tapping it with an open bucket while holding a knife gives 10 latex.
  - Without the knife, nothing is tapped and the tree is not harmed.
  - The tree gives latex again only after the wait, and an interrupted tap gives nothing.
  - A knife used on its own still chops at the tree.
- **Where rubber trees grow:**
  - An acacia is not a rubber tree.
  - On Gaia, jungle trees give no latex.
  - A land that is not a continent keeps its rubber trees.
- **Curing:** 10 latex and one sulphur rock cure into one sheet of rubber, which is the `rubber` material. 5 latex is not enough.
- **Uses:** a rubber sheet and a copper ingot make insulated cable.
