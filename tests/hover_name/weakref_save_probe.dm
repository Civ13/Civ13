// Real saver/loader, weak handles and widget; only the network client is adapted.
#define QDELETED(D) (!D || D.gc_destroyed)
#define REF(D) "\ref[D]"
#define QDEL_HINT_LETMELIVE 1
/datum
	var/gc_destroyed = FALSE
	var/datum/weakref/weak_reference
/datum/proc/Destroy()
	return
/datum/proc/MouseExited(atom/object, location, control, params)
	return
/obj/screen/hover_name
	var/mob/living/parentmob
/obj/screen
	var/process_flag = FALSE
/obj/screen/inventory
	var/slot_id
	var/mob/living/parentmob
/obj/screen/proc/process()
	return
/mob
	var/datum/hover_client/hover_client
	var/list/HUDinventory = list()
/mob/proc/get_equipped_item(slot)
	return null
/mob/living/human
	var/real_name = "unknown"
	var/obj/wear_mask
	var/obj/head
	var/werewolf = FALSE
	var/datum/hover_body_build/body_build
	var/title
	var/religious_title
/obj/var/flags_inv = 0
/datum/hover_body_build
	var/name
/datum/hover_client
	var/mob/mob
	var/list/screen = list()
	var/view = 5
	var/atom/eye

/proc/check_weakref_save()
	var/mob/living/human/H = new(locate(2,2,1))
	H.name = "Durable public identity"
	H.real_name = H.name
	H.persistence_owner_ckey = "weakrefaccount"
	var/datum/weakref/original = WEAKREF(H)
	check(original.resolve() == H, "source weak handle invalid")
	var/obj/item/test/I = new(H)
	I.number = 842
	var/savefile/F = new("weakref-runtime.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, H, 1)
	var/path = map_storage.entry_path(F, ref)
	F.cd = path
	check(!("weak_reference" in F.dir), "weak reference cache exported")
	check(H.weak_reference == original && original.resolve() == H, "save changed live weak cache")
	// Reproduce an old completed v2 save: the cached handle holds another
	// process's native ref string, not a durable entry reference to its owner.
	F["[path]/weak_reference"] << list("kind" = "entry", "ref" = 900)
	var/weak_path = map_storage.entry_path(F, 900)
	F["[weak_path]/type"] << /datum/weakref
	F["[weak_path]/reference"] << list("kind" = "value", "value" = REF(H))
	check(F["[weak_path]/type"] == /datum/weakref, "historical weak handle schema invalid")
	F = null
	F = new("weakref-runtime.sav")
	map_storage.clear_bookkeeping()
	var/mob/living/human/R = map_storage.Load_Entry(F, ref, starting_loc = locate(3,2,1))
	var/datum/weakref/imported_cache = R.weak_reference
	var/datum/weakref/current = WEAKREF(R)
	check(R.name == H.name && R.real_name == H.real_name && R.persistence_owner_ckey == H.persistence_owner_ckey, "weak cache migration changed identity")
	var/obj/item/test/RI = locate(/obj/item/test) in R
	check(RI && RI.number == 842 && R.loc == locate(3,2,1), "weak cache migration changed inventory or location")
	var/datum/hover_client/C = new
	C.mob = R
	C.eye = R
	R.hover_client = C
	var/obj/screen/hover_name/label = new
	label.parentmob = R
	R.HUDneed["hover name"] = label
	C.screen += label
	label.set_target(R)
	check(findtext(label.maptext, "Durable public identity"), "restored own hover lost public name")
	label.process()
	check(findtext(label.maptext, "Durable public identity"), "stationary restored own hover cleared")
	check(!imported_cache, "historical weak reference cache imported")
	check(!("900" in map_storage.existing_references), "historical weak handle constructed")
	check(current && current.resolve() == R, "restored weak handle fails to resolve")
	// Import must skip the old cache before decoding, preserving a live cache.
	map_storage.clear_bookkeeping()
	map_storage.Load_Entry(F, ref, replacement = R)
	check(R.weak_reference == current && current.resolve() == R, "replacement import replaced live weak cache")
	var/savefile/L = new("weakref-flat.sav")
	L["/entries/1/type"] << /mob/living/human
	L["/entries/1/weak_reference"] << "**entry900"
	L["/entries/900/type"] << /datum/weakref
	L["/entries/900/reference"] << REF(H)
	map_storage.clear_bookkeeping()
	var/mob/living/human/legacy = map_storage.Load_Entry(L, 1, starting_loc = locate(4,2,1))
	check(!legacy.weak_reference && !("900" in map_storage.existing_references), "flat historical weak cache imported")
	check(WEAKREF(legacy).resolve() == legacy, "flat restored weak handle fails to resolve")
	map_storage.clear_bookkeeping()
	// Leave no duplicate ownership or test inventory for the parent world save.
	qdel(label)
	qdel(C)
	qdel(I)
	for(var/obj/item/test/restored_item in R)
		qdel(restored_item)
	qdel(H)
	qdel(R)
	qdel(legacy)
	world.log << "PASS weak reference save migration and restored own hover"
