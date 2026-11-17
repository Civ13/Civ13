# Ore extraction kit

`pwsh -NoProfile -File tests/resource_extraction/run.ps1 -ByondBin <BYOND-bin> -Probe tests/ore_extraction_kit/probe.dm`

Runs the production extraction-kit `attackby` bodies in `code/modules/1713/ores.dm`
and `aluminium.dm` with only the wait (`/obj/item/stack/ore/proc/kit_wait`)
replaced. Each use must purify one ore into the 5-unit kit and leave the rest
of the stack: a stack of 50 iron once gave 5 units and vanished. Covers a full
kit, an interrupted wait, the last ore of a stack and every ore the kit takes.
Not covered: the real wait timing and graphical interaction.
