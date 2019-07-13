/obj/item/weapon/reagent_containers/food/snacks/breadslice/attackby(obj/item/W as obj, mob/user as mob)

	if (istype(W,/obj/item/weapon/material/shard) || istype(W,/obj/item/weapon/reagent_containers/food/snacks))
		var/obj/item/weapon/reagent_containers/food/snacks/csandwich/S = new(get_turf(src))
		S.attackby(W,user)
		qdel(src)
	..()

/obj/item/weapon/reagent_containers/food/snacks/csandwich
	name = "sandwich"
	desc = "The best thing since sliced bread."
	icon_state = "breadslice"
	bitesize = 2
	satisfaction = 7
	var/list/ingredients = list()

/obj/item/weapon/reagent_containers/food/snacks/csandwich/attackby(obj/item/W as obj, mob/user as mob)

	var/sandwich_limit = 4
	for (var/obj/item/O in ingredients)
		if (istype(O,/obj/item/weapon/reagent_containers/food/snacks/breadslice))
			sandwich_limit += 4

	if (contents.len > sandwich_limit)
		user << "<span class = 'red'>If you put anything else on \the [src] it's going to collapse.</span>"
		return
	else if (istype(W,/obj/item/weapon/material/shard))
		user << "<span class = 'notice'>You hide [W] in \the [src].</span>"
		user.drop_item()
		W.loc = src
		update()
		return
	else if (istype(W,/obj/item/weapon/reagent_containers/food/snacks))
		user << "<span class = 'notice'>You layer [W] over \the [src].</span>"
		var/obj/item/weapon/reagent_containers/F = W
		if (F && F.reagents)
			F.reagents.trans_to_obj(src, F.reagents.total_volume)
		user.drop_item()
		W.loc = src
		ingredients += W
		update()
		return
	..()

/obj/item/weapon/reagent_containers/food/snacks/csandwich/proc/update()
	var/fullname = "" //We need to build this from the contents of the var.
	var/i = FALSE

	overlays.Cut()

	for (var/obj/item/weapon/reagent_containers/food/snacks/O in ingredients)

		i++
		if (i == TRUE)
			fullname += "[O.name]"
		else if (i == ingredients.len)
			fullname += " and [O.name]"
		else
			fullname += ", [O.name]"

		var/image/I = new(icon, "sandwich_filling")
		I.color = O.filling_color
		I.pixel_x = pick(list(-1,0,1))
		I.pixel_y = (i*2)+1
		overlays += I

	var/image/T = new(icon, "sandwich_top")
	T.pixel_x = pick(list(-1,0,1))
	T.pixel_y = (ingredients.len * 2)+1
	overlays += T

	name = lowertext("[fullname] sandwich")
	if (length(name) > 80) name = "[pick(list("absurd","colossal","enormous","ridiculous"))] sandwich"
	w_class = ceil(Clamp((ingredients.len/2),2,4))

/obj/item/weapon/reagent_containers/food/snacks/csandwich/Destroy()
	for (var/obj/item/O in ingredients)
		qdel(O)
	..()

/obj/item/weapon/reagent_containers/food/snacks/csandwich/examine(mob/user)
	..(user)
	if (contents)
		var/obj/item/O = pick(contents)
		user << "<span class = 'notice'>You think you can see [O.name] in there.</span>"

/obj/item/weapon/reagent_containers/food/snacks/csandwich/attack(mob/M as mob, mob/user as mob, def_zone)

	var/obj/item/shard
	for (var/obj/item/O in contents)
		if (istype(O,/obj/item/weapon/material/shard))
			shard = O
			break

	var/mob/living/H
	if (istype(M,/mob/living))
		H = M

	if (H && shard && M == user) //This needs a check for feeding the food to other people, but that could be abusable.
		H << "<span class = 'red'>You lacerate your mouth on a [shard.name] in the sandwich!</span>"
		H.adjustBruteLoss(5) //TODO: Target head if human.
	..()
