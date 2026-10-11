// Production configuration and persistence; bounded startup/wait/inventory adapters.
/world
	hub = ""
	hub_password = ""
	maxx = 5
	maxy = 3
	maxz = 1
	turf = /turf
	area = /area
/mob/living/human/configuration_ci
	var/test_incapacitated = FALSE
	New()
		return
	incapacitated(incapacitation_flags = INCAPACITATION_DEFAULT)
		return test_incapacitated
	update_icons()
		return
	unEquip(obj/item/I, force = FALSE)
		if (r_hand == I) r_hand = null
		if (l_hand == I) l_hand = null
		I.loc = loc
		return TRUE

/obj/item/weapon/gun/projectile/configuration_ci
	weight = 4
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL|ATTACH_UNDER
	scope_mounts = list("dovetail")
	under_mounts = list("picatinny")
	caliber = "7.62x54"
	var/test_action = "complete"
	wait_for_configuration(mob/living/human/H, delay)
		sleep(1)
		switch(test_action)
			if ("cancel") return FALSE
			if ("drop part") H.r_hand.loc = H.loc
			if ("drop gun") loc = H.loc
			if ("tool lost")
				for (var/obj/item/weapon/screwdriver/S in H.contents) S.loc = H.loc
			if ("incapacitated") H:test_incapacitated = TRUE
			if ("load") ammo_magazine = new /obj/item/ammo_magazine(src)
			if ("damage") health--
			if ("shared") configuration_concurrent = install_configuration(H.r_hand,H)
		return TRUE

var/configuration_checks = 0
var/configuration_runtime = FALSE
var/configuration_concurrent
/world/Error(exception/E)
	configuration_runtime = TRUE
	world.log << "GUN_CONFIGURATION RUNTIME: [E] at [E.file]:[E.line]"
	text2file("FAIL: runtime [E]","gun_configuration-result.txt")
/proc/configuration_check(condition,label)
	if (!condition) throw EXCEPTION(label)
	configuration_checks++
	world.log << "GUN_CONFIGURATION PASS: [label]"
/proc/configuration_hold(mob/living/human/configuration_ci/H,obj/item/P,obj/item/weapon/gun/G)
	H.hand = FALSE
	H.r_hand = P
	H.l_hand = G
	P.loc = H
	G.loc = H
/proc/configuration_roundtrip(obj/item/I)
	var/savefile/F = new("configuration-[configuration_checks].sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F,I,1)
	configuration_check(ref > 0,"production serializer accepts [I.type]")
	map_storage.clear_bookkeeping()
	var/obj/item/result = map_storage.Load_Entry(F,ref,starting_loc=locate(2,1,1))
	for (var/datum/D in map_storage.all_loaded.Copy()) D.after_load()
	return result
/world/New()
	try
		run_configuration_checks()
		configuration_check(!configuration_runtime,"no runtime errors")
		text2file("PASS: [configuration_checks] production hardware/configuration/ammo/maintenance/save assertions","gun_configuration-result.txt")
	catch(var/exception/E)
		text2file("FAIL: [E] at [E.file]:[E.line]","gun_configuration-result.txt")
	del(world)
/proc/run_configuration_checks()
	var/turf/T = locate(1,1,1)
	var/mob/living/human/configuration_ci/H = new(T)
	var/obj/item/weapon/screwdriver/S = new(H)
	var/obj/item/weapon/gun/projectile/configuration_ci/G = new(T)
	var/obj/item/weapon/attachment/scope/adjustable/advanced/reddot/O = new(H)
	configuration_hold(H,O,G)
	configuration_check(!G.install_configuration(O,H),"Picatinny optic rejects native dovetail without hardware")
	var/obj/item/weapon/gun_mount/R = new(H)
	configuration_hold(H,R,G)
	S.loc = T
	configuration_check(!G.install_configuration(R,H),"rail requires screwdriver")
	S.loc = H
	configuration_check(G.install_configuration(R,H) && R.loc == G && G.optic_rail == R,"real dovetail rail installs")
	configuration_check(G.weight == 4.15 && G.ergonomics < 1,"hardware mass costs native handling")
	var/rail_ergonomics = G.ergonomics
	G.last_shot_time = world.time
	var/rail_spread = G.get_dispersion_range(H)
	configuration_hold(H,O,G)
	configuration_check(G.install_configuration(O,H) && O.loc == R && G.scope == O,"hardware physically hosts compatible optic")
	configuration_check(G.ergonomics > rail_ergonomics && G.caliber == "7.62x54","optic affects native dispersion ergonomics without changing ammunition")
	G.last_shot_time = world.time
	configuration_check(G.get_dispersion_range(H) < rail_spread,"production firing dispersion responds to configured ergonomics")
	configuration_check(!G.remove_configuration(R,H),"occupied rail cannot be removed underneath optic")
	var/obj/item/weapon/gun_mount/R2 = new(H)
	configuration_hold(H,R2,G)
	configuration_check(!G.install_configuration(R2,H),"duplicate rail rejected")
	configuration_check(!G.install_configuration(S,H),"non-module tool rejected without runtime")
	G.gun_work_busy = TRUE
	R.mount_busy = TRUE
	O.configuration_busy = TRUE
	var/obj/item/weapon/gun/projectile/configuration_ci/saved = configuration_roundtrip(G)
	configuration_check(saved && saved.optic_rail && saved.scope && saved.scope.loc == saved.optic_rail && saved.optic_rail.loc == saved,"nested hardware and optic survive native save")
	configuration_check(!saved.gun_work_busy && !saved.optic_rail.mount_busy && !saved.scope.configuration_busy,"runtime reservations reset after load")
	configuration_check(saved.weight == G.weight && abs(saved.ergonomics-G.ergonomics) < 0.001 && saved.caliber == G.caliber,"configuration stats recompute identically after load")
	G.gun_work_busy = FALSE
	R.mount_busy = FALSE
	O.configuration_busy = FALSE
	configuration_hold(H,S,G)
	configuration_check(G.remove_configuration(O,H) && !O.A_attached && O.loc == T,"optic reversibly removes")
	for (var/datum/action/action in O.actions)
		configuration_check(!action.owner && !(action in H.actions),"removed optic actions release actor references")
	configuration_check(G.remove_configuration(R,H) && G.weight == 4 && G.ergonomics == 1 && !G.scope,"rail removal restores exact base stats")
	configuration_check(!G.remove_configuration(R,H) && (G.attachment_slots & ATTACH_SCOPE),"repeated removal cannot mint extra slot bits")
	for (var/i in 1 to 12)
		configuration_hold(H,R,G)
		configuration_check(G.install_configuration(R,H),"cycle [i] rail install")
		configuration_hold(H,O,G)
		configuration_check(G.install_configuration(O,H),"cycle [i] optic install")
		configuration_hold(H,S,G)
		configuration_check(G.remove_configuration(O,H) && G.remove_configuration(R,H) && G.weight == 4 && G.ergonomics == 1 && G.attachments.len == 1,"cycle [i] no accumulated effects or retained modules")
	// The intended negative control omits completion ownership validation here.
	configuration_hold(H,R,G)
	G.test_action = "drop part"
	configuration_check(!G.install_configuration(R,H) && !G.optic_rail && R.loc == T,"post-wait dropped part remains uninstalled")
	for (var/action in list("cancel","drop gun","tool lost","incapacitated","load","shared"))
		G.loc = H
		H.test_incapacitated = FALSE
		S.loc = H
		configuration_hold(H,R,G)
		G.test_action = action
		var/result = G.install_configuration(R,H)
		configuration_check(action == "shared" ? (result && !configuration_concurrent) : (!result && !G.optic_rail && !G.gun_work_busy && !R.mount_busy),"safe interrupted/shared installation [action]")
		if (G.ammo_magazine) qdel(G.ammo_magazine)
		G.ammo_magazine = null
		G.test_action = "complete"
		H.test_incapacitated = FALSE
		S.loc = H
		if (G.optic_rail) G.remove_configuration(R,H)
	configuration_hold(H,R,G)
	G.chambered = new /obj/item/ammo_casing(G)
	configuration_check(!G.install_configuration(R,H),"loaded chamber rejects work")
	qdel(G.chambered)
	G.chambered = null
	var/obj/item/ammo_casing/C = new(G)
	G.loaded += C
	configuration_check(!G.install_configuration(R,H),"internal ammunition rejects work")
	G.loaded.Cut()
	qdel(C)
	G.ammo_magazine = new /obj/item/ammo_magazine(G)
	configuration_check(!G.install_configuration(R,H),"even empty inserted magazine rejects work")
	qdel(G.ammo_magazine)
	G.ammo_magazine = null
	var/obj/item/weapon/attachment/silencer/pistol/P = new(H)
	configuration_hold(H,P,G)
	configuration_check(!G.install_configuration(P,H),"wrong suppressor caliber/category rejected")
	var/obj/item/weapon/attachment/under/foregrip/U = new(H)
	configuration_hold(H,U,G)
	configuration_check(!G.install_configuration(U,H),"underbarrel needs firearm bench")
	var/obj/structure/repair/gun/B = new(locate(2,1,1))
	configuration_check(G.install_configuration(U,H) && G.under == U,"compatible underbarrel installs at bench")
	configuration_check(G.remove_configuration(U,H) && !G.under,"underbarrel removes at bench")
	new /obj/item/weapon/gun_mount(R)
	configuration_hold(H,R,G)
	configuration_check(!G.install_configuration(R,H),"hardware nesting/chains rejected")
	for (var/obj/item/I in R.contents.Copy()) qdel(I)
	var/obj/item/weapon/gun_cleaning_kit/K = new(H)
	configuration_hold(H,K,G)
	G.health = 30
	G.maxhealth = 100
	configuration_check(!G.service_firearm(H,K,null) && G.health == 30,"field kit rejects damage below fifty percent")
	G.health = 90
	configuration_check(!G.service_firearm(H,K,null) && G.health == 90,"field kit never lowers healthy condition")
	G.health = 50
	configuration_check(G.service_firearm(H,K,null) && G.health == 80,"field kit restores fifty-to-eighty range")
	G.health = 60
	G.test_action = "damage"
	configuration_check(!G.service_firearm(H,K,null) && G.health == 59 && !G.gun_work_busy,"damage during maintenance cancels repair")
	G.test_action = "complete"
	configuration_check(G.service_firearm(H,null,B) && G.maxhealth == 99 && G.health == 84,"bench retains native twenty-five repair and one max-condition cost")
	configuration_check(!B.firearm_service_busy && !G.gun_work_busy,"bench and gun locks released")
	G.gun_work_busy = TRUE
	configuration_check(!G.special_check(H),"gun cannot fire during work")
	configuration_check(!G.load_ammo(C,H),"gun cannot reload during work")
	G.gun_work_busy = FALSE
	// Real production SVD spawns its native dovetail scope; migration is idempotent.
	var/obj/item/weapon/gun/projectile/semiautomatic/svd/V = new(T)
	configuration_check(V.scope && V.scope.loc == V,"native SVD constructor retains optic")
	V.configuration_base_ergonomics = null
	V.configuration_base_weight = null
	V.ergonomics = V.scope.ergonomics
	var/obj/item/weapon/gun/projectile/semiautomatic/svd/loaded_svd = configuration_roundtrip(V)
	configuration_check(loaded_svd.scope && loaded_svd.scope.loc == loaded_svd && loaded_svd.attachments.len == V.attachments.len,"legacy SVD attachments migrate without duplicate constructor parts")
	var/effect = loaded_svd.ergonomics
	loaded_svd.after_load()
	configuration_check(loaded_svd.ergonomics == effect,"repeated migration does not accumulate effects")
