// Nomads-mode adoption: a character can offer to adopt someone standing next
// to them. If the target accepts, the target takes the adopter's last name.
// The adoptee can later un-adopt themselves, which restores the name they had
// before the adoption. The original name is an ordinary saved var, so it
// survives a world save and load; verbs are not saved and are re-granted.

/mob/living/human
	// Full name before the first adoption; null when not adopted.
	var/adoption_original_name = null
	// Runtime-only offer guards.
	var/tmp/adoption_offer_pending = FALSE
	var/tmp/adoption_offer_next = 0

#define ADOPTION_OFFER_COOLDOWN 300

/proc/adoption_enabled()
	return map && map.nomads

// Last space-separated word of a name, or null for a one-word name.
/proc/adoption_surname(var/full_name)
	if (!istext(full_name))
		return null
	var/list/parts = splittext(trim(full_name), " ")
	if (parts.len < 2)
		return null
	return parts[parts.len]

// The name with its last word replaced by (or, for a one-word name, followed by) surname.
/proc/adoption_apply_surname(var/full_name, var/surname)
	var/list/parts = splittext(trim(full_name), " ")
	if (parts.len < 2)
		return "[trim(full_name)] [surname]"
	parts[parts.len] = surname
	return jointext(parts, " ")

/mob/living/human/New()
	..()
	adoption_refresh_verbs()

/mob/living/human/after_load()
	. = ..()
	adoption_refresh_verbs()

/mob/living/human/proc/adoption_refresh_verbs()
	if (!adoption_enabled())
		verbs -= /mob/living/human/proc/offer_adoption
		verbs -= /mob/living/human/proc/unadopt
		return
	verbs |= /mob/living/human/proc/offer_adoption
	if (adoption_original_name)
		verbs |= /mob/living/human/proc/unadopt
	else
		verbs -= /mob/living/human/proc/unadopt

// Renames through the shared helper so name, real_name, mind and DNA agree.
/mob/living/human/proc/adoption_rename(var/new_name)
	if (!new_name || new_name == real_name)
		return FALSE
	fully_replace_character_name(real_name, new_name)
	if (name != real_name)
		name = real_name
	return TRUE

/mob/living/human/proc/adoption_can_respond()
	return !stat && client && !restrained()

/mob/living/human/proc/offer_adoption()
	set category = null
	set name = "Offer Adoption"
	set desc = "Offer to adopt this person into your family. They take your last name if they accept."
	set src in view(1)

	if (!ishuman(usr))
		return
	var/mob/living/human/user = usr
	if (!adoption_enabled())
		to_chat(user, SPAN_WARNING("Adoption is only available in Nomads."))
		return
	if (user.stat || user.restrained())
		return
	if (user == src)
		to_chat(user, SPAN_WARNING("You cannot adopt yourself."))
		return
	if (world.time < user.adoption_offer_next)
		to_chat(user, SPAN_WARNING("Wait a moment before offering another adoption."))
		return
	var/surname = adoption_surname(user.real_name)
	if (!surname)
		to_chat(user, SPAN_WARNING("You have no last name to pass on."))
		return
	if (!adoption_can_respond())
		to_chat(user, SPAN_WARNING("[src] does not seem to respond..."))
		return
	if (adoption_original_name)
		to_chat(user, SPAN_WARNING("[src] has already been adopted. They must un-adopt themselves first."))
		return
	if (adoption_surname(real_name) == surname)
		to_chat(user, SPAN_WARNING("[src] already shares your last name."))
		return
	if (adoption_offer_pending)
		to_chat(user, SPAN_WARNING("[src] is already considering an adoption offer."))
		return

	user.adoption_offer_next = world.time + ADOPTION_OFFER_COOLDOWN
	adoption_offer_pending = TRUE
	to_chat(user, SPAN_NOTICE("You offer to adopt [src] into the [surname] family."))
	var/answer = WWinput(src, "[user.real_name] offers to adopt you into the [surname] family. Your last name will become [surname]. Will you accept?", "Adoption", "No", list("Yes","No"))
	adoption_offer_pending = FALSE

	if (answer != "Yes")
		if (user)
			to_chat(user, SPAN_WARNING("[src] declines your adoption offer."))
		return
	// Recheck everything that may have changed while the prompt was open.
	if (!user || !adoption_enabled() || user.stat || get_dist(user, src) > 1 || !adoption_can_respond() || adoption_original_name)
		to_chat(src, SPAN_WARNING("The adoption could not be completed."))
		if (user)
			to_chat(user, SPAN_WARNING("The adoption of [src] could not be completed."))
		return
	surname = adoption_surname(user.real_name)
	if (!surname || adoption_surname(real_name) == surname)
		to_chat(src, SPAN_WARNING("The adoption could not be completed."))
		to_chat(user, SPAN_WARNING("The adoption of [src] could not be completed."))
		return

	var/original = real_name
	if (!adoption_rename(adoption_apply_surname(original, surname)))
		return
	adoption_original_name = original
	adoption_refresh_verbs()
	visible_message(SPAN_NOTICE("[user.real_name] adopts [original], who is now known as [real_name]."))
	log_game("[key_name(user)] adopted [key_name(src)]: [original] -> [real_name]")

/mob/living/human/proc/unadopt()
	set category = "IC"
	set name = "Un-adopt Yourself"
	set desc = "Leave your adoptive family and take back the name you had before."

	if (usr != src)
		return
	if (!adoption_original_name)
		to_chat(src, SPAN_WARNING("You have not been adopted."))
		adoption_refresh_verbs()
		return
	if (stat)
		return
	var/answer = WWinput(src, "Leave your adoptive family and go back to being [adoption_original_name]?", "Un-adopt", "No", list("Yes","No"))
	if (answer != "Yes" || !adoption_original_name || stat)
		return
	var/adopted_name = real_name
	var/original = adoption_original_name
	adoption_rename(original)
	adoption_original_name = null
	adoption_refresh_verbs()
	to_chat(src, SPAN_NOTICE("You leave your adoptive family. You are [real_name] again."))
	log_game("[key_name(src)] un-adopted: [adopted_name] -> [real_name]")

#undef ADOPTION_OFFER_COOLDOWN
