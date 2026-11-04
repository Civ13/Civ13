// Minimal stand-ins for the game code the transfer bridge and trade post use.
// The pilot compiles the real transfer_bridge.dm, transfer_trade_post.dm,
// http.dm, _rust_g.dm and the transfer hooks from functions.dm against these.

#define QDELING(X) (X && X:gcDestroyed)
#define QDELETED(X) (!X || QDELING(X))

/datum/var/gcDestroyed
/datum/var/map_storage_saved_vars

/proc/qdel(datum/D)
	if(!D || D.gcDestroyed) return
	D.gcDestroyed = TRUE
	D.Destroy()

/datum/proc/Destroy()
	return

/atom/movable/Destroy()
	loc = null
	return ..()

/proc/message_admins(text)
	world.log << "ADMIN: [text]"

/proc/to_chat(target, text)
	return

/proc/stack_trace(text)
	world.log << "TRACE: [text]"

/proc/trim(text)
	var/start = 1
	var/end = length(text)
	while(start <= end && text2ascii(text, start) <= 32) start++
	while(end >= start && text2ascii(text, end) <= 32) end--
	return copytext(text, start, end + 1)

/proc/english_list(list/L)
	return jointext(L, ", ")

/proc/ishuman(M)
	return ismob(M)

/proc/get_turf(atom/A)
	while(A && !isturf(A)) A = A.loc
	return A

var/global/pilot_save_active = FALSE

/proc/persistence_save_active()
	return pilot_save_active

/map_storage

/obj/var/flammable = TRUE
/obj/var/anchored = FALSE
/obj/structure

/atom/proc/examine(mob/user)
	return

/atom/proc/attackby(obj/item/W, mob/user)
	return

/atom/proc/attack_hand(mob/user)
	return

/atom/proc/Adjacent(atom/A)
	return TRUE

/atom/movable/proc/forceMove(atom/destination)
	loc = destination
	return TRUE

/mob/proc/get_active_hand()
	return null

/mob/proc/remove_from_mob(obj/O)
	O.loc = loc

/obj/item
/obj/item/stack
	var/amount = 1
	var/max_amount = 50

/obj/item/stack/New(loc, new_amount)
	..()
	if(new_amount) amount = new_amount

/obj/item/stack/material
/obj/item/stack/material/wood
/obj/item/stack/material/stone
/obj/item/stack/material/clay
/obj/item/stack/material/rope
/obj/item/stack/material/cloth
/obj/item/stack/material/leather
/obj/item/stack/material/copper
/obj/item/stack/material/tin
/obj/item/stack/material/bronze
/obj/item/stack/material/iron
/obj/item/stack/material/silver
/obj/item/stack/material/gold
/obj/item/stack/material/steel
	max_amount = 2000
