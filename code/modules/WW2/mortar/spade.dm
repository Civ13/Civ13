/obj/structure/mortar/spade
	name = "37mm Spade Mortar"
	icon_state = "spade"

/obj/structure/mortar/spade/verb/Get()
	set src in oview(1, usr)
	set category = null
	if (usr.l_hand && usr.r_hand)
		usr << "<span class = 'warning'>You need to have a hand free to do this.</span>"
		return
	usr.face_atom(src)
	visible_message("<span class = 'warning'>[usr] starts to get their spade mortar from the ground.</span>")
	if (do_after(usr, 50, get_turf(usr)))
		qdel(src)
		usr.put_in_any_hand_if_possible(new/obj/item/weapon/shovel/spade/mortar, prioritize_active_hand = TRUE)
		visible_message("<span class = 'warning'>[user] gets their spade mortar from the ground.</span>")