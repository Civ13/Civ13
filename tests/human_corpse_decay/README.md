# Native human corpse regression

Run with a trusted BYOND 516.1681 bin directory:

```
python tests/human_corpse_decay/run.py --byond-bin /absolute/BYOND/byond/bin
python tests/human_corpse_decay/run.py --byond-bin /absolute/BYOND/byond/bin --negative-control nodrop
python tests/human_corpse_decay/run.py --byond-bin /absolute/BYOND/byond/bin --negative-control restart
python tests/human_corpse_decay/run.py --byond-bin /absolute/BYOND/byond/bin --negative-control noop
```

On Windows use a verified full Python interpreter path. `--output` selects a unique evidence directory. Default output is unique temporary storage. Compilation requires the exact 516.1681 banner and zero errors/warnings. The runner disables ordinary world/map startup and outbound notification flags, copies only tracked name data, launches the real native production-source 4x4 world in safe mode, and stops it within 120 seconds. All saves/logs/exports are isolated; generated checkout compilation files are cleaned.

The fixture uses actual human New, death, revive/rejuvenate, inventory slot/drop callbacks, physical movement, native serializer/loader and GC. It checks roots and nested identity/metadata, uniform dependent-slot cascades, protected and canceled retirement, bounded candidate/drop budgets, map corpses, zombie outcomes, both phase clocks, dead/live/corrupt-state native saves and 20cycles of 128bones. Negative controls deliberately enable nodrop gear loss, erase age on load or refresh age on no-op movement, and must fail the corresponding behavioral assertion after clean compilation.

Evidence includes commit/version/world metadata, dirty patch when applicable, compile/runtime logs, cycle counts, RSS samples, native save files and six actual sprite exports. Short isolated memory observations are not production or multiweek evidence. A fixture listener checks physical retirement and native slot state; it is not the extraction settlement implementation.

## Native bones preview

These are BYOND `icon()` exports of the six existing `icons/misc/tribal.dmi` remains states used by production `/obj/structure/religious/remains/New()`. No artwork was generated. The fixture exports the same states into its evidence directory.

![remains1](sprites/remains1.png) ![remains2](sprites/remains2.png) ![remains3](sprites/remains3.png) ![remains4](sprites/remains4.png) ![remains5](sprites/remains5.png) ![remains6](sprites/remains6.png)

The icon-readiness and icon-callback controls check partial native organ restoration and delayed constructor work. The fixture lets unrelated human initialization finish first, then verifies missing-species deferral, healthy icon generation and retired callback cancellation. Both daemon output and runtime logs reject native errors/engine diagnostics and print the rejected text; the fixture explicitly closes its port and refuses reopening.
