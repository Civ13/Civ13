/obj/item/weapon/material/kitchen
	icon = 'icons/obj/kitchen.dmi'

/*
 * Utensils
 */
/obj/item/weapon/material/kitchen/utensil
	w_class = ITEM_SIZE_TINY
	thrown_force_divisor = TRUE
	attack_verb = list("attacked", "stabbed", "poked")
	sharp = TRUE
	edge = TRUE
	force_divisor = 0.1 // 6 when wielded with hardness 60 (steel)
	thrown_force_divisor = 0.25 // 5 when thrown with weight 20 (steel)
	var/loaded	  //Descriptive string for currently loaded food object.
	var/scoop_food = TRUE
	var/shiv = 0
	var/usespeed = 0.2


/obj/item/weapon/material/kitchen/utensil/New()
	..()
	if (prob(60))
		pixel_y = rand(0, 4)
	create_reagents(5)
	return

/obj/item/weapon/material/kitchen/utensil/attack(mob/living/human/M as mob, mob/living/human/user as mob)
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

/obj/item/weapon/material/kitchen/utensil/chopsticks
	name = "chopsticks"
	desc = "It's pair of chopsticks. Wan' sum rice muhda fukka?"
	icon_state = "chopsticks"
	material = "wood"
	applies_material_colour = FALSE
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
	slot_flags = SLOT_BELT|SLOT_POCKET//|SLOT_MASK
	edge = TRUE
	sharp = TRUE
	var/atk_mode = SLASH
	var/suicide = FALSE // for the hari kiri action

/obj/item/weapon/material/kitchen/utensil/knife/proc/handle_suicide(mob/living/user)
	..()
	if (!ishuman(user))
		return
	var/mob/living/human/M = user
	suicide = TRUE
	M.visible_message("<span class = 'red'>[user] sticks [M.gender == FEMALE ? "her" : "his"] [src] in [M.gender == FEMALE ? "her" : "his"] gut.</span>")
	if (!do_after(user, 60))
		M.visible_message("<span class = 'notice'>[user] failed to commit suicide.</span>")
		suicide = FALSE
		return
	else
		user << "<span class = 'notice'>Ow...</span>"
		user.apply_effect(110,AGONY,0)
		user.apply_damage(src.sharpness*2.5, "brute", "groin")
		user.death()
		user.visible_message("<span class = 'warning'>[user] cuts themselves open.</span>")
		M.attack_log += "\[[time_stamp()]\] [M]/[M.ckey]</b> disemboweled themselves."
		suicide = FALSE

/obj/item/weapon/material/kitchen/utensil/knife/attack(atom/A, mob/living/user, target_zone)
	if (A == user)
		if (target_zone == "groin" && !suicide)
			handle_suicide(user)
			return TRUE
	return ..(A, user, target_zone)

/obj/item/weapon/material/kitchen/utensil/knife/razorblade
	name = "razor blade"
	desc = "A folding blade, used to cut beard and hairs."
	icon = 'icons/obj/items.dmi'
	icon_state = "razorblade"
	item_state = "knife"
	force_divisor = 0.2
	w_class = ITEM_SIZE_TINY

/obj/item/weapon/material/kitchen/utensil/knife/attack_self(mob/user)
	..()
	if(atk_mode == SLASH)
		atk_mode = STAB
		user << "<span class='notice'>You will now stab.</span>"
		edge = FALSE
		sharp = TRUE
		attack_verb = list("stabbed")
		hitsound = "stab_sound"
		return

	else if(atk_mode == STAB)
		atk_mode = SLASH
		user << "<span class='notice'>You will now slash.</span>"
		attack_verb = list("slashed", "diced")
		hitsound = "slash_sound"
		edge = TRUE
		sharp = TRUE
		return

/obj/item/weapon/material/kitchen/utensil/knife/razorblade/attack(mob/living/human/M as mob, mob/living/user as mob)
	if (user.a_intent == I_DISARM && user.targeted_organ == "head" && (M in range(user,1) || M == user) && ishuman(M) && ishuman(user))
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

/obj/item/weapon/material/kitchen/utensil/knife/shank
	name = "shank"
	desc = "A small self-made knife used a lot in jail."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "steelshank"
	item_state = "knife"
	applies_material_colour = FALSE
	unbreakable = FALSE
	drawsound = 'sound/items/unholster_knife.ogg'
	force_divisor = 0.4
	default_material = "steel"

/obj/item/weapon/material/kitchen/utensil/knife/shank/glass
	name = "shank"
	icon_state = "glassshank"
	force_divisor = 0.45
	default_material = "glass"

/obj/item/weapon/material/kitchen/utensil/knife/shank/iron
	name = "shank"
	icon_state = "ironshank"
	force_divisor = 0.4
	default_material = "iron"
/obj/item/weapon/material/kitchen/utensil/knife/shank/wood
	name = "shank"
	icon_state = "woodshank"
	applies_material_colour = FALSE
	force_divisor = 0.35
	default_material = "wood"

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

/obj/item/weapon/material/kitchen/utensil/knife/bowie/iron
	default_material = "iron"

/obj/item/weapon/material/kitchen/utensil/knife/dagger
	name = "dagger"
	desc = "A long, sharp, swordlike knife that is used for close quarter combat."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "dagger"
	item_state = "knife"
	applies_material_colour = FALSE
	unbreakable = TRUE
	drawsound = 'sound/items/unholster_knife.ogg'
	force_divisor = 0.75

/obj/item/weapon/material/kitchen/utensil/knife/dagger/iron
	default_material = "iron"

/obj/item/weapon/material/kitchen/utensil/knife/switchblade
	name = "switchblade knife"
	desc = "A sharp, concealable, spring-loaded knife."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "switchblade"
	item_state = null
	applies_material_colour = FALSE
	unbreakable = TRUE
	hitsound = null
	attack_verb = list("patted", "tapped")
	force_divisor = 0.05
	w_class = ITEM_SIZE_SMALL
	throwforce = 0
	throw_speed = 3
	throw_range = 5
	secondary_action = TRUE
	drawsound = 'sound/weapons/hiddenblade_deploy.ogg'
	var/active = FALSE

/obj/item/weapon/material/kitchen/utensil/knife/switchblade/update_icon()
	if(active)
		icon_state = "switchblade_open"
		item_state = "knife"
	else
		icon_state = "switchblade"
		item_state = null

/obj/item/weapon/material/kitchen/utensil/knife/switchblade/update_force()
	..()
	if(active)
		edge = TRUE
		sharp = TRUE
		throwforce = 5
		hitsound = 'sound/weapons/bladeslice.ogg'
		w_class = ITEM_SIZE_NORMAL
		force_divisor = 0.7
		attack_verb = list("attacked", "slashed", "stabbed", "sliced", "torn", "ripped", "diced", "cut")
	else
		edge = FALSE
		sharp = FALSE
		hitsound = initial(hitsound)
		w_class = initial(w_class)
		force_divisor = initial(force_divisor)
		attack_verb = initial(attack_verb)

/obj/item/weapon/material/kitchen/utensil/knife/switchblade/secondary_attack_self(mob/living/human/user)
	if(!active)
		visible_message("<span class='warning'>With a simple press, [user] extends the blade on their switchblade knife.</span>", 3)
		playsound(loc, 'sound/weapons/switchblade.ogg', 15, 1)
		active = TRUE
	else
		visible_message("<span class='notice'>\The [user] retracts the blade on their switchblade knife.</span>", 3)
		active = FALSE
	update_force()
	update_icon()
	add_fingerprint(user)

/obj/item/weapon/material/kitchen/utensil/knife/fancy
	name = "fancy knife"
	desc = "A expensive knife."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "fancyknife"
	item_state = "knife"
	applies_material_colour = FALSE
	unbreakable = TRUE
	drawsound = 'sound/items/unholster_knife.ogg'
	force_divisor = 0.3

/obj/item/weapon/material/kitchen/utensil/knife/fancy/silver
	default_material = "silver"

/obj/item/weapon/material/kitchen/utensil/knife/trench
	name = "trench knife"
	desc = "A rather large knife."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "trenchknife"
	item_state = "knife"
	applies_material_colour = FALSE
	unbreakable = TRUE
	drawsound = 'sound/items/unholster_knife.ogg'
	force_divisor = 0.7

/obj/item/weapon/material/kitchen/utensil/knife/trench/iron
	default_material = "iron"

/obj/item/weapon/material/kitchen/utensil/knife/meat
	name = "meat knife"
	desc = "A rather medium knife."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "meatknife"
	item_state = "knife"
	applies_material_colour = FALSE
	unbreakable = TRUE
	drawsound = 'sound/items/unholster_knife.ogg'
	force_divisor = 0.4

/obj/item/weapon/material/kitchen/utensil/knife/shaggers
	name = "shagger knife"
	desc = "A makeshift knife made poorly by ghetto folks."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "shagger"
	item_state = "knife"
	applies_material_colour = FALSE
	unbreakable = TRUE
	drawsound = 'sound/items/unholster_knife.ogg'
	force_divisor = 0.4

/obj/item/weapon/material/kitchen/utensil/knife/fish
	name = "fish knife"
	desc = "A rather medium knife."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "fishknife"
	item_state = "knife"
	applies_material_colour = FALSE
	unbreakable = TRUE
	drawsound = 'sound/items/unholster_knife.ogg'
	force_divisor = 0.5

/obj/item/weapon/material/kitchen/utensil/knife/fish/silver
	default_material = "silver"

/obj/item/weapon/material/kitchen/utensil/knife/tacticalknife
	name = "tactical knife"
	desc = "A rather tactical knife."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "tacticalknife"
	item_state = "knife"
	applies_material_colour = FALSE
	unbreakable = TRUE
	drawsound = 'sound/items/unholster_knife.ogg'
	force_divisor = 0.6

/obj/item/weapon/material/kitchen/utensil/knife/blackknife
	name = "black knife"
	desc = "A rather large knife."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "blackknife"
	item_state = "knife"
	applies_material_colour = FALSE
	unbreakable = TRUE
	drawsound = 'sound/items/unholster_knife.ogg'
	force_divisor = 0.6

/obj/item/weapon/material/kitchen/utensil/knife/military
	name = "military knife"
	desc = "A rather large knife."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "militaryknife"
	item_state = "knife"
	applies_material_colour = FALSE
	unbreakable = TRUE
	drawsound = 'sound/items/unholster_knife.ogg'
	force_divisor = 0.9

/obj/item/weapon/material/kitchen/utensil/knife/military/iron
	default_material = "iron"

/obj/item/weapon/material/kitchen/utensil/knife/shadowdagger
	name = "shadow dagger"
	desc = "A tactical knife."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "smolknife"
	item_state = "knife"
	applies_material_colour = FALSE
	unbreakable = TRUE
	drawsound = 'sound/items/unholster_knife.ogg'
	force_divisor = 0.6

/obj/item/weapon/material/kitchen/utensil/knife/shadowdaggersal
	name = "shadow dagger"
	desc = "A tactical knife."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "salamon"
	item_state = "knife"
	applies_material_colour = FALSE
	unbreakable = TRUE
	drawsound = 'sound/items/unholster_knife.ogg'
	force_divisor = 0.6

/obj/item/weapon/material/kitchen/utensil/knife/bread
	name = "bread knife"
	desc = "A rather large knife."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "breadknife"
	item_state = "knife"
	applies_material_colour = FALSE
	unbreakable = TRUE
	drawsound = 'sound/items/unholster_knife.ogg'
	force_divisor = 0.2

/obj/item/weapon/material/kitchen/utensil/knife/survival
	name = "survival knife"
	desc = "A small compact survival knife."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "survivalknife"
	item_state = "knife"
	applies_material_colour = FALSE
	unbreakable = TRUE
	drawsound = 'sound/items/unholster_knife.ogg'
	force_divisor = 0.3

/obj/item/weapon/material/kitchen/utensil/knife/bone
	name = "tribal bone knife"
	desc = "A small knife with a bone blade and ridged handle."
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "boneknife"
	item_state = "knife"
	applies_material_colour = FALSE
	unbreakable = TRUE
	drawsound = 'sound/items/unholster_knife.ogg'
	force_divisor = 0.1
	default_material = "bone"

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
	force_divisor = 0.1

/obj/item/weapon/material/kitchen/utensil/knife/circumcision/New()
	..()
	name = "circumcision knife"

/obj/item/weapon/material/kitchen/utensil/knife/circumcision/attack(target as mob, mob/living/user as mob)
	if (istype(target, /mob/living/human))
		var/mob/living/human/H = target
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

/obj/item/weapon/material/kitchen/utensil/knife/wood
	default_material = "wood"

/obj/item/weapon/material/kitchen/utensil/knife/hook
	name = "meat hook"
	desc = "A sharp, metal hook what sticks into things."
	icon_state = "hook_knife"
	item_state = "hook_knife"

/obj/item/weapon/material/kitchen/utensil/knife/butcher
	name = "butcher's cleaver"
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "butch"
	desc = "A huge knife used for chopping and chopping up meat."
	edge = FALSE
	force_divisor = 0.25 // 15 when wielded with hardness 60 (steel)
	attack_verb = list("cleaved", "slashed", "sliced", "torn", "ripped", "diced", "cut")
	drawsound = 'sound/items/unholster_knife.ogg'
	unbreakable = TRUE

/obj/item/weapon/material/kitchen/utensil/knife/tanto
	name = "tanto"
	desc = "A knife used by the japanese for centuries. Made to slice and slash, not chop or saw. Often the tool of choice for ritual suicide."
	icon_state = "tanto"
	item_state = "tanto"
	block_chance = 10
	force_divisor = 0.4 // 42 when wielded with hardnes 60 (steel)
	thrown_force_divisor = 0.8 // 10 when thrown with weight 20 (steel)
	value = 60
	cooldownw = 6



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
