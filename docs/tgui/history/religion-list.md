# Religion List reader migration

This independent local source slice starts from master
`5bf745fc202ca5cc3794b778b5a5acdb9971264f`. It follows the bounded-reader step
of the all-screens inventory and does not stack on Known Languages #3452 or
Ship Stocks #3460. Player Help and preferences remain with their owners. The
faction list's dynamically generated symbols and rich text are a separate slice.

The existing Check Religion List verb/category/registration and civilizations
gate remain. It sends only the public religion name and index-3 point total,
in the same map-list order, including zero/negative/fractional totals. Founder,
clergy, colors and other stored record fields are not included. All preceding
religion creation, conversion, faith, clergy and object behavior is unchanged;
the historical #2984 founder-reference fix is in that preserved source.

Names are escaped once on the server and rendered as inert text. The existing
default modern adapter displays a labelled table and keeps a real classic
NanoUI template. The new dedicated religion_list window avoids reusing the old
artillery_window name. The UI uses update-only status, has no domain action
allowlist entry and disables the inherited machine-reset close callback.

The original /mob verb is also granted to observers on nomad maps. This reader
therefore adds no living/conscious/human/membership restriction: the source mob
must be its current connected owner and the existing map gate must hold. Body
transfer fails the source/user identity check. It is a snapshot: invoking the
verb refreshes data, while manager refreshes validate status/ownership without
querying point records. No automatic polling, mob/save field, gameplay mutation,
movement lock or generic mob.ui_interact override is introduced.

Local verification is limited to component/source/bootstrap checks, TypeScript,
an actual retained doT template and production-bundle JSDOM. These are not native
Topic, focus, cache, observer, close or transfer acceptance. BYOND/native client
execution, publication and deployment remain held until Main reviews the patch.
Future normal PR CI would use the existing compiler/offline/frontend scope;
this patch adds dependency paths, not commands or native-fixture admission.
