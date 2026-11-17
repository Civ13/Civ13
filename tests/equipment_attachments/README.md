# Equipment attachments probe

Native probe for clothing attachments (`code/game/objects/items/clothing/clothing_accessories.dm`,
`code/_onclick/hud/attachment_strip.dm`, `code/modules/1713/belt_pouches.dm`) and the belt slot.

Run on Linux with the pinned compiler:

    python3 tests/ecology_spawning/run_linux.py . tests/equipment_attachments/probe.dm

Checks: where the attachment strip tiles sit and that they follow a moved
storage window, that a held item clicked onto clothes with two pouches goes
into the first pouch only, that an empty-hand click on a necklace tile takes
the necklace off into the hand while a pouch tile only opens the pouch, that
examining a strip attachment leaves it on, that dragging a tile to a chosen
hand takes it into that hand (a full hand refuses it) and dragging it to the
wearer's tile or the next one sets it down there (a far tile is refused), that removed pouches and dropped clothes stop being
strip targets, that the belt stays on when the clothes come off, the belt's
attachment points (two pouches, one sheath or holster, one tool loop), what
the tool loop holds, and the shoulder belt carrying one sword beside a pouch.

The strip itself needs a game client and is not drawn here.
