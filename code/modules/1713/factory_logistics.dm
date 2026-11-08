// Logistics (phase 4a of docs/factory-automation-design.md): the fast belt,
// ports that let arms load and unload train wagons and shopping carts, and the
// vehicle cargo hold.

var/global/list/factory_active_fast_belts = list()

//////////////////////////////////////////////////////////////////////////////
// Fast belt: a second belt step each tick, so cargo crosses two tiles a second.
// The second step runs after every belt has taken its first, with the moved
// marks cleared, so only fast belts advance in it.

/obj/structure/factory_belt/fast
	name = "fast factory belt"
	desc = "A geared roller belt that carries loose items toward the arrow twice as fast as a plain belt. It needs a powered belt drive nearby. Use a wrench to turn it."
	color = "#ffd27f"
	belt_passes = 2
	assembly_type = /obj/item/factory_belt_assembly/fast

/obj/item/factory_belt_assembly/fast
	name = "fast factory belt assembly"
	desc = "A folded geared belt section. Use it on an adjacent floor tile to lay a fast belt that runs away from you."
	color = "#ffd27f"
	belt_type = /obj/structure/factory_belt/fast

/proc/factory_fast_belts_step()
	if (!factory_active_fast_belts.len)
		return
	factory_belt_moved.Cut()
	for (var/obj/structure/factory_belt/B in factory_active_fast_belts.Copy())
		if (QDELETED(B))
			factory_active_fast_belts -= B
			continue
		B.belt_step()

//////////////////////////////////////////////////////////////////////////////
// Internal storage ports, used by train wagons and shopping carts. Automation
// obeys the same limits as a person filling the storage by hand.

/proc/factory_storage_accepts(obj/item/weapon/storage/S, obj/item/I)
	usr = null // automation never acts for whoever last clicked
	if (!S || QDELETED(S) || !factory_movable_item(I) || I.loc == S)
		return 0
	return S.can_be_inserted(I, TRUE) ? factory_item_amount(I) : 0

/proc/factory_storage_insert(obj/item/weapon/storage/S, obj/item/I)
	var/amount = factory_storage_accepts(S, I)
	if (amount <= 0 || !S.handle_item_insertion(I, TRUE))
		return 0
	factory_storage_refresh(S)
	return amount

/proc/factory_storage_offer(obj/item/weapon/storage/S, filter_type)
	if (!S || QDELETED(S))
		return null
	for (var/obj/item/I in S.contents)
		if ((!filter_type || istype(I, filter_type)) && factory_movable_item(I))
			return I
	return null

/proc/factory_storage_take(obj/item/weapon/storage/S, obj/item/I, atom/destination)
	usr = null
	if (!S || !destination || I.loc != S || !factory_movable_item(I))
		return FALSE
	if (!S.remove_from_storage(I, destination) || I.loc != destination)
		return FALSE
	factory_storage_refresh(S)
	return TRUE

// People looking into the storage see what automation changed.
/proc/factory_storage_refresh(obj/item/weapon/storage/S)
	var/obj/holder = S.loc
	if (istype(holder))
		holder.update_icon()
	for (var/mob/M in range(1, get_turf(S)))
		if (M.s_active == S)
			S.orient2hud(M)
			S.show_to(M)

/obj/structure/trains/storage/factory_accepts(obj/item/I, from_dir = 0)
	return factory_storage_accepts(storage, I)

/obj/structure/trains/storage/factory_insert(obj/item/I, from_dir = 0)
	return factory_storage_insert(storage, I)

/obj/structure/trains/storage/factory_offer(to_dir = 0, filter_type = null)
	return factory_storage_offer(storage, filter_type)

/obj/structure/trains/storage/factory_take(obj/item/I, atom/destination)
	return factory_storage_take(storage, I, destination)

/obj/structure/shopping_cart/factory_accepts(obj/item/I, from_dir = 0)
	return factory_storage_accepts(storage, I)

/obj/structure/shopping_cart/factory_insert(obj/item/I, from_dir = 0)
	return factory_storage_insert(storage, I)

/obj/structure/shopping_cart/factory_offer(to_dir = 0, filter_type = null)
	return factory_storage_offer(storage, filter_type)

/obj/structure/shopping_cart/factory_take(obj/item/I, atom/destination)
	return factory_storage_take(storage, I, destination)

//////////////////////////////////////////////////////////////////////////////
// Vehicle cargo hold: a bolted steel box for a vehicle bed. Anything standing
// on a vehicle's frame rides with it, so the hold travels with the vehicle;
// arms load and unload it through the same storage port as train wagons.

/obj/structure/cargo_hold
	name = "cargo hold"
	desc = "A steel cargo box made to bolt onto a vehicle bed. It rides with the vehicle and holds twenty items, bulky ones included. Feeder arms can load and unload it. Use a wrench to bolt or unbolt it."
	icon = 'icons/obj/closet.dmi'
	icon_state = "securecargo"
	density = TRUE
	anchored = FALSE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/max_storage = 20
	var/obj/item/weapon/storage/internal/storage

/obj/structure/cargo_hold/New()
	..()
	storage = new/obj/item/weapon/storage/internal(src)
	storage.storage_slots = max_storage
	storage.max_w_class = 5
	storage.max_storage_space = max_storage * 5

/obj/structure/cargo_hold/Destroy()
	qdel(storage)
	storage = null
	return ..()

/obj/structure/cargo_hold/examine(mob/user)
	..()
	if (storage)
		to_chat(user, SPAN_NOTICE("It holds [storage.contents.len] of [max_storage] items and is [anchored ? "bolted down" : "loose"]."))

/obj/structure/cargo_hold/attack_hand(mob/user)
	if (istype(user, /mob/living/human) && (user in range(1, src)) && storage)
		storage.open(user)

/obj/structure/cargo_hold/MouseDrop(obj/over_object)
	if (storage && storage.handle_mousedrop(usr, over_object))
		..(over_object)

/obj/structure/cargo_hold/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/wrench))
		anchored = !anchored
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		to_chat(user, SPAN_NOTICE("You [anchored ? "bolt down" : "unbolt"] \the [src]."))
		return
	if (storage)
		storage.attackby(W, user)

/obj/structure/cargo_hold/factory_accepts(obj/item/I, from_dir = 0)
	return factory_storage_accepts(storage, I)

/obj/structure/cargo_hold/factory_insert(obj/item/I, from_dir = 0)
	return factory_storage_insert(storage, I)

/obj/structure/cargo_hold/factory_offer(to_dir = 0, filter_type = null)
	return factory_storage_offer(storage, filter_type)

/obj/structure/cargo_hold/factory_take(obj/item/I, atom/destination)
	return factory_storage_take(storage, I, destination)
