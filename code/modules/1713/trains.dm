/obj/structure/rails
	name = "rails"
	desc = "A bunch of rails used by trains."
	icon = 'icons/obj/trains.dmi'
	icon_state = "rails"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE

/obj/structure/rails/end
	icon_state = "rails_end"

/obj/structure/trains
	icon = 'icons/obj/trains.dmi'
	icon_state = "miningcar"
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	anchored = FALSE
	density = TRUE
	opacity = FALSE

/obj/structure/trains/storage
	var/max_storage = 7
	var/obj/item/weapon/storage/internal/storage

/obj/structure/trains/storage/miningcart
	name = "mining cart"
	desc = "A wooden mining cart, for underground rails."
	icon_state = "miningcar"

/obj/structure/trains/storage/miningcart/New()
	..()
	storage = new/obj/item/weapon/storage/internal(src)
	storage.storage_slots = max_storage
	storage.max_w_class = 5
	storage.max_storage_space = max_storage*5
	update_icon()

/obj/structure/trains/storage/miningcart/Destroy()
	qdel(storage)
	storage = null
	..()

/obj/structure/trains/storage/miningcart/attack_hand(mob/user as mob)
	if (istype(user, /mob/living/carbon/human) && user in range(1,src))
		storage.open(user)
		update_icon()
	else
		return
/obj/structure/trains/storage/miningcart/MouseDrop(obj/over_object as obj)
	if (storage.handle_mousedrop(usr, over_object))
		..(over_object)
		update_icon()

/obj/structure/trains/storage/miningcart/attackby(obj/item/W as obj, mob/user as mob)
	..()
	storage.attackby(W, user)
	update_icon()