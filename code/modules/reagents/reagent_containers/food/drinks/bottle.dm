///////////////////////////////////////////////Alchohol bottles! -Agouri //////////////////////////
//Functionally identical to regular drinks. The only difference is that the default bottle size is 100. - Darem
//Bottles now weaken and break when shattered on people's heads. - Giacom

/obj/item/weapon/reagent_containers/food/drinks/bottle
	amount_per_transfer_from_this = 10
	volume = 100
	item_state = "broken_beer" //Generic held-item sprite until unique ones are made.
	force = 5
	var/shatter_duration = 5 //Directly relates to the 'weaken' duration. Lowered by armor (i.e. helmets)
	var/isGlass = TRUE //Whether the 'bottle' is made of glass or not so that milk cartons dont shatter when someone gets hit by it

	var/obj/item/weapon/reagent_containers/glass/rag/rag = null
	var/rag_underlay = "rag"
	var/icon_state_full
	var/icon_state_empty

	dropsound = 'sound/effects/drop_glass.ogg'

	w_class = 3

/obj/item/weapon/reagent_containers/food/drinks/bottle/on_reagent_change()
	update_icon()

/obj/item/weapon/reagent_containers/food/drinks/bottle/New()
	..()
	icon_state_full = icon_state
	if (findtext(icon_state, "bottle") || findtext(icon_state, "canteen"))
		icon_state_empty = icon_state
	else
		icon_state_empty = "[icon_state]_empty"

/obj/item/weapon/reagent_containers/food/drinks/bottle/Destroy()
	if (rag)
		rag.forceMove(loc)
	rag = null
	return ..()

//when thrown on impact, bottles shatter and spill their contents
/obj/item/weapon/reagent_containers/food/drinks/bottle/throw_impact(atom/hit_atom, var/speed)
	var/alcohol_power = calculate_alcohol_power()

	..()

	var/mob/M = thrower
	if (isGlass && istype(M))
		var/throw_dist = get_dist(throw_source, loc)
		if (shatter_check(throw_dist)) //not as reliable as shattering directly
			if (reagents)
				hit_atom.visible_message("<span class='notice'>The contents of \the [src] splash all over [hit_atom]!</span>")
				reagents.splash(hit_atom, reagents.total_volume)
			shatter(loc, hit_atom, alcohol_power)

/obj/item/weapon/reagent_containers/food/drinks/bottle/proc/calculate_alcohol_power()
	. = 0

	if (reagents)
		for (var/datum/reagent/R in reagents.reagent_list)
			if (istype(R, /datum/reagent/ethanol))
				var/datum/reagent/ethanol/E = R
				. += (min(max(E.strength, 25), 50) * E.volume)

	if (rag && rag.reagents)
		for (var/datum/reagent/R in rag.reagents.reagent_list)
			if (istype(R, /datum/reagent/ethanol))
				var/datum/reagent/ethanol/E = R
				. += (min(max(E.strength, 25), 50) * E.volume)

/obj/item/weapon/reagent_containers/food/drinks/bottle/proc/shatter_check(var/distance)
	if (!isGlass || !shatter_duration)
		return FALSE

	var/list/chance_table = list(50, 75, 90, 95, 100, 100, 100) //starting from distance 0
	var/idx = max(distance + 1, 1) //since list indices start at 1
	if (idx > chance_table.len)
		return 0
	return prob(chance_table[idx])

/obj/item/weapon/reagent_containers/food/drinks/bottle/throw_at(atom/target, range, speed, thrower)
	..(target, range, speed, thrower)
	spawn (3)
		while (src && throwing)
			sleep(1)
		if (src && !throwing)
			if (loc == get_turf(target))
				Bump(target, TRUE)
			else
				var/area/src_area = get_area(src)
				if (src_area && map && map.caribbean_blocking_area_types.Find(src_area.type))
					Bump(loc, TRUE, FALSE)
				else
					Bump(loc, TRUE)

/obj/item/weapon/reagent_containers/food/drinks/bottle/Bump(atom/A, yes, explode = TRUE)
	if (src && isGlass)
		if (isliving(A) || isturf(A) || (isobj(A) && A.density))
			shatter(get_turf(A), A, explode ? calculate_alcohol_power() : 0)
	..(A, yes)

// molotov recode, 4/7/18 - Kachnov
/obj/item/weapon/reagent_containers/food/drinks/bottle/proc/shatter(var/newloc, atom/against = null, var/alcohol_power = 0)

	if (!newloc)
		newloc = get_turf(src)

	if (rag && rag.on_fire && alcohol_power)

		forceMove(newloc)

		if (against && isliving(against))
			var/mob/living/L = against
			L.IgniteMob()

		rag.loc = null
		qdel(rag)
		rag = null

// for reference:
// "apply_damage(ceil(fire_stacks/3)+1, BURN, "chest", FALSE)" is the fire damage formula, found in living_defense.dm

		mainloop:
			for (var/turf/T in range(get_turf(src), 1))
				if ((prob(90) || T == get_turf(src)) && !T.density)
					for (var/obj/structure/S in T)
						if (S.density && !S.low)
							continue mainloop
					var/obj/fire/F = T.create_fire(temp = max(375, ceil(alcohol_power/5)))
					F.time_limit = pick(50, 60, 70)
					for (var/mob/living/L in T)
						if (L.on_fire)
							continue
						L.fire_stacks += ceil(alcohol_power/1000)
						L.IgniteMob()
						L.adjustFireLoss(rand(alcohol_power*0.004,alcohol_power*0.008))
						if (ishuman(L))
							L.emote("painscream")

	if (src)
		if (ismob(loc))
			var/mob/M = loc
			M.drop_from_inventory(src)

		//Creates a shattering noise and replaces the bottle with a broken_bottle
		var/obj/item/weapon/broken_bottle/B = new /obj/item/weapon/broken_bottle(newloc)
		if (prob(33))
			new/obj/item/weapon/material/shard(newloc) // Create a glass shard at the target's location!

		B.icon_state = icon_state

		var/icon/I = new('icons/obj/drinks.dmi', icon_state)
		I.Blend(B.broken_outline, ICON_OVERLAY, rand(5), TRUE)
		I.SwapColor(rgb(255, FALSE, 220, 255), rgb(0, FALSE, FALSE, FALSE))
		B.icon = I

		playsound(src,'sound/effects/drop_glass.ogg',100,1)
		transfer_fingerprints_to(B)

		qdel(src)
		return B

/obj/item/weapon/reagent_containers/food/drinks/bottle/attackby(obj/item/W, mob/user)
	if (!rag && istype(W, /obj/item/weapon/reagent_containers/glass/rag))
		insert_rag(W, user)
		update_icon()
		return
	else if (rag && (istype(W, /obj/item/weapon/flame) || istype(W, /obj/item/clothing/mask/smokable/cigarette) && W:on))
		rag.attackby(W, user)
		update_icon()
		return
	else return ..()

/obj/item/weapon/reagent_containers/food/drinks/bottle/attack_self(mob/user)
	if (rag)
		remove_rag(user)
	else
		..()

/obj/item/weapon/reagent_containers/food/drinks/bottle/proc/insert_rag(obj/item/weapon/reagent_containers/glass/rag/R, mob/user)
	if (!isGlass || rag) return
	if (user.unEquip(R))
		user << "<span class='notice'>You stuff [R] into [src].</span>"
		rag = R
		rag.forceMove(src)
		flags &= ~OPENCONTAINER
		update_icon()

/obj/item/weapon/reagent_containers/food/drinks/bottle/proc/remove_rag(mob/user)
	if (!rag) return
	user.put_in_hands(rag)
	rag = null
	flags |= (initial(flags) & OPENCONTAINER)
	update_icon()
	user << "<span class='notice'>You remove the rag from [src].</span>"

/obj/item/weapon/reagent_containers/food/drinks/bottle/open(mob/user)
	if (rag) return
	..()

/obj/item/weapon/reagent_containers/food/drinks/bottle/update_icon()
	underlays.Cut()
	if (rag)
		var/underlay_image = image(icon='icons/obj/drinks.dmi', icon_state=rag.on_fire? "[rag_underlay]_lit" : rag_underlay)
		underlays += underlay_image
		if (rag.on_fire)
			set_light(2)
	else
		set_light(0)
		if (reagents.total_volume)
			icon_state = icon_state_full
		else
			icon_state = icon_state_empty

/obj/item/weapon/reagent_containers/food/drinks/bottle/apply_hit_effect(mob/living/target, mob/living/user, var/hit_zone)
	var/blocked = ..()

	if (user.a_intent != I_HURT)
		return
	if (!shatter_check(1))
		return //won't always break on the first hit

	// You are going to knock someone out for longer if they are not wearing a helmet.
	var/weaken_duration = FALSE
	if (blocked < 2)
		weaken_duration = shatter_duration + min(0, force - target.getarmor(hit_zone, "melee") + 10)

	var/mob/living/carbon/human/H = target
	if (istype(H) && H.headcheck(hit_zone))
		var/obj/item/organ/affecting = H.get_organ(hit_zone) //headcheck should ensure that affecting is not null
		user.visible_message("<span class='danger'>[user] shatters [src] into [H]'s [affecting.name]!</span>")
		if (weaken_duration)
			target.apply_effect(min(weaken_duration, 5), WEAKEN, blocked) // Never weaken more than a flash!
	else
		user.visible_message("<span class='danger'>\The [user] shatters [src] into [target]!</span>")

	//The reagents in the bottle splash all over the target, thanks for the idea Nodrak
	var/alcohol_power = calculate_alcohol_power()

	if (reagents)
		spawn (1) // wait until after our explosion, if we have one
			user.visible_message("<span class='notice'>The contents of \the [src] splash all over [target]!</span>")
			if (reagents) reagents.splash(target, reagents.total_volume)

	//Finally, shatter the bottle. This kills (qdel) the bottle.

	var/obj/item/weapon/broken_bottle/B = shatter(target.loc, target, alcohol_power)
	user.put_in_active_hand(B)

//Keeping this here for now, I'll ask if I should keep it here.
/obj/item/weapon/broken_bottle

	name = "Broken Bottle"
	desc = "A bottle with a sharp broken bottom."
	icon = 'icons/obj/drinks.dmi'
	icon_state = "broken_bottle"
	force = 9
	throwforce = 5
	throw_speed = 3
	throw_range = 5
	item_state = "beer"
	attack_verb = list("stabbed", "slashed", "attacked")
	sharp = TRUE
	edge = FALSE
	dropsound = 'sound/effects/drop_glass.ogg'
	var/icon/broken_outline = icon('icons/obj/drinks.dmi', "broken")
	value = 0
/obj/item/weapon/broken_bottle/attack(mob/living/carbon/M as mob, mob/living/carbon/user as mob)
	if (M != user || M.a_intent != I_HELP)
		playsound(loc, 'sound/weapons/bladeslice.ogg', 50, TRUE, -1)
	return ..()


/obj/item/weapon/reagent_containers/food/drinks/bottle/gin
	name = "Griffeater Gin"
	desc = "A bottle of high quality gin."
	icon_state = "ginbottle"
	center_of_mass = list("x"=16, "y"=4)
	New()
		..()
		reagents.add_reagent("gin", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/gin/empty
	name = "Griffeater Gin"
	desc = "A bottle of high quality gin."
	icon_state = "ginbottle"
	center_of_mass = list("x"=16, "y"=4)
	New()
		..()
		reagents.del_reagents()

/obj/item/weapon/reagent_containers/food/drinks/bottle/whiskey
	name = "Uncle Git's Special Reserve"
	desc = "A premium single-malt whiskey, gently matured inside the tunnels of a nuclear shelter. TUNNEL WHISKEY RULES."
	icon_state = "whiskeybottle"
	center_of_mass = list("x"=16, "y"=3)
	New()
		..()
		reagents.add_reagent("whiskey", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/whiskey/empty
	name = "Uncle Git's Special Reserve"
	desc = "A premium single-malt whiskey, gently matured inside the tunnels of a nuclear shelter. TUNNEL WHISKEY RULES."
	icon_state = "whiskeybottle"
	center_of_mass = list("x"=16, "y"=3)
	New()
		..()
		reagents.del_reagents()


/obj/item/weapon/reagent_containers/food/drinks/bottle/vodka
	name = "Tunguska Triple Distilled"
	desc = "Aah, vodka. Prime choice of drink AND fuel by Russians worldwide."
	icon_state = "vodkabottle"
	center_of_mass = list("x"=17, "y"=3)
	New()
		..()
		reagents.add_reagent("vodka", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/vodka/empty
	name = "Tunguska Triple Distilled"
	desc = "Aah, vodka. Prime choice of drink AND fuel by Russians worldwide."
	icon_state = "vodkabottle"
	center_of_mass = list("x"=17, "y"=3)
	New()
		..()
		reagents.del_reagents()

/obj/item/weapon/reagent_containers/food/drinks/bottle/tequilla
	name = "Caccavo Guaranteed Quality Tequilla"
	desc = "Made from premium petroleum distillates, pure thalidomide and other fine quality ingredients!"
	icon_state = "tequillabottle"
	center_of_mass = list("x"=16, "y"=3)
	New()
		..()
		reagents.add_reagent("tequilla", 100)
/obj/item/weapon/reagent_containers/food/drinks/bottle/tequilla/empty
	name = "Caccavo Guaranteed Quality Tequilla"
	desc = "Made from premium petroleum distillates, pure thalidomide and other fine quality ingredients!"
	icon_state = "tequillabottle"
	center_of_mass = list("x"=16, "y"=3)
	New()
		..()
		reagents.del_reagents()

/obj/item/weapon/reagent_containers/food/drinks/bottle/bottleofnothing
	name = "Bottle of Nothing"
	desc = "A bottle filled with nothing"
	icon_state = "bottleofnothing"
	center_of_mass = list("x"=17, "y"=5)
	New()
		..()
		reagents.add_reagent("nothing", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/patron
	name = "Wrapp Artiste Patron"
	desc = "Silver laced tequilla, served in night clubs across the earth."
	icon_state = "patronbottle"
	center_of_mass = list("x"=16, "y"=6)
	New()
		..()
		reagents.add_reagent("patron", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/patron/empty
	name = "Wrapp Artiste Patron"
	desc = "Silver laced tequilla, served in night clubs across the earth."
	icon_state = "patronbottle"
	center_of_mass = list("x"=16, "y"=6)
	New()
		..()
		reagents.del_reagents()

/obj/item/weapon/reagent_containers/food/drinks/bottle/rum
	name = "bottle of rum"
	desc = "Pirate's favourite."
	icon_state = "oldstyle_rum"
	value = 25
	center_of_mass = list("x"=16, "y"=8)
	New()
		..()
		reagents.add_reagent("rum", 80)

/obj/item/weapon/reagent_containers/food/drinks/bottle/rum/empty
	name = "empty bottle of rum"
	desc = "Pirate's favourite. When full, of course."
	icon_state = "oldstyle_rum_empty"
	value = 1
	center_of_mass = list("x"=16, "y"=8)
	New()
		..()
		reagents.del_reagents()

/obj/item/weapon/reagent_containers/food/drinks/bottle/holywater
	name = "Flask of Holy Water"
	desc = "A flask of the preacher's holy water."
	icon_state = "holyflask"
	center_of_mass = list("x"=17, "y"=10)
	New()
		..()
		reagents.add_reagent("holywater", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/vermouth
	name = "Goldeneye Vermouth"
	desc = "Sweet, sweet dryness."
	icon_state = "vermouthbottle"
	center_of_mass = list("x"=17, "y"=3)
	New()
		..()
		reagents.add_reagent("vermouth", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/vermouth/empty
	name = "Goldeneye Vermouth"
	desc = "Sweet, sweet dryness~"
	icon_state = "vermouthbottle"
	center_of_mass = list("x"=17, "y"=3)
	New()
		..()
		reagents.del_reagents()

/obj/item/weapon/reagent_containers/food/drinks/bottle/kahlua
	name = "Robert Robust's Coffee Liqueur"
	desc = "A widely known, Mexican coffee-flavoured liqueur. In production since 1936, HONK"
	icon_state = "kahluabottle"
	center_of_mass = list("x"=17, "y"=3)
	New()
		..()
		reagents.add_reagent("kahlua", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/kahlua/empty
	name = "Robert Robust's Coffee Liqueur"
	desc = "A widely known, Mexican coffee-flavoured liqueur. In production since 1936, HONK"
	icon_state = "kahluabottle"
	center_of_mass = list("x"=17, "y"=3)
	New()
		..()
		reagents.del_reagents()

/obj/item/weapon/reagent_containers/food/drinks/bottle/goldschlager
	name = "College Girl Goldschlager"
	desc = "Because they are the only ones who will drink 100 proof cinnamon schnapps."
	icon_state = "goldschlagerbottle"
	center_of_mass = list("x"=15, "y"=3)
	New()
		..()
		reagents.add_reagent("goldschlager", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/goldschlager/empty
	name = "College Girl Goldschlager"
	desc = "Because they are the only ones who will drink 100 proof cinnamon schnapps."
	icon_state = "goldschlagerbottle"
	center_of_mass = list("x"=15, "y"=3)
	New()
		..()
		reagents.del_reagents()

/obj/item/weapon/reagent_containers/food/drinks/bottle/cognac
	name = "Chateau De Baton Premium Cognac"
	desc = "A sweet and strongly alchoholic drink, made after numerous distillations and years of maturing. You might as well not scream 'SHITCURITY' this time."
	icon_state = "cognacbottle"
	center_of_mass = list("x"=16, "y"=6)
	New()
		..()
		reagents.add_reagent("cognac", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/cognac/empty
	name = "Chateau De Baton Premium Cognac"
	desc = "A sweet and strongly alchoholic drink, made after numerous distillations and years of maturing. You might as well not scream 'SHITCURITY' this time."
	icon_state = "cognacbottle"
	center_of_mass = list("x"=16, "y"=6)
	New()
		..()
		reagents.del_reagent()

/obj/item/weapon/reagent_containers/food/drinks/bottle/wine
	name = "Red Wine"
	desc = "Typical red wine."
	icon_state = "winebottle"
	center_of_mass = list("x"=16, "y"=4)
	value = 16
	New()
		..()
		reagents.add_reagent("wine", 100)
/obj/item/weapon/reagent_containers/food/drinks/bottle/palmwine
	name = "Palm Wine"
	desc = "A crude drink, made from fermented palm sap."
	icon_state = "tribalpot"
	center_of_mass = list("x"=16, "y"=4)
	value = 18
	New()
		..()
		reagents.add_reagent("palmwine", 40)

/obj/item/weapon/reagent_containers/food/drinks/bottle/wine/empty
	name = "Doublebeard Bearded Special Wine"
	desc = "A faint aura of unease and asspainery surrounds the bottle."
	icon_state = "winebottle"
	center_of_mass = list("x"=16, "y"=4)
	value = 1
	New()
		..()
		reagents.del_reagents()

/obj/item/weapon/reagent_containers/food/drinks/bottle/absinthe
	name = "Jailbreaker Verte"
	desc = "One sip of this and you just know you're gonna have a good time."
	icon_state = "absinthebottle"
	center_of_mass = list("x"=16, "y"=6)
	New()
		..()
		reagents.add_reagent("absinthe", 100)

/obj/item/weapon/reagent_containers/food/drinks/bottle/absinthe/empty
	name = "Jailbreaker Verte"
	desc = "One sip of this and you just know you're gonna have a good time."
	icon_state = "absinthebottle"
	center_of_mass = list("x"=16, "y"=6)
	New()
		..()
		reagents.del_reagents()

//////////////////////////SMALL BOTTLES ///////////////////////


//Small bottles
/obj/item/weapon/reagent_containers/food/drinks/bottle/small
	volume = 30
	shatter_duration = TRUE
	flags = FALSE //starts closed
	rag_underlay = "rag_small"
	icon_state = "oldstyle_beer_empty"
	item_state = "beer"

/obj/item/weapon/reagent_containers/food/drinks/bottle/small/beer
	name = "beer"
	desc = "A bottle of bear"
	icon_state = "oldstyle_beer"
	item_state = "beer"
	center_of_mass = list("x"=16, "y"=12)
	value = 5
	New()
		..()
		reagents.add_reagent("beer", 40)

/obj/item/weapon/reagent_containers/food/drinks/bottle/small/ale
	name = "ale"
	desc = "A bottle of dark ale."
	icon_state = "oldstyle_beer"
	item_state = "beer"
	center_of_mass = list("x"=16, "y"=10)
	value = 6
	New()
		..()
		reagents.add_reagent("ale", 40)

/obj/item/weapon/reagent_containers/food/drinks/bottle/small/sake
	volume = 50
	name = "sake"
	desc = "A bottle of sake."
	icon_state = "sake"
	item_state = "beer"
	center_of_mass = list("x"=16, "y"=10)
	value = 6
	New()
		..()
		reagents.add_reagent("sake", 50)

/obj/item/weapon/reagent_containers/food/drinks/bottle/small/sake/empty
	volume = 50
	shatter_duration = TRUE
	flags = FALSE //starts closed
	rag_underlay = "rag_small"
	icon_state = "sake_empty"
	item_state = "beer"