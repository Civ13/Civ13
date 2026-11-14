# Equipment attachments probe

Native probe for clothing attachments (`code/game/objects/items/clothing/clothing_accessories.dm`,
`code/_onclick/hud/attachment_strip.dm`) and the belt slot.

Run on Linux with the pinned compiler:

    python3 tests/ecology_spawning/run_linux.py . tests/equipment_attachments/probe.dm

Checks: where the attachment strip tiles sit and that they follow a moved
storage window, that a held item clicked onto clothes with two pouches goes
into the first pouch only, that removed pouches and dropped clothes stop being
strip targets, and that the belt stays on when the clothes come off.

The strip itself needs a game client and is not drawn here.
