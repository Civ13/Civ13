# Treated cloth

On Linux, load the pinned BYOND libraries first:

```bash
source '<pinned BYOND bin directory>/byondsetup'
```

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/treated_cloth/probe.dm
```

The probe runs `code/modules/1713/treated_cloth.dm` in the shared resource-extraction fixture. It stands in for the `do_after` wait and the probe mob's hands.

It checks the following:

- **Pitch:** too little pitch coats nothing, an interrupted coating or one during a world save uses nothing, and 30 units of pitch coat five sheets of cloth into tarred canvas. Harm intent coats nothing.
- **Oil:** linseed oil makes oilcloth at one sheet per five units; water makes nothing.
- **Wax:** a cake of beeswax waxes up to three sheets, from either side, and is used up.
- **Other cloth:** silk is not oiled.
- **Material:** all three are materials, and oilcloth has its pile sprites.
