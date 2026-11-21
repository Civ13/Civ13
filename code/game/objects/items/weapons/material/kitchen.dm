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
		if (M == user)
			if (!M.can_eat(loaded))
				return
			else if (M.get_fullness() > M.food_fullness_limit())
				to_chat(user, "<span class='danger'>You cannot force any more food to go down your throat.</span>")
				return
			reagents.trans_to_mob(M, reagents.total_volume, CHEM_INGEST)
			M.visible_message("<span class='notice'>\The [user] eats some [loaded] from \the [src].</span>")
		else
			user.visible_message("<span class='warning'>\The [user] begins to feed \the [M]!</span>")
			if (!(M.can_force_feed(user, loaded) && do_mob(user, M, 5 SECONDS)))
				return
			if (!reagents.total_volume || !M.can_finish_force_feed(user, loaded))
				return
			reagents.trans_to_mob(M, reagents.total_volume, CHEM_INGEST)
			M.visible_message("<span class='notice'>\The [user] feeds some [loaded] to \the [M] with \the [src].</span>")
			// Past capacity it still goes down, but it comes back up.
			if (M.is_overfed())
				M.overfed_vomit(user)
		playsound(M.loc,"eat", rand(20,45), TRUE)
		overlays.Cut()
		return
	else
		to_chat(user, "<span class='warning'>You don't have anything on \the [src].</span>")	//if we have help intent and no food scooped up DON'T STAB OURSELVES WITH THE FORK
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
	tool_flags = TOOL_KNIFE
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
		to_chat(user, "<span class = 'notice'>Ow...</span>")
		user.apply_effect(110,AGONY,0)
		user.apply_damage(src.sharpness*2.5, "brute", "groin")
		user.death()
		user.visible_message("<span class = 'warning'>[user] cuts themselves open.</span>")
		M.append_attack_log("\[[time_stamp()]\] [M]/[M.ckey]</b> disemboweled themselves.")
		suicide = FALSE

/obj/item/weapon/material/kitchen/utensil/knife/attack(atom/A, mob/living/user, target_zone)
	if (A == user)
		if (target_zone == "groin" && !suicide)
			handle_suicide(user)
			return TRUE
	return ..(A, user, target_zone)

/obj/item/weapon/material/kitchen/utensil/knife/razorblade
	name = "razor blade"
	desc = "A folding blade, used to cut beard and hairs. Aim at the head or face on any intent but harm to groom."
	icon = 'icons/obj/items.dmi'
	icon_state = "razorblade"
	item_state = "knife"
	force_divisor = 0.2
	w_class = ITEM_SIZE_TINY

/obj/item/weapon/material/kitchen/utensil/knife/attack_self(mob/user)
	..()
	if(atk_mode == SLASH)
		atk_mode = STAB
		to_chat(user, "<span class='notice'>You will now stab.</span>")
		edge = FALSE
		sharp = TRUE
		attack_verb = list("stabbed")
		hitsound = "stab_sound"
		return

	else if(atk_mode == STAB)
		atk_mode = SLASH
		to_chat(user, "<span class='notice'>You will now slash.</span>")
		attack_verb = list("slashed", "diced")
		hitsound = "slash_sound"
		edge = TRUE
		sharp = TRUE
		return

// Any intent but harm on the head or face grooms; harm still cuts.
/obj/item/weapon/material/kitchen/utensil/knife/razorblade/attack(mob/living/human/M as mob, mob/living/user as mob)
	if (user.a_intent != I_HARM && (user.targeted_organ in list("head", "eyes", "mouth")) && ishuman(M) && ishuman(user) && ((M in range(user,1)) || M == user))
		groom(M, user)
		return TRUE
	return ..()

/obj/item/weapon/material/kitchen/utensil/knife/razorblade/proc/groom(mob/living/human/M, mob/living/human/user)
	// Preview only self-grooming for a connected player. Preserve the classic
	// independent hair/beard prompts for other targets and clientless actors.
	var/client/C = user.client
	if (M != user || !C)
		return groom_classic(M, user)
	if (C.grooming_preview || !grooming_valid(M, user))
		return
	var/datum/grooming_preview/P = new()
	P.viewer = user
	P.viewer_client = C
	P.razor = src
	P.subject = M
	C.grooming_preview = P
	groom_select(M, user, P)
	P.close()
	qdel(P)

/obj/item/weapon/material/kitchen/utensil/knife/razorblade/proc/groom_classic(mob/living/human/M, mob/living/human/user)
	if (M == user)
		user.visible_message("[user] starts cutting their own hair...", "You start cutting your hair...")
	else
		user.visible_message("[user] starts cutting [M]'s hair...", "You start cutting [M]'s hair...")
	if (!do_after(user, 80, M))
		return
	var/list/hairlist = M.generate_valid_hairstyles(1,1)
	var/new_hstyle = WWinput(user, "Please select a hair style.", "Grooming", WWinput_first_choice(hairlist), WWinput_list_or_null(hairlist))
	if (new_hstyle && (new_hstyle in hairlist))
		M.h_style = new_hstyle
		var/datum/sprite_accessory/S = hair_styles_list[new_hstyle]
		if (S)
			M.h_growth = S.growth
	if (M.gender == MALE)
		var/list/fhairlist = M.generate_valid_facial_hairstyles(1)
		var/new_fstyle = WWinput(user, "Please select a facial hair style.", "Grooming", WWinput_first_choice(fhairlist), WWinput_list_or_null(fhairlist))
		if (new_fstyle && (new_fstyle in fhairlist))
			M.f_style = new_fstyle
			var/datum/sprite_accessory/F = facial_hair_styles_list[new_fstyle]
			if (F)
				M.f_growth = F.growth
	M.update_hair()
	M.update_body()
	user.visible_message("[user] finishes cutting [M == user ? "their own" : "[M]'s"] hair.", "You finish cutting [M == user ? "your" : "[M]'s"] hair.")

/obj/item/weapon/material/kitchen/utensil/knife/razorblade/proc/grooming_valid(mob/living/human/M, mob/living/human/user)
	if (QDELETED(src) || QDELETED(M) || QDELETED(user) || user.get_active_hand() != src || user.incapacitated() || user.a_intent == I_HARM)
		return FALSE
	if (!M.species || !M.body_build || (M != user && !(M in range(user, 1))))
		return FALSE
	var/obj/item/organ/external/head/H = M.get_organ("head")
	return H && !H.is_stump()

/obj/item/weapon/material/kitchen/utensil/knife/razorblade/proc/groom_select(mob/living/human/M, mob/living/human/user, datum/grooming_preview/P)
	var/old_hstyle = M.h_style
	var/old_fstyle = M.f_style
	P.original_hair = old_hstyle
	P.original_beard = old_fstyle
	if (!P.ask())
		return
	var/new_hstyle = P.selected_hair
	var/new_fstyle = P.selected_beard
	if (!grooming_valid(M, user) || !P.valid() || M.h_style != old_hstyle || M.f_style != old_fstyle)
		return
	if (new_hstyle == old_hstyle && new_fstyle == old_fstyle)
		return
	if (M == user)
		user.visible_message("[user] starts cutting their own hair...", "You start cutting your hair...")
	else
		user.visible_message("[user] starts cutting [M]'s hair...", "You start cutting [M]'s hair...")
	if (!do_after(user, 80, M) || !grooming_valid(M, user) || !P.valid() || M.h_style != old_hstyle || M.f_style != old_fstyle)
		return
	if (new_hstyle != old_hstyle && !(new_hstyle in M.generate_valid_hairstyles(TRUE, TRUE)))
		return
	if (new_fstyle != old_fstyle && (M.gender != MALE || !(new_fstyle in M.generate_valid_facial_hairstyles(TRUE))))
		return
	if (new_hstyle != old_hstyle)
		var/datum/sprite_accessory/S = hair_styles_list[new_hstyle]
		M.h_style = new_hstyle
		M.h_growth = S.growth
	if (new_fstyle != old_fstyle)
		var/datum/sprite_accessory/F = facial_hair_styles_list[new_fstyle]
		M.f_style = new_fstyle
		M.f_growth = F.growth
	M.update_hair()
	M.update_body()
	user.visible_message("[user] finishes cutting [M == user ? "their own" : "[M]'s"] hair.", "You finish cutting [M == user ? "your" : "[M]'s"] hair.")

/client/var/tmp/datum/grooming_preview/grooming_preview

// Private, transient review of a proposed cut. Only the initiating body can answer.
/datum/grooming_preview
	should_save = FALSE
	var/mob/living/human/viewer
	var/client/viewer_client
	var/obj/item/weapon/material/kitchen/utensil/knife/razorblade/razor
	var/mob/living/human/subject
	var/nonce
	var/waiting = FALSE
	var/accepted = FALSE
	var/original_hair
	var/original_beard
	var/selected_hair
	var/selected_beard
	var/list/hair_choices
	var/list/beard_choices

/datum/grooming_preview/proc/valid()
	return viewer_client && viewer_client.mob == viewer && viewer_client.grooming_preview == src && !QDELETED(razor) && razor.grooming_valid(subject, viewer)

/datum/grooming_preview/proc/close()
	if (viewer_client?.grooming_preview == src)
		viewer_client.grooming_preview = null
		show_browse(viewer_client, null, "window=grooming_preview")

/datum/grooming_preview/proc/ask()
	if (!valid())
		return FALSE
	waiting = TRUE
	var/token = "\ref[src]"
	var/key = md5("[token]-[world.time]")
	nonce = key
	hair_choices = subject.generate_valid_hairstyles(TRUE, TRUE) - original_hair
	beard_choices = subject.gender == MALE ? subject.generate_valid_facial_hairstyles(TRUE) - original_beard : list()
	hair_choices.Insert(1, "Keep current hair")
	beard_choices.Insert(1, "Keep current facial hair")
	var/hair_options = style_options(hair_choices, key, FALSE)
	var/beard_options = style_options(beard_choices, key, TRUE)
	var/beard_visibility = beard_choices.len > 1 ? "" : "display:none"
	var/list/pictures = list()
	for (var/side in list(SOUTH, EAST))
		var/view = side == SOUTH ? "front" : "side"
		var/icon/base = subject.grooming_head(side)
		var/icon/current = icon(base)
		var/icon/F = subject.grooming_layer(original_beard, side, TRUE)
		var/icon/H = subject.grooming_layer(original_hair, side, FALSE)
		if (F)
			current.Blend(F, ICON_OVERLAY)
		if (H)
			current.Blend(H, ICON_OVERLAY)
		var/current_file = "groom_[key]_current_[side].png"
		var/base_file = "groom_[key]_base_[side].png"
		viewer_client << browse_rsc(current, current_file)
		viewer_client << browse_rsc(base, base_file)
		pictures += "<tr><th scope='row'>[capitalize(view)]</th><td><div class='portrait'><img src='[current_file]' alt='Current [view]'></div></td><td><div class='portrait'><img src='[base_file]' alt='Proposed [view]'><img id='beard-[view]' style='display:none' alt=''><img id='scalp-[view]' style='display:none' alt=''></div></td></tr>"
	viewer_client << browse_rsc('UI/js/grooming_preview.js', "civ13_grooming_preview.js")
	var/html = {"<html><head><meta http-equiv='X-UA-Compatible' content='IE=edge'>
		<style>
		body{background:#222;color:#eee;font:14px sans-serif;text-align:center;}
		label{display:block;margin:8px 0;} select{max-width:230px;}
		th,td{padding:3px 7px;} .portrait{width:96px;height:83px;position:relative;overflow:hidden;}
		.portrait img{width:160px;height:160px;position:absolute;left:-32px;top:-2px;image-rendering:pixelated;}
		button,a{margin:0 6px;} a{color:#9df;}
		</style><script src='civ13_grooming_preview.js'></script></head>
		<body id='grooming-preview' data-ref='[html_encode(token)]' data-nonce='[html_encode(nonce)]'>
		<h2>Preview haircut</h2>
		<label for='groom-hair'>Hairstyle <select id='groom-hair'>[hair_options]</select></label>
		<label for='groom-beard' style='[beard_visibility]'>Facial hair <select id='groom-beard'>[beard_options]</select></label>
		<table align='center'><tr><td></td><th>Current</th><th>Proposed</th></tr>[jointext(pictures, "")]</table>
		<p>Headwear is not shown. Nothing changes until you apply and finish the cut.</p>
		<p><button id='groom-apply' type='button' disabled>Apply cut</button>
		<a href='?src=[token];groom=cancel;nonce=[nonce]'>Cancel</a></p></body></html>"}
	show_browse(viewer_client, html, "window=grooming_preview;size=410x415;can_close=1;can_resize=1")
	winset(viewer_client, "grooming_preview", "on-close=\".windowclose [token]\"")
	var/deadline = world.time + 1200
	while (waiting && world.time < deadline && valid())
		sleep(2)
	waiting = FALSE
	if (viewer_client?.grooming_preview == src)
		show_browse(viewer_client, null, "window=grooming_preview")
	return accepted

/datum/grooming_preview/proc/style_options(list/choices, key, facial)
	var/list/options = list()
	for (var/i in 1 to choices.len)
		var/style = i == 1 ? (facial ? original_beard : original_hair) : choices[i]
		var/list/files = list()
		for (var/side in list(SOUTH, EAST))
			var/icon/I = subject.grooming_layer(style, side, facial)
			var/file = ""
			if (I)
				file = "groom_[key]_[facial]_[i]_[side].png"
				viewer_client << browse_rsc(I, file)
			files += file
		options += "<option value='[i]' data-front='[files[1]]' data-side='[files[2]]'>[html_encode(choices[i])]</option>"
	return jointext(options, "")

/datum/grooming_preview/Topic(href, list/href_list)
	if (!waiting || usr != viewer || !valid())
		return
	if (href_list["close"])
		waiting = FALSE
		return
	if (href_list["nonce"] != nonce)
		return
	var/action = href_list["groom"]
	if (action == "cancel")
		waiting = FALSE
		return
	if (action != "apply")
		return
	var/h = text2num(href_list["hair"])
	var/f = text2num(href_list["beard"])
	if (!isnum(h) || h != round(h) || h < 1 || h > hair_choices.len || !isnum(f) || f != round(f) || f < 1 || f > beard_choices.len)
		return
	selected_hair = h == 1 ? original_hair : hair_choices[h]
	selected_beard = f == 1 ? original_beard : beard_choices[f]
	accepted = TRUE
	waiting = FALSE

// Reuse the actual style sprites and colors. Never change live hair or overlays.
/mob/living/human/proc/grooming_layer(style, side, facial)
	if (!style || body_build.nohair || body_build.nofacialhair)
		return null
	var/list/styles = facial ? facial_hair_styles_list : hair_styles_list
	var/datum/sprite_accessory/S = styles[style]
	if (!S || !(species.get_bodytype() in S.species_allowed))
		return null
	var/icon/I = icon(S.icon, "[S.icon_state]_s", side)
	if (S.do_colouration)
		I.Blend(facial ? rgb(r_facial, g_facial, b_facial) : rgb(r_hair, g_hair, b_hair), ICON_ADD)
	return I

/mob/living/human/proc/grooming_head(side)
	var/g = gender == FEMALE ? "_f" : "_m"
	var/icon/portrait = icon(species.icobase, "head[g][body_build.index]", side)
	if (species.appearance_flags & HAS_SKIN_COLOR)
		portrait.Blend(rgb(r_skin, g_skin, b_skin), ICON_ADD)
	if (species.appearance_flags & HAS_SKIN_TONE)
		var/tone = abs(s_tone)
		portrait.Blend(rgb(tone, tone, tone), s_tone >= 0 ? ICON_ADD : ICON_SUBTRACT)
	var/icon/eyes = icon('icons/mob/human_face.dmi', "eyes[body_build.index]", side)
	if (species.appearance_flags & HAS_EYE_COLOR)
		eyes.Blend(rgb(r_eyes, g_eyes, b_eyes), ICON_ADD)
	portrait.Blend(eyes, ICON_OVERLAY)
	return portrait

/obj/item/weapon/material/kitchen/utensil/knife/shank
	name = "shank"
	desc = "A small self-made knife."
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
	desc = "A dagger with two sharp edges alongside a very sharp point."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "dagger"
	item_state = "knife"
	applies_material_colour = FALSE
	unbreakable = TRUE
	drawsound = 'sound/items/unholster_knife.ogg'
	force_divisor = 0.76

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
	if(active)
		edge = TRUE
		sharp = TRUE
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
	..()
	if(active)
		throwforce = 5

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
	force_divisor = 0.4

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
				to_chat(user, "<span class = 'notice'>[H] is already circumcised!</span>")
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
	force_divisor = 0.4 // 42 when wielded with hardness 60 (steel)
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
