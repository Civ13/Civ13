/obj/item/weapon/material/kitchen
	icon = 'icons/obj/kitchen.dmi'

/*
 * Utensils
 */
/obj/item/weapon/material/kitchen/utensil
	w_class = TRUE
	thrown_force_divisor = TRUE
//	origin_tech = "materials=1"
	attack_verb = list("attacked", "stabbed", "poked")
	sharp = TRUE
	edge = TRUE
	force_divisor = 0.1 // 6 when wielded with hardness 60 (steel)
	thrown_force_divisor = 0.25 // 5 when thrown with weight 20 (steel)
	var/loaded      //Descriptive string for currently loaded food object.
	var/scoop_food = TRUE

/obj/item/weapon/material/kitchen/utensil/New()
	..()
	if (prob(60))
		pixel_y = rand(0, 4)
	create_reagents(5)
	return

/obj/item/weapon/material/kitchen/utensil/attack(mob/living/carbon/M as mob, mob/living/carbon/user as mob)
	if (!istype(M))
		return ..()

	if (user.a_intent != I_HELP || !scoop_food)
		if (user.targeted_organ == "eyes")
			return eyestab(M,user)
		else if (user.targeted_organ == "head" && (sharp || edge) && ishuman(M))
			M.resolve_item_attack(src, user, user.targeted_organ)
		else
			return ..()

	if (reagents.total_volume > 0)
		reagents.trans_to_mob(M, reagents.total_volume, CHEM_INGEST)
		if (M == user)
			if (!M.can_eat(loaded))
				return
			else if (M.get_fullness() > 580)
				user << "<span class='danger'>You cannot force any more food to go down your throat.</span>"
				return
			M.visible_message("<span class='notice'>\The [user] eats some [loaded] from \the [src].</span>")
		else
			user.visible_message("<span class='warning'>\The [user] begins to feed \the [M]!</span>")
			if (!(M.can_force_feed(user, loaded) && do_mob(user, M, 5 SECONDS)))
				return
			else if (M.get_fullness() > 580)
				user << "<span class='danger'>You cannot force any more food to go down [M]'s throat.</span>"
				return
			M.visible_message("<span class='notice'>\The [user] feeds some [loaded] to \the [M] with \the [src].</span>")
		playsound(M.loc,'sound/items/eatfood.ogg', rand(10,40), TRUE)
		overlays.Cut()
		return
	else
		user << "<span class='warning'>You don't have anything on \the [src].</span>"	//if we have help intent and no food scooped up DON'T STAB OURSELVES WITH THE FORK
		return

/obj/item/weapon/material/kitchen/utensil/fork
	name = "fork"
	desc = "It's a fork. Sure is pointy."
	icon_state = "fork"

/obj/item/weapon/material/kitchen/utensil/spoon
	name = "spoon"
	desc = "It's a spoon. You can see your own upside-down face in it."
	icon_state = "spoon"
	attack_verb = list("attacked", "poked")
	edge = FALSE
	sharp = FALSE
	force_divisor = 0 //no dmg. no more memes

/*
 * Knives
 */
#define SLASH 1
#define STAB 2
#define BASH 3

/obj/item/weapon/material/kitchen/utensil/knife
	name = "knife"
	desc = "A knife for eating with. Can cut through any food."
	icon_state = "knife"
	force_divisor = 0.1 // 6 when wielded with hardness 60 (steel)
	scoop_food = FALSE
	slot_flags = SLOT_BELT|SLOT_POCKET
	edge = TRUE
	sharp = TRUE
	var/atk_mode = SLASH
/obj/item/weapon/material/kitchen/utensil/knife/razorblade
	name = "razor blade"
	desc = "A folding blade, used to cut beard and hairs."
	icon = 'icons/obj/items.dmi'
	icon_state = "razorblade"
	item_state = "knife"
	force_divisor = 0.2
	w_class = 1.0

/obj/item/weapon/material/kitchen/utensil/knife/attack_self(mob/user)
	..()
	if(atk_mode == SLASH)
		atk_mode = STAB
		user << "<span class='notice'>You will now stab.</span>"
		edge = 0
		sharp = 1
		attack_verb = list("stabbed")
		hitsound = "stab_sound"
		return

	else if(atk_mode == STAB)
		atk_mode = SLASH
		user << "<span class='notice'>You will now slash.</span>"
		attack_verb = list("slashed", "diced")
		hitsound = "slash_sound"
		edge = 1
		sharp = 1
		return

/obj/item/weapon/material/kitchen/utensil/knife/razorblade/attack(mob/living/carbon/human/M as mob, mob/living/user as mob)
	if (user.a_intent == I_HELP && (M in range(user,1) || M == user) && ishuman(M) && ishuman(user))
		visible_message("[user] starts cutting [M]'s hair...","You start cutting [M]'s hair...")
		if (do_after(user, 80, M))
			var/list/hairlist = M.generate_valid_hairstyles(1,1)
			var/new_hstyle = WWinput(usr, "Please select a hair style.", "Grooming", WWinput_first_choice(hairlist), WWinput_list_or_null(hairlist))
			if (new_hstyle)
				M.h_style = new_hstyle
				for (var/hairstyle in hair_styles_list)
					var/datum/sprite_accessory/S = hair_styles_list[hairstyle]
					if (S.name == M.h_style)
						M.h_growth = S.growth
			if (M.gender == MALE)
				var/list/fhairlist = M.generate_valid_facial_hairstyles(1,1)
				var/new_fstyle = WWinput(usr, "Please select a facial hair style.", "Grooming", WWinput_first_choice(fhairlist), WWinput_list_or_null(fhairlist))
				if (new_fstyle)
					M.f_style = new_fstyle
					for (var/hairstyle in facial_hair_styles_list)
						var/datum/sprite_accessory/S = facial_hair_styles_list[hairstyle]
						if (S.name == M.f_style)
							M.f_growth = S.growth
			M.update_hair()
			M.update_body()
			visible_message("[user] finishes cutting [M]'s hair.","You finish cutting [M]'s hair.")
			return
	else
		return ..()

/obj/item/weapon/material/kitchen/utensil/knife/makeshift_knife
	name = "boot knife"
	desc = "A small self made knife used a lot in jail."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "makeshift_knife"
	item_state = "knife"
	applies_material_colour = FALSE
	unbreakable = TRUE
	drawsound = 'sound/items/unholster_knife.ogg'
	force_divisor = 0.3

/obj/item/weapon/material/kitchen/utensil/knife/bowie
	name = "bowie knife"
	desc = "A rather large bowie knife."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "bowie_knife"
	item_state = "knife"
	applies_material_colour = FALSE
	unbreakable = TRUE
	drawsound = 'sound/items/unholster_knife.ogg'
	force_divisor = 0.6

/obj/item/weapon/material/kitchen/utensil/knife/bone
	name = "bone knife"
	desc = "A small knife with a bone blade and obsidian handle."
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "boneknife"
	item_state = "knife"
	applies_material_colour = FALSE
	unbreakable = TRUE
	drawsound = 'sound/items/unholster_knife.ogg'
	force_divisor = 0.3

/obj/item/weapon/material/kitchen/utensil/knife/bone/New()
	..()
	name = "bone knife"

/obj/item/weapon/material/kitchen/utensil/knife/circumcision
	name = "circumcision knife"
	desc = "A small knife with a bone handle, used to perform circumcisions."
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "circumcision"
	item_state = "knife"
	applies_material_colour = FALSE
	unbreakable = TRUE
	drawsound = 'sound/items/unholster_knife.ogg'
	force_divisor = 0.35

/obj/item/weapon/material/kitchen/utensil/knife/circumcision/New()
	..()
	name = "circumcision knife"

/obj/item/weapon/material/kitchen/utensil/knife/circumcision/attack(target as mob, mob/living/user as mob)
	if (istype(target, /mob/living/carbon/human))
		var/mob/living/carbon/human/H = target
		if (user.a_intent == I_HELP && H.gender == MALE)
			if (H.circumcised)
				user << "<span class = 'notice'>[H] is already circumcised!</span>"
				return
			else
				visible_message("<span class = 'notice'>[user] starts to circumcise [H]...</span>")
				if (do_after(user, 90, H) && !H.circumcised)
					visible_message("<span class = 'notice'>[user] successfully circumcises [H].</span>")
					H.circumcised = TRUE
					return
				else
					return ..()
		else
			return ..()
	else
		return ..()

/obj/item/weapon/material/kitchen/utensil/knife/attack(target as mob, mob/living/user as mob)
	return ..()

/obj/item/weapon/material/kitchen/utensil/knife/iron
	default_material = "iron"

/obj/item/weapon/material/kitchen/utensil/knife/bronze
	default_material = "bronze"

/obj/item/weapon/material/kitchen/utensil/knife/steel
	default_material = "steel"
/*
 * Rolling Pins
 */

/obj/item/weapon/material/kitchen/rollingpin
	name = "rolling pin"
	desc = "Used to knock out the Bartender."
	icon_state = "rolling_pin"
	attack_verb = list("bashed", "battered", "bludgeoned", "thrashed", "whacked")
	default_material = "wood"
	force_divisor = 0.7 // 10 when wielded with weight 15 (wood)
	thrown_force_divisor = TRUE // as above
	hitsound = "swing_hit"
	flammable = TRUE
/obj/item/weapon/material/kitchen/rollingpin/attack(mob/living/M as mob, mob/living/user as mob)
	return ..()
