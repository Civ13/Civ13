/****************************************************
				EXTERNAL ORGANS
****************************************************/

//These control the damage thresholds for the various ways of removing limbs
//Numbers below 1.0 = more damage required
#define DROPLIMB_THRESHOLD_DESTROY 0.95
#define DROPLIMB_THRESHOLD_EDGE 1
#define DROPLIMB_THRESHOLD_TEAROFF 0.9

// new min_broken_damage, max_damage values based off of damage values defines
// in __projectiles.dm

/obj/item/organ/external
	name = "external"
	min_broken_damage = 70
	max_damage = 0
	dir = SOUTH
	organ_tag = "limb"

	// Damage vars.
	var/brute_mod = 1.0
	var/burn_mod = 1.0

	var/nationality = null

	// Appearance vars.
	var/icon_name = null
	var/body_part = null
	var/icon_position = FALSE
	var/model
	var/damage_state = "00"
	var/brute_dam = FALSE //sum of blunt, pierce and cut damage
	var/burn_dam = FALSE
	var/blunt_dam = FALSE // not sharp and not edged. More likely to break bones. Won't bleed.
	var/pierce_dam = FALSE // sharp but not edged. More likely to give internal bleeding or damage wounds. Just a little bleeding.
	var/cut_dam = FALSE // superficial damage, not a lot of damage but lots of bleeding.
	var/max_size = FALSE
	var/last_dam = -1
	var/icon/mob_icon
//	var/gendered_icon = FALSE
	var/limb_name
	var/disfigured = FALSE
	var/cannot_amputate
	var/cannot_break
	var/s_tone
	var/list/s_col
	var/list/h_col

	// Wound and structural data.
	var/list/wounds = list()
	var/number_wounds = FALSE 			// cache the number of wounds, which is NOT wounds.len!
	var/perma_injury = FALSE
	var/obj/item/organ/external/parent
	var/list/obj/item/organ/external/children
	var/list/internal_organs = list() 	// Internal organs of this body part
	var/damage_msg = "<span class = 'red'>You feel an intense pain</span>"
	var/broken_description
	var/open = FALSE
	var/stage = FALSE
	var/cavity = FALSE
	var/sabotaged = FALSE 				// If a prosthetic limb is emagged, it will detonate when it fails.
	var/list/implants = list()
	var/wound_update_accuracy = TRUE 	// how often wounds should be updated, a higher number means less often
	var/joint = "joint"   				// Descriptive string used in dislocation.
	var/amputation_point  				// Descriptive string used in amputation.
	var/dislocated = FALSE				// If you target a joint, you can dislocate the limb, causing temporary damage to the organ.

	// Joint/state stuff.
	var/can_grasp 						//It would be more appropriate if these two were named "affects_grasp" and "affects_stand" at this point
	var/can_stand
	var/pain = FALSE
	var/fracturetimer = 0
	var/artery_name = "artery"		 	// Flavour text for carotid artery, aorta, etc.
	var/arterial_bleed_severity = 1		// Multiplier for bleeding in a limb.
	var/prosthesis = FALSE
	var/prosthesis_type = "none"
	var/pain_disability_threshold
	var/atom/movable/applied_pressure
	var/burn_ratio = 0
	var/brute_ratio = 0
	var/encased = ""
	var/cavity_name = ""

/obj/item/organ/external/New()
	..()
	if(isnull(pain_disability_threshold))
		pain_disability_threshold = (max_damage * 0.75)

/obj/item/organ/external/Destroy()
	if (parent && parent.children)
		parent.children -= src

	if (children)
		for (var/obj/item/organ/external/C in children)
			qdel(C)

	if (internal_organs)
		for (var/obj/item/organ/O in internal_organs)
			qdel(O)
	applied_pressure = null
	return ..()

/obj/item/organ/external/emp_act(severity)
	switch (severity)
		if (1)
			take_damage(10)
		if (2)
			take_damage(5)
		if (3)
			take_damage(1)

/obj/item/organ/external/attack_self(var/mob/user)
	if (!contents.len)
		return ..()
	var/list/removable_objects = list()
	for (var/obj/item/organ/external/E in (contents + src))
		if (!istype(E))
			continue
		for (var/obj/item/I in E.contents)
			if (istype(I,/obj/item/organ))
				continue
			removable_objects |= I
	if (removable_objects.len)
		var/obj/item/I = pick(removable_objects)
		I.loc = get_turf(user) //just in case something was embedded that is not an item
		if (istype(I))
			if (!(user.l_hand && user.r_hand))
				user.put_in_hands(I)
		user.visible_message("<span class='danger'>\The [user] rips \the [I] out of \the [src]!</span>")
		return //no eating the limb until everything's been removed
	return ..()

/obj/item/organ/external/examine()
	..()
	if (in_range(usr, src) || isghost(usr))
		for (var/obj/item/I in contents)
			if (istype(I, /obj/item/organ))
				continue
			usr << "<span class='danger'>There is \a [I] sticking out of it.</span>"
	return

/obj/item/organ/external/attackby(obj/item/weapon/W as obj, mob/user as mob)
	switch(stage)
		if (0)
			if (istype(W,/obj/item/weapon/surgery/scalpel))
				user.visible_message("<span class='danger'><b>[user]</b> cuts [src] open with [W]!</span>")
				stage++
				return
		if (1)
			if (istype(W,/obj/item/weapon/surgery/retractor))
				user.visible_message("<span class='danger'><b>[user]</b> cracks [src] open like an egg with [W]!</span>")
				stage++
				return
		if (2)
			if (istype(W,/obj/item/weapon/surgery/hemostat))
				if (contents.len)
					var/obj/item/removing = pick(contents)
					removing.loc = get_turf(user.loc)
					if (!(user.l_hand && user.r_hand))
						user.put_in_hands(removing)
					user.visible_message("<span class='danger'><b>[user]</b> extracts [removing] from [src] with [W]!</span>")
				else
					user.visible_message("<span class='danger'><b>[user]</b> fishes around fruitlessly in [src] with [W].</span>")
				return
	..()

/obj/item/organ/external/proc/is_dislocated()
	if (dislocated > 0)
		return TRUE
	if (parent)
		return parent.is_dislocated()
	return FALSE

/obj/item/organ/external/proc/dislocate(var/primary)
	if (dislocated != -1)
		if (primary)
			dislocated = 2
		else
			dislocated = TRUE
	owner.verbs |= /mob/living/human/proc/undislocate
	if (children && children.len)
		for (var/obj/item/organ/external/child in children)
			child.dislocate()

/obj/item/organ/external/proc/undislocate()
	if (dislocated != -1)
		dislocated = FALSE
	if (children && children.len)
		for (var/obj/item/organ/external/child in children)
			if (child.dislocated == TRUE)
				child.undislocate()
	if (owner)
		owner.shock_stage += 20
		for (var/obj/item/organ/external/limb in owner.organs)
			if (limb.dislocated == 2)
				return
		owner.verbs -= /mob/living/human/proc/undislocate

/obj/item/organ/external/update_health()
	damage = min(max_damage, (brute_dam + burn_dam))
	pain = min(max_damage, (brute_dam + burn_dam))
	if (damage > max_damage)
		if (prob(20))
			droplimb(0,DROPLIMB_EDGE)
			for(var/mob/living/human/NB in view(6,src))
				if (!NB.orc)
					NB.mood -= 9
					//NB.ptsd += 1
	return


/obj/item/organ/external/New(var/mob/living/human/holder)
	..(holder, FALSE)
	if (owner)
		replaced(owner)
		sync_colour_to_human(owner)
	spawn(1)
		get_icon()

/obj/item/organ/external/replaced(var/mob/living/human/target)
	owner = target
	forceMove(owner)
	if (istype(owner))
		owner.organs_by_name[limb_name] = src
		owner.organs |= src
		for (var/obj/item/organ/organ in src)
			organ.replaced(owner,src)

	if (parent_organ)
		parent = owner.organs_by_name[parent_organ]
		if (parent)
			if (!parent.children)
				parent.children = list()
			parent.children.Add(src)
			//Remove all stump wounds since limb is not missing anymore
			for (var/datum/wound/lost_limb/W in parent.wounds)
				parent.wounds -= W
				qdel(W)
				break
			parent.update_damages()


/****************************************************
			   DAMAGE PROCS
****************************************************/

/obj/item/organ/external/proc/is_damageable(var/additional_damage = FALSE)
	return (vital || brute_dam + burn_dam + additional_damage <= max_damage)


/obj/item/organ/external/take_damage(brute, burn, sharp, edge, used_weapon = null)
	brute = round(brute * brute_mod, 0.1)
	burn = round(burn * burn_mod, 0.1)
	if((brute <= 0) && (burn <= 0))
		return 0

	// High brute damage or sharp objects may damage internal organs
	var/damage_amt = brute
	var/cur_damage = brute_dam
	if(internal_organs && internal_organs.len && (cur_damage + damage_amt >= max_damage || (((sharp && damage_amt >= 5) || damage_amt >= 10) && prob(5))))
		// Damage an internal organ
		var/list/victims = list()
		for(var/obj/item/organ/I in internal_organs)
			if(I.damage < I.max_damage && prob(I.relative_size))
				victims += I
		if(!victims.len)
			victims += pick(internal_organs)
		for(var/obj/item/organ/victim in victims)
			brute /= 2
			damage_amt /= 2
			victim.take_damage(damage_amt)

	if(status & ORGAN_BROKEN && brute)
		jostle_bone(brute)
//		if(can_feel_pain() && prob(40))
//			owner.emote("scream")	//getting hit on broken hand hurts
	var/canbreak = TRUE
	if(blunt_dam > min_broken_damage && prob(blunt_dam)) //blunt damage is gud at fracturing
		if (canbreak)
			if (istype(used_weapon, /obj/item/projectile))
				if (prob(35))
					fracture()
			else
				fracture()

	if(brute_dam*0.8 > min_broken_damage && prob(brute_dam*0.7))
		if (canbreak)
			if (istype(used_weapon, /obj/item/projectile))
				if (prob(18))
					fracture()
			else
				fracture()

	var/can_cut = (prob(brute*2) || sharp)
	var/spillover = 0
	var/pure_brute = brute
	if(!is_damageable(brute + burn))
		spillover =  brute_dam + burn_dam + brute - max_damage
		if(spillover > 0)
			brute -= spillover
		else
			spillover = brute_dam + burn_dam + brute + burn - max_damage
			if(spillover > 0)
				burn -= spillover
	// If the limbs can break, make sure we don't exceed the maximum damage a limb can take before breaking
	// Non-vital organs are limited to max_damage. You can't kill someone by bludeonging their arm all the way to 200 -- you can
	// push them faster into paincrit though, as the additional damage is converted into shock.

	var/datum/wound/created_wound
	if(is_damageable(brute + burn))
		if(brute)
			if(can_cut)
				//need to check sharp again here so that blunt damage that was strong enough to break skin doesn't give puncture wounds
				if(sharp && !edge)
					created_wound = createwound( PIERCE, brute )
				else
					created_wound = createwound( CUT, brute )
			else
				createwound( BRUISE, brute )
		if(burn)
			createwound( BURN, burn )
	else
		//If there are still hurties to dispense
		if (spillover && owner)
			owner.shock_stage += spillover * config.organ_damage_spillover_multiplier

	// sync the organ's damage with its wounds
	src.update_damages()
	if (owner)
		owner.updatehealth() //droplimb will call updatehealth() again if it does end up being called
	//If limb took enough damage, try to cut or tear it off
	if(owner && loc == owner && !is_stump())
		if(!cannot_amputate && (brute_dam + burn_dam + brute + burn + spillover) >= (max_damage * config.organ_health_multiplier))
			//organs can come off in three cases
			//1. If the damage source is edge_eligible and the brute damage dealt exceeds the edge threshold, then the organ is cut off.
			//2. If the damage amount dealt exceeds the disintegrate threshold, the organ is completely obliterated.
			//3. If the organ has already reached or would be put over it's max damage amount (currently redundant),
			//   and the brute damage dealt exceeds the tearoff threshold, the organ is torn off.
			//Check edge eligibility
			var/edge_eligible = 0
			if(edge)
				if(istype(used_weapon,/obj/item))
					var/obj/item/W = used_weapon
					if(W.w_class >= w_class)
						edge_eligible = 1
				else
					edge_eligible = 1

			if (!istype(used_weapon, /obj/item/projectile))
				brute = pure_brute
				if(edge_eligible && brute >= max_damage / DROPLIMB_THRESHOLD_EDGE && prob(brute/3))
					if (prob(20))
						droplimb(0, DROPLIMB_EDGE)
						for(var/mob/living/human/NB in view(6,src))
							if (!NB.orc)
								NB.mood -= 10
								//NB.ptsd += 1
				else if(burn >= max_damage / DROPLIMB_THRESHOLD_DESTROY && prob(burn/3))
					if (prob(20))
						droplimb(0, DROPLIMB_BURN)
						for(var/mob/living/human/NB in view(6,src))
							if (!NB.orc)
								NB.mood -= 10
								//NB.ptsd += 1
				else if(brute >= max_damage / DROPLIMB_THRESHOLD_DESTROY && prob(brute/3))
					if (prob(20))
						droplimb(0, DROPLIMB_BLUNT)
						for(var/mob/living/human/NB in view(6,src))
							if (!NB.orc)
								NB.mood -= 10
								//NB.ptsd += 1
				else if(brute >= max_damage / DROPLIMB_THRESHOLD_TEAROFF && prob(brute/3))
					if (prob(20))
						droplimb(0, DROPLIMB_BLUNT)
						for(var/mob/living/human/NB in view(6,src))
							if (!NB.orc)
								NB.mood -= 10
								//NB.ptsd += 1

	if(owner && update_damstate())
		owner.UpdateDamageIcon()

	return created_wound


/obj/item/organ/external/proc/heal_damage(brute, burn, internal = FALSE, robo_repair = FALSE, var/mob/living/human/healer = null)

	if (healer && healer != owner)
		healer.awards["medic"]+=(brute+burn)
		owner.awards["wounded"]+=(brute+burn)

	//Heal damage on the individual wounds
	for (var/datum/wound/W in wounds)
		if (brute == 0 && burn == 0)
			break

		// heal brute damage
		if (W.damage_type == BURN)
			burn = W.heal_damage(burn)
		else
			brute = W.heal_damage(brute)

	if (internal)
		status &= ~ORGAN_BROKEN
		perma_injury = FALSE

	/*if ((brute || burn) && children && children.len && (owner.species.flags & REGENERATES_LIMBS))
		var/obj/item/organ/external/stump/S = locate() in children
		if (S)
			world << "Extra healing to go around ([brute+burn]) and [owner] needs a replacement limb."*/

	//Sync the organ's damage with its wounds
	update_damages()
	owner.updatehealth()

	return update_damstate()

/*
This function completely restores a damaged organ to perfect condition.
*/
/obj/item/organ/external/rejuvenate()
	damage_state = "00"
	status = FALSE
	perma_injury = FALSE
	brute_dam = FALSE
	burn_dam = FALSE
	germ_level = FALSE
	pain = FALSE
	for(var/datum/wound/wound in wounds)
		if (wound.embedded_objects)
			wound.embedded_objects.Cut()
	wounds.Cut()
	number_wounds = FALSE

	// handle internal organs
	for (var/obj/item/organ/current_organ in internal_organs)
		current_organ.rejuvenate()

	// remove embedded objects and drop them on the floor
	for (var/obj/implanted_object in implants)
	/*	if (!istype(implanted_object,/obj/item/weapon/implant))*/	// We don't want to remove REAL implants. Just shrapnel etc.
		implanted_object.loc = owner.loc
		implants -= implanted_object

	owner.updatehealth()


/obj/item/organ/external/proc/createwound(var/type = CUT, var/damage)
	if (damage == FALSE) return

	//moved this before the open_wound check so that having many small wounds for example doesn't somehow protect you from taking internal damage (because of the return)
	//Possibly trigger an internal wound, too.
	var/local_damage = brute_dam + burn_dam + damage
	if (damage > 15 && type == PIERCE && local_damage > 30 && prob(damage*0.8))
		var/datum/wound/internal_bleeding/I = new (min(damage - 17, 12), src)
		wounds += I
		owner.custom_pain("You feel something rip in your [name]!", 120)

	// first check whether we can widen an existing wound
	if (wounds.len > 0 && prob(max(50+(number_wounds-1)*10,90)))
		if ((type == CUT || type == BRUISE) && damage >= 5)
			//we need to make sure that the wound we are going to worsen is compatible with the type of damage...
			var/list/compatible_wounds = list()
			for (var/datum/wound/W in wounds)
				if (W.can_worsen(type, damage))
					compatible_wounds += W

			if (compatible_wounds.len)
				var/datum/wound/W = pick(compatible_wounds)
				W.open_wound(damage)
				return

	//Creating wound
	var/wound_type = get_wound_type(type, damage)

	if (wound_type)
		var/datum/wound/W = new wound_type(damage, src)

		//Check whether we can add the wound to an existing wound
		for (var/datum/wound/other in wounds)
			if (other.can_merge(W))
				other.merge_wound(W)
				W = null // to signify that the wound was added
				break
		if (W)
			wounds += W

/****************************************************
			   PROCESSING & UPDATING
****************************************************/

//external organs handle brokenness a bit differently when it comes to damage. Instead brute_dam is checked inside process()
//this also ensures that an external organ cannot be "broken" without broken_description being set.
/obj/item/organ/external/is_broken()
	return ((status & ORGAN_CUT_AWAY) || ((status & ORGAN_BROKEN) && !(status & ORGAN_SPLINTED)))

//Determines if we even need to process this organ.
/obj/item/organ/external/proc/need_process()
	if (status & (ORGAN_CUT_AWAY|ORGAN_BLEEDING|ORGAN_BROKEN|ORGAN_DESTROYED|ORGAN_SPLINTED|ORGAN_DEAD|ORGAN_MUTATED))
		return TRUE
	if (brute_dam || burn_dam)
		return TRUE
	if (last_dam != brute_dam + burn_dam) // Process when we are fully healed up.
		last_dam = brute_dam + burn_dam
		return TRUE
	else
		last_dam = brute_dam + burn_dam
	if (germ_level)
		return TRUE
	return FALSE

/obj/item/organ/external/process()
	if (owner)
		//Dismemberment
		//if (parent && parent.is_stump()) //should never happen
		//	warning("\The [src] ([type]) belonging to [owner] ([owner.type]) was attached to a stump")
		//	remove()
		//	return

		// Process wounds, doing healing etc. Only do this every few ticks to save processing power
		if (owner.life_tick % wound_update_accuracy == FALSE)
			update_wounds()

		//Chem traces slowly vanish
		if (owner.life_tick % 10 == FALSE)
			for (var/chemID in trace_chemicals)
				trace_chemicals[chemID] = trace_chemicals[chemID] - 1
				if (trace_chemicals[chemID] <= 0)
					trace_chemicals.Remove(chemID)

		if (!(status & ORGAN_BROKEN))
			perma_injury = FALSE

		//Infections
		update_germs()
	else
		..()

//Updating germ levels. Handles organ germ levels and necrosis.
/*
The INFECTION_LEVEL values defined in setup.dm control the time it takes to reach the different
infection levels. Since infection growth is exponential, you can adjust the time it takes to get
from one germ_level to another using the rough formula:

desired_germ_level = initial_germ_level*e^(desired_time_in_seconds/1000)

So if I wanted it to take an average of 15 minutes to get from level one (100) to level two
I would set INFECTION_LEVEL_TWO to 100*e^(15*60/1000) = 245. Note that this is the average time,
the actual time is dependent on RNG.

INFECTION_LEVEL_ONE		below this germ level nothing happens, and the infection doesn't grow
INFECTION_LEVEL_TWO		above this germ level the infection will start to spread to internal and adjacent organs
INFECTION_LEVEL_THREE	above this germ level the player will take additional toxin damage per second, and will die in minutes without
						antitox. also, above this germ level you will need to overdose on penicillin to reduce the germ_level.

Note that amputating the affected organ does in fact remove the infection from the player's body.
*/
/obj/item/organ/external/proc/update_germs()

	if (owner.bodytemperature >= 170)	//cryo stops germs from moving and doing their bad stuffs
		//** Syncing germ levels with external wounds
		handle_germ_sync()

		//** Handle antibiotics and curing infections
		handle_antibiotics()

		//** Handle the effects of infections
		handle_germ_effects()

/obj/item/organ/external/proc/handle_germ_sync()
	var/antibiotics = owner.reagents.get_reagent_amount("penicillin")
	for (var/datum/wound/W in wounds)
		//Open wounds can become infected
		if (owner.germ_level > W.germ_level && W.infection_check())
			W.germ_level+=0.5

	if (antibiotics < 5)
		for (var/datum/wound/W in wounds)
			//Infected wounds raise the organ's germ level
			if (W.germ_level > germ_level)
				germ_level+=0.5
				break	//limit increase to a maximum of one per second

/obj/item/organ/external/handle_germ_effects()

	if (germ_level < INFECTION_LEVEL_TWO)
		return ..()

	var/antibiotics = owner.reagents.get_reagent_amount("penicillin")

	if (germ_level >= INFECTION_LEVEL_TWO)
		//spread the infection to internal organs
		var/obj/item/organ/target_organ = null	//make internal organs become infected one at a time instead of all at once
		for (var/obj/item/organ/I in internal_organs)
			if (I.germ_level > 0 && I.germ_level < min(germ_level, INFECTION_LEVEL_TWO))	//once the organ reaches whatever we can give it, or level two, switch to a different one
				if (!target_organ || I.germ_level > target_organ.germ_level)	//choose the organ with the highest germ_level
					target_organ = I

		if (!target_organ)
			//figure out which organs we can spread germs to and pick one at random
			var/list/candidate_organs = list()
			for (var/obj/item/organ/I in internal_organs)
				if (I.germ_level < germ_level)
					candidate_organs |= I
			if (candidate_organs.len)
				target_organ = pick(candidate_organs)

		if (target_organ)
			target_organ.germ_level+=0.5

		//spread the infection to child and parent organs
		if (children)
			for (var/obj/item/organ/external/child in children)
				if (child.germ_level < germ_level)
					if (child.germ_level < INFECTION_LEVEL_ONE*2 || prob(30))
						child.germ_level+=0.5

		if (parent)
			if (parent.germ_level < germ_level)
				if (parent.germ_level < INFECTION_LEVEL_ONE*2 || prob(30))
					parent.germ_level+=0.5

	if (germ_level >= INFECTION_LEVEL_THREE && antibiotics < 30)	//overdosing is necessary to stop severe infections
		if (!(status & ORGAN_DEAD))
			status |= ORGAN_DEAD
			owner << "<span class='notice'>You can't feel your [name] anymore...</span>"
			owner.update_body(1)

		germ_level+=0.5
		owner.adjustToxLoss(1)

//Updating wounds. Handles wound natural I had some free spachealing, internal bleedings and infections
/obj/item/organ/external/proc/update_wounds()

	for (var/datum/wound/W in wounds)
		// wounds can disappear after 10 minutes at the earliest
		if (W.damage <= 0 && W.created + 10 * 10 * 60 <= world.time)
			wounds -= W
			continue
			// let the GC handle the deletion of the wound

		// Internal wounds get worse over time. Low temperatures (cryo) stop them.
		if (W.internal && owner.bodytemperature >= 170)
			var/adrenaline = owner.reagents.get_reagent_amount("adrenaline")
			if (!(W.can_autoheal() || (adrenaline)))	//adrenaline stops internal wounds from growing bigger with time, unless it is so small that it is already healing
				W.open_wound(0.1 * wound_update_accuracy)
			var/blooddrop = W.damage/40
			if (applied_pressure)
				blooddrop *= 0.3
			owner.vessel.remove_reagent("blood", wound_update_accuracy * blooddrop) //line should possibly be moved to handle_blood, so all the bleeding stuff is in one place.
			if (prob(1 * wound_update_accuracy))
				owner.custom_pain("You feel a stabbing pain in your [name]!",60)

		// slow healing
		var/heal_amt = FALSE

		// if damage >= 50 AFTER treatment then it's probably too severe to heal within the timeframe of a round.
		if (W.can_autoheal() && W.wound_damage() < 50)
			heal_amt += 0.5

		//salved wounds heal faster
		if (W.salved)
			heal_amt *= 1.2
		//we only update wounds once in [wound_update_accuracy] ticks so have to emulate realtime
		heal_amt *= wound_update_accuracy
		//configurable regen speed woo, no-regen hardcore or instaheal hugbox, choose your destiny
		heal_amt *= config.organ_regeneration_multiplier
		// amount of healing is spread over all the wounds
		heal_amt /= (wounds.len + 1)
		// making it look prettier on scanners
		heal_amt = round(heal_amt,0.1)
		W.heal_damage(heal_amt)

		// Salving also helps against infection
		if (W.germ_level > 0 && W.salved && prob(2))
			W.disinfected = TRUE
			W.germ_level = FALSE

	// sync the organ's damage with its wounds
	update_damages()
	if (update_damstate())
		owner.UpdateDamageIcon(1)

//Updates brute_damn and burn_damn from wound damages. Updates BLEEDING status.
/obj/item/organ/external/proc/update_damages()

	number_wounds = 0
	brute_dam = 0
	burn_dam = 0
	status &= ~ORGAN_BLEEDING
	var/clamped = FALSE

	var/mob/living/human/H
	if (istype(owner,/mob/living/human))
		H = owner

	//update damage counts
	for (var/datum/wound/W in wounds)
		if (!W.internal) //so IB doesn't count towards crit/paincrit
			switch(W.damage_type)
				if (BURN)
					burn_dam += W.damage
				else if (PIERCE)
					brute_dam += W.damage
					pierce_dam += W.damage
				else if (CUT)
					brute_dam += W.damage
					cut_dam += W.damage
				else if (BRUISE)
					brute_dam += W.damage
					blunt_dam += W.damage
		if (W.bleeding() && (H && !(H.species.flags & NO_BLOOD)))
			W.bleed_timer--
			status |= ORGAN_BLEEDING

		clamped |= W.clamped

		number_wounds += W.amount

	//things tend to bleed if they are CUT OPEN
	if (open && !clamped && (H && !(H.species.flags & NO_BLOOD)))
		status |= ORGAN_BLEEDING

	//Bone fractures
	if (blunt_dam >= min_broken_damage * config.organ_health_multiplier && !H.buckled && !H.resting)
		if (blunt_dam > fracturetimer+20)
			fracture()

	if (!(brute_dam+burn_dam) || !number_wounds)
		disfigured = FALSE

	damage = brute_dam + burn_dam

	update_damage_ratios()

//Returns TRUE if damage_state changed
/obj/item/organ/external/proc/update_damstate()
	var/n_is = damage_state_text()
	if (n_is != damage_state)
		damage_state = n_is
		return TRUE
	return FALSE

// new damage icon system
// returns just the brute/burn damage code
/obj/item/organ/external/proc/damage_state_text()

	var/tburn = FALSE
	var/tbrute = FALSE

	if (burn_dam ==0)
		tburn =0
	else if (burn_dam < (max_damage * 0.25 / 2))
		tburn = TRUE
	else if (burn_dam < (max_damage * 0.75 / 2))
		tburn = 2
	else
		tburn = 3

	if (brute_dam == FALSE)
		tbrute = FALSE
	else if (brute_dam < (max_damage * 0.25 / 2))
		tbrute = TRUE
	else if (brute_dam < (max_damage * 0.75 / 2))
		tbrute = 2
	else
		tbrute = 3
	return "[tbrute][tburn]"

/****************************************************
			   DISMEMBERMENT
****************************************************/

//Handles dismemberment
/obj/item/organ/external/proc/droplimb(var/clean, var/disintegrate = DROPLIMB_EDGE, var/ignore_children = null)

	if (cannot_amputate || !owner)
		return

	switch(disintegrate)
		if (DROPLIMB_EDGE)
			if (!clean)
				var/gore_sound = "ripping tendons and flesh"
				owner.visible_message(
					"<span class='danger'>\The [owner]'s [name] flies off in an arc!</span>",\
					"<span class='moderate'><b>Your [name] goes flying off!</b></span>",\
					"<span class='danger'>You hear a terrible sound of [gore_sound].</span>")
			playsound(owner, 'sound/effects/gore/severed.ogg', 100, FALSE)//Pay the sound whether or not it's being amputated cleanly. Because I ilke that sound.
		if (DROPLIMB_BURN)
			var/gore = " of burning flesh"
			owner.visible_message(
				"<span class='danger'>\The [owner]'s [name] flashes away into ashes!</span>",\
				"<span class='moderate'><b>Your [name] flashes away into ashes!</b></span>",\
				"<span class='danger'>You hear a crackling sound[gore].</span>")
		if (DROPLIMB_BLUNT)
			if (!istype(src, /obj/item/organ/external/head))
				var/gore = " in a shower of gore"
				var/gore_sound = "sickening splatter of gore"
				owner.visible_message(
					"<span class='danger'>\The [owner]'s [name] explodes[gore]!</span>",\
					"<span class='moderate'><b>Your [name] explodes[gore]!</b></span>",\
					"<span class='danger'>You hear the [gore_sound].</span>")
				playsound(owner, "chop", 100 , FALSE)//Splat.
			else
				owner.death()
				playsound(owner, "chop", 100 , FALSE)//Splat.

	var/mob/living/human/victim = owner //Keep a reference for post-removed().
	var/obj/item/organ/external/parent_organ = parent

	if (disintegrate != DROPLIMB_BLUNT)
		removed(null, ignore_children)

		victim.traumatic_shock += 60

		if (parent_organ)
			var/datum/wound/lost_limb/W = new (src, disintegrate, clean)
			var/obj/item/organ/external/stump/stump = new (victim, FALSE, src)
			stump.artery_name = "mangled [artery_name]"
			stump.name = "stump of \a [name]"
			stump.wounds |= W
			victim.organs |= stump
			stump.update_damages()

	spawn(1)
		if (victim)
			victim.updatehealth()
			victim.UpdateDamageIcon()
			victim.regenerate_icons()
		dir = 2
	victim.instadeath_check()
	switch(disintegrate)
		if (DROPLIMB_EDGE)
			compile_icon()
			add_blood(victim)
			var/matrix/M = matrix()
			M.Turn(rand(180))
			transform = M
			if (!clean)
				// Throw limb around.
				if (src && istype(loc,/turf))
					throw_at(get_edge_target_turf(src,pick(alldirs)),rand(1,3),30)
				dir = 2
		if (DROPLIMB_BURN)
			new /obj/effect/decal/cleanable/ash(get_turf(victim))
			for (var/obj/item/I in src)
				if (I.w_class > 2 && !istype(I,/obj/item/organ))
					I.loc = get_turf(src)
			qdel(src)
		if (DROPLIMB_BLUNT)
			if (!istype(src, /obj/item/organ/external/head))
				var/obj/effect/decal/cleanable/blood/gibs/gore = new victim.species.single_gib_type(get_turf(victim))
				if (victim.species.flesh_color)
					gore.fleshcolor = victim.species.flesh_color
				if (victim.species.blood_color)
					gore.basecolor = victim.species.blood_color
				gore.update_icon()
				gore.throw_at(get_edge_target_turf(src,pick(alldirs)),rand(1,3),30)

				for (var/obj/item/organ/I in internal_organs)
					I.removed()
					if (istype(loc,/turf))
						I.throw_at(get_edge_target_turf(src,pick(alldirs)),rand(1,3),30)

				for (var/obj/item/I in src)
					if (I.w_class <= 2)
						qdel(I)
						continue
					I.loc = get_turf(src)
					I.throw_at(get_edge_target_turf(src,pick(alldirs)),rand(1,3),30)

				qdel(src)

/****************************************************
			   HELPERS
****************************************************/

/obj/item/organ/external/proc/update_damage_ratios()
	var/limb_loss_threshold = max_damage
	brute_ratio = brute_dam / (limb_loss_threshold * 2)
	burn_ratio = burn_dam / (limb_loss_threshold * 2)

/obj/item/organ/external/proc/is_stump()
	return FALSE

/obj/item/organ/external/proc/release_restraints(var/mob/living/human/holder)
	if (!holder)
		holder = owner
	if (!holder)
		return
	if (holder.handcuffed && body_part in list(ARM_LEFT, ARM_RIGHT, HAND_LEFT, HAND_RIGHT))
		holder.visible_message(\
			"\The [holder.handcuffed.name] falls off of [holder.name].",\
			"\The [holder.handcuffed.name] falls off you.")
		holder.drop_from_inventory(holder.handcuffed)
	if (holder.legcuffed && body_part in list(FOOT_LEFT, FOOT_RIGHT, LEG_LEFT, LEG_RIGHT))
		holder.visible_message(\
			"\The [holder.legcuffed.name] falls off of [holder.name].",\
			"\The [holder.legcuffed.name] falls off you.")
		holder.drop_from_inventory(holder.legcuffed)

// checks if all wounds on the organ are bandaged
/obj/item/organ/external/proc/is_bandaged()
	for (var/datum/wound/W in wounds)
		if (W.internal) continue
		if (!W.bandaged)
			return FALSE
	return TRUE

// checks if all wounds on the organ are salved
/obj/item/organ/external/proc/is_salved()
	for (var/datum/wound/W in wounds)
		if (W.internal) continue
		if (!W.salved)
			return FALSE
	return TRUE

// checks if all wounds on the organ are disinfected
/obj/item/organ/external/proc/is_disinfected()
	for (var/datum/wound/W in wounds)
		if (W.internal) continue
		if (!W.disinfected)
			return FALSE
	return TRUE

/obj/item/organ/external/proc/bandage()
	var/rval = FALSE
	status &= ~ORGAN_BLEEDING
	for (var/datum/wound/W in wounds)
		if (W.internal) continue
		rval |= !W.bandaged
		W.bandaged = TRUE
	return rval

/obj/item/organ/external/proc/salve()
	var/rval = FALSE
	for (var/datum/wound/W in wounds)
		if (W.internal) continue
		rval |= !W.salved
		W.salved = TRUE
		W.germ_level *= 0.5
	return rval

/obj/item/organ/external/proc/disinfect()
	var/rval = FALSE
	for (var/datum/wound/W in wounds)
		if (W.internal) continue
		rval |= !W.disinfected
		W.disinfected = TRUE
		W.germ_level = FALSE
	return rval

/obj/item/organ/external/proc/clamping()
	var/rval = FALSE
	status &= ~ORGAN_BLEEDING
	for (var/datum/wound/W in wounds)
		if (W.internal) continue
		rval |= !W.clamped
		W.clamped = TRUE
	return rval

/obj/item/organ/external/proc/fracture()
	if ((status & ORGAN_BROKEN) || cannot_break)
		return

	if (owner)
		playsound(owner, "trauma", 75, FALSE)
		if (owner.species && !(owner.species.flags & NO_PAIN))
			owner.emote("painscream")

	status |= ORGAN_BROKEN
	broken_description = "broken"//pick("broken","fracture","hairline fracture")
	perma_injury = brute_dam

	// Fractures have a chance of getting you out of restraints
	if (prob(25))
		release_restraints()
	return

/obj/item/organ/external/proc/mend_fracture()
	status &= ~ORGAN_BROKEN
	return TRUE


/obj/item/organ/external/proc/get_damage()	//returns total damage
	return max(brute_dam + burn_dam - perma_injury, perma_injury)	//could use max_damage?

/obj/item/organ/external/proc/has_infected_wound()
	for (var/datum/wound/W in wounds)
		if (W.germ_level > INFECTION_LEVEL_ONE)
			return TRUE
	return FALSE

/obj/item/organ/external/is_usable()
	return !is_dislocated() && !(status & (ORGAN_MUTATED|ORGAN_DEAD))

/obj/item/organ/external/proc/embed(var/obj/item/weapon/W, var/silent = FALSE, var/supplied_message)

	// w_class 2 tends to not embed, w_class 3+ never embeds - Kachnov
	if (W.w_class == 2 && prob(60))
		return
	else if (W.w_class > 2)
		return

	if (!owner || loc != owner)
		return
	if (!silent)
		if (supplied_message)
			owner.visible_message("<span class='danger'>[supplied_message]</span>")
		else
			owner.visible_message("<span class='danger'>\The [W] sticks in the wound!</span>")
	implants += W
	owner.embedded_flag = TRUE
	owner.verbs += /mob/proc/yank_out_object
	W.add_blood(owner)
	if (ismob(W.loc))
		var/mob/living/H = W.loc
		H.drop_from_inventory(W)
	W.loc = owner

/obj/item/organ/external/removed(var/mob/living/user, var/ignore_children = FALSE)

	if (!owner)
		return

	var/mob/living/human/victim = owner

	..()

	victim.bad_external_organs -= src

	for (var/atom/movable/implant in implants)
		//large items and non-item objs fall to the floor, everything else stays
		var/obj/item/I = implant
		if (istype(I) && I.w_class < 3)
			implant.loc = get_turf(victim.loc)
		else
			implant.loc = src

	implants.Cut()

	// Attached organs also fly off.
	if (!ignore_children)
		for (var/obj/item/organ/external/O in children)
			O.removed()
			if (O)
				O.loc = src
				for (var/obj/item/I in O.contents)
					I.loc = src

	// Grab all the internal giblets too.
	for (var/obj/item/organ/organ in internal_organs)
		organ.removed()
		organ.loc = src

	// Remove parent references
	parent.children -= src
	parent = null

	release_restraints(victim)
	victim.organs -= src
	victim.organs_by_name[limb_name] = null // Remove from owner's vars.


/obj/item/organ/external/proc/disfigure(var/type = "brute")
	if (disfigured)
		return
	/*if (owner)
		if (type == "brute")
			owner.visible_message("\red You hear a sickening cracking sound coming from \the [owner]'s [name].",	\
			"\red <b>Your [name] becomes a mangled mess!</b>",	\
			"\red You hear a sickening crack.")
		else
			owner.visible_message("\red \The [owner]'s [name] melts away, turning into mangled mess!",	\
			"\red <b>Your [name] melts away!</b>",	\
			"\red You hear a sickening sizzle.")
	*/ //No! Fuck that shit.
	disfigured = TRUE

/obj/item/organ/external/proc/get_wounds_desc()
	. = ""
	if (status & ORGAN_DESTROYED && !is_stump())
		. += "tear at [amputation_point] so severe that it hangs by a scrap of flesh"

	var/list/wound_descriptors = list()
	if (open > 1)
		wound_descriptors["an open incision"] = TRUE
	else if (open)
		wound_descriptors["an incision"] = TRUE
	for (var/datum/wound/W in wounds)
		if (W.internal && !open) continue // can't see internal wounds
		var/this_wound_desc = W.desc
		if (W.damage_type == BURN && W.salved) this_wound_desc = "salved [this_wound_desc]"
		if (W.bleeding()) this_wound_desc = "bleeding [this_wound_desc]"
		else if (W.bandaged) this_wound_desc = "bandaged [this_wound_desc]"
		if (W.germ_level > 600) this_wound_desc = "badly infected [this_wound_desc]"
		else if (W.germ_level > 330) this_wound_desc = "lightly infected [this_wound_desc]"
		if (wound_descriptors[this_wound_desc])
			wound_descriptors[this_wound_desc] += W.amount
		else
			wound_descriptors[this_wound_desc] = W.amount

	if (wound_descriptors.len)
		var/list/flavor_text = list()
		var/list/no_exclude = list("gaping wound", "big gaping wound", "massive wound", "large bruise",\
		"huge bruise", "massive bruise", "severe burn", "large burn", "deep burn", "carbonised area") //note to self make this more robust
		for (var/wound in wound_descriptors)
			switch(wound_descriptors[wound])
				if (1)
					flavor_text += "[prob(10) && !(wound in no_exclude) ? "what might be " : ""]a [wound]"
				if (2)
					flavor_text += "[prob(10) && !(wound in no_exclude) ? "what might be " : ""]a pair of [wound]s"
				if (3 to 5)
					flavor_text += "several [wound]s"
				if (6 to INFINITY)
					flavor_text += "a ton of [wound]\s"
		return english_list(flavor_text)

/****************************************************
			   ORGAN DEFINES
****************************************************/

/obj/item/organ/external/chest
	name = "upper body"
	limb_name = "chest"
	icon_name = "torso"
	min_broken_damage = 55
	max_damage = 101
	w_class = ITEM_SIZE_HUGE
	body_part = UPPER_TORSO
	vital = TRUE
	amputation_point = "spine"
	joint = "neck"
	dislocated = -1
//	gendered_icon = TRUE
	cannot_amputate = TRUE
	parent_organ = null
	artery_name = "aorta"
	encased = "ribcage"
	cavity_name = "thoracic"

/obj/item/organ/external/groin
	name = "lower body"
	limb_name = "groin"
	icon_name = "groin"
	min_broken_damage = 55
	max_damage = 101
	w_class = ITEM_SIZE_HUGE
	body_part = LOWER_TORSO
	cannot_amputate = TRUE
	vital = TRUE
	parent_organ = "chest"
	amputation_point = "lumbar"
	joint = "hip"
	dislocated = -1
//	gendered_icon = TRUE
	artery_name = "iliac artery"
	cavity_name = "abdominal"

/obj/item/organ/external/arm
	limb_name = "l_arm"
	name = "left arm"
	icon_name = "l_arm"
	min_broken_damage = 40
	max_damage = 60
	w_class = ITEM_SIZE_NORMAL
	body_part = ARM_LEFT
	parent_organ = "chest"
	joint = "left elbow"
	amputation_point = "left shoulder"
	can_grasp = TRUE
	artery_name = "basilic vein"
/obj/item/organ/external/arm/right
	limb_name = "r_arm"
	name = "right arm"
	icon_name = "r_arm"
	body_part = ARM_RIGHT
	joint = "right elbow"
	amputation_point = "right shoulder"

/obj/item/organ/external/leg
	limb_name = "l_leg"
	name = "left leg"
	icon_name = "l_leg"
	min_broken_damage = 40
	max_damage = 70
	w_class = ITEM_SIZE_NORMAL
	body_part = LEG_LEFT
	icon_position = LEFT
	parent_organ = "groin"
	joint = "left knee"
	amputation_point = "left hip"
	can_stand = TRUE
	artery_name = "femoral artery"
/obj/item/organ/external/leg/right
	limb_name = "r_leg"
	name = "right leg"
	icon_name = "r_leg"
	body_part = LEG_RIGHT
	icon_position = RIGHT
	joint = "right knee"
	amputation_point = "right hip"

/obj/item/organ/external/foot
	limb_name = "l_foot"
	name = "left foot"
	icon_name = "l_foot"
	min_broken_damage = 35
	max_damage = 65
	w_class = ITEM_SIZE_SMALL
	body_part = FOOT_LEFT
	icon_position = LEFT
	parent_organ = "l_leg"
	joint = "left ankle"
	amputation_point = "left ankle"
	can_stand = TRUE
/obj/item/organ/external/foot/removed()
	if (owner) owner.u_equip(owner.shoes)
	..()

/obj/item/organ/external/foot/right
	limb_name = "r_foot"
	name = "right foot"
	icon_name = "r_foot"
	body_part = FOOT_RIGHT
	icon_position = RIGHT
	parent_organ = "r_leg"
	joint = "right ankle"
	amputation_point = "right ankle"

/obj/item/organ/external/hand
	limb_name = "l_hand"
	name = "left hand"
	icon_name = "l_hand"
	min_broken_damage = 35
	max_damage = 60
	w_class = ITEM_SIZE_SMALL
	body_part = HAND_LEFT
	parent_organ = "l_arm"
	joint = "left wrist"
	amputation_point = "left wrist"
	can_grasp = TRUE
/obj/item/organ/external/hand/removed()
	owner.u_equip(owner.gloves)
	..()

/obj/item/organ/external/hand/right
	limb_name = "r_hand"
	name = "right hand"
	icon_name = "r_hand"
	body_part = HAND_RIGHT
	parent_organ = "r_arm"
	joint = "right wrist"
	amputation_point = "right wrist"

/obj/item/organ/external/head
	limb_name = "head"
	icon_name = "head"
	name = "head"
	min_broken_damage = 40
	max_damage = 60
	w_class = ITEM_SIZE_NORMAL
	body_part = HEAD
	vital = TRUE
	parent_organ = "chest"
	joint = "jaw"
	amputation_point = "neck"
	artery_name = "carotid artery"
	var/list/teeth_list = list()
	var/max_teeth = 32
	var/eye_icon = "eyes_s"
	var/eye_icon_location = 'icons/mob/human_face.dmi'

/obj/item/organ/external/head/removed()
	if (owner)
		name = "[owner.real_name]'s head"
		owner.u_equip(owner.head)
		owner.u_equip(owner.l_ear)
		owner.u_equip(owner.r_ear)
		owner.u_equip(owner.wear_mask)
		spawn(1)
			if (owner)
				owner.update_hair()
	..()

/obj/item/organ/external/head/take_damage(brute, burn, sharp, edge, used_weapon = null, list/forbidden_limbs = list())
	..(brute, burn, sharp, edge, used_weapon, forbidden_limbs)
	if (!disfigured)
		if (brute_dam > 40)
			if (prob(50))
				disfigure("brute")
		if (burn_dam > 40)
			disfigure("burn")


/obj/item/organ/external/head/proc/get_hair_icon()
	var/image/res = image(species.icon_template,"")
	if(owner.f_style)
		var/icon/facial_s = new/icon("icon" = 'icons/mob/human_face.dmi', "icon_state" = "[owner.f_style]_s")
		facial_s.Blend(rgb(owner.r_facial, owner.g_facial, owner.b_facial))
		res.overlays |= facial_s

	if(owner.h_style)
		var/icon/hair_s = new/icon("icon" = 'icons/mob/human_face.dmi', "icon_state" = "[owner.h_style]_s")
		if(islist(h_col) && h_col.len >= 3)
			hair_s.Blend(rgb(h_col[1], h_col[2], h_col[3]))
		res.overlays |= hair_s
	return res


/obj/item/organ/external/head/proc/get_teeth() //returns collective amount of teeth
	var/amt = FALSE
	if (!teeth_list) teeth_list = list()
	for (var/obj/item/stack/teeth in teeth_list)
		amt += teeth.amount
	return amt

/obj/item/organ/external/head/proc/knock_out_teeth(throw_dir, num=32) //Won't support knocking teeth out of a dismembered head or anything like that yet.
	num = Clamp(num, TRUE, 32)
	var/done = FALSE
	if (teeth_list && teeth_list.len) //We still have teeth
		var/stacks = rand(1,3)
		for (var/curr = TRUE to stacks) //Random amount of teeth stacks
			var/obj/item/stack/teeth/teeth = pick(teeth_list)
			if (!teeth || teeth.zero_amount()) return //No teeth left, abort!
			var/drop = round(min(teeth.amount, num)/stacks) //Calculate the amount of teeth in the stack
			var/obj/item/stack/teeth/T = new teeth.type(owner.loc, drop)
			teeth.use(drop)
			T.add_blood(owner)
			playsound(owner, "trauma", 75, FALSE)
			var/turf/target = get_turf(owner.loc)
			var/range = rand(1, 3)//T.throw_range)
			for (var/i = TRUE; i < range; i++)
				var/turf/new_turf = get_step(target, throw_dir)
				target = new_turf
				if (new_turf && new_turf.density)
					break
			T.throw_at(target,T.throw_range,T.throw_speed)
			teeth.zero_amount() //Try to delete the teeth
			done = TRUE
	return done


/obj/item/stack/teeth
	name = "teeth"
	singular_name = "tooth"
	w_class = ITEM_SIZE_TINY
	throwforce = 2
	max_amount = 32
	desc = "Welp. Someone had their teeth knocked out."
	icon = 'icons/mob/surgery.dmi'
	icon_state = "tooth"

/obj/item/stack/teeth/New()
	..()
	icon_state = "tooth"

/obj/item/stack/teeth/human
	name = "human teeth"
	singular_name = "human tooth"

/obj/item/stack/teeth/generic //Used for species without unique teeth defined yet
	name = "teeth"

/obj/item/stack/proc/zero_amount()//Teeth shit
	if (amount < 1)
		qdel(src)
		return TRUE
	return FALSE


/obj/item/organ/external/proc/sever_artery()
	if(!(status & ORGAN_ARTERY_CUT) && species && species.has_organ["heart"])
		status |= ORGAN_ARTERY_CUT
		if(artery_name == "carotid artery" && owner)
			playsound(owner.loc, 'sound/voice/throat.ogg', 50, 1, -1)
		return TRUE
	return FALSE


/obj/item/organ/external/proc/jostle_bone(force)
	if(!(status & ORGAN_BROKEN)) //intact bones stay still
		return
	if(brute_dam + force < min_broken_damage/5)	//no papercuts moving bones
		return
	if(internal_organs.len && prob(brute_dam + force))
		owner.custom_pain("A piece of bone in your [name] moves painfully!", 50)
		var/obj/item/organ/I = pick(internal_organs)
		I.take_damage(rand(3,5))

// Pain/halloss
/obj/item/organ/external/proc/get_pain()

	update_health()
	var/lasting_pain = 0
	if(is_broken())
		lasting_pain += 10
	else if(is_dislocated())
		lasting_pain += 5
	return pain + lasting_pain + (1.2 * brute_dam) + (1.5 * burn_dam)

/obj/item/organ/external/proc/remove_pain(var/amount)

	update_health()
	var/last_pain = pain
	pain = max(0,min(max_damage,pain-amount))
	return -(pain-last_pain)

/obj/item/organ/external/proc/add_pain(var/amount)

	update_health()
	var/last_pain = pain
	pain = max(0,min(max_damage,pain+amount))
	if(owner && ((amount > 15 && prob(20)) || (amount > 30 && prob(60))))
		owner.emote("painscream")
	return pain-last_pain

/obj/item/organ/external/proc/stun_act(var/stun_amount, var/agony_amount)
	return

/obj/item/organ/external/proc/get_agony_multiplier()
	return 1