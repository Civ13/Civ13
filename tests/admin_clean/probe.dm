var/checks = 0
var/list/failed_labels = list()
var/log_calls = 0
var/message_calls = 0

/datum/actor
	var/datum/role/holder
	var/datum/actor/client
/datum/role
	var/rights = 0
/proc/to_chat(user, message)
	return
/proc/rights2text(rights)
	return "fixture rights"
/proc/key_name(who)
	return "fixture"
/proc/key_name_admin(who)
	return "fixture"
/proc/log_admin(message)
	log_calls++
/proc/message_admins(message, actor)
	message_calls++
/proc/get_turf(atom/A)
	while (A && !isturf(A))
		A = A.loc
	return A
/atom
	var/simulated = TRUE
	var/fluorescent = TRUE
	var/germ_level = 100
	var/list/blood_DNA = list("fixture" = "A+")
	var/gc_destroyed = FALSE
	var/gcDestroyed = FALSE
/obj/item
	var/blood_overlay
	var/shit_overlay
	var/piss_overlay
	var/health = 17
	var/owner = "original owner"
	var/reagent_volume = 23
	var/icon_calls = 0
/obj/item/proc/update_icon()
	icon_calls++
/obj/item/clothing/update_icon()
	..()
	if (dirtyness || fleas || radiation)
		failed_labels += "clothing reset before item refresh"
/obj/item/clothing
	var/gunshot_residue = "residue"
	var/radiation = 40
	var/dirtyness = 90
	var/fleas = TRUE
/mob
	var/refreshes = 0
/mob/proc/regenerate_icons()
	refreshes++
/mob/proc/probe_no_refresh()
	return

/proc/check(condition, label)
	checks++
	if (!condition)
		failed_labels += label
		world.log << "FAIL [label]"

/world
	maxx = 1
	maxy = 1
	maxz = 1
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return 0
/client/New()
	del(src)
/world/New()
	OpenPort("none")
	check(!world.port, "closed fixture port")
	check(!OpenPort(0) && !world.port, "reopen refused")
	var/datum/actor/A = new
	var/obj/item/clothing/I = new(locate(1,1,1))
	A.cmd_admin_clean_item(I)
	check(I.dirtyness == 90 && I.icon_calls == 0 && log_calls == 0, "non-admin direct call rejected")
	A.holder = new
	A.holder.rights = 2
	A.cmd_admin_clean_item(I)
	check(I.dirtyness == 90 && I.icon_calls == 0, "other staff rights rejected")
	A.holder.rights = R_ADMIN
	A.holder.rights = 0
	A.cmd_admin_clean_item(I)
	check(I.dirtyness == 90 && I.icon_calls == 0, "rights loss rejected")
	A.holder.rights = R_ADMIN
	A.cmd_admin_clean_item(null)
	var/obj/other = new(locate(1,1,1))
	A.cmd_admin_clean_item(other)
	check(!log_calls, "null and non-item rejected")
	I.gc_destroyed = TRUE
	A.cmd_admin_clean_item(I)
	check(I.icon_calls == 0, "queued deletion rejected")
	I.gc_destroyed = FALSE
	I.gcDestroyed = TRUE
	A.cmd_admin_clean_item(I)
	check(I.icon_calls == 0, "legacy deletion rejected")
	I.gcDestroyed = FALSE
	I.loc = null
	A.cmd_admin_clean_item(I)
	check(I.icon_calls == 0, "detached target rejected")
	del(I)
	A.cmd_admin_clean_item(I)
	check(!log_calls, "deleted reference rejected")
	A.holder = null
	var/obj/item/deadmin_target = new(locate(1,1,1))
	A.cmd_admin_clean_item(deadmin_target)
	check(deadmin_target.icon_calls == 0, "deadmin direct call rejected")
	A.holder = new
	A.holder.rights = R_ADMIN

	for (var/mode in list("ground", "held", "worn", "nested"))
		var/mob/carrier = new(locate(1,1,1))
		var/obj/item/bag = new(carrier)
		I = new(locate(1,1,1))
		if (mode == "held" || mode == "worn")
			I.loc = carrier
		if (mode == "nested")
			I.loc = bag
		var/atom/old_loc = I.loc
		var/obj/item/child = new(I)
		I.blood_overlay = image(icon = null, icon_state = "blood")
		I.shit_overlay = image(icon = null, icon_state = "shit")
		I.piss_overlay = image(icon = null, icon_state = "piss")
		I.overlays += I.blood_overlay
		I.overlays += I.shit_overlay
		I.overlays += I.piss_overlay
		var/prior_logs = log_calls
		A.cmd_admin_clean_item(I)
		check(!I.blood_DNA && !I.germ_level && !I.fluorescent && !I.gunshot_residue, "[mode] forensic washing")
		check(!I.dirtyness && !I.fleas && !I.radiation, "[mode] clothing washing")
		check(!I.overlays.len && !I.shit_overlay && !I.piss_overlay && I.icon_calls == 1, "[mode] item appearance")
		check(carrier.refreshes == ((mode == "held" || mode == "worn") ? 1 : 0), "[mode] refresh")
		check(I.loc == old_loc && child.loc == I && child.germ_level == 100, "[mode] contents and ownership")
		check(I.health == 17 && I.owner == "original owner" && I.reagent_volume == 23, "[mode] durability and reagents")
		check(log_calls == prior_logs + 1 && message_calls == log_calls, "[mode] audited once")
	var/obj/item/plain = new(locate(1,1,1))
	A.cmd_admin_clean_item(plain)
	check(!plain.blood_DNA && plain.icon_calls == 1, "ordinary item washed")
	check(plain.health == 17 && plain.reagent_volume == 23, "ordinary item preserved")
	A.cmd_admin_clean_item(plain)
	check(plain.icon_calls == 2 && plain.health == 17, "repeat clean safe")
	check(log_calls == 6 && message_calls == 6, "success audit count")
	text2file(json_encode(list("checks" = checks, "failed_labels" = failed_labels)), "result.json")
	world.log << "COMPLETE admin clean fixture"
	del(world)
	return
