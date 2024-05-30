var/global/list/ashtray_cache = list()

/obj/item/weapon/material/ashtray
	name = "ashtray"
	icon = 'icons/obj/objects.dmi'
	icon_state = "ashtray"
	var/base_icon = "ashtray"
	force_divisor = 0.1
	thrown_force_divisor = 0.1
	var/image/base_image
	var/max_butts = 10

/obj/item/weapon/material/ashtray/New(var/newloc, var/material_name)
	..(newloc, material_name)
	if (!material) // Safety check.
		qdel(src)
		return
	max_butts = round(material.hardness/10) //This is arbitrary but whatever.
	pixel_y = rand(-5, 5)
	pixel_x = rand(-6, 6)
	update_icon()
	return

/*
/obj/item/weapon/material/ashtray/examine(mob/user)
	if(material)
		desc = "It's made of [material.display_name]."

	..()
	if(contents.len >= max_butts)
		to_chat(user, "It's full.")
	else if(contents.len)
		to_chat(user, "It has [contents.len] cig butts in it.")
*/

/obj/item/weapon/material/ashtray/update_icon()
	color = null
	overlays.Cut()
	var/cache_key = "base-[material.name]"
	if (!ashtray_cache[cache_key])
		var/image/I = image('icons/obj/objects.dmi',"ashtray")
		I.color = material.icon_colour
		ashtray_cache[cache_key] = I
	overlays |= ashtray_cache[cache_key]

	if (contents.len == max_butts)
		if (!ashtray_cache["full"])
			ashtray_cache["full"] = image('icons/obj/objects.dmi',"ashtray_full")
		overlays |= ashtray_cache["full"]
		desc = "It's stuffed full."
	else if (contents.len > max_butts/2)
		if (!ashtray_cache["half"])
			ashtray_cache["half"] = image('icons/obj/objects.dmi',"ashtray_half")
		overlays |= ashtray_cache["half"]
		desc = "It's half-full."
	else
		desc = "An ashtray made of [material.display_name]."


/obj/item/weapon/material/ashtray/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/cigbutt) || istype(W, /obj/item/clothing/mask/smokable/cigarette) || istype(W, /obj/item/weapon/flame/match)) 

		if (contents.len >= max_butts)
			user.visible_message(SPAN_NOTICE("[user] tries to place \the [W] into \the [src], it doesn't fit."), SPAN_WARNING("You try and place \the [W] into the [src], but realise that it doesn't fit!"), "You hear some noise.")
			return

		if (istype(W, /obj/item/clothing/mask/smokable/cigarette))
			var/obj/item/clothing/mask/smokable/cigarette/cig = W
			if (cig.lit)
				user.visible_message(SPAN_NOTICE("[user] crushes \the [cig] in \the [src], putting it out."), SPAN_WARNING("You crush \the [cig] in \the [src], putting it out."), "You hear the light crushing of something.")
				// W = cig.die(1) - runtimes trying to modify the O.layer in remove_from_mob() to initial(O.layer)

				// Insert temporary solution;
				var/obj/item/butt = new cig.type_butt(src)
				cig.transfer_fingerprints_to(butt)
				butt.color = color
				qdel(cig)
			else
				user.visible_message(SPAN_NOTICE("[user] places the unlit [cig.name] into \the [src]."), SPAN_WARNING("You place the unlit [cig.name] into \the [src]."), "You hear some light noise.")

		user.remove_from_mob(W)
		W.loc = src
		user.update_inv_l_hand()
		user.update_inv_r_hand()
		add_fingerprint(user)
		update_icon()
	
	else
		health = max(0, health - W.force/2)
		user.visible_message(SPAN_DANGER("[user] hits \the [src] with \the [W]"), SPAN_WARNING("You hit \the [src] with \the [W]."), "You hear something being hit!")
		user.do_attack_animation(src)
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		if(health < 1) 
			shatter() 


/obj/item/weapon/material/ashtray/throw_impact(atom/hit_atom)
	if (health > 0)
		health = max(0,health - 3)
		if (contents.len)
			src.visible_message(SPAN_DANGER("\The [src] slams into \the [hit_atom] spilling its contents!")) // This registers the turf not the walls/covers. (e.g, slams into the road.)
		for (var/obj/O in contents)
			O.dropInto(loc)
			O.pixel_y = rand(-5, 5)
			O.pixel_x = rand(-6, 6)
		if (health < 1)
			shatter() // Shatter into material shrapnel.
			return
		update_icon()
	return ..()

/obj/item/weapon/material/ashtray/bronze/New(var/newloc)
	..(newloc, "bronze")

/obj/item/weapon/material/ashtray/glass/New(var/newloc)
	..(newloc, "glass")

/obj/item/weapon/material/ashtray/stone/New(var/newloc)
	..(newloc, "stone")

/obj/item/weapon/material/ashtray/marble/New(var/newloc)
	..(newloc, "marble")