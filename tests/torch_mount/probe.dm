// Native probe for wall torch mounts.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/torch_mount/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf/floor/plating/marble
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/torch_mount_probe/New()
	return
/mob/living/human/torch_mount_probe/New()
	return
/mob/living/human/torch_mount_probe/update_icons()
	return
var/eco_failures = 0
var/eco_runtime_error = FALSE
/proc/eco_check(condition, label)
	if (!condition)
		eco_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	eco_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		makeDatumRefLists()
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/torch_mount_probe
		torch_mount_checks()
	catch(var/exception/e)
		eco_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = eco_failures, "runtime_error" = eco_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	shutdown()

/proc/torch_mount_hold(mob/living/human/H, obj/item/I)
	I.loc = H
	H.r_hand = I
	H.hand = 0

/proc/torch_mount_checks()
	var/mob/living/human/torch_mount_probe/H = new(locate(5, 5, 1))
	var/obj/structure/torch_stand/S = new(locate(5, 6, 1))
	S.dir = NORTH
	eco_check(S.storage, "a new mount has its holder")
	eco_check(S.can_dismantle_with_hammer(H), "empty mount can be dismantled")
	// Unlit torch, through the item click path.
	var/obj/item/flashlight/torch/T = new(locate(5, 5, 1))
	torch_mount_hold(H, T)
	T.resolve_attackby(S, H)
	eco_check(T.loc == S.storage, "an unlit torch goes into the mount (loc [T.loc])")
	eco_check(!S.can_dismantle_with_hammer(H) && T.loc == S.storage, "hammering an occupied mount leaves the torch in place")
	eco_check(S.icon_state == "torch_stand1", "the mount shows an unlit torch ([S.icon_state])")
	// Lighting it in the mount lights the mount.
	T.on = TRUE
	T.update_icon()
	eco_check(S.icon_state == "torch_stand1_on" && S.light_range > 0, "a lit torch lights the mount ([S.icon_state])")
	// Taking it out.
	S.storage.remove_from_storage(T, get_turf(S))
	eco_check(T.loc == get_turf(S), "the torch comes back out")
	eco_check(S.can_dismantle_with_hammer(H), "after removing the torch the mount can be dismantled again")
	eco_check(S.icon_state == "torch_stand" && !S.light_range, "an empty mount is dark ([S.icon_state])")
	qdel(T)
	// A lit torch.
	var/obj/item/flashlight/torch/on/L = new(locate(5, 5, 1))
	torch_mount_hold(H, L)
	L.resolve_attackby(S, H)
	eco_check(L.loc == S.storage, "a lit torch goes into the mount (loc [L.loc])")
	eco_check(S.icon_state == "torch_stand1_on", "the mount shows a lit torch ([S.icon_state])")
	S.storage.remove_from_storage(L, get_turf(S))
	// A lantern.
	var/obj/item/flashlight/lantern/on/N = new(locate(5, 5, 1))
	torch_mount_hold(H, N)
	N.resolve_attackby(S, H)
	eco_check(N.loc == S.storage, "a lantern goes into the mount (loc [N.loc])")
	eco_check(!S.can_dismantle_with_hammer(H), "an occupied lantern mount also refuses dismantling")
	S.storage.remove_from_storage(N, get_turf(S))
	// A load: the saved holder (with its torch) replaces the constructor's.
	var/obj/structure/torch_stand/R = new(locate(7, 6, 1))
	var/obj/item/weapon/storage/internal/old_holder = R.storage
	var/obj/item/weapon/storage/internal/saved = new(null)
	saved.loc = R
	saved.master_item = null
	var/obj/item/flashlight/torch/on/kept = new(saved)
	R.storage = saved
	qdel(old_holder)
	R.after_load()
	eco_check(R.storage == saved && saved.master_item == R, "a loaded mount keeps its saved holder")
	eco_check(R.icon_state == "torch_stand1_on" && R.light_range > 0, "a loaded mount with a lit torch is lit ([R.icon_state])")
	R.storage.remove_from_storage(kept, get_turf(R))
	eco_check(R.icon_state == "torch_stand", "the torch comes out of a loaded mount")
	var/obj/item/flashlight/torch/again = new(locate(5, 5, 1))
	torch_mount_hold(H, again)
	again.resolve_attackby(R, H)
	eco_check(again.loc == R.storage, "a loaded mount takes a torch again")
	// A load that lost the holder reference rebuilds one.
	var/obj/structure/torch_stand/Z = new(locate(8, 6, 1))
	qdel(Z.storage)
	Z.storage = null
	Z.after_load()
	eco_check(Z.storage && Z.storage.loc == Z && Z.storage.master_item == Z, "a mount without a holder rebuilds one")
	// Other structures with a built-in holder share the same path.
	var/obj/structure/katana_stand/K = new(locate(9, 6, 1))
	var/obj/item/weapon/material/sword/katana/blade = new(locate(5, 5, 1))
	torch_mount_hold(H, blade)
	blade.resolve_attackby(K, H)
	eco_check(blade.loc == K.storage, "a katana stand takes a katana (loc [blade.loc])")
