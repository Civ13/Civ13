// Dentistry: tooth decay, toothache and abscesses, drawing and replanting
// teeth, band bridges, dentures and fillings, each tied to the research era
// in which people actually practised it (docs/dentistry.md).
//
// State lives on the head as plain numbers and one typepath, so it saves with
// the body and never holds an object reference:
// - decayed_teeth: natural teeth with untreated caries (some may be scraped
//   out and waiting for a filling, prepared_teeth)
// - filled_teeth: natural teeth restored with a filling; they no longer decay
// - dental_plaque: built up by sweet and starchy bites, cleared by a chewing
//   stick or toothbrush; enough of it slowly rots a sound tooth
// - bridge_teeth: replacement teeth held by fixed band bridges
// - denture_type/denture_teeth: a removable set and how many gaps it fills
// Teeth are only lost, never regrown, outside spawning and revival.

#define DENTAL_TICK 60 // life ticks (about a minute) between dental checks
#define DENTAL_PLAQUE_MAX 150
#define DENTAL_PLAQUE_ROT 100 // plaque at which a sound tooth may start to rot
#define DENTAL_ROT_CHANCE 8 // percent a minute while plaque is past DENTAL_PLAQUE_ROT
#define DENTAL_SWEET_PLAQUE 5 // most plaque one bite can add
#define DENTAL_ABSCESS_AFTER 120 // minutes a cavity goes untreated before it can abscess
#define DENTAL_ABSCESS_CHANCE 3 // percent a minute after that
#define DENTAL_TOOTHACHE_PAIN 15
#define DENTAL_ABSCESS_PAIN 35
#define DENTAL_ABSCESS_TOX_CAP 20 // an abscess makes you ill, but never kills alone
#define DENTAL_CHEW_FULL 16 // chewing teeth needed to bite at full size
#define DENTAL_SPEECH_GAPS 8 // missing teeth before speech starts to whistle
#define DENTAL_REPLANT_WINDOW (10 MINUTES) // a knocked-out tooth can be pushed back this long
#define DENTAL_BRIDGE_ANCHORS 2 // natural teeth a band bridge must be bound to
#define DENTAL_REFUSED -1 // SURGERY_FAILURE: a step that applies but was refused with a message

/obj/item/organ/external/head
	var/decayed_teeth = 0
	var/prepared_teeth = 0
	var/filled_teeth = 0
	var/dental_plaque = 0
	var/caries_minutes = 0
	var/abscess = FALSE
	var/bridge_teeth = 0
	var/denture_type = null
	var/denture_teeth = 0

/obj/item/organ/external/head/proc/reset_dental_state()
	decayed_teeth = 0
	prepared_teeth = 0
	filled_teeth = 0
	dental_plaque = 0
	caries_minutes = 0
	abscess = FALSE
	bridge_teeth = 0
	denture_type = null
	denture_teeth = 0

// Keep every count inside the natural teeth left after a loss.
/obj/item/organ/external/head/proc/clamp_dental_state()
	var/natural = get_teeth()
	decayed_teeth = Clamp(decayed_teeth, 0, natural)
	filled_teeth = Clamp(filled_teeth, 0, natural - decayed_teeth)
	prepared_teeth = Clamp(prepared_teeth, 0, decayed_teeth)
	if (!decayed_teeth)
		caries_minutes = 0
		abscess = FALSE
	var/gaps = max(0, max_teeth - natural)
	bridge_teeth = Clamp(bridge_teeth, 0, gaps)
	denture_teeth = Clamp(denture_teeth, 0, max(0, gaps - bridge_teeth))

// Teeth lost by a blow or a pull are a random mix of rotten, filled and sound.
/obj/item/organ/external/head/proc/lose_dental_teeth(lost, natural_before)
	for (var/i = 1 to lost)
		var/left = max(1, natural_before - i + 1)
		if (decayed_teeth && prob(100 * decayed_teeth / left))
			decayed_teeth--
		else if (filled_teeth && prob(100 * filled_teeth / left))
			filled_teeth--
	clamp_dental_state()
	if (owner && bridge_teeth && get_teeth() < DENTAL_BRIDGE_ANCHORS)
		bridge_teeth = 0
		new /obj/item/dental_bridge(get_turf(owner))
		to_chat(owner, SPAN_WARNING("With too few teeth left to hold it, your band bridge comes loose and falls out."))

/obj/item/organ/external/head/proc/sound_teeth()
	return max(0, get_teeth() - decayed_teeth - filled_teeth)

/obj/item/organ/external/head/proc/denture_chew_factor()
	if (!ispath(denture_type, /obj/item/dentures))
		return 0
	var/obj/item/dentures/D = denture_type
	return initial(D.chew_factor)

// Teeth that bite: natural ones, bridged ones and a share of a denture set
// (early carved sets were mostly for looks and were taken out to eat).
/obj/item/organ/external/head/proc/chewing_teeth()
	return get_teeth() + bridge_teeth + denture_teeth * denture_chew_factor()

// Teeth that shape speech and show in a smile.
/obj/item/organ/external/head/proc/visible_teeth()
	return get_teeth() + bridge_teeth + denture_teeth

/obj/item/organ/external/head/proc/remove_natural_tooth(prefer_decayed = TRUE)
	var/natural = get_teeth()
	if (natural <= 0)
		return null
	var/was_decayed = FALSE
	if (prefer_decayed && decayed_teeth)
		decayed_teeth--
		prepared_teeth = min(prepared_teeth, decayed_teeth)
		was_decayed = TRUE
	else if (filled_teeth && prob(100 * filled_teeth / max(1, natural - decayed_teeth)))
		filled_teeth--
	var/obj/item/stack/teeth/source = null
	for (var/obj/item/stack/teeth/T in teeth_list)
		if (T.amount > 0)
			source = T
			break
	if (!source)
		return null
	var/obj/item/stack/teeth/pulled = new source.type(owner ? get_turf(owner) : get_turf(src), 1)
	source.use(1)
	if (QDELETED(source))
		teeth_list -= source
	if (owner)
		pulled.mark_fresh(owner)
		pulled.add_blood(owner)
	if (was_decayed)
		pulled.rotten_tooth = TRUE
		pulled.name = "rotten [initial(pulled.singular_name)]"
		pulled.desc = "A tooth black with decay, drawn from someone's mouth."
	clamp_dental_state()
	return pulled

/obj/item/organ/external/head/proc/add_natural_tooth()
	if (get_teeth() >= max_teeth)
		return FALSE
	var/obj/item/stack/teeth/T = null
	for (var/obj/item/stack/teeth/S in teeth_list)
		if (!QDELETED(S))
			T = S
			break
	if (T)
		T.amount++
	else
		var/teeth_path = owner && owner.species ? owner.species.teeth_type : /obj/item/stack/teeth/generic
		T = new teeth_path(src, 1)
		teeth_list += T
	clamp_dental_state()
	return TRUE

// Sweet food feeds the decay; plain starch barely does.
/obj/item/organ/external/head/proc/add_food_plaque(datum/reagents/R, amount)
	if (!R || R.total_volume <= 0 || amount <= 0)
		return
	var/share = min(1, amount / R.total_volume)
	var/sweet = (R.get_reagent_amount("sugar") + R.get_reagent_amount("honey") + R.get_reagent_amount("syrup")) * share
	dental_plaque = min(DENTAL_PLAQUE_MAX, dental_plaque + min(DENTAL_SWEET_PLAQUE, sweet) + 0.2)

/obj/item/organ/external/head/proc/clean_teeth(amount)
	dental_plaque = max(0, dental_plaque - amount)

////////////////////////////////////////////////////////////////////////
// Life, eating and speech
////////////////////////////////////////////////////////////////////////

/mob/living/human/proc/dental_head()
	var/obj/item/organ/external/head/H = get_organ("head")
	return istype(H) && !H.is_stump() ? H : null

/mob/living/human/proc/handle_teeth()
	if (life_tick % DENTAL_TICK || inducedSSD || (status_flags & GODMODE))
		return
	var/obj/item/organ/external/head/H = dental_head()
	if (!H)
		return
	H.clamp_dental_state()
	// Saliva slowly washes some of it away on its own.
	H.dental_plaque = max(0, H.dental_plaque - 0.5)
	if (H.dental_plaque >= DENTAL_PLAQUE_ROT && H.sound_teeth() && prob(DENTAL_ROT_CHANCE))
		H.decayed_teeth++
		H.dental_plaque -= 50
		to_chat(src, SPAN_WARNING("One of your teeth twinges when you bite down. A cavity is starting."))
	if (!H.decayed_teeth)
		return
	H.caries_minutes++
	if (H.abscess)
		if (reagents && reagents.has_reagent("penicillin"))
			H.abscess = FALSE
			H.caries_minutes = 0
			to_chat(src, SPAN_NOTICE("The swelling in your jaw goes down. The bad tooth still needs seeing to."))
			return
		if (getToxLoss() < DENTAL_ABSCESS_TOX_CAP)
			adjustToxLoss(0.5)
		if (prob(50))
			custom_pain("Your jaw throbs around a swollen, abscessed tooth!", DENTAL_ABSCESS_PAIN)
			adjust_mood(-2, "an abscessed tooth")
		return
	if (H.caries_minutes >= DENTAL_ABSCESS_AFTER && prob(DENTAL_ABSCESS_CHANCE))
		H.abscess = TRUE
		custom_pain("Your jaw swells hot and tight around a rotten tooth!", DENTAL_ABSCESS_PAIN, TRUE)
		return
	if (prob(20))
		custom_pain("A dull toothache nags at you.", DENTAL_TOOTHACHE_PAIN)
		adjust_mood(-1, "a toothache")

// Called by take_food_bite before the bite is swallowed; returns its size.
/mob/living/human/proc/dental_bite(obj/item/weapon/reagent_containers/food/snacks/S, amount)
	var/obj/item/organ/external/head/H = dental_head()
	if (!H || !S || !S.reagents)
		return amount
	H.add_food_plaque(S.reagents, amount)
	if (H.decayed_teeth && prob(H.abscess ? 50 : 15))
		custom_pain("Pain shoots through a bad tooth as you bite down!", H.abscess ? DENTAL_ABSCESS_PAIN : DENTAL_TOOTHACHE_PAIN)
	var/chew = H.chewing_teeth()
	if (chew >= DENTAL_CHEW_FULL)
		return amount
	if (prob(10))
		to_chat(src, SPAN_NOTICE("With so few teeth you have to gum at \the [S] in small bites."))
	return amount * (0.5 + 0.5 * chew / DENTAL_CHEW_FULL)

// Gaps in the teeth make "s" whistle into "th"; a full set, false or not, fixes it.
/mob/living/human/dental_speech(message)
	var/obj/item/organ/external/head/H = dental_head()
	if (!H || !message)
		return message
	var/gaps = H.max_teeth - H.visible_teeth()
	if (gaps < DENTAL_SPEECH_GAPS || !prob(min(90, (gaps - DENTAL_SPEECH_GAPS + 1) * 5)))
		return message
	message = replacetextEx(message, "ss", "th")
	message = replacetextEx(message, "s", "th")
	message = replacetextEx(message, "S", "Th")
	return message

/mob/living/human/proc/dental_examine_text(datum/gender/T)
	var/obj/item/organ/external/head/O = dental_head()
	if (!O)
		return ""
	. = ""
	var/missing = O.max_teeth - O.visible_teeth()
	if (missing > 0)
		. += "<span class='warning'>[O.visible_teeth() <= 0 ? "All" : "[missing]"] of [T.his] teeth are missing!</span>\n"
	if (O.denture_type)
		var/obj/item/dentures/D = O.denture_type
		. += "[T.He] [T.has] [initial(D.worn_text)].\n"
	if (O.bridge_teeth)
		. += "[T.He] [T.has] false teeth bound in with gold bands.\n"
	if (O.abscess)
		. += "<span class='warning'>[T.His] jaw is swollen on one side.</span>\n"

// Self-click on the mouth with an empty hand on help intent.
/mob/living/human/proc/take_out_dentures()
	var/obj/item/organ/external/head/H = dental_head()
	if (!H || !ispath(H.denture_type, /obj/item/dentures))
		return FALSE
	if (get_active_hand())
		return FALSE
	var/obj/item/dentures/D = new H.denture_type(get_turf(src))
	H.denture_type = null
	H.denture_teeth = 0
	put_in_hands(D)
	visible_message("[src] takes out [D].", SPAN_NOTICE("You take out your [D.name]."))
	return TRUE

////////////////////////////////////////////////////////////////////////
// Teeth stacks: a knocked-out tooth stays fresh for a short while
////////////////////////////////////////////////////////////////////////

/obj/item/stack/teeth
	var/tmp/knocked_out_at = null // world.time it left a mouth; never saved
	var/tmp/tooth_owner = null // real_name of that mouth
	var/rotten_tooth = FALSE

/obj/item/stack/teeth/proc/mark_fresh(mob/living/human/from)
	knocked_out_at = world.time
	tooth_owner = from ? from.real_name : null

/obj/item/stack/teeth/proc/is_fresh_for(mob/living/human/M)
	return !rotten_tooth && !isnull(knocked_out_at) && istype(M) && tooth_owner && tooth_owner == M.real_name && world.time - knocked_out_at <= DENTAL_REPLANT_WINDOW

// A merged pile is only as fresh as its stalest tooth, and only one person's.
/obj/item/stack/teeth/proc/absorb_freshness(obj/item/stack/teeth/other)
	if (!istype(other))
		return
	if (tooth_owner != other.tooth_owner)
		tooth_owner = null
	if (isnull(knocked_out_at) || isnull(other.knocked_out_at))
		knocked_out_at = null
	else
		knocked_out_at = min(knocked_out_at, other.knocked_out_at)
	rotten_tooth = rotten_tooth || other.rotten_tooth

/obj/item/stack/teeth/merge(obj/item/stack/S)
	if (istype(S, /obj/item/stack/teeth))
		var/obj/item/stack/teeth/T = S
		T.absorb_freshness(src)
	return ..()

/obj/item/stack/teeth/transfer_to(obj/item/stack/S, _amount = null)
	if (istype(S, /obj/item/stack/teeth) && stacktype == S.stacktype)
		var/obj/item/stack/teeth/T = S
		T.absorb_freshness(src)
	return ..()

/obj/item/stack/teeth/split(_amount)
	var/was_at = knocked_out_at
	var/was_owner = tooth_owner
	var/was_rotten = rotten_tooth
	. = ..()
	var/obj/item/stack/teeth/T = .
	if (istype(T) && T != src)
		T.knocked_out_at = was_at
		T.tooth_owner = was_owner
		T.rotten_tooth = was_rotten

/obj/item/stack/teeth/examine(mob/user)
	..()
	if (!isnull(knocked_out_at) && world.time - knocked_out_at <= DENTAL_REPLANT_WINDOW && !rotten_tooth)
		to_chat(user, SPAN_NOTICE("[amount > 1 ? "They are" : "It is"] fresh, with the root still pink. Pushed back into the socket soon, a tooth can take again."))

////////////////////////////////////////////////////////////////////////
// Tools and hygiene
////////////////////////////////////////////////////////////////////////

/obj/item/weapon/surgery/dental_forceps
	name = "dental forceps"
	desc = "Stout iron forceps with curved beaks, for drawing teeth."
	icon = 'icons/obj/dentistry.dmi'
	icon_state = "forceps"
	attack_verb = list("pinched")

/obj/item/weapon/surgery/dental_forceps/bronze
	name = "bronze dental forceps"
	desc = "Stout bronze forceps with curved beaks, for drawing teeth."
	icon_state = "forceps_bronze"

/obj/item/weapon/surgery/dental_pick
	name = "dental pick"
	desc = "A slim hooked iron pick for scraping the rot out of a tooth before it is filled."
	icon = 'icons/obj/dentistry.dmi'
	icon_state = "dental_pick"
	attack_verb = list("poked", "jabbed")

/obj/item/weapon/tooth_cleaner
	name = "tooth cleaner"
	icon = 'icons/obj/dentistry.dmi'
	w_class = ITEM_SIZE_TINY
	var/clean_amount = 60
	var/clean_time = 30
	var/uses = 0 // 0 means it never wears out

/obj/item/weapon/tooth_cleaner/attack_self(mob/living/human/user)
	if (!istype(user))
		return
	var/obj/item/organ/external/head/H = user.dental_head()
	if (!H || H.get_teeth() <= 0)
		to_chat(user, SPAN_WARNING("You have no teeth to clean."))
		return
	if (user.check_mouth_coverage())
		to_chat(user, SPAN_WARNING("Your mouth is covered."))
		return
	user.visible_message("[user] starts cleaning [user.gender == FEMALE ? "her" : "his"] teeth with \the [src].", SPAN_NOTICE("You start cleaning your teeth with \the [src]."))
	if (!do_after(user, clean_time, user) || loc != user || QDELETED(H) || H != user.dental_head())
		return
	H.clean_teeth(clean_amount)
	to_chat(user, SPAN_NOTICE("Your teeth feel clean."))
	if (uses)
		uses--
		if (!uses)
			to_chat(user, SPAN_NOTICE("\The [src] is chewed to a stub. You throw it away."))
			qdel(src)

/obj/item/weapon/tooth_cleaner/chewing_stick
	name = "chewing stick"
	desc = "A twig with one end chewed into soft fibres, for scrubbing the teeth. It wears out after a few uses."
	icon_state = "chewing_stick"
	clean_amount = 60
	clean_time = 40
	uses = 6

/obj/item/weapon/tooth_cleaner/toothbrush
	name = "toothbrush"
	desc = "A carved bone handle set with a tuft of stiff bristles, for scrubbing the teeth."
	icon_state = "toothbrush"
	clean_amount = DENTAL_PLAQUE_MAX
	clean_time = 25

////////////////////////////////////////////////////////////////////////
// Bridges and dentures
////////////////////////////////////////////////////////////////////////

/obj/item/dental_bridge
	name = "gold band bridge"
	desc = "Replacement teeth bound on a band of soft gold. A dentist ties it to the teeth either side of a gap, so it needs some natural teeth left to hold on to."
	icon = 'icons/obj/dentistry.dmi'
	icon_state = "bridge_gold"
	w_class = ITEM_SIZE_TINY
	var/teeth_held = 3

/obj/item/dentures
	name = "dentures"
	desc = "A set of false teeth."
	icon = 'icons/obj/dentistry.dmi'
	w_class = ITEM_SIZE_TINY
	var/chew_factor = 1 // share of the teeth it fills that can really chew
	var/worn_text = "false teeth"
	var/brittle = FALSE // can shatter if knocked out by a blow

/obj/item/dentures/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("Use it on your own mouth (or a patient's) to fit it. To take it out again, click your own mouth with an empty hand on help intent."))

/obj/item/dentures/attack(mob/living/M, mob/living/user, def_zone)
	if (!ishuman(M) || !ishuman(user) || user.a_intent != I_HELP || user.targeted_organ != "mouth")
		return ..()
	var/mob/living/human/target = M
	var/obj/item/organ/external/head/H = target.dental_head()
	if (!H)
		return TRUE
	if (H.denture_type)
		to_chat(user, SPAN_WARNING("[target == user ? "You already have" : "[target] already has"] dentures in."))
		return TRUE
	var/gaps = H.max_teeth - H.get_teeth() - H.bridge_teeth
	if (gaps <= 0)
		to_chat(user, SPAN_WARNING("There are no gaps for \the [src] to fill."))
		return TRUE
	if (target.check_mouth_coverage())
		to_chat(user, SPAN_WARNING("The mouth is covered."))
		return TRUE
	if (target != user)
		user.visible_message("[user] starts fitting \the [src] into [target]'s mouth.")
		if (!do_after(user, 30, target) || loc != user || H.denture_type || H != target.dental_head())
			return TRUE
	H.denture_type = type
	H.denture_teeth = gaps
	user.drop_from_inventory(src)
	user.visible_message("[user] fits \the [src] into [target == user ? "[user.gender == FEMALE ? "her" : "his"] own" : "[target]'s"] mouth.", SPAN_NOTICE("You fit \the [src]."))
	qdel(src)
	return TRUE

/obj/item/dentures/bone
	name = "carved bone dentures"
	desc = "A set of false teeth carved from a single piece of bone. They look better than gaps, but are poor for chewing and are best taken out to eat."
	icon_state = "dentures_bone"
	chew_factor = 0.3
	worn_text = "carved bone false teeth"

/obj/item/dentures/human
	name = "human-tooth dentures"
	desc = "Real human teeth riveted into a carved bone base. They chew far better than carved teeth."
	icon_state = "dentures_human"
	chew_factor = 0.6
	worn_text = "a set of false teeth made of other people's teeth"

/obj/item/dentures/porcelain
	name = "porcelain dentures"
	desc = "Glossy fired porcelain teeth and gums. They never rot or stain, but they can shatter."
	icon_state = "dentures_porcelain"
	chew_factor = 0.8
	worn_text = "bright porcelain false teeth"
	brittle = TRUE

/obj/item/dentures/vulcanite
	name = "vulcanite dentures"
	desc = "Porcelain teeth set in a moulded base of hard vulcanised rubber. Cheap, snug and tough."
	icon_state = "dentures_vulcanite"
	chew_factor = 0.9
	worn_text = "vulcanite false teeth"

/obj/item/dentures/acrylic
	name = "acrylic dentures"
	desc = "A modern set of false teeth in pink acrylic. Light, strong and comfortable."
	icon_state = "dentures_acrylic"
	chew_factor = 1
	worn_text = "acrylic false teeth"

// Unfired porcelain shapes fire into a set in any kiln.
/obj/item/weapon/clay/porcelain_dentures
	name = "unfired porcelain dentures"
	desc = "Fine clay shaped into a set of teeth and gums. Fire it in a kiln."
	icon = 'icons/obj/dentistry.dmi'
	icon_state = "porcelain_unfired"
	result = /obj/item/dentures/porcelain

// Dentures and bridges can fly out with the teeth on a hard blow.
/obj/item/organ/external/head/proc/knock_out_prosthetics()
	if (!owner)
		return FALSE
	if (ispath(denture_type, /obj/item/dentures) && prob(50))
		var/obj/item/dentures/D = denture_type
		denture_type = null
		denture_teeth = 0
		if (initial(D.brittle) && prob(40))
			owner.visible_message(SPAN_DANGER("[owner]'s porcelain teeth shatter!"))
			return TRUE
		var/obj/item/dentures/out = new D(get_turf(owner))
		out.throw_at(get_step(get_turf(owner), pick(cardinal)), 2, 1)
		owner.visible_message(SPAN_DANGER("[owner]'s false teeth fly out!"))
		return TRUE
	return FALSE

////////////////////////////////////////////////////////////////////////
// Surgery steps on the mouth (face closed)
////////////////////////////////////////////////////////////////////////

/datum/surgery_step/dental
	priority = 1
	can_infect = TRUE
	blood_level = 0

/datum/surgery_step/dental/can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
	if (target_zone != "mouth" || !ishuman(target) || target.op_stage.face)
		return FALSE
	var/obj/item/organ/external/head/H = target.dental_head()
	if (!H || H.open)
		return FALSE
	if (target.check_mouth_coverage())
		return FALSE
	return TRUE

/datum/surgery_step/dental/proc/known_or_warn(mob/living/user, node_id)
	if (!ishuman(user))
		return FALSE
	return crafting_node_allowed_or_warn(user, node_id)

// Drawing a tooth: the rotten one first. Any era; pliers do at a pinch.
/datum/surgery_step/dental/extract
	allowed_tools = alist(
		1 = list("/obj/item/weapon/surgery/hemostat", 60),
		2 = list("/obj/item/weapon/wirecutters", 55),
		3 = list("/obj/item/weapon/surgery/dental_forceps", 100),
		4 = list("/obj/item/weapon/surgery/dental_forceps/bronze", 90),
	)
	min_duration = 40
	max_duration = 60
	blood_level = 1

/datum/surgery_step/dental/extract/can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
	if (!..())
		return FALSE
	var/obj/item/organ/external/head/H = target.dental_head()
	return H.get_teeth() > 0

/datum/surgery_step/dental/extract/begin_step(mob/user, mob/living/human/target, target_zone, obj/item/tool)
	var/obj/item/organ/external/head/H = target.dental_head()
	user.visible_message("[user] grips one of [target]'s [H.decayed_teeth ? "rotten " : ""]teeth with \the [tool] and starts to pull.", \
		"You grip one of [target]'s [H.decayed_teeth ? "rotten " : ""]teeth with \the [tool] and start to pull.")
	target.custom_pain("Your tooth is being wrenched from its socket!", 60)
	..()

/datum/surgery_step/dental/extract/end_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
	var/obj/item/organ/external/head/H = target.dental_head()
	if (!H)
		return
	var/had_abscess = H.abscess
	var/obj/item/stack/teeth/T = H.remove_natural_tooth(TRUE)
	if (!T)
		return
	H.lose_dental_teeth(0, H.get_teeth())
	user.visible_message(SPAN_NOTICE("[user] draws \a [T.singular_name] out of [target]'s mouth with \the [tool]."), \
		SPAN_NOTICE("You draw \a [T.singular_name] out of [target]'s mouth."))
	if (had_abscess && !H.abscess)
		to_chat(target, SPAN_NOTICE("The pressure in your jaw eases as the bad tooth comes out."))
	else if (had_abscess && H.abscess)
		H.abscess = FALSE
		H.caries_minutes = 0
		to_chat(target, SPAN_NOTICE("The abscess drains with the tooth. Another bad tooth is left."))
	H.take_damage(2, 0)
	if (ishuman(user) && prob(40))
		var/mob/living/human/U = user
		U.bloody_hands(target, FALSE)

/datum/surgery_step/dental/extract/fail_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
	var/obj/item/organ/external/head/H = target.dental_head()
	user.visible_message(SPAN_WARNING("[user]'s grip slips and the tooth cracks in [target]'s jaw!"), \
		SPAN_WARNING("Your grip slips and the tooth cracks!"))
	target.custom_pain("A crack of pain splits your jaw!", 70, TRUE)
	if (H)
		H.take_damage(5, 0)

// Pushing a freshly knocked-out tooth back into its socket (Abulcasis, Pare).
/datum/surgery_step/dental/replant
	allowed_tools = alist(
		1 = list("/obj/item/stack/teeth", 100),
	)
	min_duration = 15
	max_duration = 25
	can_infect = FALSE

/datum/surgery_step/dental/replant/can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
	if (!..())
		return FALSE
	var/obj/item/stack/teeth/T = tool
	var/obj/item/organ/external/head/H = target.dental_head()
	if (!istype(T) || !T.is_fresh_for(target) || H.get_teeth() >= H.max_teeth)
		return FALSE
	if (!known_or_warn(user, "surgical_theory"))
		return DENTAL_REFUSED
	return TRUE

/datum/surgery_step/dental/replant/begin_step(mob/user, mob/living/human/target, target_zone, obj/item/tool)
	user.visible_message("[user] starts pressing a knocked-out tooth back into [target]'s gum.", \
		"You start pressing the tooth back into its socket.")
	target.custom_pain("Your gum aches as the tooth is pressed home.", 30)
	..()

/datum/surgery_step/dental/replant/end_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
	var/obj/item/stack/teeth/T = tool
	var/obj/item/organ/external/head/H = target.dental_head()
	if (!istype(T) || !H || !T.is_fresh_for(target))
		return
	// The sooner it goes back, the likelier it takes: about half at once,
	// falling to about one in five by the end of the window.
	var/elapsed = (world.time - T.knocked_out_at) / DENTAL_REPLANT_WINDOW
	var/chance = 50 - 30 * Clamp(elapsed, 0, 1)
	if (!T.use(1))
		return
	if (prob(chance) && H.add_natural_tooth())
		user.visible_message(SPAN_NOTICE("[user] seats the tooth back in [target]'s gum. It holds."), \
			SPAN_NOTICE("The tooth seats firmly. It has taken."))
	else
		user.visible_message(SPAN_WARNING("The tooth will not hold in [target]'s gum and drops out, dead."), \
			SPAN_WARNING("The tooth will not hold. Its root is dead."))
		var/obj/item/stack/teeth/dead = new T.type(get_turf(target), 1)
		dead.add_blood(target)

// Scraping or drilling out the rot so a cavity can be filled.
/datum/surgery_step/dental/prepare_cavity
	allowed_tools = alist(
		1 = list("/obj/item/weapon/surgery/dental_pick", 85),
		2 = list("/obj/item/weapon/surgery/surgicaldrill", 100),
	)
	min_duration = 50
	max_duration = 70

/datum/surgery_step/dental/prepare_cavity/can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
	if (!..())
		return FALSE
	var/obj/item/organ/external/head/H = target.dental_head()
	if (H.decayed_teeth - H.prepared_teeth <= 0)
		return FALSE
	if (H.abscess)
		to_chat(user, SPAN_WARNING("That tooth is abscessed. Draw it, or clear the infection first, before filling it."))
		return DENTAL_REFUSED
	if (!known_or_warn(user, "surgical_theory"))
		return DENTAL_REFUSED
	return TRUE

/datum/surgery_step/dental/prepare_cavity/begin_step(mob/user, mob/living/human/target, target_zone, obj/item/tool)
	user.visible_message("[user] starts working the rot out of one of [target]'s teeth with \the [tool].", \
		"You start working the rot out of the cavity with \the [tool].")
	target.custom_pain("Your tooth screams as it is [istype(tool, /obj/item/weapon/surgery/surgicaldrill) ? "drilled" : "scraped"]!", 50)
	..()

/datum/surgery_step/dental/prepare_cavity/end_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
	var/obj/item/organ/external/head/H = target.dental_head()
	if (!H || H.decayed_teeth - H.prepared_teeth <= 0)
		return
	H.prepared_teeth++
	user.visible_message(SPAN_NOTICE("[user] cleans out the cavity in [target]'s tooth. It is ready for a filling."), \
		SPAN_NOTICE("The cavity is clean and ready for a filling."))

/datum/surgery_step/dental/prepare_cavity/fail_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
	user.visible_message(SPAN_WARNING("[user]'s [tool.name] skids off the tooth and into [target]'s gum!"), \
		SPAN_WARNING("Your [tool.name] skids into the gum!"))
	target.custom_pain("Something stabs into your gum!", 40, TRUE)
	var/obj/item/organ/external/head/H = target.dental_head()
	if (H)
		H.take_damage(3, 0)

// Packing the clean cavity: lead and tin first, gold leaf later, then amalgam.
/datum/surgery_step/dental/fill_cavity
	allowed_tools = alist(
		1 = list("/obj/item/stack/material/lead", 75),
		2 = list("/obj/item/stack/material/tin", 80),
		3 = list("/obj/item/stack/material/gold", 90),
		4 = list("/obj/item/stack/ore/amalgam/silver", 100),
		5 = list("/obj/item/stack/ore/amalgam/silver_pressed", 100),
	)
	min_duration = 40
	max_duration = 50
	can_infect = FALSE

/datum/surgery_step/dental/fill_cavity/can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
	if (!..())
		return FALSE
	var/obj/item/organ/external/head/H = target.dental_head()
	if (H.prepared_teeth <= 0)
		return FALSE
	var/node = istype(tool, /obj/item/stack/ore/amalgam) ? "anesthetic_surgery" : "surgical_theory"
	if (!known_or_warn(user, node))
		return DENTAL_REFUSED
	return TRUE

/datum/surgery_step/dental/fill_cavity/begin_step(mob/user, mob/living/human/target, target_zone, obj/item/tool)
	user.visible_message("[user] starts packing [tool] into the cavity in [target]'s tooth.", \
		"You start packing [tool] into the cavity.")
	..()

/datum/surgery_step/dental/fill_cavity/end_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
	var/obj/item/organ/external/head/H = target.dental_head()
	var/obj/item/stack/S = tool
	if (!H || H.prepared_teeth <= 0 || !istype(S) || !S.use(1))
		return
	H.prepared_teeth--
	H.decayed_teeth--
	H.filled_teeth++
	H.clamp_dental_state()
	user.visible_message(SPAN_NOTICE("[user] fills the cavity in [target]'s tooth."), \
		SPAN_NOTICE("You fill the cavity. The tooth is sound again."))

// Binding a band bridge to the teeth either side of a gap (Etruscan work).
/datum/surgery_step/dental/fit_bridge
	allowed_tools = alist(
		1 = list("/obj/item/dental_bridge", 100),
	)
	min_duration = 50
	max_duration = 70
	can_infect = FALSE

/datum/surgery_step/dental/fit_bridge/can_use(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
	if (!..())
		return FALSE
	var/obj/item/organ/external/head/H = target.dental_head()
	if (H.max_teeth - H.get_teeth() - H.bridge_teeth - H.denture_teeth <= 0)
		return FALSE
	if (H.get_teeth() < DENTAL_BRIDGE_ANCHORS)
		to_chat(user, SPAN_WARNING("There are not enough natural teeth left to bind a bridge to."))
		return DENTAL_REFUSED
	return TRUE

/datum/surgery_step/dental/fit_bridge/begin_step(mob/user, mob/living/human/target, target_zone, obj/item/tool)
	user.visible_message("[user] starts binding \the [tool] to the teeth in [target]'s mouth.", \
		"You start binding \the [tool] to the teeth either side of the gap.")
	..()

/datum/surgery_step/dental/fit_bridge/end_step(mob/living/user, mob/living/human/target, target_zone, obj/item/tool)
	var/obj/item/organ/external/head/H = target.dental_head()
	var/obj/item/dental_bridge/B = tool
	if (!H || !istype(B))
		return
	var/gaps = H.max_teeth - H.get_teeth() - H.bridge_teeth - H.denture_teeth
	if (gaps <= 0)
		return
	H.bridge_teeth += min(gaps, B.teeth_held)
	user.drop_from_inventory(B)
	qdel(B)
	user.visible_message(SPAN_NOTICE("[user] binds a gold band bridge into [target]'s mouth."), \
		SPAN_NOTICE("You bind the bridge in place."))

#undef DENTAL_TICK
#undef DENTAL_PLAQUE_MAX
#undef DENTAL_PLAQUE_ROT
#undef DENTAL_ROT_CHANCE
#undef DENTAL_SWEET_PLAQUE
#undef DENTAL_ABSCESS_AFTER
#undef DENTAL_ABSCESS_CHANCE
#undef DENTAL_TOOTHACHE_PAIN
#undef DENTAL_ABSCESS_PAIN
#undef DENTAL_ABSCESS_TOX_CAP
#undef DENTAL_CHEW_FULL
#undef DENTAL_SPEECH_GAPS
#undef DENTAL_REPLANT_WINDOW
#undef DENTAL_BRIDGE_ANCHORS
#undef DENTAL_REFUSED
