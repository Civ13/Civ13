# Pine resin

On Linux, load the pinned BYOND libraries first:

```bash
source '<pinned BYOND bin directory>/byondsetup'
```

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/resin/probe.dm
```

The probe runs `code/modules/1713/resin.dm` in the shared resource-extraction fixture. It stands in for the `do_after` waits and for the probe mob's other hand.

It checks the following:

- **Tapping:** a living pine is a resin tree.
  - Tapping it with an open bucket while holding a knife gives 10 resin.
  - Without the knife, nothing is tapped and the tree is not harmed.
  - The pine gives resin again only after the twenty-minute wait (not after eighteen), and an interrupted tap gives nothing.
  - A container without room for 10 resin taps nothing and leaves the tree ready.
  - In harm intent a container taps nothing; a dead pine and a broadleaf tree give none.
  - A knife used on its own still chops at the tree.
- **Cooking down:** on a lit brazier in help intent, 10 resin cooks into one resin lump and leaves 2 turpentine. An unlit brazier cooks nothing, 5 resin is not enough, and no cooking finishes during a world save. The lump is the `resin` material.
- **Melting:** a cold pot melts nothing; a hot pot melts one lump into 10 resin.
- **Fuel:** resin and turpentine refuel a torch, resin for longer than oil.
