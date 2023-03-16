//TO DO TODO: CHECK ALL attack_by it MUST return TRUE or FALSE if we don't want after_atttack call

//var/const/MOOD_LOSS_PER_DECISECOND_OF_MENTAL_WORK = 0.1 //it's good values, but if no restoration of mood by resting - no way to use it
//var/const/MOOD_LOSS_PER_DECISECOND_OF_PHYSICAL_WORK = 0.05
/var/const/MOOD_LOSS_PER_DECISECOND_OF_MENTAL_WORK = 0 //setting it to 0, because have no normal mood restoration TO DO TODO: make some mood restoration on resting and sleeping, also make meditation (religion?)
/var/const/MOOD_LOSS_PER_DECISECOND_OF_PHYSICAL_WORK = 0 //setting it to 0, because have no normal mood restoration
//TO DO TODO: Make some normalization of mood to normal state (not 100, but 50 for full water and food lvl) with time depending on the state: rest, sleep, awake
/var/const/STAMINA_LOSS_BASE_PER_DECISECOND_SDS_OF_WORK = 0 //(summ of used strength, dexterity and stamina itself in deciseconds)
/var/const/TIME_TO_DRY = 1200 //TO DO: Add dry_transform() procedure, which will replace the old mechanics of items with the mechanics of changing reagents in dried items. 
//TO DO TODO: Make this proc global using
/mob/living/human/var/tmp/last_mood_check = 0

/mob/living/human/proc/in_mood(no_mood_check_treshold = 38)
	return TRUE //This is temporary! TO DO TODO: Return this function after reworking mood restoration and mood buff/debuff system
	//checking mood for doing anything
	if (world.timeofday<src.last_mood_check) //prevent mood check spam
		src.mood -= 0.25
		src << "<span class='warning'>You are far too upset to work, restore your mood first! Wait 5 seconds at minimum before trying again.</span>"
		return FALSE
	if (src.mood > no_mood_check_treshold)
		return TRUE
	if (prob(src.mood * 1.5))
		return TRUE
	else
		src << "<span class='warning'>You are not in the mood to do this. Relax first.</span>"
		src.last_mood_check = world.timeofday + 45
		return FALSE

// TO DO TODO: Make this universal proc for all expirience gains
/mob/living/human/proc/give_exp(var/list/exp_skills_list, var/list/exp_skills_percent = list(), work_amount = 10, no_emotes = FALSE, no_msg = FALSE, change_mood_coefficient = 1, EUREKA_chance = 0.5, breakthrough_chance = 5 , fail_chance = 5, EPIC_fail_chance = 0.5)
	// returns 0 - nothing happens, 1 - breaktrough, 2 - EUREKA, -1 - fail, -2 - EPIC fail
	// exp_skills_list - list of skills how it declared in human_defines.dm, f.e. list("swords","strength","dexterity","stamina") or empty list if you want simply generate chance
	// exp_skills_percent - list of percent distribution of gain expirience, f.e. list(85,5,5,5) or empty list, if you want equal distribution in skills experience
	// 		if you want to give more experience for any reason, then you can exceed 100% of the total experience (this will work wor mood gains too), f.e. list(130,5,5,5)
	// work_amount - in deciseconds work amount
	// no_emotes - set it to TRUE if no emotes when procedure work
	// no_msg - set it to TRUE if no messages to user when procedure work
	// change_mood_coefficient - set this multiplicator not 1 if you want greater or less effect to mood
	// EUREKA_chance, breakthrough_chance, fail_chance, EPIC_fail_chance - in percents, by default they are 0.5, 5, 5 and 0.5
	var/equal_distribution = 0
	var/exp_gain = work_amount/10/2 //1 exp for every 2 seconds of work
	var/e_c = EUREKA_chance * 100
	var/b_c = breakthrough_chance * 100
	var/f_c = fail_chance * 100
	var/c_c = EPIC_fail_chance * 100
	var/s_c = rand(1,10000)
	var/need_calc = work_amount && exp_skills_list.len
	var/result
	var/this_exp
	if (s_c <= e_c) // EUREKA!
		if (!no_emotes)
			src.emote(pick("laugh","dance"))
		result = 2
	else if (s_c <= e_c+b_c) // breaktrough
		if (!no_emotes)
			src.emote("giggle")
		result = 1
	else if (s_c >= 10000-c_c) // EPIC fail
		if (!no_emotes)
			src.emote(pick("cry", "scream"))
		result = -1
	else if (s_c >= 10000-c_c-f_c) // fail
		if (!no_emotes)
			src.emote("sigh")
		result = -2
	else // all as usual
		result = 0
	if (need_calc)
		if (exp_skills_list.len < exp_skills_percent) //equal distribution
			equal_distribution = 100 / exp_skills_list.len
		for (var/I=1, I<exp_skills_list.len+1, I++)
			if (equal_distribution>0)
				this_exp = exp_gain*equal_distribution/100
			else
				this_exp = exp_gain*exp_skills_percent[I]/100
			switch (result)
				if (2) // EUREKA!
					if (exp_skills_list[I] in list ("strength", "dexterity", "stamina"))
						src.adaptStat(exp_skills_list[I],this_exp) //no boost for physical stats
						src.mood += this_exp * change_mood_coefficient / 5 //mood busted as usual too
						continue
					src.adaptStat(exp_skills_list[I],this_exp*20) //20 times more than usual. EUREKA!
					src.mood += this_exp * change_mood_coefficient * 2 //10 times more than usual
					if(!no_msg)
						if (exp_skills_list[I] in list ("crafting", "swords", "bows", "farming", "throwing", "magic", "philosophy"))
							src << "<span class='good'>EUREKA!</span> <span class='notice'>You have learned much more about [exp_skills_list[I]].</span>"
						if (exp_skills_list[I] in list ("rifle", "pistol", "machinegun"))
							src << "<span class='good'>EUREKA!</span> <span class='notice'>You have learned much more about [exp_skills_list[I]]s.</span>"
						if (exp_skills_list[I] == "medical")
							src << "<span class='good'>EUREKA!</span> <span class='notice'>You have learned much more about medicine.</span>"
				if (1) // breaktrough
					if (exp_skills_list[I] in list ("strength", "dexterity", "stamina"))
						src.adaptStat(exp_skills_list[I],this_exp) //no boost for physical stats
						src.mood += this_exp * change_mood_coefficient / 5 //mood busted as usual too
						continue
					src.adaptStat(exp_skills_list[I],this_exp*3) //3 times more than usual.
					src.mood += this_exp * change_mood_coefficient / 5 * 2 //2 times more than usual
					if(!no_msg)
						if (exp_skills_list[I] in list ("crafting", "swords", "bows", "farming", "throwing", "magic", "philosophy"))
							src << "<span class='notice'>You learned little more about [exp_skills_list[I]].</span>"
						if (exp_skills_list[I] in list ("rifle", "pistol", "machinegun"))
							src << "<span class='notice'>You learned little more about [exp_skills_list[I]]s.</span>"
						if (exp_skills_list[I] == "medical")
							src << "<span class='notice'>You learned little more about medicine.</span>"
				if (-1) // fail
					src.adaptStat(exp_skills_list[I],this_exp/2) //small mood decreasing, 1/2 exp gain
					src.mood -= this_exp * change_mood_coefficient / 5
				if (-2) // EPIC fail
					if (exp_skills_list[I] in list ("strength", "dexterity", "stamina"))
						src.mood -= this_exp * change_mood_coefficient / 5 //small mood decreasing for physical stats
						continue
					src.adaptStat(exp_skills_list[I],-this_exp*3) //3 times skill anti-boost
					src.mood -= this_exp * change_mood_coefficient / 5 * 5 //5x mood decreasing for intellectual skills
					if(!no_msg)
						if (exp_skills_list[I] in list ("crafting", "swords", "bows", "farming", "throwing", "magic", "philosophy"))
							src << "<span class='notice'>You've lost a bit of [exp_skills_list[I]] skill.</span>"
						if (exp_skills_list[I] in list ("rifle", "pistol", "machinegun"))
							src << "<span class='notice'>You've lost a bit of [exp_skills_list[I]]s skill.</span>"
						if (exp_skills_list[I] == "medical")
							src << "<span class='notice'>You've lost a bit of medicine skill.</span>"
				else // all as usual
					src.adaptStat(exp_skills_list[I],this_exp)
					src.mood += this_exp * change_mood_coefficient / 5 //small happiness boost, when succeeded (1*coefficient for each 10 seconds of work)
	return result

//TO DO TODO: make this procedure global using
/obj/structure/proc/wrench_action(var/mob/living/human/H)
	if(!not_movable)
		playsound(src.loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		H.visible_message(
			"<span class='notice'>You can see how [H.name] [anchored ? "un" : ""]fasten [src].</span>",
			"<span class='notice'>You [anchored ? "un" : ""]fasten [src].</span>",
			"<span class='notice'>Somebody fasten or unfasten something.</span>")
		anchored = !anchored
	else
		H << "<span class='warning'>\The [src] is not movable.</span>"

//TO DO TODO: make this procedure global using
/obj/structure/proc/hammer_action(var/mob/living/human/H, var/obj/item/weapon/W, var/work_amount = 50, var/list/components = list(), var/list/quantities = list())
	// Dismantling procedure
	// Good: when set work_amount as time of creation, quantities as 75% of used items
	if(!not_disassemblable)
		if (!H.in_mood())
			return
		var/I = work_amount*(0.85/H.getStatCoeff("crafting") + 0.05/H.getStatCoeff("strength") + 0.05/H.getStatCoeff("dexterity") + 0.05/H.getStatCoeff("stamina"))
		if (istype(W,/obj/item/weapon/hammer/tribalhammer))
			I *= 1.5
		if (istype(W,/obj/item/weapon/hammer/modern))
			I /= 1.5
		I = clamp(I, 10, 300)
		if (H.stats["stamina"][1]<H.stats["stamina"][2])
			if (H.stats["stamina"][1]<I*STAMINA_LOSS_BASE_PER_DECISECOND_SDS_OF_WORK)
				H << "<span class='warning'>You must restore your stamina before dismantling [src].</span>"
				return
		playsound(src.loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		H.visible_message(
			"<span class='notice'>You can see how [H.name] begin dismantling \the [src].</span>",
			"<span class='notice'>You begin dismantling \the [src].</span>",
			"<span class='notice'>Somebody dismantling something.</span>")
		if (do_after(H, I , src))
			H.stats["stamina"][1] -= I*STAMINA_LOSS_BASE_PER_DECISECOND_SDS_OF_WORK*0.15
			H.mood -= I*MOOD_LOSS_PER_DECISECOND_OF_PHYSICAL_WORK*0.15
			H.mood -= I*MOOD_LOSS_PER_DECISECOND_OF_MENTAL_WORK*0.85
			H.visible_message(
				"<span class='notice'>You can see how [H.name] dismantled \the [src].</span>",
				"<span class='notice'>You dismantle \the [src].</span>",
				"<span class='notice'>Somebody dismantled something.</span>")
			H.give_exp(list("crafting","strength","dexterity","stamina"), list(85,5,5,5), I)
			I = 1
			for (var/P in components)
				new P(src.loc, quantities[I])
				I++
			for (var/obj/item/P in contents)
				P.loc = src.loc
			qdel(src)
		else
			H.visible_message(
				"<span class='notice'>You can see how [H.name] stops dismantling \the [src].</span>",
				"<span class='notice'>You stops dismantling \the [src].</span>",
				"<span class='notice'>Dismantling sounds are gone.</span>")
	else
		H << "<span class='warning'>\The [src] is not dissasemblable.</span>"

////////////////////////////////////////////////////////////////////////
//  Loom  //////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
// TO DO TODO: Reconsider the weaving process in a more realistic way (different technological levels
//  	of weaving, a more detailed process: material -> threads -> fabric) e t.c.
/obj/structure/loom
	name = "loom"
	desc = "A loom, used to transform cotton into cloth."
	icon = 'icons/obj/structures.dmi'
	icon_state = "loom"
	anchored = TRUE
	density = TRUE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/tmp/obj/item/stack/current_work = null
	var/tmp/obj/item/stack/current_material = null
	var/tmp/mob/living/human/current_user = null
	var/tmp/work_time_amount = 0

/obj/structure/loom/proc/finish_work()
	if (current_work)
		current_user.visible_message(
			"<span class='notice'>You can see how [current_user.name] made [current_work.name] on \a [src.name].</span>",
			"<span class='notice'>You finish producing \the [current_work.name].</span>",
			"<span class='notice'>The sounds of \the [src.name] were gone.</span>")
		icon_state = "loom"
		qdel(current_material)
		var/obj/item/stack/this_production = new current_work.type(null, current_work.amount, FALSE) //deleting and creating for sterilization effect (we need really new object)
		current_user.put_in_active_hand(this_production)
		qdel(current_work)
		if (current_user.give_exp(list("crafting","dexterity"), list(67,33), work_time_amount) == -2)
			var/newamount = clamp(ceil(this_production.amount/2+rand(1,ceil(this_production.amount/2))),ceil(this_production.amount/2),this_production.amount)
			if (newamount < this_production.amount)
				current_user << "<span class='bad'>You produced [this_production.amount - newamount] less [this_production.name] due epic fail.</span>"
				this_production.amount = newamount
		current_user.mood -= work_time_amount*MOOD_LOSS_PER_DECISECOND_OF_MENTAL_WORK*0.67
		current_user.mood -= work_time_amount*MOOD_LOSS_PER_DECISECOND_OF_PHYSICAL_WORK*0.33
		current_user.stats["stamina"][1] -= work_time_amount*STAMINA_LOSS_BASE_PER_DECISECOND_SDS_OF_WORK*0.33
	current_work = null
	current_material = null
	current_user = null
	work_time_amount = 0

/obj/structure/loom/proc/produce(var/obj/item/stack/W, var/mob/living/human/H, var/obj/item/stack/P)
	if (!H.in_mood())
		return
	if(!anchored)
		H << "<span class='warning'>\The [src] needs to be fixed in place before anything can be woven.</span>"
		return
	if (current_work)
		H << "<span class='warning'>\The [src.name] is busy, wait for the weaver to finish work.</span>"
		return
	current_work = new P(null, W.amount, FALSE) //in fact for information purpose only we really need new object
	current_material = W
	current_user = H
	H.visible_message(
		"<span class='notice'>You can see how [H.name] began to weave [W.name] on \a [src.name].</span>",
		"<span class='notice'>You start to produce \the [current_work.name].</span>",
		"<span class='notice'>You hear someone begin to weave on \the [src.name].</span>")
	icon_state = "loom1"
	work_time_amount = round(1000/(W.amount*3+47)) //The efficiency increases with the amount of material. For 1 material we get 20 deciseconds, for 50 material - 254 deciseconds.
	work_time_amount = work_time_amount*(0.67/H.getStatCoeff("crafting") + 0.33/H.getStatCoeff("dexterity"))
	if (do_after(H, work_time_amount, src.loc))
		finish_work()
	else
		icon_state = "loom"
		//20% - with no penalty, 30% - little mood decreasing, 25% - mood decreasing,
		//15% - to lose some material and mood decreasing, 10% to lose all material and great mood decreasing
		switch (rand(1,100)) //here are another algorithm because we don't know how much work was really done
			if (1 to 20) //20% with no penalty... almost
				H.visible_message(
					"<span class='notice'>You see how [H.name] pulls [W.name] out of [src.name], stopping work.</span>",
					"<span class='notice'>You safely pull \the [W.name] from \the [src.name], stopping work.</span>",
					"<span class='notice'>The sounds of \the [src.name] gone.</span>")
				if (prob(25)) //5% to lose or gain some skill
					if (prob(80)) //4% to lose
						H.emote("sigh")
						H << "<span class='notice'>You've lost a bit of crafting skill.</span>"
						H.adaptStat("crafting", -1)
					else //1% to gain
						H.emote("giggle")
						H << "<span class='notice'>You learned a little more about the craft.</span>"
						H.adaptStat("crafting", 1)
			if (21 to 50) //30% little mood decreasing
				H.visible_message(
					"<span class='notice'>You see how [H.name] sighs and pulls [W.name] out of [src.name], stopping work.</span>",
					"<span class='notice'>You pull \the [W.name] from \the [src.name], stopping work. You are a little upset.</span>",
					"<span class='notice'>You hear an irritated murmur. The sounds of \the [src.name] gone.</span>")
				H.mood -= 2
			if (51 to 75) //25% nervously
				H.visible_message(
					"<span class='notice'>You see how [H.name] nervously plucks [W.name] from \the [src.name], stopping work.</span>",
					"<span class='notice'>You nervously pluck \the [W.name] from \the [src.name], stopping work. You are a some upset.</span>",
					"<span class='notice'>The sounds of \the [src.name] gone.</span>")
				H.emote("sigh")
				H.mood -= 4
			if (76 to 90) //15% losing some material
				H.visible_message(
					"<span class='notice'>You see how [H.name] plucks [W.name] from \the [src.name], stopping work and losing some [W.name].</span>",
					"<span class='notice'>You pull \the [W.name] from \the [src.name], stopping work. You are upset.</span>",
					"<span class='notice'>The sounds of \the [src.name] gone.</span>")
				W.amount = round(W.amount/2 + W.amount/10*rand(1,10))
				H << "<span class='bad'>You lose [current_work.amount - W.amount] [W.name]].</span>"
				H.emote("cry")
				H.mood -= 8
				if (prob(33)) //5% to lose or gain some skill
					if (prob(80)) //4% to gain
						H << "<span class='notice'>You learned a little more about the craft.</span>"
						H.adaptStat("crafting", rand(1, clamp(current_work.amount-W.amount,1,5)))
					else //1% to lose
						H << "<span class='notice'>You've lost a bit of crafting skill.</span>"
						H.adaptStat("crafting", -1)
			else //10% to lose all material
				H.visible_message(
					"<span class='notice'>You see how [H.name] plucks [W.name] from \the [src.name], stopping work and losing some [W.name].</span>",
					"<span class='notice'>You pull \the [W.name] from \the [src.name], stopping work. You are very upset.</span>",
					"<span class='notice'>The sounds of \the [src.name] gone.</span>")
				if (prob(50)) //5% to breakthrough
					if (prob(10)) //0.5% EUREKA!
						H << "<span class='notice'>But...</span> <span class='good'>EUREKA!</span> <span class='notice'>You have learned several times more about the craft.</span>"
						H.adaptStat("crafting", current_work.amount*2) //20 times more than usual. EUREKA!
					else // 4.5% breakthrough
						H << "<span class='notice'>But... You learned a little more about the craft.</span>"
						H.adaptStat("crafting", rand(1, clamp(current_work.amount-W.amount,1,20))) //In fact three times more.
				W.amount = 0
				qdel(W)
				H.emote("scream")
				H.mood -= 16
		qdel(current_work)
		current_work = null
		current_material = null
		current_user = null

/obj/structure/loom/attackby(var/obj/item/stack/W as obj, var/mob/living/human/H as mob)
	if (istype(W, /obj/item/stack/material/cotton) || istype(W, /obj/item/stack/material/rettedfabric))
		produce(W, H, /obj/item/stack/material/cloth)
		return
	if (istype(W, /obj/item/stack/material/preparedkevlar))
		produce(W, H, /obj/item/stack/material/kevlar)
		return
	if (istype(W, /obj/item/stack/material/wool))
		produce(W, H, /obj/item/stack/material/woolcloth)
		return
	if (istype(W,/obj/item/weapon/wrench))
		wrench_action(H)
		return
	if (istype(W,/obj/item/weapon/hammer))
		hammer_action(H, W, 150, list("/obj/item/stack/material/wood"), list(6))
		return
	..(W, H)

/obj/structure/loom/initialize()
	. = ..()
	finish_work()

/obj/structure/loom/after_load()
	. = ..()
	finish_work()

/obj/structure/loom/before_save()
	. = ..()
	finish_work()

////////////////////////////////////////////////////////////////////////
//  Mills  /////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
/obj/structure/mill
	name = "mill"
	desc = "A small mill, used to grind cereals into flour."
	icon = 'icons/obj/structures.dmi'
	icon_state = "flour_mill"
	anchored = TRUE
	density = FALSE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/tmp/obj/item/weapon/reagent_containers/current_work = null
	var/tmp/complete_percent = 0 //for manual mills
	var/tmp/list/workers_list = list() //mostly for team work possibility in manual mills
	var/tmp/list/workers_work = list()
	var/tmp/obj/item/weapon/reagent_containers/current_material = null

/obj/structure/mill/examine(mob/user, distance)
	..(user, distance)
	if (in_range(user, src) || isghost(user))
		if (current_material)
			var/msg = "<span class='notice'>There is [current_material.name] here and it's ground into [current_work.name]"
			if (istype(src, /obj/structure/mill/large))
				msg += ".</span>"
			else
				switch (complete_percent)
					if (0 to 24)	msg += " less than a quarter"
					if (25 to 33)	msg += " less than a third"
					if (34 to 45)	msg += " less than a half"
					if (46 to 54)	msg += " about a half"
					if (55 to 65)   msg += " more than a half"
					if (66 to 74)	msg += " more than a two thirds"
					if (75 to 85)	msg += " more than a three quarters"
					else			msg += " and need a bit of work to complete"
				msg += ".</span>"
			user << msg
		else
			user << "<span class='notice'>It's empty.</span>"
	else
		if (current_material)
			user << "<span class='notice'>Some grain are in.</span>"

/obj/structure/mill/proc/finish_work()
	if (current_work)
		if (istype(src, /obj/structure/mill/large))
			icon_state = "mill_large"
			visible_message("<span class='notice'>You can see how [src.name] finish grind [current_material.name] to [current_work.name]</span>",
				"<span class='notice'>The grinding sounds are gone.</span>")
		else
			icon_state = "flour_mill"
			visible_message("<span class='notice'>You can see how [english_list(workers_list, src.name)] finish grind [current_material.name] in [src.name] to [current_work.name]</span>",
				"<span class='notice'>The grinding sounds are gone.</span>")
			var/work_index = 1
			for(var/mob/living/human/H in workers_list)
				H.give_exp(list("strength", "stamina", "dexterity"), list(40, 40, 20), workers_work[work_index], TRUE, TRUE, 1, 0, 0, 0, 0)
				work_index += 1
		qdel(current_material)
		new current_work.type(src.loc) //deleting and creating for sterilization effect (we need really new object)
		qdel(current_work)
	current_work = null
	current_material = null
	complete_percent = 0
	workers_list.Cut()
	workers_work.Cut()

/obj/structure/mill/proc/produce(var/obj/item/weapon/reagent_containers/W, var/mob/living/human/H, var/obj/item/weapon/reagent_containers/P)
	if(!anchored)
		H << "<span class='warning'>\The [src] needs to be locked in place before anything can be ground.</span>"
		return
	if (!istype(src, /obj/structure/mill/large))
		if (H.stats["stamina"][1] < H.stats["stamina"][2]*0.1)
			H << "<span class='warning'>You must restore your stamina before mill on [src].</span>"
			return
		if (!H.in_mood())
			return
	if (current_work)
		if (istype(src, /obj/structure/mill/large))
			H << "<span class='warning'>\The [src.name] is busy, wait for [src.name] finish work.</span>"
			return
		if (workers_list.len == 0)
			H.visible_message(
				"<span class='notice'>You can see how [H.name] continue grind [current_work.name] in \the [src.name].</span>",
				"<span class='notice'>You continue produce \a [current_work.name].</span>",
				"<span class='notice'>You hear how someone starts to grind something in [src].</span>")
		else
			H.visible_message(
				"<span class='notice'>You can see how [H.name] started to help grind [current_work.name] in \the [src.name].</span>",
				"<span class='notice'>You started helping produce \a [current_work.name].</span>",
				"<span class='notice'>The grinding sounds became more frequent.</span>")
	else
		current_work = new P(null)
		current_material = W
		H.drop_item()
		W.loc = null
		H.visible_message(
			"<span class='notice'>You can see how [H.name] began to grind [current_work.name] [istype(src, /obj/structure/mill/large) ? "on" : "in"] \the [src.name].</span>",
			"<span class='notice'>You [istype(src, /obj/structure/mill/large) ? "put [current_work.name] to [src] for" : "start to"] produce \a [current_work.name].</span>",
			"<span class='notice'>You hear how someone starts to grind something in [src].</span>")
	if (istype(src, /obj/structure/mill/large))
		icon_state = "mill_large1"
		spawn(30+rand(1,30))
			finish_work()
	else
		var/total_work = 0
		workers_list += H
		workers_work += 0
		var/work_index = workers_work.len
		var/some_work_done = FALSE
		var/is_tired = FALSE
		var/is_mentally_tired = FALSE
		icon_state = "flour_mill1"
		while (complete_percent<100)
			if (H.stats["stamina"][1] < H.stats["stamina"][2]*0.1)
				some_work_done = TRUE
				is_tired = TRUE
				break
			if (!H.in_mood())
				some_work_done = TRUE
				is_mentally_tired = TRUE
				break
			if (do_after(H, 10, H.loc, TRUE, FALSE))
				complete_percent += 6*H.getStatCoeff("strength") + 6*H.getStatCoeff("stamina") + 3*H.getStatCoeff("dexterity")
				total_work += 10
				workers_work[work_index] = total_work
				H.stats["stamina"] -= STAMINA_LOSS_BASE_PER_DECISECOND_SDS_OF_WORK*10
				H.mood -= MOOD_LOSS_PER_DECISECOND_OF_PHYSICAL_WORK*10
			else
				some_work_done = TRUE
				break
		if (some_work_done)
			H.give_exp(list("strength", "stamina", "dexterity"), list(40, 40, 20), total_work, TRUE, TRUE, 1, 0, 0, 0, 0)
			workers_list.Cut(work_index, work_index+1)
			workers_work.Cut(work_index, work_index+1)
			var/reason = "stopped"
			if (is_mentally_tired) reason = "not in mood to"
			if (is_tired) reason = "tired to"
			if (workers_list.len == 0)
				icon_state = "flour_mill"
				H.visible_message(
					"<span class='notice'>You can see that [H.name] stops grinding [current_work.name] in [src.name].</span>",
					"<span class='notice'>You [reason] grind \a [current_work.name].</span>",
					"<span class='notice'>The grinding sounds are gone.</span>")
			else
				H.visible_message(
					"<span class='notice'>You can see that [H.name] stops helping to grind [current_work.name] in [src.name].</span>",
					"<span class='notice'>You [reason] helping grind \a [current_work.name].</span>",
					"<span class='notice'>The grinding sounds have become more rare.</span>")
		if (complete_percent>=100)
			finish_work()

/obj/structure/mill/attack_hand(mob/user)
	if (current_work) //continue or help to work
		produce(current_material, user, current_work)
		return
	..()

/obj/structure/mill/attackby(var/obj/item/W as obj, var/mob/living/human/H as mob)
	if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/wheat))
		produce(W, H, /obj/item/weapon/reagent_containers/food/condiment/flour)
		return
	if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/oat))
		produce(W, H, /obj/item/weapon/reagent_containers/food/condiment/flour/oatflour)
		return
	if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/barley))
		produce(W, H, /obj/item/weapon/reagent_containers/food/condiment/flour/barleyflour)
		return
	if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/rice))
		produce(W, H, /obj/item/weapon/reagent_containers/food/snacks/rice)
		return
	if (istype(W,/obj/item/weapon/wrench))
		wrench_action(H)
		return
	if (istype(W,/obj/item/weapon/hammer))
		hammer_action(H, W, 90, list("/obj/item/stack/material/wood"), list(3))
		return
	..(W, H)

/obj/structure/mill/large
	name = "mill"
	desc = "A millstone that is used to grind grain into flour."
	icon = 'icons/obj/structures.dmi'
	icon_state = "mill_large"
	flammable = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/mill/initialize()
	. = ..()
	finish_work()

/obj/structure/mill/after_load()
	. = ..()
	finish_work()

/obj/structure/mill/before_save()
	. = ..()
	finish_work()

////////////////////////////////////////////////////////////////////////
// Dehydrator //////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
// Accepts items with the dry_type path set, converting them to that path after the drying process is complete.
// Dehydrator have 3x4 size, or 3 collums on 4 rows.
// By default dry_size=2 - this means that the item will take up two slots from left to right in the first empty space on the dehydrator.
// With dry_size values of 1, 2 and 3, an item will take up the corresponding number of slots. For dry_size=4 only turned position will be used, better use dry_size=13 (see below).
// Values of +4 will occupy two rows, for example 6 will occupy 2 slots of 2 rows (2x2); 5: 1x2; 6: 2x2; 7: 3x2; 8 will fit only rotated 2x4, better use dry_size=14 (see below).
// Values +8 will occupy three rows, and +12 all four rows. 9: 1x3; 10: 2x3; 11: 3x3; 12 - will fit only rotated, better use dry_size=15 (see below).
// Values +12 will occipy all four rows 13: 1x4; 14: 2x4; 15: 3x4 (full dehydrator); dry_size>15 will never fit to dehydrator.
// Alghorithm will try to rotate item if not empty space are found. For example 1x3 item (dry_size=9) not found a place, but dehydrator have free row, and item will placed 3x1 (as dry_size=3).
// ====================================================================
// Items must have an icon in 'icons/obj/food/dryer.dmi' named the same as icon_state of drying product
// Items must have an icon in 'icons/obj/food/dryer.dmi' named as icon_state of drying product with additional "R" at end. For exapmle "rawcutletR"
// Product (dried and ready) items must have an icons with normal and rotated states in 'icons/obj/food/dryer.dmi'
// Items with size of 4 rows (dry_size=13..15) or equal side sizes (1x1, 2x2, 3x3) may not have an icon with additional "R".
// For optimization try don't use dry_size 4, 8 and 12. Use instead 13, 14 and 15. Also, this will save you from having to draw two icons: straight and rotated; it will be enough to draw only one straight icon.
// If dehydrator will be dismantled or destroyed all items are dryed will be drop at place, where dehydrator was.
// Ready dried products may have another dry_type (for example, a half-dried item as the dry_type of a fresh item may have a fully dried item as the dry_type)
// ====================================================================
// TO DO: Add dry_transform() procedure, which will replace the old mechanics of items with the mechanics of changing reagents in dried items.
/obj/structure/dehydrator
	name = "dehydrator"
	desc = "A wood structure used to dry meat, fish, tobacco, and so on."
	icon = 'icons/obj/food/dryer.dmi'
	icon_state = "empty"
	anchored = TRUE
	density = TRUE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/tmp/slots[4][3] //[row][slot in row] - food/snacks item list which dries
	var/tmp/obj/item/weapon/storage/internal/storage //storage for dryed raw items (for algorithm purpose)
	var/tmp/current_process_id = "" //for control of only one process at time to one dehydrator

/obj/structure/dehydrator/update_icon()
	var/icon/I = new('icons/obj/food/dryer.dmi')
	for (var/L in overlays)
		overlays -= L
	icon_state = "empty"
	for (var/R=1,R<5,R++)
		for (var/P=1,P<4,P++)
			if (slots[R][P])
				if (!findtext(slots[R][P],"busy"))
					overlays += image(I, src, "[slots[R][P].icon_state][!!findtext(slots[R][P].name,"_ROTATED_") ? "R" : ""]", OBJ_LAYER+0.1, NORTH, 4+5*P, 1-6*R)

/obj/structure/dehydrator/proc/split_size(from_int, is_rotated = FALSE)
	var/rows = from_int % 4
	if (rows==0)
		rows = 4
	var/columns = round((from_int - rows) / 4) + 1
	if (is_rotated)
		return list(columns, rows)
	return list(rows, columns)

/obj/structure/dehydrator/proc/put_in_place(var/obj/item/W, var/list/pos = list(1, 1), var/list/sizeHV = list(1, 1), is_rotated = FALSE, init = FALSE)
	if (!init)
		if (istype(W, /obj/item/weapon/reagent_containers/food))
			var/obj/item/weapon/reagent_containers/food/D = W
			D.name = "[D.name]ON_DEHYDRATOR[is_rotated ? "_ROTATED_" : "_STRAIGHT_"]DECAY_[num2text(D.decay, 8, 10)]POS_[num2text(pos[1]+(pos[2]-1)*4, 1, 16)]TIMER_00000000"
			D.decay = 0 //stop decaying when on dehydrator
		else
			W.name = "[W.name]ON_DEHYDRATOR[is_rotated ? "_ROTATED_" : "_STRAIGHT_"]DECAY_[num2text(0, 8, 10)]POS_[num2text(pos[1]+(pos[2]-1)*4, 1, 16)]TIMER_00000000"
	slots[pos[1]][pos[2]] = W
	storage.handle_item_insertion(W, TRUE) //put to storage for preparing to destroy, or for map save when it happens
	for (var/P=0, P<sizeHV[1], P++)
		for (var/R=0, R<sizeHV[2], R++)
			if (P==0)
				if (R==0)
					continue
			slots[pos[1]+R][pos[2]+P] = "busy"+num2text(pos[1],1)+num2text(pos[2],1)
	update_icon()

/obj/structure/dehydrator/proc/clean_by(slot_row, slot_pos)
	for (var/R=1, R<5, R++)
		for (var/P=1, P<4, P++)
			if (slots[R][P] == "busy"+num2text(slot_row,1)+num2text(slot_pos,1))
				slots[R][P] = null
	slots[slot_row][slot_pos] = null

/obj/structure/dehydrator/proc/clean_from(slot_row, slot_pos)
	var/list/sizeHV = split_size(slots[slot_row][slot_pos].dry_size, !!findtext(slots[slot_row][slot_pos].name, "_ROTATED_"))
	for (var/W=0, W<sizeHV[1], W++)
		for (var/H=0, H<sizeHV[2], H++)
			slots[slot_row+H][slot_pos+W] = null

/obj/structure/dehydrator/proc/hang_on(var/obj/item/D, var/list/sizeHV = list())
	var/is_rotated = TRUE
	var/place_found = FALSE
	if (sizeHV.len == 0)
		sizeHV = split_size(D.dry_size)
		is_rotated = FALSE //first call, not rotated
	for (var/R=1, R<5, R++)
		if (place_found)
			break
		for (var/P=1, P<4, P++)
			if (slots[R][P]==null)
				place_found = TRUE
				for (var/W=0, W<sizeHV[1], W++)
					if (P+W>3)
						place_found = FALSE
						break
					if (!place_found)
						break
					for (var/H=0, H<sizeHV[2], H++)
						if (W==0)
							if (H==0)
								continue
						if (R+H>4)
							place_found = FALSE
							break
						if (slots[R+H][P+W])
							place_found = FALSE
							break
				if (place_found)
					if (!istype(D, /obj/item/stack) || D.amount == 1)
						put_in_place(D, list(R, P), sizeHV, is_rotated)
					else
						var/obj/item/stack/S0 = D
						var/obj/item/stack/S1 =	S0.split(1)
						put_in_place(S1, list(R, P), sizeHV, is_rotated)
					break
	if (place_found)
		return TRUE
	else
		if (is_rotated)
			return FALSE
		else
			sizeHV.Swap(1, 2)
			return hang_on(D, sizeHV) //trying to hang this item rotated

/obj/structure/dehydrator/proc/dry_as_text(var/obj/item/I)
	switch(get_dry_timer(I)/TIME_TO_DRY)
		if (0 to 0.15) return "not dried"
		if (0.15 to 0.4) return "a quarter dry"
		if (0.4 to 0.6) return "half dried"
		if (0.6 to 0.85) return "three quarters dry"
		if (1 to INFINITY)
			if (!findtext(normal_item_name(I),"dried"))
				if (!findtext(normal_item_name(I),"dry")) //two if for optimization purpose
					return "dried"
			else
				return ""
		else return "almost dry"

/obj/structure/dehydrator/examine(mob/user, distance)
	..(user, distance)
	var/list/dryed_now = list()
	var/additional_info = in_range(user, src) || isghost(user)
	if (storage.contents.len>0)
		for(var/obj/item/I in storage.contents)
			dryed_now += "[additional_info ? "[dry_as_text(I)] " : ""][normal_item_name(I)]"
		user << "<span class='notice'>There [storage.contents.len == 1 ? "is dries" : "are drying"] [english_list(dryed_now, "")].</span>"

/obj/structure/dehydrator/proc/normal_item_name(var/obj/item/I)
	return copytext(I.name, 1, findtext(I.name, "ON_DEHYDRATOR"))

/obj/structure/dehydrator/proc/get_dry_timer(var/obj/item/I)
	return text2num(copytext(I.name, findtext(I.name,"TIMER_")+6, findtext(I.name,"TIMER_")+14))

/obj/structure/dehydrator/proc/set_dry_timer(var/obj/item/I, new_timer)
	I.name = splicetext(I.name, findtext(I.name,"TIMER_")+6, findtext(I.name,"TIMER_")+14, num2text(new_timer, 8, 10))

/obj/structure/dehydrator/attackby(var/obj/item/W, var/mob/living/human/H as mob, icon_x, icon_y)
	if (istype(W, /obj/item/weapon/wrench))
		if (H)
			wrench_action(H)
			return TRUE
	if (istype(W, /obj/item/weapon/hammer))
		if (H)
			hammer_action(H, W, 110, list("/obj/item/stack/material/wood"), list(4))
			return TRUE
	if (!W.dried_type)
		if (H)
			H << "<span class='warning'>\The [W.name] is not for drying.</span>"
		return TRUE//This can't be dryed
	if (!W.dry_size)
		return TRUE//ERROR
	if (istype(W, /obj/item/weapon/reagent_containers/food))
		var/obj/item/weapon/reagent_containers/food/D = W
		if (D.rotten)
			if (H)
				H << "<span class='warning'>\The [W.name] is rotten.</span>"
			return TRUE
	if (W.dry_size>15)
		if (H)
			H << "<span class='warning'>\The [W.name] not fit here!</span>"
		return TRUE
	if (!hang_on(W))
		if (H)
			H << "<span class='warning'>Not enough room for one more [W.name]!</span>"
		return TRUE
	if (H)
		H.visible_message(
			"<span class='notice'>You can see how [H.name] hang \a [normal_item_name(W)] to dry.</span>",
			"<span class='notice'>You hang \a [normal_item_name(W)] to dry.")
		return TRUE
	..(W, H, icon_x, icon_y)

/obj/structure/dehydrator/attack_hand(mob/H, icon_x, icon_y)
	var/obj/item/S = take_product_by_x_y(icon_x, icon_y, H)
	if (S)
		if (!H.put_in_any_hand_if_possible(S, FALSE, TRUE, TRUE, TRUE))
			H.drop_item(S)
		H.visible_message(
			"<span class='notice'>You can see how [H.name] removes \a [S.name] from \the [src].</span>",
			"<span class='notice'>You remove \a [S.name] from \the [src].")
	return TRUE

/obj/structure/dehydrator/proc/dry_process(var/this_process = null)
	var/list/pos
	var/obj/item/P
	var/obj/item/I
	var/dry_timer
	var/list/sizeHV
	var/is_rotated
	if (!isturf(src.loc)) //if dehydrator location is gone, or dehydrator is gone, process must die
		return
	if (this_process==null) //initial call
		this_process = current_process_id
	if (this_process<>current_process_id) //only one process for one dehydrator and this process must die
		return
	spawn(150) //one tick at 15 seconds will be enough
		if (!storage) //storage remove, dehydrator dismantled, process must die
			return
		if (storage.contents.len>0)
			for (I in storage.contents)
				if (I.dried_type)
					dry_timer = get_dry_timer(I)
					dry_timer += 150
					set_dry_timer(I, dry_timer)
					if (dry_timer >= TIME_TO_DRY)
						pos = split_size(text2num(copytext(I.name, findtext(I.name,"POS_")+4, findtext(I.name,"POS_")+5), 16))
						P = new I.dried_type(null)
						is_rotated = !!findtext(slots[pos[1]][pos[2]].name, "_ROTATED_")
						sizeHV = split_size(slots[pos[1]][pos[2]].dry_size, is_rotated)
						put_in_place(P, pos, sizeHV, is_rotated)
						if (!P.dried_type)
							set_dry_timer(P, TIME_TO_DRY+1)
						qdel(I)
						P.visible_message("[normal_item_name(P)] finishes drying.")
						update_icon()
		dry_process(this_process)

/obj/structure/dehydrator/proc/take_product_by_x_y(icon_x, icon_y, new_location)
	var/row = max(1,min(5-ceil((icon_y-3)/6),4))
	var/pos = max(1,min(ceil((icon_x-8)/5),3))
	var/real_row
	var/real_pos
	var/obj/item/S
	if (slots[row][pos] == null)
		return FALSE //no items here
	if (findtext(slots[row][pos],"busy")) //drying object is in another slot
		real_row = text2num(copytext(slots[row][pos],5,6))
		real_pos = text2num(copytext(slots[row][pos],6,7))
	else
		real_row = row
		real_pos = pos
	S = remove_from_dehydrator(real_row, real_pos, new_location)
	clean_by(real_row, real_pos)
	update_icon()
	return S

/obj/structure/dehydrator/bullet_act(var/obj/item/projectile/P, def_zone)
	var/shoot_x = rand(1,32)
	var/shoot_y = rand(1,32)
	var/obj/item/S
	if (shoot_x>6 && shoot_x<26)
		if (shoot_y>3 && shoot_y<30) //in hitbox
			if (shoot_x==7 || shoot_x==8 || shoot_x==24 || shoot_x==25)
				return ..(P, def_zone) //hit to dehydrator vertical frame
			if (shoot_y==4 || shoot_y==5 || shoot_y==10 || shoot_y==11 || shoot_y==16 || shoot_y==17 || shoot_y==22 || shoot_y==23 || shoot_y==28 || shoot_y==29)
				return ..(P, def_zone) //hit to dehydrator horizontal frame
			//shoot throw slots, checking
			S = take_product_by_x_y(shoot_x, shoot_y)
			if (S)
				S.visible_message("<span class = 'warning'>\The [S.name] gets pierced!</span>")
				P.do_bullet_act(S, def_zone) //bullet hit to product
				return FALSE
			else
				return PROJECTILE_CONTINUE //miss
	else if (shoot_y==3)
		if ((shoot_x>5 && shoot_x<9) || (shoot_x>23 && shoot_x<27))
			return ..(P, def_zone) //hit to dehydrator leg
	else if (shoot_y==2)
		if ((shoot_x>4 && shoot_x<7) || (shoot_x>25 && shoot_x<28))
			return ..(P, def_zone) //hit to dehydrator leg
	return PROJECTILE_CONTINUE //miss

/obj/structure/dehydrator/proc/clean_drop_slots() //Drop all items out without changing names, they will be restored on reinit()
	for (var/R=1, R<5, R++)
		for (var/P=1, P<4, P++)
			if (slots[R][P]<>null)
				if (!findtext(slots[R][P],"busy"))
					storage.remove_from_storage(slots[R][P])
				slots[R][P] = null

/obj/structure/dehydrator/proc/refill()
	var/is_rotated
	var/obj/item/weapon/reagent_containers/food/snacks/S
	var/T
	var/list/pos
	var/list/sizeHV
	clean_drop_slots()
	//place temporary dropped or saved items back in place
	for (S in src.loc)
		if (findtext(S.name, "ON_DEHYDRATOR"))
			is_rotated = !!findtext(S.name, "_ROTATED_")
			T = findtext(S.name,"POS_") + 4
			T = text2num(copytext(S.name, T, T+1), 16)
			pos = split_size(T)
			sizeHV = split_size(S.dry_size, is_rotated)
			put_in_place(S, pos, sizeHV, is_rotated, TRUE)
	for (S in src.loc) //On second pass we try to hang food/snacks items in location (from mapping)
		attackby(S, null)

/obj/structure/dehydrator/proc/reinit()
	spawn(rand(5,15)) //To prevent too much load when starting the server and to slightly spread the processes of dehydrators loaded from the map in time.
		refill()
		current_process_id = "[time2text(world.realtime,"DDhhmmss")]-[num2text(rand(1,99999),5,10)]" //New value will kill old process on next Call
		dry_process()

/obj/structure/dehydrator/New()
	. = ..()
	storage = new/obj/item/weapon/storage/internal(src)
	storage.storage_slots = 12 //enough
	storage.max_storage_space = 120000 //may be enough
	spawn(rand(5,15))
		reinit()

/obj/structure/dehydrator/proc/remove_from_dehydrator(row, pos, new_location)
	var/obj/item/S
	var/T
	S = slots[row][pos]
	storage.remove_from_storage(S, new_location) //placing item from dehydrator storage to turf or into user
	if (istype(S, /obj/item/weapon/reagent_containers/food))
		var/obj/item/weapon/reagent_containers/food/D = S
		T = findtext(S.name,"DECAY_") + 6
		D.decay = text2num(copytext(S.name, T, T+8)) //restoring decay value
		spawn(600+rand(1, 50)) //in order not to create a duplicate process, we wait until the old process dies
			if (D)
				D.food_decay() //restarting decay process
	S.name = normal_item_name(S)
	return S

/obj/structure/dehydrator/Destroy()
	current_process_id = "" //To kill process
	for (var/R=1, R<5, R++)
		for (var/P=1, P<4, P++)
			if (slots[R][P]<>null)
				if (!findtext(slots[R][P],"busy"))
					remove_from_dehydrator(R, P, src.loc)
	qdel(storage)
	storage = null
	..()

/obj/structure/dehydrator/initialize() //on new map start from .dmm
	spawn(50+rand(50,100))
		if(current_process_id=="") // for preventing double initialisation from new() and set autoinit
			reinit()
	. = ..()

/obj/structure/dehydrator/after_load() //after load from map save
	current_process_id = "" //because save algorithm may save this var, or load algorithm may leave old process
	spawn(50+rand(50,100))
		reinit()
	..()

/obj/structure/dehydrator/before_save() //before save to map
	//Don't know which algorithm will be used, but we have reinit() and may safely drop all items to ground without changes
	clean_drop_slots()
	..()

////////////////////////////////////////////////////////////////////////
//  Fermentation jar  //////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
// TO DO TODO: Rework this vague mechanism into a chemical reaction, and remake the jar itself into reagents_container like a large beaker, but with much less accurate transfer amounts
// At this time it's infinity yeast generator... o_O ... yes.
/obj/item/weapon/starterjar
	name = "fermentation starter jar"
	icon = 'icons/obj/drinks.dmi'
	desc = "A glass jar, used to multiply yeast."
	icon_state = "jar0"
	item_state = "beaker"
	var/fermenting = 0
	var/fermenting_timer = 0
	var/fermenting_contents = 0
	flags = FALSE

/obj/item/weapon/starterjar/attackby(obj/O as obj, mob/living/human/user as mob)
	if (fermenting != 0)
		user << "<span class='warning'>This jar already has a starter culture inside!</span>"
		return
	if (istype(O, /obj/item/weapon/reagent_containers/food/condiment/flour))
		user.visible_message("<span class='notice'>[user.name] adds some flour to the jar.</span>",
			"<span class='notice'>You add [O.name] to the jar.</span>")
		fermenting = 1
		icon_state = "jarF"
		fermenting_timer = world.time + 1600 + rand(0,200)
		qdel(O)
		fermenting_process()
		return
	if (istype(O, /obj/item/weapon/reagent_containers/food/snacks/grown/wheat) || istype(O, /obj/item/weapon/reagent_containers/food/snacks/grown/oat) || istype(O, /obj/item/weapon/reagent_containers/food/snacks/grown/rice) || istype(O, /obj/item/weapon/reagent_containers/food/snacks/grown/barley))
		user.visible_message("<span class='notice'>[user.name] adds some grain to the jar.</span>",
			"<span class='notice'>You add [O.name] to the jar.</span>")
		fermenting = 1
		icon_state = "jarG"
		fermenting_timer = world.time + 1000 + rand(0,1400) //wild yeast have more variety
		qdel(O)
		fermenting_process()
		return
	else if (istype(O, /obj/item/weapon/reagent_containers/food/condiment/enzyme))
		user.visible_message("<span class='notice'>[user.name] adds [O.name] to the jar.</span>",
			"<span class='notice'>You add [O.name] to the jar.</span>")
		fermenting = 2
		fermenting_contents++
		icon_state = "jar1"
		qdel(O)
		yeast_growth()
		return
	else if (istype(O,/obj/item/weapon/hammer) || istype(O,/obj/item/weapon/hammer/modern))
		playsound(loc, 'sound/weapons/smash.ogg', 75, 1)
		user << "<span class='notice'>You begin smashing apart \the [src].</span>"
		if (do_after(user, 25, src))
			user << "<span class='notice'>You smash apart \the [src].</span>"
			new /obj/item/weapon/material/shard/glass(loc)
			qdel(src)
	else
		..()

/obj/item/weapon/starterjar/proc/fermenting_process()
	if (world.time>=fermenting_timer)
		visible_message("The flour in the jar ferments.")
		fermenting = 2
		fermenting_contents = 1
		icon_state = "jar1"
		yeast_growth()
	else
		spawn(100)
			fermenting_process()

/obj/item/weapon/starterjar/proc/yeast_growth()
	//Yeah there is a bug, form abuse load/unload yeast that may produce +4 fermenting_contents at time, BUT enzymes not essentials at this moment
	//	and it will fixed, when working on TO DO part (look at the begining of starterjar TODO)
	if (fermenting_contents>0)
		spawn(1500+rand(0,400))
			if (fermenting_contents > 0 && fermenting_contents < 5)
				fermenting_contents++
				icon_state = "jar[fermenting_contents]"
			yeast_growth()

/obj/item/weapon/starterjar/attack_self(var/mob/living/human/user as mob)
	if (fermenting==2 && fermenting_contents>0)
		user << "You take some yeast out of the jar."
		var/obj/item/weapon/reagent_containers/food/condiment/enzyme/Y = new/obj/item/weapon/reagent_containers/food/condiment/enzyme(null)
		if (!user.put_in_any_hand_if_possible(Y))
			Y.loc = usr.loc
		fermenting_contents--
		icon_state = "jar[fermenting_contents]"
		if (fermenting_contents==0)
			fermenting = 0
	else
		..()

/obj/item/weapon/starterjar/proc/restore_from_icon_state()
	if (fermenting==0 && icon_state<>"jar0")
		switch(icon_state)
			if ("jarF")
				fermenting = 1
				fermenting_timer = world.time + 900 // 1/2 of normal, because not so important
				fermenting_process()
			if ("jarG")
				fermenting = 1
				fermenting_timer = world.time + 1200 // 1/2 of normal, because not so important
				fermenting_process()
			else
				fermenting = 2
				fermenting_contents = text2num(copytext(icon_state,4,5))
				yeast_growth()

/obj/item/weapon/starterjar/initialize()
	. = ..()
	restore_from_icon_state()

/obj/item/weapon/starterjar/after_load()
	. = ..()
	restore_from_icon_state()

////////////////////////////////////////////////////////////////////////
//  Seed collector  ////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
// TO DO TODO: If seeds genetics will be implemented, then seeds collector MUST be reworked as production collector
// TO DO TODO: save-load mechanics MUST be in storage.dm - check it and fix it if needs.
/obj/item/weapon/storage/seed_collector
	name = "seed collector"
	icon = 'icons/obj/storage.dmi'
	desc = "To store your seeds."
	icon_state = "seed_collector"
	item_state = "backpack"
	w_class = ITEM_SIZE_LARGE
	flags = FALSE
	slot_flags = SLOT_BACK
	max_storage_space = 50000 //we don't worry that, yes, all calculated by slots
	storage_slots = 21 //we need stop the mess of seeds in one bag
	can_hold = list(/obj/item/stack/farming/seeds)
	flammable = TRUE

/obj/item/weapon/storage/seed_collector/attack_self(var/mob/living/human/user as mob, var/target_loc = null)
	if (src == target_loc)
		return FALSE
	var/collected
	var/some_not_collected = FALSE
	var/some_collected = FALSE
	if (!target_loc)
		target_loc = user.loc
	for (var/obj/item/stack/farming/seeds/G in target_loc)
		collected = FALSE
		for (var/obj/item/stack/farming/seeds/S in contents)
			if (S.type==G.type)
				if (S.amount+G.amount<=S.max_amount)
					S.amount += G.amount
					S.update_icon()
					user << "<span class='notice'>You put \the [S.name] into [src][S.amount==S.max_amount ? " to full stack" : ""].</span>"
					qdel(G)
					collected = TRUE
					some_collected = TRUE
					break
				else if (S.amount < S.max_amount)
					G.amount -= S.max_amount - S.amount
					S.amount = S.max_amount
					some_collected = TRUE
					user << "<span class='notice'>You put \the [S.name] into [src] to full stack.</span>"
		if (!collected)
			if (can_be_inserted(G, TRUE))
				user << "<span class='notice'>You put \the [G.name] into [src], starting new stack[G.amount==G.max_amount ? " to full stack" : ""].</span>"
				handle_item_insertion(G,TRUE)
				some_collected = TRUE
			else
				some_not_collected = TRUE
	if (some_not_collected)
		user << "<span class='warning'>Some seeds not fit into [src], make some space.</span>"
	if (src == user.s_active)
		orient2hud(user)
	return some_collected || some_not_collected

/obj/item/weapon/storage/seed_collector/afterattack(atom/target, mob/user, proximity_flag, params)
	if (proximity_flag)
		if (user.a_intent <> I_HARM)
			var/to_loc = target.loc
			if (isturf(target))
				to_loc = target
			if (!attack_self(user, to_loc))
				return
	..(target, user, proximity_flag, params)

/obj/item/stack/farming/seeds/AltClick(mob/living/user)
	..(user)
	if (istype(src.loc, /obj/item/weapon/storage/seed_collector))
		var/obj/item/weapon/storage/seed_collector/L = src.loc
		L.orient2hud(user)

/obj/item/weapon/storage/seed_collector/slot_orient_objs(rows, cols, list/obj/item/display_contents, Xcord, Ycord)
	..()
	for (var/obj/item/stack/farming/seeds/S in contents)
		S.maptext = "<font style='text-color: white; font-size: 8pt; font-family: sans-serif; -dm-text-outline: 1px black; vertical-align: top; text-align: right'>[S.amount]</font><br>"
		S.maptext += "<font style='text-color: white; font-size: 6pt; font-family: arial narrow; -dm-text-outline: 1px black; vertical-align: bottom; text-align: center'>[S.plant]</font><br>"

////////////////////////////////////////////////////////////////////////
//  Ore collector  /////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
// TO DO TODO: save-load mechanics MUST be in storage.dm - check it and fix it if needs.
// TO DO TODO: Maybe need dirt collector, cotton collector and so on? What about other raw materials collectors? But: think for balance before.
/obj/item/weapon/storage/ore_collector
	name = "ore collector"
	icon = 'icons/obj/storage.dmi'
	desc = "A leather bag, used to collect ores and raw stones."
	icon_state = "ore_collector"
	item_state = "backpack"
	w_class = ITEM_SIZE_LARGE
	slot_flags = SLOT_BACK
	max_storage_space = 50000 //we don't worry that, yes, all calculated by slots
	storage_slots = 7 //we need stop the mess of ores in one bag
	can_hold = list(
		/obj/item/stack/ore,
		/obj/item/stack/material/stone,
		/obj/item/stack/material/sandstone,
		/obj/item/stack/material/obsidian,
		/obj/item/stack/material/marble
	)
	flammable = TRUE

/obj/item/weapon/storage/ore_collector/attack_self(var/mob/living/human/user as mob, var/target_loc = null)
	if (src == target_loc)
		return FALSE
	var/collected
	var/some_not_collected = FALSE
	var/some_collected = FALSE
	var/list/not_collected = list()
	if (!target_loc)
		target_loc = user.loc
	for (var/obj/item/stack/G in target_loc)
		if (!is_type_in_list(G, can_hold))
			continue
		collected = FALSE
		for (var/obj/item/stack/S in contents)
			if (S.type==G.type)
				if (S.amount+G.amount<=S.max_amount)
					S.amount += G.amount
					S.update_icon()
					user << "<span class='notice'>You put \the [S.name] into [src][S.amount==S.max_amount ? " to full stack" : ""].</span>"
					qdel(G)
					collected = TRUE
					some_collected = TRUE
					break
				else if (S.amount < S.max_amount)
					G.amount -= S.max_amount - S.amount
					S.amount = S.max_amount
					some_collected = TRUE
					user << "<span class='notice'>You put \the [S.name] into [src] to full stack.</span>"
		if (!collected)
			if (can_be_inserted(G, TRUE))
				user << "<span class='notice'>You put \the [G.name] into [src], starting new stack[G.amount==G.max_amount ? " to full stack" : ""].</span>"
				handle_item_insertion(G,TRUE)
				some_collected = TRUE
			else
				some_not_collected = TRUE
				if (istype(G, /obj/item/stack/ore))
					if (!("ore" in not_collected))
						not_collected += "ore"
				else
					if (!("stone" in not_collected))
						not_collected += "stone"
	if (some_not_collected)
		user << "<span class='warning'>Some [english_list(not_collected)] not fit into [src], make some space.</span>"
	if (src == user.s_active)
		orient2hud(user)
	return some_collected || some_not_collected

/obj/item/weapon/storage/ore_collector/afterattack(atom/target, mob/user, proximity_flag, params)
	if (proximity_flag)
		if (user.a_intent <> I_HARM)
			var/to_loc = target.loc
			if (isturf(target))
				to_loc = target
			if (!attack_self(user, to_loc))
				return
	..(target, user, proximity_flag, params)

/obj/item/stack/AltClick(mob/living/user)
	..(user)
	if (istype(src.loc, /obj/item/weapon/storage/ore_collector))
		var/obj/item/weapon/storage/ore_collector/L = src.loc
		L.orient2hud(user)

/obj/item/weapon/storage/ore_collector/slot_orient_objs(rows, cols, list/obj/item/display_contents, Xcord, Ycord)
	..()
	for (var/obj/item/stack/S in contents)
		var/short_name = lowertext(S.name)
		if (short_name == "mineral coal")
			short_name = "coal"
		else if (short_name == "pig iron")
			short_name = "pig iron"
		else if (findtext(short_name," "))
			short_name = copytext(short_name,1,findtext(short_name," "))
		S.maptext = "<font style='text-color: white; font-size: 8pt; font-family: sans-serif; -dm-text-outline: 1px black; vertical-align: top; text-align: right'>[S.amount]</font><br>"
		S.maptext += "<font style='text-color: white; font-size: 6pt; font-family: arial narrow; -dm-text-outline: 1px black; vertical-align: bottom; text-align: center'>[short_name]</font><br>"

////////////////////////////////////////////////////////////////////////
//  Produce basket (produce collector)  ////////////////////////////////
////////////////////////////////////////////////////////////////////////
/obj/item/weapon/storage/produce_basket
	name = "produce basket"
	icon = 'icons/obj/storage.dmi'
	desc = "A woven basket, used to collect fruits and vegetables."
	icon_state = "produce_basket"
	item_state = "produce_basket"
	w_class = ITEM_SIZE_LARGE
	flags = FALSE
	max_w_class = 3
	max_storage_space = 30
	storage_slots = 30
	display_contents_with_number = TRUE //visually stack unstackable!
	can_hold = list(/obj/item/weapon/reagent_containers/food/snacks/grown)
	flammable = TRUE
	var/tmp/next_usage = 0 //for prevent spam clicks

/obj/item/weapon/storage/produce_basket/attack_self(var/mob/living/human/user as mob, var/target_loc = null, var/obj/item/weapon/storage/from_storage=null)
	if (src == target_loc)
		return FALSE
	var/some_items = FALSE
	if (!target_loc)
		target_loc = user.loc
	for (var/obj/item/weapon/reagent_containers/food/snacks/grown/G in target_loc)
		some_items = TRUE
		if (can_be_inserted(G))
			if (from_storage)
				from_storage.remove_from_storage(G)
			handle_item_insertion(G)
	return some_items

/obj/item/weapon/storage/produce_basket/afterattack(atom/target, mob/user, proximity_flag, params)
	if (world.timeofday>next_usage)
		next_usage = world.timeofday + 10
		if (proximity_flag)
			if (user.a_intent <> I_HARM)
				var/to_loc = target.loc
				var/obj/item/weapon/storage/to_storage = null
				if (isturf(target))
					to_loc = target
				if (istype(target, /obj/item/weapon/storage))
					to_storage = target
					to_loc = target.contents
				if (!attack_self(user, to_loc, to_storage))
					//no items here? try unloading!
					var/some_items = FALSE
					for (var/obj/item/weapon/reagent_containers/food/snacks/grown/G in contents)
						some_items = TRUE
						if (to_storage)
							if (to_storage.can_be_inserted(G))
								remove_from_storage(G)
								to_storage.handle_item_insertion(G)
							else
								break
						else
							remove_from_storage(G, to_loc)
					if (some_items)	//items was unloaded
						if (to_storage)
							to_storage.update_icon()
						if (src.loc <> user) //returning back in hand!
							user.put_in_active_hand(src)
						return
				else //after loading items
					if (to_storage)
						to_storage.update_icon()
					if (src.loc <> user) //returning back in hand!
						user.put_in_active_hand(src)
					return
	..(target, user, proximity_flag, params)

////////////////////////////////////////////////////////////////////////
//  Oil well  //////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
//TO DO TODO: Add examine proc
//TO DO TODO: Some kind of mechanical energy must be needed to work.
//TO DO TODO: Check /obj/structure/oil_spring in code... it's need to be cleaned! BTW, all oil_fires.dm must be cleaned
//TO DO TODO: Make petroleum production more realistic.... maybe, or not
//TO DO TODO: Clean fuckups in oil_fires.dm
//TO DO TODO: Make different types of blood/oil (look at glass.dm)
//TO DO TODO: Clean fuckups with item/flashlight
/obj/structure/oilwell
	name = "wooden oil well"
	desc = "An oil well, extracting petroleum to a barrel."
	icon = 'icons/obj/obj32x64.dmi'
	icon_state = "oilwell"
	anchored = TRUE
	density = TRUE
	flammable = TRUE
	var/tmp/obj/structure/oil_spring/base = null
	var/tmp/obj/item/weapon/reagent_containers/glass/barrel/work_barrel = null
	var/tmp/extracting_now = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE

/obj/structure/oilwell/New()
	. = ..()
	link_to_spring()

/obj/structure/oilwell/proc/link_to_spring()
	for (var/obj/structure/oil_spring/OS in src.loc)
		base = OS
		break
	if (!work_barrel)
		load_barrel()
	start_extraction()

/obj/structure/oilwell/proc/start_extraction()
	if (base)
		if (!extracting_now)
			extract()

/obj/structure/oilwell/proc/extract()
	extracting_now = TRUE
	var/need_extract
	spawn(1200)
		need_extract = FALSE
		if (work_barrel)
			if (work_barrel.reagents.total_volume < work_barrel.reagents.maximum_volume)
				if (base.counter>0)
					work_barrel.reagents.add_reagent("petroleum", min(work_barrel.reagents.get_free_space(), 10))
					base.counter --
					need_extract = TRUE
					if (work_barrel.reagents.total_volume == work_barrel.reagents.maximum_volume)
						visible_message("<span class='notice'>\The [work_barrel] in \the [src] filled up.</span>")
						need_extract = FALSE
		if (base.counter<1)
			need_extract = TRUE //need to be sure, that spring will refiled
			if (base.timeout<world.time) //if no sheduled refill() we call it
				base.timeout = world.time + 600 //give default timeout
				base.refill()
		if (need_extract)
			extract()
		else
			extracting_now = FALSE

/obj/structure/oilwell/proc/load_barrel()
	for (var/obj/item/weapon/reagent_containers/glass/barrel/B in src.loc)
		if (B.reagents.total_volume<B.reagents.maximum_volume)
			work_barrel = B
			B.loc = null
			start_extraction()
			break

/obj/structure/oilwell/proc/unload_barrel()
	work_barrel.loc = src.loc
	work_barrel = null

/obj/structure/oilwell/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/reagent_containers/glass/barrel))
		if (!work_barrel)
			if (do_after(user, 35, src))
				user.drop_item(src.loc)
				user.visible_message("<span class='notice'>[user] puts \the [W] in \the [src].</span>",
					"<span class='notice'>You put \the [W] in \the [src].</span>")
				load_barrel()
		else
			user << "<span class='warning'>There is already a connected [work_barrel].</span>"
		return
	if (istype(W,/obj/item/weapon/hammer))
		hammer_action(user, W, 270, list("/obj/item/stack/material/wood"), list(30))
		return
	..(W, user)

/obj/structure/oilwell/attack_hand(var/mob/living/human/H)
	if (work_barrel)
		H << "You start taking \the barrel from \the [src]..."
		if (do_after(H, 35, src))
			H.visible_message("<span class='notice'>[H] removes \the [work_barrel] from \the [src].</span>",
				"<span class='notice'>You remove \the [work_barrel] from \the [src].</span>",)
			unload_barrel()
	else
		H << "There is no container to remove from \the [src]."

/obj/structure/oilwell/Destroy()
	unload_barrel()
	. = ..()

/obj/structure/oilwell/initialize()
	. = ..()
	link_to_spring()

/obj/structure/oilwell/before_save()
	. = ..()
	unload_barrel()

/obj/structure/oilwell/after_load()
	. = ..()
	link_to_spring()

////////////////////////////////////////////////////////////////////////
//  Printing press  ////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
//TO DO TODO: FIX books at maps!
//TO DO TODO: Fix Chemistry-Reagents-Compounds.dm for compound reactions to books
//TO DO TODO: Fix books recipes. Book is book! Why is 15 wood for book? It's a house? WALL?
//TO DO TODO: Split research "books" to different items types. Stone must be stone. Scroll must be scroll. Paper must be paper. Wood must be wood... Yes, create another type of book: Waxed tablet.
//TO DO TODO: Make a parchments (paper from leather) ? Think about it wisely...
//TO DO TODO: Rework books crafting, they must be crafted from paper or parchments (if it is a book). Parchments book is a different item from paper book.
//TO DO TODO: Rework paper crafting. It's must be different from age to age.
//TO DO TODO: below are not completed rework of printing press... Complete it LATER, not now.
//TO DO TODO: languages for text... many work at /obj/item/weapon/pen , languages for books, languages for all what may be wroten.
/*
/obj/structure/printingpress
	name = "printing press"
	desc = "Used to copy books and papers."
	icon = 'icons/obj/structures.dmi'
	icon_state = "printingpress0"
	anchored = TRUE
	density = TRUE
	flammable = TRUE
	var/tmp/obj/item/weapon/base = null
	var/tmp/obj/item/weapon/copy = null
	var/tmp/obj/item/weapon/storage/internal/storage //for store copy and original and not drop it on ground
	var/tmp/list/obj/item/weapon/copies = list()
	var/tmp/copying = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/printingpress/New()
	. = ..()
	storage = new/obj/item/weapon/storage/internal(src)
	storage.storage_slots = 12 //enough
	storage.max_storage_space = 5000 //may be enough

/obj/structure/printingpress/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/book) || istype(W, /obj/item/weapon/paper))
		var/tolist = list()
		var/msg = "Printing press slots [!(base||copy) ? "are empty." : "contains:"]\n\n"
		if (!base)
			tolist += "Original"
		else
			msg += "  [capitalize(base.name)] in original slot.\n\n"
		if (!copy)
			tolist += "Copy"
		else
			msg += "  [capitalize(copy.name)] in copy slot.\n\n"
		msg += "Ready copies storage "
		if (!copies.len)
			msg += "is empty.\n\n"
		else
		    msg += "contains [copies.len] exemplar[copies.len>1 : "s" : ""].\n\n"
		if (copies.len<10)
			msg += "\nAdd [W.name] to original slot, copy slot or store it?\n"
			tolist += "Store"
		else
			msg += "\nAdd [W.name] to original or copy slot?\n"
		tolist += "Cancel"
		var/input = WWinput(user, msg, "Printing Press", "Cancel", tolist)
		switch (input)
			if ("Original") 	base = W
			if ("Copy")     	copy = W
			if ("Store")		copies += W
			else            	return
		storage.handle_item_insertion(W, TRUE)
		return
	if (istype(W,/obj/item/weapon/wrench))
		wrench_action(user)
		return
	if (istype(W,/obj/item/weapon/hammer))
		hammer_action(user, W, 120, list("/obj/item/stack/material/wood"), list(9))
		return
	..(W, user)

/obj/structure/printingpress/attack_hand(var/mob/living/human/H)
	if (copying)
		H << "<span class='warning'>The [src] is busy now.</span>"
		return
	var/msg = "Printing press slots [!(base||copy) ? "are empty." : "contains:"]\n"
	var/obj/item/weapon/paper/PO
	var/obj/item/weapon/book/BO
	if (base)
		msg += "  [capitalize(base.name)] in original slot.\n"
		tolist += "Grab from original slot"
	if (copy)
		msg += "  [capitalize(copy.name)] in copy slot.\n"
		tolist += "Grab from copy slot"
	msg += "\n"
	if (!copies.len)
		msg += "Ready copies storage is empty.\n"
	else
		msg += "In storage:\n"
		for (var/obj/item/weapon/stored in copies)
			msg += "  [capitalize(stored.name)]"
			tolist += "Take [capitalize(stored.name)] from storage"
	if (base && copy)
		if (istype(base, /obj/item/weapon/paper) || istype(copy, /obj/item/weapon/paper))
			if (base.type == copy.type)
				PO = copy
				if (!PO.info)
					tolist += "Begin copy from [base.name]"
				else
					msg += "Copying process can't be started, because [base.name] not clean.\n"
			else
				msg += "Copying process can't be started, because both documents must be of the same type.\n"
		else
			BO = copy

	if ((!base) && (!copy))
		H << "<span class='warning'>There is nothing inside the press.</span>"
		return
	if (!copy)
		base.alpha = 255
		H.put_in_active_hand(base)
		H << "<span class='notice'>You remove \the [base] from original slot.</span>"
		base = null
		return
	if (!base)
		copy.alpha = 255
		H.put_in_active_hand(copy)
		H << "<span class='notice'>You remove \the [copy] from copy slot.</span>"
		copy = null
		return
	if (base.type <> copy.type) //TO DO TODO: Rework to not accept wrong item type to second slot (in attackby proc)
		H << "<span class='warning'>Both documents must be of the same type. They are dropped for [src].</span>"
		unload_inv()
		return
	var/spawntimer = 90
	if (istype(base, /obj/item/weapon/book))
		spawntimer = 250
	copying = TRUE
	visible_message("Copying \the [base]...")
	icon_state = "printingpress1"
	if (do_after(H, spawntimer, src))
		if (!src)
			return
		if (!copying)
			return
		visible_message("The printing press finishes copying.")
		if (istype(base, /obj/item/weapon/paper))
			PO = base
			var/obj/item/weapon/paper/PN = new/obj/item/weapon/paper(src.loc)
			PN.info = PO.info
			PN.info_links = PO.info_links
			PN.fields = PO.fields
			PN.free_space = PO.free_space
			PN.rigged = PO.rigged
			PN.spam_flag = PO.spam_flag
			PN.stamps = PO.stamps
			PN.update_icon()
			H.put_in_active_hand(PN)
		else
			var/obj/item/weapon/book/BN
			var/obj/item/weapon/book/BO = base
			if (istype(base, /obj/item/weapon/book/holybook))
				var/obj/item/weapon/book/holybook/HO = base
				var/obj/item/weapon/book/holybook/HN = new/obj/item/weapon/book/holybook(src.loc)
				HN.religion = HO.religion
				HN.religion_type = HO.religion_type
				BN = HN
			else if (istype(base, /obj/item/weapon/book/research))
				var/obj/item/weapon/book/research/RO = base
				var/obj/item/weapon/book/research/RN = new/obj/item/weapon/book/research(src.loc)
				RN.completed = RO.completed
				RN.k_class = RO.k_class
				RN.k_level = RO.k_level
				RN.styleb = RO.styleb
				BN = RN
			else if (istype(base, /obj/item/weapon/book))
				BN = new/obj/item/weapon/book(src.loc)
				BN.dat = BO.dat
				BN.due_date = BO.due_date
			else
				return
			BN.author = BO.author
			BN.title = BO.title
			BN.name = BO.name
			BN.desc = BO.desc
			BN.unique = BO.unique
			BN.update_icon()
			H.put_in_active_hand(BN)
		qdel(copy)
		copy = null
	copying = FALSE
	icon_state = "printingpress0"

/obj/structure/printingpress/proc/unload_inv()
	copying = FALSE
	if (base)
		base.loc = src.loc
		base.alpha = 255
		base = null
	if (copy)
		copy.loc = src.loc
		copy.alpha = 255
		copy = null

/obj/structure/printingpress/Destroy()
	unload_inv()
	. = ..()

/obj/structure/printingpress/before_save()
	unload_inv()
	. = ..()
*/
//below are untouched original code of printing press... mostly untouched
////////////////////PRINTING/PRESS///////////////////////////
/obj/structure/printingpress
	name = "printing press"
	desc = "Used to copy books and papers."
	icon = 'icons/obj/structures.dmi'
	icon_state = "printingpress0"
	anchored = TRUE
	density = TRUE
	flammable = TRUE
	var/list/base = list()
	var/list/copy = list()
	var/copying = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE

/obj/structure/printingpress/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/book) || istype(W, /obj/item/weapon/paper))
		var/tolist = list("Cancel")
		if (isemptylist(copy) && isemptylist(base))
			tolist = list("Original","Copy","Cancel")
		else if (isemptylist(copy) && !isemptylist(base))
			tolist = list("Copy","Cancel")
		else if (!isemptylist(copy) && isemptylist(base))
			tolist = list("Original","Cancel")
		else
			tolist = list("Cancel")
		var/input = WWinput(user, "Add to original or copy?", "Printing Press", "Cancel", tolist)
		if (input == "Cancel")
			return
		else if (input == "Original")
			base += W
			user.drop_from_inventory(W)
			W.forceMove(locate(0,0,0))
			return

		else if (input == "Copy")
			copy += W
			user.drop_from_inventory(W)
			W.forceMove(locate(0,0,0))
			return

	if (istype(W,/obj/item/weapon/wrench))
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		user << (anchored ? "<span class='notice'r>You unfasten \the [src] from the floor.</span>" : "<span class='notice'>You secure \the [src] to the floor.</span>")
		anchored = !anchored
	else if (istype(W,/obj/item/weapon/hammer) || istype(W,/obj/item/weapon/hammer/modern))
		playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		user << "<span class='notice'>You begin dismantling \the [src].</span>"
		if (do_after(user,60,src))
			user << "<span class='notice'>You dismantle \the [src].</span>"
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc) 	//5 out of 12 to craft
			qdel(src)

	else
		..()

/obj/structure/printingpress/attack_hand(var/mob/living/human/H)
	if (copying)
		return

	if (isemptylist(base) && isemptylist(copy))
		H << "There is nothing inside the press."
		return

	if (isemptylist(copy))
		for(var/obj/item/weapon/B in base)
			H << "You remove \the [B]."
			B.loc = get_turf(src)
			base -= B
		return

	if (isemptylist(base))
		for(var/obj/item/weapon/C in copy)
			H << "You remove \the [C]."
			C.loc = get_turf(src)
			copy -= C
		return
	if (!isemptylist(base) && !isemptylist(copy))
		if (base[1].type != copy[1].type)
			H << "Both documents must be of the same type."
			for(var/obj/item/weapon/C in copy)
				C.loc = get_turf(src)
				copy -= C
			for(var/obj/item/weapon/B in base)
				B.loc = get_turf(src)
				base -= B
			return
		else
			var/spawntimer = 90
			if (istype(base[1], /obj/item/weapon/book))
				spawntimer = 250
			else if (istype(base[1], /obj/item/weapon/paper))
				spawntimer = 90
			copying = TRUE
			visible_message("Copying \the [base[1]]...")
			icon_state = "printingpress1"
			if (do_after(H, spawntimer, src))
				if (!isemptylist(base) && !isemptylist(copy))
					visible_message("The printing press finishes copying.")
					icon_state = "printingpress0"
					for(var/obj/item/weapon/B in base)
						B.loc = get_turf(src)
						base -= B
						if (istype(B, /obj/item/weapon/book) && !istype(B, /obj/item/weapon/book/holybook) && !istype(B, /obj/item/weapon/book/research))
							var/obj/item/weapon/book/NC = B
							var/obj/item/weapon/book/NB = new/obj/item/weapon/book(src.loc)
							NB.dat = NC.dat
							NB.due_date = NC.due_date
							NB.author = NC.author
							NB.unique = NC.unique
							NB.title = NC.title
						else if (istype(B, /obj/item/weapon/book/holybook))
							var/obj/item/weapon/book/holybook/NC = B
							var/obj/item/weapon/book/holybook/NB = new/obj/item/weapon/book/holybook(src.loc)
							NB.author = NC.author
							NB.title = NC.title
							NB.name = NC.name
							NB.desc = NC.desc
							NB.religion = NC.religion
							NB.religion_type = NC.religion_type
						else if (istype(B, /obj/item/weapon/paper))
							var/obj/item/weapon/paper/NC = B
							var/obj/item/weapon/paper/NP = new/obj/item/weapon/paper(src.loc)
							NP.info = NC.info
							NP.info_links = NC.info_links
							NP.fields = NC.fields
							NP.free_space = NC.free_space
							NP.rigged = NC.rigged
							NP.spam_flag = NC.spam_flag
						else if (istype(B, /obj/item/weapon/book/research))
							var/obj/item/weapon/book/research/NC = B
							var/obj/item/weapon/book/research/NB = new/obj/item/weapon/book/research(src.loc)
							NB.author = NC.author
							NB.title = NC.title
							NB.name = NC.name
							NB.desc = NC.desc
							NB.completed = NC.completed = 0
							NB.k_class = NC.k_class = "none"
							NB.k_level = NC.k_level = 0
							NB.styleb = NC.styleb = "scroll"
							/*
 							//Theese have no sense for research or not used anywhere in code
							NB.sum_a = NC.sum_a = 0
							NB.sum_b = NC.sum_b = 0
							NB.sum_c = NC.sum_c = 0
							NB.monk = NC.monk = FALSE //if the book was authored by a monk
							NB.religion = NC.religion = "none"
							*/
					for(var/obj/item/weapon/C in copy)
						copy -= C
						qdel(C)
					copying = FALSE
					return
			else
				copying = FALSE
				icon_state = "printingpress0"
				return
	return

////////////////////////////////////////////////////////////////////////
//  Canning  ///////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
//TO DO TODO: look to this code later, not now. Some fixes was implemented, but not detailed.
/obj/structure/canner
	name = "canner"
	desc = "A pressure tool used to seal cans."
	icon = 'icons/obj/cans.dmi'
	icon_state = "canner"
	anchored = TRUE
	density = FALSE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	flags = CONDUCT

/obj/structure/canner/attackby(var/obj/item/W as obj, var/mob/living/human/H as mob)
	if (istype(W, /obj/item/weapon/can))
		var/obj/item/weapon/can/C = W
		if (C.stored.len)
			H << "You start sealing \the [C]..."
			icon_state = "canner_active"
			if (do_after(H, 50, H.loc))
				H << "You finish sealing \the [C]."
				C.open = FALSE
				C.sealed = TRUE
				C.update_icon()
				icon_state = "canner"
			else
				icon_state = "canner"
		return
	if (istype(W, /obj/item/weapon/wrench))
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		H << (anchored ? "<span class='notice'r>You unfasten \the [src] from the floor.</span>" : "<span class='notice'>You secure \the [src] to the floor.</span>")
		anchored = !anchored
		return
	if (istype(W, /obj/item/weapon/hammer))
		playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		H << "<span class='notice'>You begin dismantling \the [src].</span>"
		if (do_after(H, 50, src))
			H << "<span class='notice'>You dismantle \the [src].</span>"
			var/P = "/obj/item/stack/material/iron"
			new P(loc, 4) //4 out of 7 to craft
			qdel(src)

/obj/item/weapon/can
	name = "empty can"
	desc = "A tin can that can keep food good for a long time. Can fit 5 units."
	icon = 'icons/obj/cans.dmi'
	icon_state = "can_empty"
	var/base_icon = "can"
	w_class = ITEM_SIZE_SMALL
	flammable = FALSE
	slot_flags = null
	var/max_capacity = 5
	var/brand = ""
	var/list/stored = list()
	var/open = TRUE
	var/sealed = FALSE
	var/customcolor1 = null
	var/customcolor2 = null
	basematerials = list("tin", 0.45)
	New()
		flags |= CONDUCT

/obj/item/weapon/can/small
	name = "empty small can"
	desc = "A tin can that can keep food good for a long time. Can fit 3 units."
	icon_state = "small_can_empty"
	base_icon = "small_can"
	w_class = ITEM_SIZE_TINY
	slot_flags = SLOT_POCKET
	max_capacity = 3
	basematerials = list("tin", 0.3)

/obj/item/weapon/can/large
	name = "empty large can"
	desc = "A tin can that can keep food good for a long time. Can fit 10 units."
	icon_state = "large_can_empty"
	base_icon = "large_can"
	w_class = ITEM_SIZE_NORMAL
	slot_flags = null
	max_capacity = 10
	basematerials = list("tin", 0.9)

/obj/item/weapon/can/update_icon()
	if (open)
		if (stored.len)
			icon_state = "[base_icon]_open"
		else
			icon_state = "[base_icon]_empty"
	else
		icon_state = "[base_icon]"

/obj/item/weapon/can/attackby(var/obj/item/W as obj, var/mob/living/human/H as mob)
	if (istype(W, /obj/item/weapon/reagent_containers/food/snacks) && open)
		if (stored.len<max_capacity && !sealed)
			stored += W
			H.drop_from_inventory(W)
			W.forceMove(src)
			H << "You put \the [W] in \the [src]."
			icon_state = "[base_icon]_open"
			if (stored.len==1)
				name = "[brand]canned [W]"
				name = replacetext(name, "the","")
			else
				if (!findtext(name, "[W]"))
					name = replacetext(name, " and ",", ")
					name = "[name] and [W]"
					name = replacetext(name, "the","")
			if (!findtext(W.name, "canned"))
				W.name = replacetext(W.name, "the","")
				W.name = "canned [W.name]"
			name = replacetext(name, "  "," ")
			var/obj/item/weapon/reagent_containers/food/snacks/S = W
			if (S.satisfaction > 0)
				S.satisfaction *= 0.5 //canned food doesn't taste as good
			else
				S.satisfaction *= 1.5 //food that is already bad will taste worse when canned
		else
			H << "<span class='notice'>\the [src] is full!</span>"
		return
	if (istype(W, /obj/item/weapon/material/kitchen/utensil/knife))
		if (!open)
			open = TRUE
			update_icon()
			H << "You open \the [src]."
		return
	..()

/obj/item/weapon/can/attack_hand(mob/living/human/user)
	if (stored.len && user.has_empty_hand() && loc == user && open)
		for (var/obj/item/I in stored)
			I.loc = user.loc
			stored -= I
			user.put_in_active_hand(I)
			user << "You remove \the [I] from \the [src]."
			if (!stored.len)
				name = "empty [brand]can"
				icon_state = "[base_icon]_empty"
			break //one item per time
	else
		..()

/obj/item/weapon/can/proc/do_color()
	if (customcolor1)
		var/image/colorov1 = image("icon" = icon, "icon_state" = "[base_icon]_o1")
		colorov1.color = customcolor1
		overlays += colorov1
	if (customcolor2)
		var/image/colorov2 = image("icon" = icon, "icon_state" = "[base_icon]_o2")
		colorov2.color = customcolor2
		overlays += colorov2

/obj/item/weapon/can/filled
	var/list/randbrand = list(
		"Master Taislin", "Metsobeshi", "Old Man", "Welmert",
		"McDonohugh", "McKellen's Delight",	"Freeman", "Kostas Finest",
		"Slowman", "Pajeet Special", "Toyoda", "Uma Delicia",
		"Ooga's Cuisine", "Burner King"
	)
	var/list/custcolor = list(
		"#e6194b",	"#3cb44b",	"#ffe119",	"#4363d8", "#f58231",	"#911eb4",	"#46f0f0",	"#f032e6",
		"#bcf60c",	"#fabebe",	"#008080",	"#e6beff",	"#9a6324", "#fffac8", "#800000", "#aaffc3",
		"#808000", "#ffd8b1", "#000075", "#808080", "#ffffff", "#000000"
	)
	var/list/filllist = list(
		/obj/item/weapon/reagent_containers/food/snacks/grown/grapes, /obj/item/weapon/reagent_containers/food/snacks/grown/olives,
		/obj/item/weapon/reagent_containers/food/snacks/grown/mushroom,	/obj/item/weapon/reagent_containers/food/snacks/grown/watermelon,
		/obj/item/weapon/reagent_containers/food/snacks/grown/orange, /obj/item/weapon/reagent_containers/food/snacks/grown/apple,
		/obj/item/weapon/reagent_containers/food/snacks/grown/banana, /obj/item/weapon/reagent_containers/food/snacks/grown/coconut,
		/obj/item/weapon/reagent_containers/food/snacks/grown/tomato, /obj/item/weapon/reagent_containers/food/snacks/grown/beans,
		/obj/item/weapon/reagent_containers/food/snacks/grown/cabbage, /obj/item/weapon/reagent_containers/food/snacks/grown/carrot,
		/obj/item/weapon/reagent_containers/food/snacks/grown/corn
	)
	var/currspawn = null
	icon_state = "can"

/obj/item/weapon/can/filled/New()
	..()
	currspawn = pick(filllist)
	brand = "[pick(randbrand)]"
	stored = fill()
	open = FALSE
	sealed = TRUE
	customcolor1 = pick(custcolor)
	customcolor2 = pick(custcolor)
	name = "[brand]'s [stored[1].name]"
	spawn(1)
		do_color()

/obj/item/weapon/can/filled/proc/fill()
	var/list/tlist = list()
	currspawn = pick(filllist)
	for (var/i=1, i <= rand(3,5), i++)
		var/obj/item/weapon/reagent_containers/food/snacks/grown/GS = new currspawn(src)
		GS.name = "canned [GS.name]"
		if (GS.satisfaction>0)
			GS.satisfaction *= 0.5 //canned food doesn't taste as good
		else
			GS.satisfaction *= 1.5 //food that is already bad will taste worse when canned
		tlist += GS
	return tlist

////////////////////////////////////////////////////////////////////////
//  Compost bin  ///////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
// TO DO TODO: Think about what if game continues after saving??? Yes, think it in details.
// TO DO TODO: Maybe a rough estimate of the quantity from the whole like in examine() make more global procedure?
/obj/structure/compost
	name = "compost bin"
	desc = "A wood box, used to turn trash and scraps into fertilizer."
	icon = 'icons/obj/structures.dmi'
	icon_state = "compostbin"
	anchored = TRUE
	density = TRUE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/tmp/current = 0
	var/tmp/composting = FALSE

/obj/structure/compost/examine(mob/user)
	if (!..(user, TRUE))
		return
	if (current==0)
		user << "<span class='notice'>It's empty</span>"
	else if (current<1)
		user << "<span class='notice'>There is mixed waste, but not enough to start the composting process.</span>"
	else if (current<2.5)
		user << "<span class='notice'>The [src] is less than a quarter full, the composting process is in progress.</span>"
	else if (current<3.3)
		user << "<span class='notice'>The [src] is less than a third full, the composting process is in progress.</span>"
	else if (current>=10)
		user << "<span class='notice'>The [src] is full and the composting process is in progress.</span>"
	else if (current>7.5)
		user << "<span class='notice'>The [src] is more than three-quarters full and the composting process is in progress.</span>"
	else if (current>6.6)
		user << "<span class='notice'>The [src] is more than two-thirds full and the composting process is in progress.</span>"
	else if (current>5)
		user << "<span class='notice'>The [src] is more than half full and the composting process is in progress.</span>"
	else
		user << "<span class='notice'>The [src] is less than half full and the composting process is in progress.</span>"

/obj/structure/compost/New()
	..()
	initialize()

/obj/structure/compost/proc/add(var/obj/item/W, var/mob/living/human/H, amount_to_add)
	current += amount_to_add
	if (H)
		H.visible_message("<span class='warning'>[H] place \the [W] in \the [src], composting it.</span>",
			"<span class='notice'>You place \the [W] in \the [src], composting it.</span>")
	qdel(W)

/obj/structure/compost/attackby(var/obj/item/W as obj, var/mob/living/human/H as mob)
	if (current>=10)
		H << "<span class='warning'>The compost bin is full!</span>"
		return
	var/list/allow_types = list(/obj/item/weapon/reagent_containers/food, /obj/item/stack/material/leaf, /obj/item/stack/farming/seeds,
		/obj/item/stack/material/poppy, /obj/item/stack/material/tobacco, /obj/item/stack/material/tobacco_green, /obj/item/stack/material/coca,
		/obj/item/stack/material/flax, /obj/item/stack/material/hemp, /obj/item/stack/material/rettedfabric,
		/obj/item/stack/dung
	)
	if (is_type_in_list(W, allow_types))
		H.drop_item(src.loc)
		auto_load(H)
		return TRUE
	if (istype(W,/obj/item/weapon/wrench))
		wrench_action(H)
		return TRUE
	if (istype(W,/obj/item/weapon/hammer))
		hammer_action(H, W, 150, list("/obj/item/stack/material/wood"), list(7))
		return TRUE
	H << "<span class='warning'>\the [W] is not suitable for compost.</span>"

/obj/structure/compost/proc/auto_load(var/mob/living/human/H)
	for (var/obj/item/W in src.loc)
		if (current>=10)
			if (H)
				H << "<span class='warning'>The compost bin is full!</span>"
			break
		if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/poo)) //poo and fertilizer not need compost, but we have now storage for poo
			if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/poo/fertilizer))
				continue
			if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/poo/animal))
				continue
			add(W, H, 0.75) //human poo is near fertilizer, but need composting first
			continue
		if (istype(W, /obj/item/stack/dung))
			continue
		if (W.type == /obj/item/stack/ore)
			add(W, H, W.amount*10) //It's not obtainable item now, we used it for save/load current values
			continue
		if (istype(W, /obj/item/weapon/reagent_containers/food))
			add(W, H, 0.5)
			continue
		if (istype(W, /obj/item/stack/material/leaf))
			add(W, H, W.amount/18) //divides (using /) by eighteenth's from each plant input of 1, 0.05(5555555555556) gain per leaf
			continue
		if (istype(W, /obj/item/stack/farming/seeds))
			add(W, H, W.amount/10) //divides (using /) by tenths from each plant input of 1, 0.10 gain per seed, 10 seeds = 1 unit. 100 seeds = 10
			continue
		if (istype(W, /obj/item/stack/material/poppy) || istype(W, /obj/item/stack/material/tobacco_green) || istype(W, /obj/item/stack/material/tobacco) || istype(W, /obj/item/stack/material/coca))
			add(W, H, W.amount/4) //by fourths from each stack plant input of 1, 0.25 gain per plant, 4 stackplants = 1 unit. 40 stackplants = 10
			continue
		if (istype(W, /obj/item/stack/material/flax) || istype(W, /obj/item/stack/material/hemp) || istype(W, /obj/item/stack/material/rettedfabric))
			add(W, H, W.amount/4) //by fourths from each stack plant input of 1, 0.25 gain per plant, 4 stackplants = 1 unit. 40 stackplants = 10

/obj/structure/compost/proc/compost()
	if (!src)
		return
	if (!src.loc)
		return
	composting = TRUE
	if (current<1)
		spawn(rand(450,600))
			compost()
	else
		spawn(rand(800,1000))
			visible_message("The composted material begins to degrade.")
			spawn(rand(800,1000))
				current--
				new/obj/item/weapon/reagent_containers/food/snacks/poo/fertilizer(loc)
				compost()

/obj/structure/compost/initialize()
	. = ..()
	if (!composting)
		auto_load()
		composting = TRUE
		spawn(rand(25,100))
			compost()

/obj/structure/compost/before_save()
	. = ..()
	var/obj/item/O = new/obj/item/stack/ore(src.loc, current/10)
	O.alpha = 0
	current = 0

/obj/structure/compost/after_load()
	. = ..()
	initialize()
