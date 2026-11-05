// Treatments a medical stack applies to each outer wound it covers.
#define MED_BANDAGE 1
#define MED_DISINFECT 2
#define MED_SALVE 4

/obj/item/stack/medical
	name = "medical pack"
	singular_name = "medical pack"
	icon = 'icons/obj/items.dmi'
	amount = 30
	max_amount = 30
	w_class = ITEM_SIZE_SMALL
	throw_speed = 4
	throw_range = 20
	var/heal_brute = 0
	var/heal_burn = 0
	var/treat_flags = 0				// MED_* flags; 0 means the subtype handles its own use (splints)
	var/heals_wounds = FALSE		// heal_brute/heal_burn also heal human wounds (otherwise only animals)
	var/expert_closes = FALSE		// very high medical skill closes fully treated outer wounds at once
	var/treat_verb = "treats"		// "[user] [treat_verb] a cut on ..."
	var/treat_verb_self = "treat"	// "You [treat_verb_self] a cut on ..."
	value = 0

/obj/item/stack/medical/attack(mob/living/human/C as mob, mob/user as mob)
	if (!istype(C) )
		if (!istype(C, /mob/living/simple_animal))
			to_chat(user, SPAN_WARNING("\The [src] cannot be applied to [C]!"))
		return TRUE

	if (!istype(user, /mob/living/human))
		to_chat(user, SPAN_WARNING("You don't have the dexterity to do this!"))
		return TRUE

	if (!treat_flags)
		return FALSE
	treat(C, user)
	return TRUE

// TRUE when this stack still has something to do for the wound.
/obj/item/stack/medical/proc/wound_needs(datum/wound/W)
	if (W.internal)
		return FALSE
	if ((treat_flags & MED_BANDAGE) && !W.bandaged)
		return TRUE
	if ((treat_flags & MED_DISINFECT) && !W.disinfected)
		return TRUE
	if ((treat_flags & MED_SALVE) && !W.salved)
		return TRUE
	return FALSE

/obj/item/stack/medical/proc/limb_needs(obj/item/organ/external/E)
	for (var/datum/wound/W in E.wounds)
		if (wound_needs(W))
			return TRUE
	return FALSE

// Subtype hook run before wound treatment; return TRUE when it used the click.
/obj/item/stack/medical/proc/pre_treat(mob/living/human/H, obj/item/organ/external/affecting, mob/user)
	return FALSE

/obj/item/stack/medical/proc/try_expert_close(obj/item/organ/external/affecting, mob/user)
	var/mob/living/human/healer = user
	if (!expert_closes || !istype(healer) || affecting.open || limb_needs(affecting))
		return
	if (healer.getStatCoeff("medical") >= GET_MIN_STAT_COEFF(STAT_VERY_HIGH))
		affecting.clear_treated_external_wounds()

// Shared wound treatment for every bandage, kit, herb and powder.
/obj/item/stack/medical/proc/treat(mob/living/human/H, mob/user)
	var/obj/item/organ/external/affecting = H.get_organ(user.targeted_organ)
	if (!affecting)
		return
	if (pre_treat(H, affecting, user))
		return
	if (affecting.open)
		if (can_operate(H) && do_surgery(H, user, src))
			return
		to_chat(user, SPAN_NOTICE("The [affecting.name] is cut open, you'll need more than \the [src]!"))
		return
	if (!limb_needs(affecting))
		to_chat(user, SPAN_WARNING("The wounds on [H]'s [affecting.name] have already been treated."))
		try_expert_close(affecting, user)
		return
	user.visible_message(SPAN_NOTICE("\The [user] starts treating [H]'s [affecting.name]."), \
						SPAN_NOTICE("You start treating [H]'s [affecting.name]."))
	var/used = 0
	for (var/datum/wound/W in affecting.wounds)
		if (!wound_needs(W))
			continue
		if (used >= amount)
			break
		if (!do_mob(user, H, W.damage/5))
			to_chat(user, SPAN_NOTICE("You must stand still to treat wounds."))
			break
		if (used >= amount || !wound_needs(W))
			continue // the stack shrank or someone else treated it meanwhile
		user.visible_message(SPAN_NOTICE("\The [user] [treat_verb] \a [W.desc] on [H]'s [affecting.name]."), \
							SPAN_NOTICE("You [treat_verb_self] \a [W.desc] on [H]'s [affecting.name]."))
		if (treat_flags & MED_BANDAGE)
			W.bandage()
		if (treat_flags & MED_DISINFECT)
			W.disinfect()
		if (treat_flags & MED_SALVE)
			W.salve()
		if (heals_wounds)
			W.heal_damage(W.damage_type == BURN ? heal_burn : heal_brute)
		used++
	// Cleaning the wounds also knocks back an infection that has not spread yet.
	if (used && (treat_flags & MED_DISINFECT) && affecting.germ_level < INFECTION_LEVEL_TWO)
		affecting.germ_level = max(0, affecting.germ_level - 100)
	affecting.update_damages()
	if (used >= amount && limb_needs(affecting))
		to_chat(user, SPAN_WARNING("\The [src] is used up, but there are more wounds to treat on \the [affecting.name]."))
	try_expert_close(affecting, user)
	if (treat_flags & MED_BANDAGE)
		H.update_bandaging(1)
	H.UpdateDamageIcon()
	H.updatehealth()
	if (used)
		use(min(used, amount))

/obj/item/stack/medical/bruise_pack
	name = "roll of gauze"
	singular_name = "gauze length"
	desc = "Some sterile gauze to wrap around bloody stumps."
	icon_state = "brutepack"
	flammable = TRUE
	treat_flags = MED_BANDAGE
	treat_verb = "bandages"
	treat_verb_self = "bandage"

/obj/item/stack/medical/bruise_pack/pre_treat(mob/living/human/H, obj/item/organ/external/affecting, mob/user)
	return try_tourniquet(H, affecting, user)

// Any bandage roll doubles as a tourniquet: tighten it above a severed limb
// artery, or loosen an existing one once the artery has stopped bleeding.
/obj/item/stack/medical/bruise_pack/proc/try_tourniquet(mob/living/human/H, obj/item/organ/external/affecting, mob/user)
	if (affecting.tourniquet)
		if (affecting.status & ORGAN_ARTERY_CUT)
			return FALSE // keep it tight; bandage the wounds underneath instead
		user.visible_message(SPAN_NOTICE("\The [user] starts loosening the tourniquet on [H]'s [affecting.name]."), \
							SPAN_NOTICE("You start loosening the tourniquet on [H]'s [affecting.name]."))
		if (!do_mob(user, H, 20) || !affecting.tourniquet)
			return TRUE
		affecting.remove_tourniquet()
		user.visible_message(SPAN_NOTICE("\The [user] removes the tourniquet from [H]'s [affecting.name]."), \
							SPAN_NOTICE("You remove the tourniquet from [H]'s [affecting.name]."))
		return TRUE
	if (!(affecting.status & ORGAN_ARTERY_CUT) || !affecting.can_take_tourniquet() || affecting.is_tourniqueted())
		return FALSE
	user.visible_message(SPAN_NOTICE("\The [user] starts tying \a [singular_name] tight above the wound on [H]'s [affecting.name]."), \
						SPAN_NOTICE("You start tying \a [singular_name] tight above the wound on [H]'s [affecting.name]."))
	if (!do_mob(user, H, 30) || affecting.is_tourniqueted() || !use(1))
		return TRUE
	affecting.apply_tourniquet()
	user.visible_message(SPAN_NOTICE("\The [user] tightens a tourniquet on [H]'s [affecting.name]. The bleeding stops."), \
						SPAN_NOTICE("You tighten a tourniquet on [H]'s [affecting.name]. The bleeding stops. Bandage the wound, then loosen it within half an hour."))
	return TRUE


/obj/item/stack/medical/advanced/bruise_pack
	name = "trauma kit"
	singular_name = "trauma kit"
	desc = "An advanced trauma kit for severe injuries."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "trauma_kit"
	item_state = "trauma_kit"
	heal_brute = 15
	flammable = TRUE
	treat_flags = MED_BANDAGE|MED_DISINFECT
	heals_wounds = TRUE
	expert_closes = TRUE
	treat_verb = "cleans and dresses"
	treat_verb_self = "clean and dress"

/obj/item/stack/medical/advanced/herbs
	name = "healing herbs"
	singular_name = "healing herb"
	desc = "Healing herbs from bushes. Apply to wounds, plant on ploughed soil, or use in hand to chew one as a slow illness remedy. Take three herbs across ten minutes without letting the remedy run out."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "healing_herbs"
	item_state = null
	amount = 10
	heal_brute = 5
	heal_burn = 5
	treat_flags = MED_DISINFECT|MED_SALVE
	heals_wounds = TRUE
	expert_closes = TRUE
	treat_verb = "rubs healing herbs over"
	treat_verb_self = "rub healing herbs over"

/obj/item/stack/medical/advanced/herbs/small
	amount = 1

/obj/item/stack/medical/advanced/herbs/attack_self(mob/user as mob)
	if (!ishuman(user) || user.stat != CONSCIOUS || !user.can_eat(src))
		return
	var/mob/living/human/H = user
	if (!H.ingested || H.ingested.get_free_space() < 10)
		to_chat(user, SPAN_WARNING("You cannot take another herb dose yet."))
		return
	H.ingested.add_reagent("herbal_remedy", 10)
	to_chat(user, SPAN_NOTICE("You chew a healing herb. It provides about three minutes of slow treatment; take another before it runs out. A full course takes ten minutes."))
	use(1)

/obj/item/stack/medical/advanced/sulfa
	name = "sulfanilamide powder packs"
	singular_name = "powder pack"
	desc = "A pack of powdered sulfanilamide, a sulfamide anti-septic."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "sulfa"
	item_state = "trauma_kit"
	amount = 20
	flammable = TRUE
	treat_flags = MED_DISINFECT
	treat_verb = "spreads sulfanilamide over"
	treat_verb_self = "spread sulfanilamide over"

/obj/item/stack/medical/advanced/sulfa/small
	amount = 5

/obj/item/stack/medical/advanced/ointment
	name = "burn kit"
	singular_name = "burn kit"
	desc = "An advanced treatment kit for severe burns."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "burn_kit"
	item_state = "burn_kit"
	heal_burn = 15
	amount = 10
	treat_flags = MED_SALVE
	heals_wounds = TRUE
	treat_verb = "smears burn ointment over"
	treat_verb_self = "smear burn ointment over"

/obj/item/stack/medical/splint
	name = "medical splints"
	singular_name = "medical splint"
	icon_state = "splint"
	amount = 5
	max_amount = 5
	flags = CONDUCT

/obj/item/stack/medical/splint/attack(mob/living/human/M as mob, mob/user as mob)
	if (..())
		return TRUE
	if (istype(M, /mob/living/human) && user.targeted_organ != "random")
		var/mob/living/human/H = M
		var/obj/item/organ/external/affecting = H.get_organ(user.targeted_organ)
		if (!affecting)
			return
		var/limb = affecting.name
		if (!(affecting.limb_name in list("chest", "head", "groin", "l_arm","r_arm","l_leg","r_leg", "l_hand", "r_hand", "l_foot", "r_foot")))
			to_chat(user, SPAN_WARNING("You can't apply a splint there!"))
			return
		else if (affecting.status & ORGAN_SPLINTED)
			to_chat(user,  SPAN_WARNING("[M]'s [limb] is already splinted!"))
			return
		else if (!(affecting.status & ORGAN_BROKEN) && !affecting.is_dislocated())
			to_chat(user,  SPAN_WARNING("[M]'s [limb] does not need splinting."))
			return
		if (M != user)
			user.visible_message(SPAN_NOTICE("[user] starts to apply \the [src] to [M]'s [limb]."), SPAN_DANGER("You start to apply \the [src] to [M]'s [limb]."), SPAN_DANGER("You hear something being wrapped."))
		else
			if ((!user.hand && affecting.limb_name == "r_arm") || (user.hand && affecting.limb_name == "l_arm"))
				to_chat(user,  SPAN_WARNING("You can't apply a splint to the arm you're using!"))
				return
			user.visible_message(SPAN_NOTICE("[user] starts to apply \the [src] to their [limb]."), SPAN_DANGER("You start to apply \the [src] to your [limb]."), SPAN_DANGER("You hear something being wrapped."))
		if (do_mob(user, M, 50))
			if (M != user)
				user.visible_message(SPAN_NOTICE("[user] finishes applying \the [src] to [M]'s [limb]."), SPAN_DANGER("You finish applying \the [src] to [M]'s [limb]."), SPAN_DANGER("You hear something being wrapped."))
			else
				if (prob(40 * H.getStatCoeff("medical")))
					user.visible_message(SPAN_NOTICE("[user] successfully applies \the [src] to their [limb]."), SPAN_DANGER("You successfully apply \the [src] to your [limb]."), SPAN_DANGER("You hear something being wrapped."))
				else
					user.visible_message(SPAN_WARNING("[user] fumbles \the [src]."), SPAN_DANGER("You fumble \the [src]."), SPAN_DANGER("You hear something being wrapped."))
					return
			affecting.status |= ORGAN_SPLINTED
			use(1)
		return

/obj/item/stack/medical/splint/small
	amount = 1
/obj/item/stack/medical/bruise_pack/bint
	name = "cloth bandages"
	singular_name = "cloth bandage"
	icon = 'icons/obj/surgery.dmi'
	icon_state = "bint"
	heal_brute = 10 // for healing dogs and other animals
	amount = 10

/obj/item/stack/medical/bruise_pack/bint/small
	amount = 1

/obj/item/stack/medical/bruise_pack/bint/medic
	amount = 40

/obj/item/stack/medical/bruise_pack/bint/leather
	name = "leather bandages"
	singular_name = "leather bandage"
	desc = "A crude bandage, made of thin animal leather."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "leatherbandage"
	heal_brute = 6 // for healing dogs and other animals
	amount = 6

/obj/item/stack/medical/bruise_pack/gauze
	name = "roll of gauze"
	singular_name = "gauze length"
	icon = 'icons/obj/surgery.dmi'
	icon_state = "gauze"
	heal_brute = 10 // for healing dogs and other animals
	amount = 10

/obj/item/bag_valve_mask
	name = "bag valve mask"
	desc = "A hand-held device commonly used to provide positive pressure ventilation to patients who are not breathing or not breathing adequately."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "valvemask"
/obj/item/bag_valve_mask/attack(var/mob/living/human/M as mob, var/mob/user as mob)
	if (M.wear_mask)
		to_chat(user, SPAN_WARNING("Uncover their mouth first!"))
		return
	user.visible_message("[user] starts to attach \the [src] to [M].", "You start to attach \the [src] to [M].")
	if (do_after(user, 80, src)) // TO-DO: Make it dependent on medical skill
		M.adjustOxyLoss(-7)
		user.visible_message(SPAN_NOTICE("[user] manually ventilates [M]."), SPAN_NOTICE("You manually ventilate [M]."))
		return

/obj/item/revival_kit
	name = "revival kit"
	desc = "A full sized hospital and multiple years of rehabilitation in only couple of seconds, a true gift from the gods! Better not be greedy..."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "revival"
/obj/item/revival_kit/attack(var/mob/living/human/M as mob, var/mob/user as mob)
	user.visible_message(SPAN_NOTICE("[user] starts trying to revive [M]."), SPAN_NOTICE("You determinately start trying to perform the work of gods on [M]."))
	if (!do_after(user, 120, src))
		user.visible_message(SPAN_NOTICE("[user] stops trying to revive [M]."), SPAN_NOTICE("You stop trying to revive [M]."))
		return
	M.revive()
	if (!M.ckey && M.lastKnownCkey)
		M.ckey = M.lastKnownCkey
	user.visible_message("<font size=4>[user] delivers a message from the GODS by reviving from [M] the dead!</font>", "<font size=4>You did something only a GOD could achieve by reviving [M]!</font>")
	playsound(get_turf(M), 'sound/hallelujah!.ogg', 120, FALSE)
	if (M.ckey == user.ckey)
		to_chat(user, SPAN_DANGER("You were greedy and now you don't feel so good..."))
		spawn(30)
			M.gib()
	qdel(src)
