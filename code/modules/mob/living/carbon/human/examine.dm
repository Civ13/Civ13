/mob/living/carbon/human/var/list/next_look_at = list()
/mob/living/carbon/human/examine(var/mob/user)

	if (ishuman(user))
		var/mob/living/carbon/human/H = user
		if (!H.next_look_at.Find(getRoundUID(TRUE)) || H.next_look_at[getRoundUID(TRUE)] <= world.time)
			H.visible_message("<small>[H] looks at [src].</small>")
			H.next_look_at[getRoundUID(TRUE)] = world.time + 100

	var/skipgloves = FALSE
	var/skipjumpsuit = FALSE
	var/skipshoes = FALSE
	var/skipmask = FALSE
	var/skipears = FALSE
	var/skipface = FALSE

	//exosuits and helmets obscure our view and stuff.
	if (wear_suit)
		skipgloves = wear_suit.flags_inv & HIDEGLOVES
		skipjumpsuit = wear_suit.flags_inv & HIDEJUMPSUIT
		skipshoes = wear_suit.flags_inv & HIDESHOES

	if (head)
		skipmask = head.flags_inv & HIDEMASK
		skipears = head.flags_inv & HIDEEARS
		skipface = head.flags_inv & HIDEFACE

	if (wear_mask)
		skipface |= wear_mask.flags_inv & HIDEFACE

	var/msg = "<span class='info'>*---------*\nThis is "

	var/datum/gender/T = gender_datums[gender]
	if (skipjumpsuit && skipface) //big suits/masks/helmets make it hard to tell their gender
		T = gender_datums[PLURAL]
	else
		if (icon)
			msg += "\icon[icon] " //fucking BYOND: this should stop dreamseeker crashing if we -somehow- examine somebody before their icon is generated

	if (!T)
		// Just in case someone VVs the gender to something strange. It'll runtime anyway when it hits usages, better to CRASH() now with a helpful message.
		CRASH("Gender datum was null; key was '[(skipjumpsuit && skipface) ? PLURAL : gender]'")

	msg += "<EM>[name]</EM>"
	if (species.name != "Human")
		msg += ", a <b><font color='[species.flesh_color]'>[species.name]</font></b>"
	msg += "!\n"

	//uniform
	if (w_uniform && !skipjumpsuit)
		//Ties
		var/tie_msg
		if (istype(w_uniform,/obj/item/clothing/under))
			var/obj/item/clothing/under/U = w_uniform
			if (U.accessories.len)
				tie_msg += ". Attached to it is [lowertext(english_list(U.accessories))]"

		if (w_uniform.blood_DNA)
			msg += "<span class='warning'>[T.He] [T.is] wearing \icon[w_uniform] [w_uniform.gender==PLURAL?"some":"a"] [(w_uniform.blood_color != "#030303") ? "blood" : "oil"]-stained [w_uniform.name][tie_msg]!</span>\n"
		else
			msg += "[T.He] [T.is] wearing \icon[w_uniform] \a [w_uniform][tie_msg].\n"

	//head
	if (head)
		if (head.blood_DNA)
			msg += "<span class='warning'>[T.He] [T.is] wearing \icon[head] [head.gender==PLURAL?"some":"a"] [(head.blood_color != "#030303") ? "blood" : "oil"]-stained [head.name] on [T.his] head!</span>\n"
		else
			msg += "[T.He] [T.is] wearing \icon[head] \a [head] on [T.his] head.\n"

	//suit/armor
	if (wear_suit)
		if (wear_suit.blood_DNA)
			msg += "<span class='warning'>[T.He] [T.is] wearing \icon[wear_suit] [wear_suit.gender==PLURAL?"some":"a"] [(wear_suit.blood_color != "#030303") ? "blood" : "oil"]-stained [wear_suit.name]!</span>\n"
		else
			msg += "[T.He] [T.is] wearing \icon[wear_suit] \a [wear_suit].\n"

	//back
	if (back)
		if (back.blood_DNA)
			msg += "<span class='warning'>[T.He] [T.has] \icon[back] [back.gender==PLURAL?"some":"a"] [(back.blood_color != "#030303") ? "blood" : "oil"]-stained [back] on [T.his] back.</span>\n"
		else
			msg += "[T.He] [T.has] \icon[back] \a [back] on [T.his] back.\n"

	//left hand
	if (l_hand)
		if (l_hand.blood_DNA)
			msg += "<span class='warning'>[T.He] [T.is] holding \icon[l_hand] [l_hand.gender==PLURAL?"some":"a"] [(l_hand.blood_color != "#030303") ? "blood" : "oil"]-stained [l_hand.name] in [T.his] left hand!</span>\n"
		else
			msg += "[T.He] [T.is] holding \icon[l_hand] \a [l_hand] in [T.his] left hand.\n"

	//right hand
	if (r_hand)
		if (r_hand.blood_DNA)
			msg += "<span class='warning'>[T.He] [T.is] holding \icon[r_hand] [r_hand.gender==PLURAL?"some":"a"] [(r_hand.blood_color != "#030303") ? "blood" : "oil"]-stained [r_hand.name] in [T.his] right hand!</span>\n"
		else
			msg += "[T.He] [T.is] holding \icon[r_hand] \a [r_hand] in [T.his] right hand.\n"

	//gloves
	if (gloves && !skipgloves)
		if (gloves.blood_DNA)
			msg += "<span class='warning'>[T.He] [T.has] \icon[gloves] [gloves.gender==PLURAL?"some":"a"] [(gloves.blood_color != "#030303") ? "blood" : "oil"]-stained [gloves.name] on [T.his] hands!</span>\n"
		else
			msg += "[T.He] [T.has] \icon[gloves] \a [gloves] on [T.his] hands.\n"
	else if (blood_DNA)
		msg += "<span class='warning'>[T.He] [T.has] [(hand_blood_color != "#030303") ? "blood" : "oil"]-stained hands!</span>\n"

	//handcuffed?
	if (handcuffed)
		msg += "<span class='warning'>[T.He] [T.is] \icon[handcuffed] handcuffed!</span>\n"

	//buckled
	if (buckled)
		msg += "<span class='warning'>[T.He] [T.is] \icon[buckled] buckled to [buckled]!</span>\n"

	//belt
	if (belt)
		if (belt.blood_DNA)
			msg += "<span class='warning'>[T.He] [T.has] \icon[belt] [belt.gender==PLURAL?"some":"a"] [(belt.blood_color != "#030303") ? "blood" : "oil"]-stained [belt.name] about [T.his] waist!</span>\n"
		else
			msg += "[T.He] [T.has] \icon[belt] \a [belt] about [T.his] waist.\n"

	//shoes
	if (shoes && !skipshoes)
		if (shoes.blood_DNA)
			msg += "<span class='warning'>[T.He] [T.is] wearing \icon[shoes] [shoes.gender==PLURAL?"some":"a"] [(shoes.blood_color != "#030303") ? "blood" : "oil"]-stained [shoes.name] on [T.his] feet!</span>\n"
		else
			msg += "[T.He] [T.is] wearing \icon[shoes] \a [shoes] on [T.his] feet.\n"
	else if (feet_blood_DNA)
		msg += "<span class='warning'>[T.He] [T.has] [(feet_blood_color != "#030303") ? "blood" : "oil"]-stained feet!</span>\n"

	//mask
	if (wear_mask && !skipmask)
		var/descriptor = "on [T.his] face"
		if (istype(wear_mask, /obj/item/weapon/grenade))
			descriptor = "in [T.his] mouth"
		if (wear_mask.blood_DNA)
			msg += "<span class='warning'>[T.He] [T.has] \icon[wear_mask] [wear_mask.gender==PLURAL?"some":"a"] [(wear_mask.blood_color != "#030303") ? "blood" : "oil"]-stained [wear_mask.name] [descriptor]!</span>\n"
		else
			msg += "[T.He] [T.has] \icon[wear_mask] \a [wear_mask] [descriptor].\n"

	//left ear
	if (l_ear && !skipears)
		msg += "[T.He] [T.has] \icon[l_ear] \a [l_ear] on [T.his] left ear.\n"

	//right ear
	if (r_ear && !skipears)
		msg += "[T.He] [T.has] \icon[r_ear] \a [r_ear] on [T.his] right ear.\n"

	//ID
	if (wear_id)
		/*var/id
		if (istype(wear_id, /obj/item/pda))
			var/obj/item/pda/pda = wear_id
			id = pda.owner
		else if (istype(wear_id, /obj/item/weapon/card/id)) //just in case something other than a PDA/ID card somehow gets in the ID slot :[
			var/obj/item/weapon/card/id/idcard = wear_id
			id = idcard.registered_name
		if (id && (id != real_name) && (get_dist(src, usr) <= 1) && prob(10))
			msg += "<span class='warning'>[T.He] [T.is] wearing \icon[wear_id] \a [wear_id] yet something doesn't seem right...</span>\n"
		else*/
		msg += "[T.He] [T.is] wearing \icon[wear_id] \a [wear_id].\n"

	//Jitters
	if (is_jittery)
		if (jitteriness >= 300)
			msg += "<span class='warning'><b>[T.He] [T.is] convulsing violently!</b></span>\n"
		else if (jitteriness >= 200)
			msg += "<span class='warning'>[T.He] [T.is] extremely jittery.</span>\n"
		else if (jitteriness >= 100)
			msg += "<span class='warning'>[T.He] [T.is] twitching ever so slightly.</span>\n"

	//splints
	for (var/organ in list("l_leg","r_leg","l_arm","r_arm"))
		var/obj/item/organ/external/o = get_organ(organ)
		if (o && o.status & ORGAN_SPLINTED)
			msg += "<span class='warning'>[T.He] [T.has] a splint on [T.his] [o.name]!</span>\n"


	var/distance = get_dist(usr,src)
	if (isghost(usr) || usr.stat == DEAD) // ghosts can see anything
		distance = TRUE
	if (stat)
		msg += "<span class='warning'>[T.He] [T.is]n't responding to anything around [T.him] and seems to be asleep.</span>\n"
		if ((stat == DEAD || losebreath) && distance <= 3)
			msg += "<span class='warning'>[T.He] [T.does] not appear to be breathing.</span>\n"

	if (fire_stacks)
		msg += "[T.He] [T.is] covered in some liquid.\n"
	if (on_fire)
		msg += "<span class='warning'>[T.He] [T.is] on fire!.</span>\n"
	msg += "<span class='warning'>"

	msg += "</span>"

	if (species.show_ssd && (!species.has_organ["brain"] || has_brain()) && stat != DEAD)
		if (!key)
			msg += "<span class='deadsay'>[T.He] [T.is] [species.show_ssd]. It doesn't look like [T.he] [T.is] waking up anytime soon.</span>\n"
		else if (!client)
			msg += "<span class='deadsay'>[T.He] [T.is] [species.show_ssd].</span>\n"

	var/list/wound_flavor_text = list()
	var/list/is_bleeding = list()

	//old system of checking health was causing problems since monkeys have less total health than humans.

	var/health_percentage = health

	if (istype(user, /mob/living/carbon/human) && user:species)
		var/mob/living/carbon/human/H = user
		health_percentage = (health/H.species.total_health) * 100

	if (health_percentage <= 75 && health_percentage > 50)//Is the person a little hurt?
		msg += "<span class='warning'><b>[T.He] looks somewhat wounded.\n</b></span>"

	if (health_percentage <= 50 && health_percentage > 25)//Hurt.
		msg += "<span class='warning'><b>[T.He] looks wounded.</b></span>\n"

	if (health_percentage <= 25)//Or incredibly hurt.
		msg += "<span class='warning'><b>[T.He] looks incredibly wounded.</b>\n</span>"

	for (var/organ_tag in species.has_limbs)

		var/list/organ_data = species.has_limbs[organ_tag]
		var/organ_descriptor = organ_data["descriptor"]
		var/obj/item/organ/external/E = organs_by_name[organ_tag]
		if (!E)
			wound_flavor_text["[organ_descriptor]"] = "<span class='warning'><b>[T.He] [T.is] missing [T.his] [organ_descriptor].</b></span>\n"
		else if (E.is_stump())
			wound_flavor_text["[organ_descriptor]"] = "<span class='warning'><b>[T.He] [T.has] a stump where [T.his] [organ_descriptor] should be.</b></span>\n"
		else
			continue

	for (var/obj/item/organ/external/temp in organs)
		if (temp)
			if (temp.wounds.len > 0 || temp.open)
				/*if (temp.is_stump() && temp.parent_organ && organs_by_name[temp.parent_organ])
					var/obj/item/organ/external/parent = organs_by_name[temp.parent_organ]
					wound_flavor_text["[temp.name]"] = "<span class='warning'>[T.He] [T.has] [temp.get_wounds_desc()] on [T.his] [parent.name].</span><br>"
				else
					wound_flavor_text["[temp.name]"] = "<span class='warning'>[T.He] [T.has] [temp.get_wounds_desc()] on [T.his] [temp.name].</span><br>"
				*///Removing because they're unneeded bloat descriptions.
				if (temp.status & ORGAN_BLEEDING)
					is_bleeding["[temp.name]"] = "<span class='danger'>[T.His] [temp.name] is bleeding!</span><br>"
			else
				wound_flavor_text["[temp.name]"] = ""
			if (temp.dislocated == 2)
				wound_flavor_text["[temp.name]"] += "<span class='warning'>[T.His] [temp.joint] is dislocated!</span><br>"
			if (((temp.status & ORGAN_BROKEN) && temp.brute_dam > temp.min_broken_damage) || (temp.status & ORGAN_MUTATED))
				wound_flavor_text["[temp.name]"] += "<span class='warning'>[T.His] [temp.name] is shattered!</span><br>"

	//Handles the text strings being added to the actual description.
	//If they have something that covers the limb, and it is not missing, put flavortext.  If it is covered but bleeding, add other flavortext.


	for (var/limb in wound_flavor_text)//Uneeded.
		msg += wound_flavor_text[limb]
		is_bleeding[limb] = null
	for (var/limb in is_bleeding)
		msg += is_bleeding[limb]
	for (var/implant in get_visible_implants(0))
		msg += "<span class='danger'>[src] [T.has] \a [implant] sticking out of [T.his] flesh!</span>\n"
	if (gender == MALE && circumcised && !w_uniform && !wear_suit)
		msg += "<span class='danger'>[src] is circumcised!</span>\n"

	var/obj/item/organ/external/head/O = locate(/obj/item/organ/external/head) in organs
	if (O && O.get_teeth() < O.max_teeth)
		msg += "<span class='warning'>[O.get_teeth() <= 0 ? "All" : "[O.max_teeth - O.get_teeth()]"] of [T.his] teeth are missing!</span>\n"

	if (print_flavor_text()) msg += "[print_flavor_text()]\n"

	msg += "*---------*</span>"
	if (pose)
		if ( findtext(pose,".",lentext(pose)) == FALSE && findtext(pose,"!",lentext(pose)) == FALSE && findtext(pose,"?",lentext(pose)) == FALSE )
			pose = addtext(pose,".") //Makes sure all emotes end with a period.
		msg += "\n[T.He] [T.is] [pose]"
	if (!map.civilizations && !map.ID == MAP_LITTLE_CREEK)
		if (original_job)
			if (ishuman(user) && user != src)
				var/mob/living/carbon/human/H = user
				if (H.original_job)
					if (H.original_job.base_type_flag() == original_job.base_type_flag()) // when you ghost, mind.assigned_job is set to null
						if (original_job.en_meaning)
							msg += "<br><i>You recognize [T.him] as a <b>[original_job.title] ([original_job.en_meaning])</b>.</i>"
						else
							msg += "<br><i>You recognize [T.him] as a <b>[original_job.title]</b>.</i>"
					else // examining someone on another team

			else if (isobserver(user))
				msg += "<br><i>[T.He] [T.is] a [original_job.title].</i>"
	else if (map.ID == MAP_LITTLE_CREEK)
		if (ishuman(user) && user != src)
			var/mob/living/carbon/human/H = user
			if (H.original_job)
				if (H.original_job_title == original_job_title && original_job_title == "East Side Gang")
					msg += "<br><i>You recognize [T.him] as a fellow <b>[original_job.title] member</b>!</i>"
				else if (H.original_job_title == original_job_title && original_job_title == "West Side Gang")
					msg += "<br><i>You recognize [T.him] as a fellow <b>[original_job.title] member</b>!</i>"
	else if (map.civilizations)
		if (ishuman(user) && user != src)
			var/mob/living/carbon/human/H = user
			if (H.religion == religion && religion_style == "Cultists" && religious_clergy == "Cultists")
				msg += "<br><i>You recognize [T.him] as an ordained <b>Cultist</b> of your cult, <b>[religion]</b>.</i>"
			else if (H.religion == religion && religion_style == "Cultists" && religious_clergy != "Cultists")
				msg += "<br><i>You recognize [T.him] as a member of your cult, <b>[religion]</b>.</i>"

			if (H.civilization == civilization && civilization != "none") // when you ghost, mind.assigned_job is set to null
				msg += "<br><i>You recognize [T.him] as a member of your faction, <b>[civilization]</b>.</i>"
				if (map.custom_civs[H.civilization][4] != null)
					if (map.custom_civs[H.civilization][4].real_name == real_name)
						msg += "<br><b>[T.He] is the leader of your faction.</b>"
			else if (civilization != "none") // examining someone on another team
				msg += "<br><span class='warning'><i>[T.He] seems to be a member of [civilization].</i>"

			else
				msg += "<br><i>[T.He] is a nomad. [T.He] has no faction</b>.</i>"
		else if (isobserver(user))
			if (civilization != "none")
				msg += "<br><i>[T.He] [T.is] a member of <b>[civilization]</b>.</i>"
			else
				msg += "<br><i>[T.He] is a nomad. [T.He] has no faction</b>.</i>"

		else if (ishuman(user) && user == src)
			var/mob/living/carbon/human/H = user
			if (H.civilization != "none")
				msg += "<br><i>You belong to <b>[H.civilization]</b>.</i>"
				if (map && map.custom_civs[H.civilization][4] && map.custom_civs[H.civilization][4].real_name == H.real_name)
					msg += "<br><b>You are the leader of your group.</b>"

	for (var/v in TRUE to embedded.len)
		msg += "<a href='?src=\ref[user];remove_embedded=[v]'>Remove [embedded[v]]</a>"

	user << msg

/mob/living/carbon/human/Topic(href, href_list[], hsrc)

	..()

	if (href_list["remove_embedded"])
		var/v = href_list["remove_embedded"]
		var/user = hsrc
		var/obj/embedded_obj = embedded[v]
		visible_message("<span class = 'danger'>[user] starts to pull [embedded_obj] out of [src].</span>")
		if (do_after(user, 15 * embedded_obj.w_class, src))
			visible_message("<span class = 'danger'>[user] pulls [embedded_obj] out of [src]!</span>")
			emote("painscream")
			adjustBruteLoss(rand(10,15))
		embedded -= embedded_obj
		embedded_obj.loc = get_turf(src)
