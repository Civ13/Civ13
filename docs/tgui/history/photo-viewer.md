# Photo viewer contract

This slice migrates only `/obj/item/weapon/photo/show()` to the existing default
modern adapter. The photo image and writing on its back are a read-only snapshot.
Camera capture, visibility/lighting composition, film, printing, copying, image
IDs, writing and renaming remain in their current handlers.

## Entry and information boundaries

Direct examine still requires an image and the existing distance <= 1 check.
Folder and clipboard look actions retain their current possession, containment
and interaction checks and call the same `show()` entrypoint. No extra remote
open route, generic href action or crafting/knowledge query is introduced.

The UI sends only the photo's name, existing resource filename, display width
and scribble. It does not send camera state, world mobs, location, creator,
the captured-description field, other album contents or hidden object fields.
The original `tmp_photo_<id>.png` delivery and filename remain unchanged.
Existing copy-ID/cache collisions are not repaired by this migration.

Normal scribbles and renamed labels are already HTML encoded by `sanitize()`.
The producer decodes once and re-encodes for a canonical text snapshot, preserving
legitimate ampersands/quotes without double encoding. Both renderers display text;
neither evaluates stored markup. Arbitrary administrator-inserted HTML is not a
supported photo caption format. Image URLs admit only the existing numeric-ID
basename. Normal 1/3/5/7 photo sizes keep their 64*size display width; corrupt or
oversized display values receive a UI-only 64..448 bound without editing the item.

## Lifecycle and fallback

The reader is bound to the same photo and viewing mob, including observers or
incapacitated/dead viewers admitted by an existing entrypoint. Domain actions
are always disabled. The state checks owner, source identity and connected
client, without adding an ongoing distance restriction to an already viewed
snapshot. Explicit reopening refreshes image/caption. Manager refresh is status
only and never recaptures an image or requeries world data.

The original shared photo window replaced its previous image. Opening another
photo therefore closes only this viewer's previous photo-reader subtype, keeping
one photo reader per mob and leaving books/machines/other viewers alone.

Close uses normal manager/transport cleanup and disables machine close logic.
It cannot clear an unrelated `using_object` interaction. Logout or body transfer
invalidates the old owner-bound reader; the new body must use a normal entrypoint.
No mob/item persistence field, movement lock or polling loop is added.

The real classic template displays the same image and inert caption with the
original pixelated appearance. Existing capability fallback and sticky recovery
remain in the shared adapter. The native write/rename prompts are unchanged.

## Review boundary

Prepared locally from merged master `fb0e5c41cd4fc7f399cb6cf90d7dbf9cb6741c62`.
No independent open photo/book/paper migration or photography issue was found in
the bounded current GitHub search. HUD/FPS, Help and manager work are separate.
No source publication, native compiler/client/runtime or deployment is authorized
for this local slice. Frontend/source/classic-template checks are offline evidence;
native image delivery/cache, actual close/focus, observer and body-transfer
acceptance remain unrun. Main reviews the concrete patch before publication.
