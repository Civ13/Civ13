# Lacquer

On Linux, load the pinned BYOND libraries first:

```bash
source '<pinned BYOND bin directory>/byondsetup'
```

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/lacquer/probe.dm
```

The probe runs `code/modules/1713/lacquer.dm` in the shared resource-extraction fixture. It stands in for the `do_after` waits and the probe mob's hands, and runs the chemistry step itself.

It checks the following:

- **Tapping:** in Asia a broadleaf tree is a lacquer tree. Without a knife or with an interrupted cut nothing is tapped; a knife and a bucket tap 5 lacquer; the tree waits about 20 minutes before it bleeds again. Gaia and pines have none.
- **Varnish:** resin and ethanol mix into spirit varnish.
- **Finishing:** a steel knife is refused; wood, a wooden shield, a leather helmet and lamellar are accepted. Harm intent and an interrupted coat use nothing; a lacquer coat costs 5 units and is not brushed again while good. A finished item wears 25% slower until the coat wears through, then wears as before. Varnish gives a shorter coat, and the pot shows which finish it holds.
