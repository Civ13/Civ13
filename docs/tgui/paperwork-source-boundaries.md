# Paperwork source boundaries

Inventory at `157df2a34cb71758231b39a78308da6af5106953`; later Book changes do
not modify these existing paper/pen/container/government sources.

| Boundary | Current source and behavior |
| --- | --- |
| Paper data/reader | `code/game/objects/items/paper/paper.dm`: stored `info` HTML/pencode output, derived `info_links`, stamp text/list and legacy counters. `show_content` uses the original human/ghost/forceshow rule and `stars(info)` for other readers. |
| Pencode | `paper.parsepencode`: center, br, b/i/u, time/date, large/small, headings, list, table/grid/row/cell and field spans. Crayons strip some constructs and use Comic Sans/bold. This is not generic Markdown. |
| Fields/editor | `[field]` becomes `paper_field` spans; `updateinfolinks` adds write links by ordinal plus EOF. MAX_FIELDS50, capacity3072. Topic checks state, active pen and range/possession/clipboard/folder after the prompt. Preserve cancellation, incomplete/malformed spans and subtype behavior. |
| Ink/signature | `items/pen.dm`: actual colored/invisible white pens, crayons and chameleon pen signatures. Real/forged signature text and date/time are resolved when written; old content is not regenerated. White ink remains visual concealment, not authenticated secrecy. |
| Stamps | `paper.attackby` creates a stamp image and plays a message/sound, but stamp-HTML append, `stamped` recording and overlay insertion are commented out as broken. This is a source finding, not an in-game reproduction. `items/stamp.dm` defines stamps; mail stamps are separate. |
| Clipboard/folder | `items/clipboard.dm`, `items/paper/folder.dm`: held-container Topics validate membership; clipboard has actual top page and pen slot, forwards writes to paper, and both contain independent raw paper readers. Moving the container can leave `paper.loc` unchanged. |
| Bundles | `items/paper/bundle.dm`: page/index/navigation/removal and direct paper/photo reads; preserve page identity, membership and combined item interactions. |
| Envelopes/mail | `objects/structures/mail.dm`: opened/knifed/sealed states, actual paper/photo storage, addressed names, wax seal colors and deliberate broken-seal mechanics. No bypass merely because a descendant paper is adjacent. |
| Copy/printing | No active generic photocopier was found in the scoped code search; photocopier-related offset arrays remain on paper. `modules/1713/computers/programs.dm` prints existing warrant subtypes and their target/reason/number fields. Do not replace government/warrant authority with a parallel document authority. |
| Persistence | `modules/persistence/functions.dm:get_saved_vars` enumerates changed item vars. `saving.dm`/`loading.dm` preserve typed list keys/values and path scalars. An omission from paper's old allowlist alone does not prove data loss. Runtime service ownership must be excluded. |
| Language | `language/language.dm`, `language/earth.dm`, `_helpers/global_lists.dm`, `mob/say.dm`, `mob/hear_say.dm`, `human/say.dm`, `__defines/species_languages.dm`: knowledge, speech ability and physical speech are separate. `say_understands` admits broader dead/universal/species cases; `hear_say` learns and scramble may expose partial original words. Neither is a written-data projection boundary. |

The Book, Notes and Flavor migrations are independent and preserved. The latest
parent assignment designates this existing worker as the paperwork implementation
owner; the other paperwork researcher is read-only. Existing Help/HUD/manager
owners retain those lanes. No archived Claude lane is being revived or edited.

The first foundation adds APIs only. All current authoring, stamp, container,
envelope, subtype, government/warrant and persistence engine code remains
byte-identical. All-reader projection/transaction integration must precede
activating new language-tagged document authoring. Study and stamp repair have
their own later bounded stages.
