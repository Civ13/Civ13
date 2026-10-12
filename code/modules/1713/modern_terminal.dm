/obj/structure/telecom/terminal
	name = "cable network terminal"
	desc = "A powered local text terminal. It sends immediate messages to terminals on the same electrical cable network; no Internet or email storage."
	icon = 'icons/obj/computers.dmi'
	icon_state = "ibm"
	powerneeded = 5
	var/tmp/last_message = -100

/obj/structure/telecom/terminal/persistence_runtime_var(var_name)
	return var_name == "last_message" || ..()

/obj/structure/telecom/terminal/attack_hand(mob/living/human/H)
	if (!istype(H) || H.stat != CONSCIOUS || !H.can_use_hands() || get_dist(H, src) > 1)
		return
	var/choice = input(H, "Local network terminal", name) in list("Send", "Power", "Cancel")
	if (!H || H.stat != CONSCIOUS || !H.can_use_hands() || get_dist(H, src) > 1)
		return
	if (choice == "Power")
		enabled = !enabled
		if (!enabled && powersource)
			powersource.update_power(-powerneeded, 1, src)
	if (choice == "Send")
		var/message = input(H, "Message to connected terminals (200 characters)", name) as text|null
		if (H && H.stat == CONSCIOUS && H.can_use_hands() && get_dist(H, src) <= 1)
			to_chat(H, "Delivered to [send_network_message(sanitize(message, 200))] terminals.")

/obj/structure/telecom/terminal/proc/send_network_message(message)
	if (!message || world.time < last_message + 20 || !operational())
		return 0
	last_message = world.time
	var/delivered = 0
	var/list/hearers = list()
	for (var/obj/structure/telecom/terminal/T in civ_telecom_devices)
		if (delivered >= 32)
			break
		if (T == src || !T.operational() || !civ_network_connected(T))
			continue
		delivered++
		for (var/mob/living/human/H in view(3, T))
			if (hearers.len >= 32)
				break
			if (!(H in hearers) && H.client && H.stat == CONSCIOUS)
				hearers |= H
				to_chat(H, "[T] displays: [message]")
	return delivered
