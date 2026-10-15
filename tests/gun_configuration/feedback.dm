// Outbound chat adapter only. Action dispatch, waits, completion and wording are production code.
var/list/configuration_messages = list()
/proc/to_chat_wrapper(target, message)
	configuration_messages += list(list("target" = target, "message" = message))

/proc/configuration_expect_message(mob/H, message, label)
	configuration_check(configuration_messages.len == 1, "[label] emits one actor message")
	var/list/row = configuration_messages[1]
	configuration_check(row["target"] == H && row["message"] == message, "[label] names the actual items to the actor")
	configuration_messages.Cut()

/proc/configuration_feedback_checks()
	var/turf/T = locate(1,1,1)
	var/mob/living/human/configuration_ci/H = new(T)
	var/obj/item/weapon/gun/projectile/configuration_ci/G = new(T)
	G.name = "test rifle"
	var/obj/item/weapon/screwdriver/S = new(H)
	var/obj/item/weapon/gun_mount/R = new(H)
	configuration_hold(H,R,G)
	configuration_messages.Cut()
	// Cancellation runs before success, so a premature-message mutation fails here.
	G.test_action = "cancel"
	configuration_check(!G.install_configuration(R,H) && !G.optic_rail,"cancelled installation preserves configuration")
	configuration_check(!configuration_messages.len,"cancelled installation emits no success")
	G.test_action = "complete"
	G.attackby(R,H)
	configuration_check(G.optic_rail == R,"public rail attackby installs hardware")
	configuration_expect_message(H,SPAN_NOTICE("You attach [R.name] to [G.name]."),"rail install")
	var/obj/item/weapon/attachment/scope/adjustable/advanced/reddot/O = new(H)
	configuration_hold(H,O,G)
	G.attackby(O,H)
	configuration_check(G.scope == O && O.loc == R,"public optic attackby installs nested optic")
	configuration_expect_message(H,SPAN_NOTICE("You attach [O.name] to [G.name]."),"scope install")
	configuration_hold(H,S,G)
	G.test_action = "cancel"
	configuration_check(!O.removed(H,G) && G.scope == O,"cancelled removal preserves optic")
	configuration_check(!configuration_messages.len,"cancelled removal emits no success")
	G.test_action = "complete"
	configuration_check(O.removed(H,G),"public attachment removal succeeds")
	configuration_expect_message(H,SPAN_NOTICE("You remove [O.name] from [G.name]."),"optic removal")
	configuration_check(G.remove_configuration(R,H),"rail removal succeeds")
	configuration_expect_message(H,SPAN_NOTICE("You remove [R.name] from [G.name]."),"rail removal")
	// A rejected public action emits its existing warning once, never a success.
	configuration_hold(H,O,G)
	configuration_check(!G.try_attach(O,H),"public incompatible optic refuses installation")
	configuration_expect_message(H,SPAN_WARNING("Unload and hold the gun, hold a compatible part in your active hand, and have the required screwdriver or firearm bench available."),"incompatible optic")
	configuration_hold(H,R,G)
	G.test_action = "drop part"
	configuration_check(!G.install_configuration(R,H),"ownership loss refuses installation")
	configuration_check(!configuration_messages.len,"ownership loss emits no success")
	G.test_action = "complete"
	var/obj/item/weapon/gun_cleaning_kit/K = new(H)
	configuration_hold(H,K,G)
	G.health = 50
	G.maxhealth = 100
	G.test_action = "cancel"
	configuration_check(!G.service_firearm(H,K,null) && G.health == 50,"cancelled cleaning preserves condition")
	configuration_check(!configuration_messages.len,"cancelled cleaning emits no success")
	G.test_action = "complete"
	G.attackby(K,H)
	configuration_check(G.health == 80,"public cleaning kit repairs firearm")
	configuration_expect_message(H,SPAN_NOTICE("You finish cleaning [G.name]."),"cleaning")
	G.attackby(K,H)
	configuration_check(G.health == 80,"repeated cleaning refuses healthy firearm")
	configuration_expect_message(H,SPAN_WARNING("Unload first. A cleaning kit works only from 50% up to 80% condition; worse damage needs a firearm maintenance bench."),"healthy firearm")
	var/obj/structure/repair/gun/B = new(locate(2,1,1))
	G.test_action = "cancel"
	configuration_check(!G.service_firearm(H,null,B) && G.health == 80 && G.maxhealth == 100,"cancelled bench service preserves condition")
	configuration_check(!configuration_messages.len,"cancelled bench service emits no success")
	G.test_action = "complete"
	B.attackby(G,H)
	configuration_check(G.health == 99 && G.maxhealth == 99,"public bench service preserves native cost")
	configuration_expect_message(H,SPAN_NOTICE("You finish repairing [G.name] at [B.name]."),"bench service")
	// Map/constructor attachments and post-load recomputation must stay silent.
	var/obj/item/weapon/gun/projectile/configuration_ci/spawned = new(T)
	var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/pso1/preinstalled = new(T)
	configuration_check(spawned.spawn_add_attachment(preinstalled) && spawned.scope == preinstalled,"spawn attachment installs normally")
	spawned.recompute_configuration(H)
	configuration_check(!configuration_messages.len,"spawn and recomputation emit no action feedback")
