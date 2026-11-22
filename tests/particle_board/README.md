# Particle board

On Linux, load the pinned BYOND libraries first:

```bash
source '<pinned BYOND bin directory>/byondsetup'
```

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/particle_board/probe.dm
```

The probe runs `code/modules/1713/particle_board.dm` in the shared resource-extraction fixture. It stands in for the hot press's wait and the probe mob's hands, and stops the minute worker so it can soak boards by calling `particle_board_tick()` itself.

It checks the following:

- **Sawdust:** the large saw mill leaves a pile of sawdust for every two logs, more joins the same pile, and neither the primitive mill nor planks give any.
- **Hot press:** no resin and three piles press nothing, an interrupted pressing uses nothing, phenolic resin presses four piles into three sheets and pine resin into two.
- **Builds:** particle board is a material softer than wood, and each build is a particle board type behind the combustion node; a plank shelf is not.
- **Water:** a puddled tile is wet; sheets swell into swollen boards after two wet minutes and crumble after five, dry sheets keep, a bookcase swells then falls apart and spills its contents, a partition swells and loses half its health, and taking a particle board table apart leaves no wooden frame.
