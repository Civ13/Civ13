# Silk

On Linux, load the pinned BYOND libraries first:

```bash
source '<pinned BYOND bin directory>/byondsetup'
```

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/silk/probe.dm
```

The probe runs `code/modules/1713/silk.dm` in the shared resource-extraction fixture. It stands in for the `do_after` waits, the egg roll and the probe mob's hands.

It checks the following:

- **Mulberries:** in Asia a broadleaf tree is a mulberry. Grab intent picks 2 mulberry leaves; help intent and an interrupted pick give nothing; sometimes the leaves carry silkworm eggs; a stripped tree gives no more. A pine is no mulberry, Gaia has none, and a land that is not a continent keeps its mulberries.
- **Rearing:** a silkworm tray refuses ordinary leaves, takes six mulberry leaves, and starts a batch once it has eggs. The batch gives six cocoons and keeps the eggs, which can be taken out again.
- **Reeling:** cold water reels nothing, no reeling finishes during a world save, and hot water reels five cocoons into five silk thread.
- **Material:** silk cloth is the `silk` material.
