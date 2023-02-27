/obj/structure/table/rack
	name = "rack"
	desc = "Different from the Middle Ages version."
	icon = 'icons/obj/objects.dmi'
	icon_state = "rack"
	flipped = -1
	low = TRUE
	fixedsprite = TRUE

/obj/structure/table/rack/New()
	..()
//	verbs -= /obj/structure/table/verb/do_flip
//	verbs -= /obj/structure/table/proc/do_put
/*
/obj/structure/table/rack/update_connections()
	return

/obj/structure/table/rack/update_desc()
	return*/

/obj/structure/table/rack/update_icon()
	return

/obj/structure/table/fancy
	name = "table"
	desc = "An old expensive table."
	icon = 'icons/obj/objects.dmi'
	icon_state = "fancytable"
	flipped = -1
	low = TRUE
	fixedsprite = TRUE

/obj/structure/table/nightstand
	name = "night stand"
	desc = "A night stand."
	icon = 'icons/obj/structures.dmi'
	icon_state = "nightstand"
	flipped = -1
	low = TRUE
	fixedsprite = TRUE

/obj/structure/table/nightstand/small
	desc = "A small dark wood night stand."
	icon = 'icons/obj/structures.dmi'
	icon_state = "nightstand_small"

/obj/structure/table/nightstand/alt
	icon = 'icons/obj/structures.dmi'
	icon_state = "nightstand_alt"

/obj/structure/table/rack/shelf
	name = "shelf"
	desc = "A store shelf."
	icon = 'icons/obj/junk.dmi'
	icon_state = "shelf0"

/obj/structure/table/rack/shelf/wooden
	name = "shelf"
	desc = "A wooden shelf."
	icon = 'icons/obj/structures.dmi'
	icon_state = "shelfwood"

/obj/structure/table/rack/shelf/store
	icon = 'icons/obj/structures.dmi'
	icon_state = "storeshelf"

/obj/structure/table/rack/coatrack
	name = "coat rack"
	desc = "A convenient place to hang your hat."
	icon = 'icons/obj/junk.dmi'
	icon_state = "coatrack"
	flammable = TRUE
	not_movable = FALSE