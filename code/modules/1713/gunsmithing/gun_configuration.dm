// Bounded gun-owned configuration. No timers, world scans or ammunition conversion.
/obj/item/weapon/gun
	var/tmp/gun_work_busy = FALSE
	var/configuration_base_ergonomics = null
	var/configuration_base_weight = null
	var/tmp/list/configuration_base_actions
	var/tmp/list/configuration_base_verbs
	var/obj/item/weapon/gun_mount/optic_rail

/obj/item/weapon/gun_mount
	name = "dovetail-to-Picatinny rail adapter"
	desc = "A removable dovetail clamp with a Picatinny optic rail. Requires a screwdriver; remove its optic before removing the rail."
	icon = 'icons/obj/guns/mounts.dmi'
	icon_state = "dovetail_rail"
	w_class = ITEM_SIZE_SMALL
	weight = 0.15
	var/input_mount = "dovetail"
	var/output_mount = "picatinny"
	var/tmp/mount_busy = FALSE

/obj/item/weapon/gun_mount/persistence_runtime_var(key)
	return key == "mount_busy" || ..()

/obj/item/weapon/attachment
	var/tmp/configuration_busy = FALSE

/obj/item/weapon/attachment/persistence_runtime_var(key)
	return (key in list("configuration_busy", "ongun", "zoomed", "looking", "actions", "azoom")) || ..()

/obj/item/weapon/gun/persistence_runtime_var(key)
	return (key in list("gun_work_busy", "configuration_base_actions", "configuration_base_verbs", "actions", "scope_image", "barrel_image", "under_image", "launcher_image", "mag_image")) || ..()

/obj/item/weapon/gun/proc/configuration_slot(obj/item/P)
	if (istype(P, /obj/item/weapon/attachment))
		var/obj/item/weapon/attachment/A = P
		return A.attachment_type
	if (istype(P, /obj/item/weapon/gun/launcher/grenade/underslung))
		return ATTACH_UNDER
	return 0

/obj/item/weapon/gun/proc/configuration_parts()
	var/list/parts = list()
	for (var/obj/item/P in contents)
		if (configuration_slot(P) && P:A_attached) parts |= P
	if (optic_rail && optic_rail.loc == src)
		for (var/obj/item/weapon/attachment/scope/A in optic_rail.contents)
			if (A.A_attached) parts |= A
	return parts

/obj/item/weapon/gun/proc/initialize_configuration()
	if (optic_rail && optic_rail.loc != src) optic_rail = null
	if (!configuration_base_actions)
		configuration_base_actions = actions ? actions.Copy() : list()
		configuration_base_verbs = verbs.Copy()
		for (var/obj/item/weapon/attachment/A in configuration_parts())
			configuration_base_actions -= A.actions
			configuration_base_verbs -= A.verbs
	if (isnull(configuration_base_ergonomics))
		// Old saves contain effective ergonomics; recover their pre-attachment value.
		var/factor = 1
		for (var/obj/item/weapon/attachment/A in configuration_parts())
			if (A.A_attached && A.ergonomics > 0) factor *= A.ergonomics
		configuration_base_ergonomics = ergonomics / factor
	if (isnull(configuration_base_weight)) configuration_base_weight = weight

/obj/item/weapon/gun/proc/recompute_configuration(mob/user)
	initialize_configuration()
	var/list/parts = configuration_parts()
	var/supported_slots = attachment_slots
	for (var/obj/item/P in attachments) supported_slots |= configuration_slot(P)
	attachments = parts
	attachment_slots = supported_slots
	scope = null
	under = null
	silencer = null
	bayonet = null
	launcher = null
	actions = configuration_base_actions.Copy()
	verbs.Cut()
	verbs |= configuration_base_verbs
	var/factor = 1
	var/added_weight = 0
	if (optic_rail && optic_rail.loc == src) added_weight += optic_rail.weight
	for (var/obj/item/P in parts)
		attachment_slots &= ~configuration_slot(P)
		added_weight += max(0, P.weight)
		if (istype(P, /obj/item/weapon/attachment))
			var/obj/item/weapon/attachment/A = P
			A.A_attached = TRUE
			factor *= max(0.01, A.ergonomics)
			actions |= A.actions
			verbs |= A.verbs
			if (istype(A, /obj/item/weapon/attachment/scope) && !istype(A, /obj/item/weapon/attachment/scope/iron_sights)) scope = A
			else if (istype(A, /obj/item/weapon/attachment/under)) under = A
			else if (istype(A, /obj/item/weapon/attachment/silencer)) silencer = A
			else if (istype(A, /obj/item/weapon/attachment/bayonet)) bayonet = A
		else
			var/obj/item/weapon/gun/launcher/grenade/underslung/L = P
			L.A_attached = TRUE
			launcher = L
	weight = configuration_base_weight + added_weight
	// Added mass costs handling; existing ergonomics still drive native firing spread.
	ergonomics = configuration_base_ergonomics * factor / (1 + added_weight / max(1, configuration_base_weight))
	if (user) update_attachment_actions(user)
	update_icon()

/obj/item/weapon/gun/after_load()
	..()
	gun_work_busy = FALSE
	if (optic_rail && optic_rail.loc != src) optic_rail = null
	recompute_configuration()

/obj/item/weapon/gun/proc/configuration_unloaded()
	if (istype(src, /obj/item/weapon/gun/projectile))
		var/obj/item/weapon/gun/projectile/G = src
		if (G.chambered || G.loaded.len || G.ammo_magazine) return FALSE
	if (istype(src, /obj/item/weapon/gun/launcher/grenade))
		var/obj/item/weapon/gun/launcher/grenade/G = src
		if (G.grenades.len) return FALSE
	if (launcher && launcher.grenades.len) return FALSE
	return TRUE

/obj/item/weapon/gun/proc/configuration_actor(mob/living/human/H)
	return !QDELETED(src) && !QDELETED(H) && loc == H && isturf(H.loc) && (H.get_active_hand() == src || H.get_inactive_hand() == src) && !H.incapacitated()

/obj/item/weapon/gun/proc/configuration_bench(mob/living/human/H)
	for (var/obj/structure/repair/gun/B in range(1, H))
		if (!QDELETED(B) && isturf(B.loc) && B.anchored) return B
	return null

/obj/item/weapon/gun/proc/configuration_tools(obj/item/P, mob/living/human/H)
	if (istype(P, /obj/item/weapon/attachment/under) || istype(P, /obj/item/weapon/gun/launcher/grenade/underslung))
		return configuration_bench(H)
	if (istype(P, /obj/item/weapon/gun_mount) || istype(P, /obj/item/weapon/attachment/scope))
		for (var/obj/item/weapon/screwdriver/S in H.contents)
			if (S.loc == H) return TRUE
		return FALSE
	return TRUE

/obj/item/weapon/gun/proc/configuration_compatible(obj/item/P)
	if (QDELETED(P)) return FALSE
	if (istype(P, /obj/item/weapon/gun_mount))
		var/obj/item/weapon/gun_mount/M = P
		return P.type == /obj/item/weapon/gun_mount && !optic_rail && !scope && (attachment_slots & ATTACH_SCOPE) && (M.input_mount in scope_mounts) && !(M.output_mount in scope_mounts) && !P.contents.len
	var/slot = configuration_slot(P)
	if (!slot || !(attachment_slots & slot)) return FALSE
	if (istype(P, /obj/item/weapon/attachment))
		var/obj/item/weapon/attachment/A = P
		if (!A.attachable || A.A_attached || A.ergonomics <= 0 || (A.fits && !(stat in A.fits))) return FALSE
		if (istype(A, /obj/item/weapon/attachment/scope) && !istype(A, /obj/item/weapon/attachment/scope/iron_sights))
			var/obj/item/weapon/attachment/scope/S = A
			return (S.mount in scope_mounts) || (optic_rail && optic_rail.loc == src && S.mount == optic_rail.output_mount && !optic_rail.contents.len)
		if (istype(A, /obj/item/weapon/attachment/silencer))
			var/obj/item/weapon/attachment/silencer/S = A
			if (!istype(src, /obj/item/weapon/gun/projectile)) return FALSE
			var/obj/item/weapon/gun/projectile/G = src
			return S.caliber == "multicaliber" || S.caliber == G.caliber
		if (istype(A, /obj/item/weapon/attachment/under))
			var/obj/item/weapon/attachment/under/U = A
			return U.mount in under_mounts
		if (istype(A, /obj/item/weapon/attachment/bayonet) && stat == "pistol") return FALSE
		return TRUE
	var/obj/item/weapon/gun/launcher/grenade/underslung/L = P
	return !L.A_attached && !L.grenades.len && (L.mount in under_mounts)

/obj/item/weapon/gun/proc/configuration_part_busy(obj/item/P, value = null)
	if (!P) return FALSE
	if (istype(P, /obj/item/weapon/attachment))
		var/obj/item/weapon/attachment/A = P
		if (!isnull(value)) A.configuration_busy = value
		return A.configuration_busy
	if (istype(P, /obj/item/weapon/gun_mount))
		var/obj/item/weapon/gun_mount/M = P
		if (!isnull(value)) M.mount_busy = value
		return M.mount_busy
	var/obj/item/weapon/gun/L = P
	if (!isnull(value)) L.gun_work_busy = value
	return L.gun_work_busy

/obj/item/weapon/gun/proc/wait_for_configuration(mob/living/human/H, delay)
	return do_after(H, delay, src)

/obj/item/weapon/gun/proc/install_configuration(obj/item/P, mob/living/human/H, spawn_part = FALSE)
	initialize_configuration()
	if (!P || gun_work_busy || !configuration_compatible(P) || configuration_part_busy(P)) return FALSE
	if (!spawn_part && (!configuration_actor(H) || !configuration_unloaded() || P.loc != H || H.get_active_hand() != P || !configuration_tools(P,H))) return FALSE
	if (!spawn_part)
		gun_work_busy = TRUE
		configuration_part_busy(P, TRUE)
		var/complete = wait_for_configuration(H, 15)
		if (!complete || QDELETED(P) || !configuration_actor(H) || !configuration_unloaded() || P.loc != H || H.get_active_hand() != P || !configuration_tools(P,H) || !configuration_compatible(P))
			gun_work_busy = FALSE
			configuration_part_busy(P, FALSE)
			return FALSE
		if (!H.unEquip(P))
			gun_work_busy = FALSE
			configuration_part_busy(P, FALSE)
			return FALSE
	P.loc = src
	if (istype(P, /obj/item/weapon/gun_mount)) optic_rail = P
	else if (istype(P, /obj/item/weapon/attachment/scope) && optic_rail && !(P:mount in scope_mounts)) P.loc = optic_rail
	if (configuration_slot(P)) P:A_attached = TRUE
	attachments |= P
	configuration_part_busy(P, FALSE)
	gun_work_busy = FALSE
	recompute_configuration(H)
	return TRUE

/obj/item/weapon/gun/proc/remove_configuration(obj/item/P, mob/living/human/H)
	if (!configuration_slot(P) && !istype(P, /obj/item/weapon/gun_mount)) return FALSE
	if (!P || gun_work_busy || configuration_part_busy(P) || !configuration_actor(H) || !configuration_unloaded() || !configuration_tools(P,H)) return FALSE
	if (istype(P, /obj/item/weapon/attachment/scope/iron_sights)) return FALSE
	if (P == optic_rail)
		if (P.loc != src || P.contents.len) return FALSE
	else if (!(P in configuration_parts())) return FALSE
	gun_work_busy = TRUE
	configuration_part_busy(P, TRUE)
	var/old_loc = P.loc
	var/complete = wait_for_configuration(H, 15)
	if (!complete || QDELETED(P) || !configuration_actor(H) || !configuration_unloaded() || !configuration_tools(P,H) || P.loc != old_loc || (P == optic_rail ? P.contents.len : !(P in configuration_parts())))
		gun_work_busy = FALSE
		configuration_part_busy(P, FALSE)
		return FALSE
	// Restore the bit once, before dropping the part. Recompute derives all effects.
	attachment_slots |= configuration_slot(P)
	attachments -= P
	if (istype(P, /obj/item/weapon/attachment))
		var/obj/item/weapon/attachment/A = P
		for (var/datum/action/action in A.actions)
			if (action.owner) action.Remove(action.owner)
	P.dropped(H)
	if (istype(P, /obj/item/weapon/attachment)) P:A_attached = FALSE
	else if (istype(P, /obj/item/weapon/gun/launcher/grenade/underslung)) P:A_attached = FALSE
	if (P == optic_rail) optic_rail = null
	P.loc = H.loc
	configuration_part_busy(P, FALSE)
	gun_work_busy = FALSE
	recompute_configuration(H)
	return TRUE

/obj/item/weapon/attachment/proc/attached(mob/user, obj/item/weapon/gun/G, quick = FALSE)
	return G && G.install_configuration(src, user, quick && !user)
/obj/item/weapon/attachment/proc/removed(mob/user, obj/item/weapon/gun/G)
	return G && G.remove_configuration(src,user)
/obj/item/weapon/gun/launcher/grenade/underslung/proc/attached(mob/user, obj/item/weapon/gun/G, quick = FALSE)
	return G && G.install_configuration(src,user,quick && !user)
/obj/item/weapon/gun/launcher/grenade/underslung/proc/removed(mob/user, obj/item/weapon/gun/G)
	return G && G.remove_configuration(src,user)
/obj/item/weapon/gun/proc/spawn_add_attachment(obj/item/weapon/attachment/A)
	return install_configuration(A, null, TRUE)
/obj/item/weapon/gun/proc/try_attach(obj/item/P, mob/user)
	if (!install_configuration(P,user))
		to_chat(user, SPAN_WARNING("Unload and hold the gun, hold a compatible part in your active hand, and have the required screwdriver or firearm bench available."))
		return FALSE
	return TRUE
/obj/item/weapon/gun/proc/attach_A(obj/item/P, mob/user)
	return try_attach(P,user)

/obj/item/weapon/gun/verb/field_strip()
	set name = "Field Strip"
	set desc = "Select a removable part. Unload first; optics need a screwdriver and underbarrel parts need a firearm bench."
	set category = null
	var/mob/living/human/H = usr
	var/list/choices = list("Cancel")
	for (var/obj/item/P in configuration_parts())
		if (!istype(P,/obj/item/weapon/attachment/scope/iron_sights)) choices += P
	if (optic_rail) choices += optic_rail
	var/choice = WWinput(H,"Remove which part?","Field Strip","Cancel",choices)
	if (choice != "Cancel" && (choice in choices) && !remove_configuration(choice,H))
		to_chat(H,SPAN_WARNING("Cannot remove this part now. Unload, keep holding the gun, and supply the required tools. Remove the optic before its rail."))

/obj/structure/repair/gun
	var/tmp/firearm_service_busy = FALSE
/obj/structure/repair/gun/persistence_runtime_var(key)
	return key == "firearm_service_busy" || ..()

/obj/item/weapon/gun/proc/firearm_service_access(mob/living/human/H, obj/item/weapon/gun_cleaning_kit/K, obj/structure/repair/gun/B)
	if (!configuration_actor(H) || !configuration_unloaded() || !isnum(health) || !isnum(maxhealth) || health <= 0 || maxhealth <= 0) return FALSE
	if (B)
		return !QDELETED(B) && isturf(B.loc) && B.anchored && in_range(B,H) && maxhealth > B.damageamount
	return !QDELETED(K) && K.loc == H && H.get_active_hand() == K && !istype(src,/obj/item/weapon/gun/projectile/bow) && health/maxhealth >= 0.5 && health/maxhealth < 0.8

/obj/item/weapon/gun/proc/service_firearm(mob/living/human/H, obj/item/weapon/gun_cleaning_kit/K, obj/structure/repair/gun/B)
	if (gun_work_busy || (B && B.firearm_service_busy) || !firearm_service_access(H,K,B)) return FALSE
	gun_work_busy = TRUE
	if (B) B.firearm_service_busy = TRUE
	var/old_health = health
	var/old_maxhealth = maxhealth
	var/bench_loc = B ? B.loc : null
	var/complete = wait_for_configuration(H, B ? B.delay : 100)
	if (!complete || !firearm_service_access(H,K,B) || health != old_health || maxhealth != old_maxhealth || (B && B.loc != bench_loc))
		gun_work_busy = FALSE
		if (B) B.firearm_service_busy = FALSE
		return FALSE
	if (B)
		maxhealth -= B.damageamount
		health = min(health+B.repairamount, maxhealth)
		B.firearm_service_busy = FALSE
	else health = maxhealth*0.8
	gun_work_busy = FALSE
	return TRUE

/obj/structure/repair/gun/attackby(obj/item/P, mob/user)
	if (istype(P,/obj/item/weapon/gun))
		var/obj/item/weapon/gun/G = P
		if (!G.service_firearm(user,null,src))
			to_chat(user,SPAN_WARNING("Unload and hold a repairable firearm next to the bench; another operation may be in progress."))
		return
	return ..()
