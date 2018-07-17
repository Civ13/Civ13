/*/mob/living/carbon/human/proc/monkeyize()
	if (transforming)
		return
	for (var/obj/item/W in src)
		if (W==w_uniform) // will be torn
			continue
		drop_from_inventory(W)
	regenerate_icons()
	transforming = TRUE
	canmove = FALSE
	stunned = TRUE
	icon = null
	invisibility = 101
	for (var/t in organs)
		qdel(t)
	var/atom/movable/overlay/animation = new /atom/movable/overlay( loc )
	animation.icon_state = "blank"
	animation.icon = 'icons/mob/mob.dmi'
	animation.master = src
	flick("h2monkey", animation)
	sleep(48)
	//animation = null

	transforming = FALSE
	stunned = FALSE
	update_canmove()
	invisibility = initial(invisibility)

	if (!species.primitive_form) //If the creature in question has no primitive set, this is going to be messy.
		gib()
		return

	for (var/obj/item/W in src)
		drop_from_inventory(W)
	set_species(species.primitive_form)
	dna.SetSEState(MONKEYBLOCK,1)
	dna.SetSEValueRange(MONKEYBLOCK,0xDAC, 0xFFF)

	src << "<b>You are now [species.name]. </b>"
	qdel(animation)

	return src

/mob/living/carbon/human/proc/slimeize(adult as num, reproduce as num)
	if (transforming)
		return
	for (var/obj/item/W in src)
		drop_from_inventory(W)
	regenerate_icons()
	transforming = TRUE
	canmove = FALSE
	icon = null
	invisibility = 101
	for (var/t in organs)
		qdel(t)

	var/mob/living/carbon/slime/new_slime
	if (reproduce)
		var/number = pick(14;2,3,4)	//reproduce (has a small chance of producing 3 or 4 offspring)
		var/list/babies = list()
		for (var/i=1,i<=number,i++)
			var/mob/living/carbon/slime/M = new/mob/living/carbon/slime(loc)
			M.nutrition = round(nutrition/number)
			step_away(M,src)
			babies += M
		new_slime = pick(babies)
	else
		new_slime = new /mob/living/carbon/slime(loc)
		if (adult)
			new_slime.is_adult = TRUE
		else
	new_slime.key = key

	new_slime << "<b>You are now a slime. Skreee!</b>"
	qdel(src)
	return
*/
/mob/living/carbon/human/proc/corgize()
	if (transforming)
		return
	for (var/obj/item/W in src)
		drop_from_inventory(W)
	regenerate_icons()
	transforming = TRUE
	canmove = FALSE
	icon = null
	invisibility = 101
	for (var/t in organs)	//this really should not be necessary
		qdel(t)

	var/mob/living/simple_animal/corgi/new_corgi = new /mob/living/simple_animal/corgi (loc)
	new_corgi.a_intent = I_HURT
	new_corgi.key = key

	new_corgi << "<b>You are now a Corgi. Yap Yap!</b>"
	qdel(src)
	return

/mob/living/carbon/human/Animalize()

	var/list/mobtypes = typesof(/mob/living/simple_animal)
	var/mobpath = input("Which type of mob should [src] turn into?", "Choose a type") in mobtypes

	if (!safe_animal(mobpath))
		usr << "<span class = 'red'>Sorry, but this mob type is currently unavailable.</span>"
		return

	if (transforming)
		return
	for (var/obj/item/W in src)
		drop_from_inventory(W)

	regenerate_icons()
	transforming = TRUE
	canmove = FALSE
	icon = null
	invisibility = 101

	for (var/t in organs)
		qdel(t)

	var/mob/new_mob = new mobpath(loc)

	new_mob.key = key
	new_mob.a_intent = I_HURT


	new_mob << "You suddenly feel more... animalistic."
	spawn()
		qdel(src)
	return

/mob/proc/Animalize()

	var/list/mobtypes = typesof(/mob/living/simple_animal)
	var/mobpath = input("Which type of mob should [src] turn into?", "Choose a type") in mobtypes

	if (!safe_animal(mobpath))
		usr << "<span class = 'red'>Sorry, but this mob type is currently unavailable.</span>"
		return

	var/mob/new_mob = new mobpath(loc)

	new_mob.key = key
	new_mob.a_intent = I_HURT
	new_mob << "You feel more... animalistic"

	qdel(src)

/* Certain mob types have problems and should not be allowed to be controlled by players.
 *
 * This proc is here to force coders to manually place their mob in this list, hopefully tested.
 * This also gives a place to explain -why- players shouldnt be turn into certain mobs and hopefully someone can fix them.
 */
/mob/proc/safe_animal(var/MP)

//Bad mobs! - Remember to add a comment explaining what's wrong with the mob
	if (!MP)
		return FALSE	//Sanity, this should never happen.

//Good mobs!
	if (ispath(MP, /mob/living/simple_animal/cat))
		return TRUE
	if (ispath(MP, /mob/living/simple_animal/corgi))
		return TRUE
	if (ispath(MP, /mob/living/simple_animal/crab))
		return TRUE
	if (ispath(MP, /mob/living/simple_animal/hostile/carp))
		return TRUE
	if (ispath(MP, /mob/living/simple_animal/tomato))
		return TRUE
	if (ispath(MP, /mob/living/simple_animal/mouse))
		return TRUE //It is impossible to pull up the player panel for mice (Fixed! - Nodrak)
	if (ispath(MP, /mob/living/simple_animal/hostile/bear))
		return TRUE //Bears will auto-attack mobs, even if they're player controlled (Fixed! - Nodrak)

	//Not in here? Must be untested!
	return FALSE



