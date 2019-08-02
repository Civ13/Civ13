/*
	Global associative list for caching humanoid icons.
	Index format m or f, followed by a string of FALSE and TRUE to represent bodyparts followed by husk fat hulk skeleton TRUE or 0.
	TODO: Proper documentation
	icon_key is [species.race_key][g][husk][fat][hulk][skeleton][s_tone]
*/
var/global/list/human_icon_cache = list()
var/global/list/tail_icon_cache = list() //key is [species.race_key][r_skin][g_skin][b_skin]
var/global/list/light_overlay_cache = list()

	///////////////////////
	//UPDATE_ICONS SYSTEM//
	///////////////////////
/*
Calling this  a system is perhaps a bit trumped up. It is essentially update_clothing dismantled into its
core parts. The key difference is that when we generate overlays we do not generate either lying or standing
versions. Instead, we generate both and store them in two fixed-length lists, both using the same list-index
(The indexes are in update_icons.dm): Each list for humans is (at the time of writing) of length 19.
This will hopefully be reduced as the system is refined.

	var/overlays_lying[19]			//For the lying down stance
	var/overlays_standing[19]		//For the standing stance

When we call update_icons, the 'lying' variable is checked and then the appropriate list is assigned to our overlays!
That in itself uses a tiny bit more memory (no more than all the ridiculous lists the game has already mind you).

On the other-hand, it should be very CPU cheap in comparison to the old system.
In the old system, we updated all our overlays every life() call, even if we were standing still inside a crate!
or dead!. 25ish overlays, all generated from scratch every second for every xeno/human/monkey and then applied.
More often than not update_clothing was being called a few times in addition to that! CPU was not the only issue,
all those icons had to be sent to every client. So really the cost was extremely cumulative. To the point where
update_clothing would frequently appear in the top 10 most CPU intensive procs during profiling.

Another feature of this new system is that our lists are indexed. This means we can update specific overlays!
So we only regenerate icons when we need them to be updated! This is the main saving for this system.

In practice this means that:
	everytime you fall over, we just switch between precompiled lists. Which is fast and cheap.
	Everytime you do something minor like take a pen out of your pocket, we only update the in-hand overlay
	etc...


There are several things that need to be remembered:

>	Whenever we do something that should cause an overlay to update (which doesn't use standard procs
	( i.e. you do something like l_hand = /obj/item/something new(src) )
	You will need to call the relevant update_inv_* proc:
		update_inv_head()
		update_inv_wear_suit()
		update_inv_gloves()
		update_inv_shoes()
		update_inv_w_uniform()
		update_inv_eyes()
		update_inv_l_hand()
		update_inv_r_hand()
		update_inv_belt()
		update_inv_wear_id()
		update_inv_ears()
		update_inv_pockets()
		update_inv_back()
		update_inv_shoulder()
		update_inv_handcuffed()
		update_inv_wear_mask()

	All of these are named after the variable they update from. They are defined at the mob/ level like
	update_clothing was, so you won't cause undefined proc runtimes with usr.update_inv_wear_id() if the usr is a
	slime etc. Instead, it'll just return without doing any work. So no harm in calling it for slimes and such.


>	There are also these special cases:
		update_mutations()	//handles updating your appearance for certain mutations.  e.g TK head-glows
		UpdateDamageIcon()	//handles damage overlays for brute/burn damage //(will rename this when I geta round to it)
		update_body()	//Handles updating your mob's icon to reflect their gender/race/complexion etc
		update_hair()	//Handles updating your hair overlay (used to be update_face, but mouth and
																			...eyes were merged into update_body)
		update_targeted() // Updates the target overlay when someone points a gun at you

>	All of these procs update our overlays_lying and overlays_standing, and then call update_icons() by default.
	If you wish to update several overlays at once, you can set the argument to FALSE to disable the update and call
	it manually:
		e.g.
		update_inv_head(0)
		update_inv_l_hand(0)
		update_inv_r_hand()		//<---calls update_icons()

	or equivillantly:
		update_inv_head(0)
		update_inv_l_hand(0)
		update_inv_r_hand(0)
		update_icons()

>	If you need to update all overlays you can use regenerate_icons(). it works exactly like update_clothing used to.

>	I reimplimented an old unused variable which was in the code called (coincidentally) var/update_icon
	It can be used as another method of triggering regenerate_icons(). It's basically a flag that when set to non-zero
	will call regenerate_icons() at the next life() call and then reset itself to 0.
	The idea behind it is icons are regenerated only once, even if multiple events requested it.

This system is confusing and is still a WIP. It's primary goal is speeding up the controls of the game whilst
reducing processing costs. So please bear with me while I iron out the kinks. It will be worth it, I promise.
If I can eventually free var/lying stuff from the life() process altogether, stuns/death/status stuff
will become less affected by lag-spikes and will be instantaneous! :3

If you have any questions/constructive-comments/bugs-to-report/or have a massivly devestated butt...
Please contact me on #coderbus IRC. ~Carn x
*/

//Human Overlays Indexes/////////
#define MUTATIONS_LAYER			1
#define DAMAGE_LAYER			2
#define SURGERY_LEVEL			3		//bs12 specific.
#define UNIFORM_LAYER			4
#define ID_LAYER				5
#define SHOES_LAYER				6
#define GLOVES_LAYER			7
#define BELT_LAYER				8
#define SUIT_LAYER				9
#define EYES_LAYER				10
#define GLASSES_LAYER			11
#define BELT_LAYER_ALT			12
#define SUIT_STORE_LAYER		13
#define BACK_LAYER				14
#define HAIR_LAYER				15		//TODO: make part of head layer?
#define EARS_LAYER				16
#define FACEMASK_LAYER			17
#define BANDAGES_LAYER			18
#define HEAD_LAYER				19
#define SHOULDER_LAYER			20
#define HANDCUFF_LAYER			21
#define LEGCUFF_LAYER			22
#define L_HAND_LAYER			23
#define R_HAND_LAYER			24
#define FIRE_LAYER				25		//If you're on fire
#define TARGETED_LAYER			26		//BS12: Layer for the target overlay from weapon targeting system
#define OVEREFFECTS_LAYER		27
#define TOTAL_LAYERS			27
//////////////////////////////////

/mob/living/carbon/human
	var/list/overlays_standing[TOTAL_LAYERS]
	var/previous_damage_appearance // store what the body last looked like, so we only have to update it if something changed

//UPDATES OVERLAYS FROM OVERLAYS_LYING/OVERLAYS_STANDING
//this proc is messy as I was forced to include some old laggy cloaking code to it so that I don't break cloakers
//I'll work on removing that stuff by rewriting some of the cloaking stuff at a later date.
/mob/living/carbon/human/update_icons()
	lying_prev = lying	//so we don't update overlays for lying/standing unless our stance changes again
//	update_hud()		//TODO: remove the need for this
	overlays.Cut()

	if (icon_update)
		icon = stand_icon
		for (var/image/I in overlays_standing)
			overlays += I
		if (species.has_floating_eyes)
			overlays |= species.get_eyes(src)

	if ((lying || prone) && !species.prone_icon) //Only rotate them if we're not drawing a specific icon for being prone.
		var/matrix/M = matrix()
		M.Turn(90)
		M.Scale(size_multiplier)
		M.Translate(1,-6)
		transform = M
	else
		var/matrix/M = matrix()
		M.Scale(size_multiplier)
		M.Translate(0, 16*(size_multiplier-1))
		transform = M
	if (riding)
		riding_mob.update_icons()
	..()

var/global/list/damage_icon_parts = list()

//DAMAGE OVERLAYS
//constructs damage icon for each organ from mask * damage field and saves it in our overlays_ lists
/mob/living/carbon/human/UpdateDamageIcon(var/update_icons=1)
	// first check whether something actually changed about damage appearance
	var/damage_appearance = ""

	for (var/obj/item/organ/external/O in organs)
		if (O.is_stump())
			continue
		damage_appearance += O.damage_state

	if (damage_appearance == previous_damage_appearance)
		// nothing to do here
		return

	previous_damage_appearance = damage_appearance

	var/image/standing_image = image(species.damage_overlays, icon_state = "00")

	// blend the individual damage states with our icons
	for (var/obj/item/organ/external/O in organs)
		if (O.is_stump())
			continue

		O.update_damstate()
		if (O.damage_state == "00") continue
		var/icon/DI
		var/cache_index = "[O.damage_state]/[O.icon_name]/[species.blood_color]/[species.get_bodytype()]"
		if (damage_icon_parts[cache_index] == null)
			DI = new /icon(species.damage_overlays, O.damage_state)			// the damage icon for whole human
			DI.Blend(new /icon(species.damage_mask, O.icon_name), ICON_MULTIPLY)	// mask with this organ's pixels
			DI.Blend(species.blood_color, ICON_MULTIPLY)
			damage_icon_parts[cache_index] = DI
		else
			DI = damage_icon_parts[cache_index]
		standing_image.overlays += DI

	overlays_standing[DAMAGE_LAYER]	= standing_image

	if (update_icons)   update_icons()

//BASE MOB SPRITE
/mob/living/carbon/human/proc/update_body(var/update_icons=1, var/forced=FALSE)

	//CACHING: Generate an index key from visible bodyparts.
	//0 = destroyed, TRUE = normal, 2 = necrotic.

	//Create a new, blank icon for our mob to use.
	if (stand_icon)
		qdel(stand_icon)
	stand_icon = new('icons/mob/human.dmi',"blank")

	var/g = "male"
	if (gender == FEMALE)
		g = "female"

	var/icon_key = "[species.race_key][g][s_tone][r_skin][g_skin][b_skin]"
	if (lip_style)
		icon_key += "[lip_style]"
	else
		icon_key += "nolips"
	var/obj/item/organ/eyes/eyes = internal_organs_by_name["eyes"]
	if (eyes)
		icon_key += "[rgb(eyes.eye_colour[1], eyes.eye_colour[2], eyes.eye_colour[3])]"
	else
		icon_key += "#000000"

	for (var/organ_tag in species.has_limbs)
		var/obj/item/organ/external/part = organs_by_name[organ_tag]
		if (isnull(part) || part.is_stump())
			icon_key += "0"
		else if (part.status & ORGAN_DEAD)
			icon_key += "2"
		else
			icon_key += "1"
		if (part)
			icon_key += "[part.species.race_key]"
			icon_key += "[part.dna.GetUIState(DNA_UI_GENDER)]"
			icon_key += "[part.dna.GetUIValue(DNA_UI_SKIN_TONE)]"
			if (part.s_col && part.s_col.len >= 3)
				icon_key += "[rgb(part.s_col[1],part.s_col[2],part.s_col[3])]"
			else
				icon_key += "#000000"
	var/icon/base_icon
	if (human_icon_cache[icon_key] && !forced)
		base_icon = human_icon_cache[icon_key]
	else
		//BEGIN CACHED ICON GENERATION.
		base_icon = new('icons/mob/human.dmi',"blank")

		for (var/obj/item/organ/external/part in organs)
			var/icon/temp = part.get_icon()
			//That part makes left and right legs drawn topmost and lowermost when human looks WEST or EAST
			//And no change in rendering for other parts (they icon_position is FALSE, so goes to 'else' part)
			if (part.icon_position&(LEFT|RIGHT))
				var/icon/temp2 = new('icons/mob/human.dmi',"blank")
				temp2.Insert(new/icon(temp,dir=NORTH),dir=NORTH)
				temp2.Insert(new/icon(temp,dir=SOUTH),dir=SOUTH)
				if (!(part.icon_position & LEFT))
					temp2.Insert(new/icon(temp,dir=EAST),dir=EAST)
				if (!(part.icon_position & RIGHT))
					temp2.Insert(new/icon(temp,dir=WEST),dir=WEST)
				base_icon.Blend(temp2, ICON_OVERLAY)
				if (part.icon_position & LEFT)
					temp2.Insert(new/icon(temp,dir=EAST),dir=EAST)
				if (part.icon_position & RIGHT)
					temp2.Insert(new/icon(temp,dir=WEST),dir=WEST)
				base_icon.Blend(temp2, ICON_UNDERLAY)
			else
				base_icon.Blend(temp, ICON_OVERLAY)

		human_icon_cache[icon_key] = base_icon

	//END CACHED ICON GENERATION.
	stand_icon.Blend(base_icon,ICON_OVERLAY)

	if (update_icons)
		update_icons()


//HAIR OVERLAY
/mob/living/carbon/human/proc/update_hair(var/update_icons=1)
	//Reset our hair
	overlays_standing[HAIR_LAYER]	= null
	if (body_build.nohair || body_build.nofacialhair) return
	var/obj/item/organ/external/head/head_organ = get_organ("head")
	if (!head_organ || head_organ.is_stump() )
		if (update_icons)   update_icons()
		return

	//masks and helmets can obscure our hair.
	if ( (head && (head.flags_inv & BLOCKHAIR)) || (wear_mask && (wear_mask.flags_inv & BLOCKHAIR)))

		if (update_icons)   update_icons()
		return
	if (wear_suit)
		if (istype(wear_suit, /obj/item/clothing/suit/storage/coat/fur))
			var/obj/item/clothing/suit/storage/coat/fur/F = wear_suit
			if (F.hood == TRUE)
				overlays_standing[HAIR_LAYER]	= null
				if (update_icons)   update_icons()
				return
		else if (istype(wear_suit, /obj/item/clothing/suit/storage/jacket/kool_kids_klub))
			overlays_standing[HAIR_LAYER]	= null
			if (update_icons)   update_icons()
			return
	//base icons
	var/icon/face_standing	= new /icon('icons/mob/human_face.dmi',"bald_s")

	if (f_style)
		var/datum/sprite_accessory/facial_hair_style = facial_hair_styles_list[f_style]
		if (facial_hair_style && facial_hair_style.species_allowed && (species.get_bodytype() in facial_hair_style.species_allowed))
			var/icon/facial_s = new/icon("icon" = facial_hair_style.icon, "icon_state" = "[facial_hair_style.icon_state]_s")
			if (facial_hair_style.do_colouration)
				facial_s.Blend(rgb(r_facial, g_facial, b_facial), ICON_ADD)

			face_standing.Blend(facial_s, ICON_OVERLAY)

	if (h_style && !(head && (head.flags_inv & BLOCKHEADHAIR && wear_suit)))
		if (istype(wear_suit, /obj/item/clothing/suit/storage/coat/fur))
			var/obj/item/clothing/suit/storage/coat/fur/C = wear_suit
			if ( C.hood == FALSE)
				var/datum/sprite_accessory/hair_style = hair_styles_list[h_style]
				if (hair_style && (species.get_bodytype() in hair_style.species_allowed))
					var/icon/hair_s = new/icon("icon" = hair_style.icon, "icon_state" = "[hair_style.icon_state]_s")
					if (hair_style.do_colouration)
						hair_s.Blend(rgb(r_hair, g_hair, b_hair), ICON_ADD)

					face_standing.Blend(hair_s, ICON_OVERLAY)
			else
				var/datum/sprite_accessory/hair_style = hair_styles_list[h_style]
				var/icon/hair_s = new/icon("icon" = hair_style.icon, "icon_state" = "bald_s")
				face_standing.Blend(hair_s, ICON_OVERLAY)

		else if (istype(wear_suit, /obj/item/clothing/suit/storage/jacket/kool_kids_klub))
			var/datum/sprite_accessory/hair_style = hair_styles_list[h_style]
			if (hair_style && (species.get_bodytype() in hair_style.species_allowed))
				var/icon/hair_s = new/icon("icon" = hair_style.icon, "icon_state" = "[hair_style.icon_state]_s")
				if (hair_style.do_colouration)
					hair_s.Blend(rgb(r_hair, g_hair, b_hair), ICON_ADD)
		else
			var/datum/sprite_accessory/hair_style = hair_styles_list[h_style]
			if (hair_style && (species.get_bodytype() in hair_style.species_allowed))
				var/icon/hair_s = new/icon("icon" = hair_style.icon, "icon_state" = "[hair_style.icon_state]_s")
				if (hair_style.do_colouration)
					hair_s.Blend(rgb(r_hair, g_hair, b_hair), ICON_ADD)

				face_standing.Blend(hair_s, ICON_OVERLAY)
	else if (h_style && !(head && (head.flags_inv & BLOCKHEADHAIR && !wear_suit)))
		var/datum/sprite_accessory/hair_style = hair_styles_list[h_style]
		if (hair_style && (species.get_bodytype() in hair_style.species_allowed))
			var/icon/hair_s = new/icon("icon" = hair_style.icon, "icon_state" = "[hair_style.icon_state]_s")
			if (hair_style.do_colouration)
				hair_s.Blend(rgb(r_hair, g_hair, b_hair), ICON_ADD)

			face_standing.Blend(hair_s, ICON_OVERLAY)

	overlays_standing[HAIR_LAYER]	= image(face_standing)

	if (update_icons)   update_icons()

/mob/living/carbon/human/update_mutations(var/update_icons=1)
	var/obj/item/organ/external/LL = get_organ("l_leg")
	var/obj/item/organ/external/RL = get_organ("r_leg")
	var/obj/item/organ/external/LF = get_organ("l_foot")
	var/obj/item/organ/external/RF = get_organ("r_foot")
	var/image/standing
	if (LL)
		if (LL.prosthesis)
			if (LL.prosthesis_type == "none")
				return
			else
				standing = image(icon = 'icons/mob/human_races/masks/prosthesis.dmi', icon_state = "[LL.prosthesis_type]_l")
	if (RL)
		if  (RL.prosthesis)
			if (RL.prosthesis_type == "none")
				return
			else
				standing = image(icon = 'icons/mob/human_races/masks/prosthesis.dmi', icon_state = "[RL.prosthesis_type]_r")
	if (LF)
		if  (LF.prosthesis)
			if (LF.prosthesis_type == "none")
				return
			else
				standing = image(icon = 'icons/mob/human_races/masks/prosthesis.dmi', icon_state = "[LF.prosthesis_type]_l")
	if (RF)
		if  (RF.prosthesis)
			if (RF.prosthesis_type == "none")
				return
			else
				standing = image(icon = 'icons/mob/human_races/masks/prosthesis.dmi', icon_state = "[RF.prosthesis_type]_l")

	overlays_standing[MUTATIONS_LAYER] = standing

	if (update_icons)   update_icons()

//For legacy support.
/mob/living/carbon/human/regenerate_icons()
	..()
	if (transforming)
		return
	update_mutations(0)
	update_body(0)
	update_hair(0)
	update_hud()//Hud Stuff
	update_inv_w_uniform(0)
	update_inv_wear_id(0)
	update_inv_gloves(0)
	update_inv_ears(0)
	update_inv_shoes(0)
	update_inv_wear_mask(0)
	update_inv_eyes(0)
	update_inv_head(0)
	update_inv_belt(0)
	update_inv_back(0)
	update_inv_shoulder(0)
	update_inv_wear_suit(0)
	update_inv_r_hand(0)
	update_inv_l_hand(0)
	update_inv_handcuffed(0)
	update_inv_legcuffed(0)
	update_inv_pockets(0)
	update_fire(0)
	update_surgery(0)
	update_bandaging(0)
	UpdateDamageIcon()
	update_icons()


/* --------------------------------------- */
//vvvvvv UPDATE_INV PROCS vvvvvv
/mob/living/carbon/human/proc/find_inv_position(var/slot_id) //Find HUD position on screen TO:DO ìîãó ëè ÿ óïðîñòèòü???? species_hud?
	for (var/obj/screen/inventory/HUDinv in HUDinventory)
		if (HUDinv.slot_id == slot_id)
			return (HUDinv.invisibility == 101) ? null : HUDinv.screen_loc
	log_admin("[src] try find_inv_position a [slot_id], but not have that slot!")
	src << "Some problem hase accure, change UI style pls or call admins."
	return "7,7"


/mob/living/carbon/human/update_inv_w_uniform(var/update_icons=1)
	var/image/pants = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "customuni_pants")
	var/image/shirt = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "customuni_shirt")
	var/image/belt = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "customuni_over")
	var/image/epaulettes = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "customuni_epaulettes")
	var/image/brown = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "modern_camo_custom_l1")
	var/image/green = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "modern_camo_custom_l2")
	var/image/black = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "modern_camo_custom_l3")
	var/image/beltm = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "modern_camo_custom_objs")
	var/image/top = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "customdress_top")
	var/image/underc = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "customdress_under")
	var/image/over = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "customdress_over")

	if (w_uniform && istype(w_uniform, /obj/item/clothing/under))
/*		var/new_screen_loc = find_inv_position(slot_w_uniform)
		if (new_screen_loc)
			w_uniform.screen_loc = new_screen_loc*/
		w_uniform.screen_loc = find_inv_position(slot_w_uniform)

		//determine state to use
		var/under_state //switched determining state first so we can make a check in icon.
		if (w_uniform.item_state_slots && w_uniform.item_state_slots[slot_w_uniform_str])
			under_state = w_uniform.item_state_slots[slot_w_uniform_str]
		else if (w_uniform.icon_state)
			under_state = w_uniform.icon_state
		else
			under_state = w_uniform.item_state


		//determine the icon to use
		var/icon/under_icon
		if (w_uniform.icon_override)
			under_icon = w_uniform.icon_override
		else
			under_icon = body_build.uniform_icon

		//need to append _s to the icon state for legacy compatibility
		var/image/standing = image(icon = under_icon, icon_state = under_state)
		standing.color = w_uniform.color
		if (istype(w_uniform, /obj/item/clothing/under/customtribalrobe))
			var/obj/item/clothing/under/customtribalrobe/CU = w_uniform
			if (!CU.uncolored)
				pants = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "tribalrobe_decoration")
				pants.color = CU.pantscolor
				shirt = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "tribalrobe_robe")
				shirt.color = CU.shirtcolor
				belt = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "tribalrobe_robebelt")
				standing.overlays += pants
				standing.overlays += shirt
				standing.overlays += belt
		if (istype(w_uniform, /obj/item/clothing/under/customuniform))
			var/obj/item/clothing/under/customuniform/CU = w_uniform
			if (!CU.uncolored)
				pants = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "customuni_pants")
				pants.color = CU.pantscolor
				shirt = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "customuni_shirt")
				shirt.color = CU.shirtcolor
				belt = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "customuni_over")
				epaulettes = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "customuni_epaulettes")
				epaulettes.color = CU.epaulettescolor
				standing.overlays += pants
				standing.overlays += shirt
				standing.overlays += belt
				standing.overlays += epaulettes
		else if (istype(w_uniform, /obj/item/clothing/under/customdress))
			var/obj/item/clothing/under/customdress/CD = w_uniform
			if (!CD.uncolored)
				top = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "customdress_top")
				underc = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "customdress_under")
				over = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "customdress_over")
				top.color = CD.topcolor
				underc.color = CD.undercolor
				over.color = CD.overcolor
				standing.overlays += top
				standing.overlays += underc
				standing.overlays += over
		else if (istype(w_uniform, /obj/item/clothing/under/customren))
			var/obj/item/clothing/under/customren/CD = w_uniform
			if (!CD.uncolored)
				top = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "customren_top")
				underc = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "customren_lining")
				top.color = CD.topcolor
				underc.color = CD.undercolor
				standing.overlays += top
				standing.overlays += underc
		else if (istype(w_uniform, /obj/item/clothing/under/customuniform_modern))
			var/obj/item/clothing/under/customuniform_modern/CU = w_uniform
			if (!CU.uncolored)
				brown = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "modern_camo_custom_l1")
				brown.color = CU.browncolor
				green = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "modern_camo_custom_l2")
				green.color = CU.greencolor
				black = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "modern_camo_custom_l3")
				black.color = CU.blackcolor
				beltm = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "modern_camo_custom_objs")
				standing.overlays += brown
				standing.overlays += green
				standing.overlays += black
				standing.overlays += beltm
		if (istype(w_uniform, /obj/item/clothing/under/custompyjamas))
			var/obj/item/clothing/under/custompyjamas/CU = w_uniform
			if (!CU.uncolored)
				pants = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "custompyjamas_base")
				shirt = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "custompyjamas_stripes")
				shirt.color = CU.stripescolor
				standing.overlays += pants
				standing.overlays += shirt
		if (istype(w_uniform, /obj/item/clothing/under/custompontificial))
			var/obj/item/clothing/under/custompontificial/CU = w_uniform
			if (!CU.uncolored)
				pants = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "custompont_leggings")
				pants.color = CU.undercolor
				shirt = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "custompont_decore")
				shirt.color = CU.topcolor
				belt = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "custompont_handdecore")
				belt.color = CU.handcolor
				epaulettes = image("icon" = 'icons/mob/uniform.dmi', "icon_state" = "custompont_mclines")
				epaulettes.color = CU.linescolor
				standing.overlays += pants
				standing.overlays += shirt
				standing.overlays += belt
				standing.overlays += epaulettes
		//apply blood overlay
		if (w_uniform.blood_DNA)
			var/image/bloodsies	= image(icon = species.blood_mask, icon_state = "uniformblood")
			bloodsies.color		= w_uniform.blood_color
			standing.overlays	+= bloodsies

		//accessories
		var/obj/item/clothing/under/under = w_uniform
		if (under.accessories.len)
			for (var/obj/item/clothing/accessory/A in under.accessories)
				var/image/NI = A.get_mob_overlay()
				if (istype(A, /obj/item/clothing/accessory/custom))
					NI.color = A.color
				standing.overlays |= NI
		if (under.shit_overlay)
			var/shit = image("icon" = 'icons/mob/human_races/masks/sickness.dmi', "icon_state"="shit")
			standing.overlays += shit
		if (under.piss_overlay)
			var/piss = image("icon" = 'icons/mob/human_races/masks/sickness.dmi', "icon_state"="piss")
			standing.overlays += piss
		overlays_standing[UNIFORM_LAYER]	= standing
	else
		overlays_standing[UNIFORM_LAYER]	= null

	if (update_icons)
		update_icons()

/mob/living/carbon/human/update_inv_wear_id(var/update_icons=1)
	if (wear_id)
		wear_id.screen_loc = find_inv_position(slot_wear_id)
		if (w_uniform && w_uniform:displays_id)
			var/image/standing
			if (wear_id.icon_override)
				standing = image("icon" = wear_id.icon_override, "icon_state" = "[wear_id.item_state]")

			else
				standing = image("icon" = 'icons/mob/mob.dmi', "icon_state" = "id")
			overlays_standing[ID_LAYER] = standing
		else
			overlays_standing[ID_LAYER]	= null
	else
		overlays_standing[ID_LAYER]	= null

	if (update_icons)   update_icons()

/mob/living/carbon/human/update_inv_gloves(var/update_icons=1)
	if (gloves)

		var/t_state = gloves.icon_state
		if (!t_state)	t_state = gloves.item_state

		var/image/standing
		if (gloves.icon_override)
			standing = image(icon = gloves.icon_override, icon_state = t_state)

		else
			standing = image(icon = body_build.gloves_icon, icon_state = t_state)

		if (gloves.blood_DNA)
			var/image/bloodsies	= image("icon" = species.blood_mask, "icon_state" = "bloodyhands")
			bloodsies.color = gloves.blood_color
			standing.overlays	+= bloodsies
/*		var/new_screen_loc = find_inv_position(slot_gloves)
		if (new_screen_loc)
			gloves.screen_loc = new_screen_loc*/
		if (gloves)
			gloves.screen_loc = find_inv_position(slot_gloves)
			standing.color = gloves.color
			overlays_standing[GLOVES_LAYER]	= standing
	else
		if (blood_DNA)
			var/image/bloodsies	= image("icon" = species.blood_mask, "icon_state" = "bloodyhands")
			bloodsies.color = hand_blood_color
			overlays_standing[GLOVES_LAYER]	= bloodsies
		else
			overlays_standing[GLOVES_LAYER]	= null
	if (update_icons)   update_icons()

/mob/living/carbon/human/update_inv_eyes(var/update_icons=1)
	if (eyes)
/*		var/new_screen_loc = find_inv_position(slot_eyes)
		if (new_screen_loc)
			glasses.screen_loc = new_screen_loc	*/
		eyes.screen_loc = find_inv_position(slot_eyes)
		if (eyes.icon_override)
			overlays_standing[GLASSES_LAYER] = image(icon = eyes.icon_override,   icon_state = eyes.icon_state)

		else
			overlays_standing[GLASSES_LAYER] = image(icon = body_build.eyes_icon, icon_state = eyes.icon_state)

	else
		overlays_standing[EYES_LAYER]	= null
	if (update_icons)   update_icons()


/mob/living/carbon/human/update_inv_ears(var/update_icons=1)
	overlays_standing[EARS_LAYER] = null
//this was causing the image to not move, so removed
//	if ( (head && (head.flags_inv & (BLOCKHAIR | BLOCKHEADHAIR))) || (wear_mask && (wear_mask.flags_inv & (BLOCKHAIR | BLOCKHEADHAIR))))
//		if (update_icons)   update_icons()
//		return

	if (l_ear || r_ear)
		if (l_ear)
			/*var/new_screen_loc = find_inv_position(slot_l_ear)
			if (new_screen_loc)
				l_ear.screen_loc = new_screen_loc	*/
			l_ear.screen_loc = find_inv_position(slot_l_ear)
			var/t_type = l_ear.icon_state
			if (l_ear.icon_override)
				t_type = "[t_type]_l"
				overlays_standing[EARS_LAYER] = image(icon = l_ear.icon_override, icon_state = t_type)

			else
				overlays_standing[EARS_LAYER] = image(icon = body_build.ears_icon, icon_state = t_type)

		if (r_ear)
			/*var/new_screen_loc = find_inv_position(slot_r_ear)
			if (new_screen_loc)
				r_ear.screen_loc = new_screen_loc	*/
			r_ear.screen_loc = find_inv_position(slot_r_ear)
			var/t_type = r_ear.icon_state
			if (r_ear.icon_override)
				t_type = "[t_type]_r"
				overlays_standing[EARS_LAYER] = image(icon = r_ear.icon_override, icon_state = t_type)

			else
				overlays_standing[EARS_LAYER] = image(icon = body_build.ears_icon, icon_state = t_type)

	else
		overlays_standing[EARS_LAYER]	= null
	if (update_icons)   update_icons()

/mob/living/carbon/human/update_inv_shoes(var/update_icons=1)
	if (shoes && !(wear_suit && wear_suit.flags_inv & HIDESHOES))
		/*var/new_screen_loc = find_inv_position(slot_shoes)
		if (new_screen_loc)
			shoes.screen_loc = new_screen_loc	*/
		shoes.screen_loc = find_inv_position(slot_shoes)
		var/image/standing
		if (shoes.icon_override)
			standing = image(icon = shoes.icon_override,   icon_state = shoes.icon_state)

		else
			standing = image(icon = body_build.shoes_icon, icon_state = shoes.icon_state)

		if (shoes.blood_DNA)
			var/image/bloodsies = image("icon" = species.blood_mask, "icon_state" = "shoeblood")
			bloodsies.color = shoes.blood_color
			standing.overlays += bloodsies
		standing.color = shoes.color
		overlays_standing[SHOES_LAYER] = standing
	else
		if (feet_blood_DNA)
			var/image/bloodsies = image("icon" = species.blood_mask, "icon_state" = "shoeblood")
			bloodsies.color = feet_blood_color
			overlays_standing[SHOES_LAYER] = bloodsies
		else
			overlays_standing[SHOES_LAYER] = null
	if (update_icons)   update_icons()

/mob/living/carbon/human/update_inv_head(var/update_icons=1)

	var/image/band = image("icon" = 'icons/mob/head.dmi', "icon_state" = "customcap_l2")
	var/image/cap = image("icon" = 'icons/mob/head.dmi', "icon_state" = "customcap_l1")
	var/image/symbol = image("icon" = 'icons/mob/head.dmi', "icon_state" = "customcap_l3")
	if (head)
		/*var/new_screen_loc = find_inv_position(slot_head)
		if (new_screen_loc)
			head.screen_loc = new_screen_loc		*/
		head.screen_loc = find_inv_position(slot_head)

		//Determine the state to use
		var/t_state
		if (istype(head, /obj/item/weapon/paper))
			/* I don't like this, but bandaid to fix half the hats in the game
			   being completely broken without re-breaking paper hats */
			t_state = "paper"
		else
			if (head.item_state_slots && head.item_state_slots[slot_head_str])
				t_state = head.item_state_slots[slot_head_str]
			else if (head.item_state)
				t_state = head.item_state
			else
				t_state = head.icon_state
		//Determine the icon to use
		var/t_icon
		if (head.icon_override)
			t_icon = head.icon_override

		else if (head.item_icons && (slot_head_str in head.item_icons))
			t_icon = head.item_icons[slot_head_str]
		else
			t_icon = body_build.hat_icon

		//Create the image
		var/image/standing
		if (body_build.name == "Gorilla")
			standing = image(icon = 'icons/mob/human_races/r_human.dmi', icon_state = "head_m_gorilla") //its the same for male and female
			var/image/addin = image(icon = t_icon, icon_state = t_state, layer = layer+0.01)
			standing.overlays += addin
		else
			standing = image(icon = t_icon, icon_state = t_state, layer = layer+0.01)
		if (istype(head, /obj/item/clothing/head/custom_off_cap))
			var/obj/item/clothing/head/custom_off_cap/CU = head
			band = image("icon" = 'icons/mob/head.dmi', "icon_state" = "customcap_l2", layer = layer+0.01)
			band.color = CU.bandcolor
			cap = image("icon" = 'icons/mob/head.dmi', "icon_state" = "customcap_l1", layer = layer+0.01)
			cap.color = CU.capcolor
			symbol = image("icon" = 'icons/mob/head.dmi', "icon_state" = "customcap_l3", layer = layer+0.01)
			symbol.color = CU.symbolcolor
			standing.overlays += band
			standing.overlays += cap
			standing.overlays += symbol

		else if (istype(head, /obj/item/clothing/head/custom/fieldcap))
			var/obj/item/clothing/head/custom/fieldcap/CU = head
			cap = image("icon" = 'icons/mob/head.dmi', "icon_state" = "fieldcap_custom", layer = layer+0.01)
			cap.color = CU.capcolor
			standing.overlays += cap

		if (head.blood_DNA)
			var/image/bloodsies = image("icon" = species.blood_mask, "icon_state" = "helmetblood", layer = layer+0.01)
			bloodsies.color = head.blood_color
			standing.overlays += bloodsies


		if (istype(head,/obj/item/clothing/head))
			var/obj/item/clothing/head/hat = head
			if (hat.attachments.len)
				for (var/attach in hat.attachments)
					var/image/NI = image("icon_state" = "[attach]", layer = layer+0.01)
					standing.overlays |= NI
			var/cache_key = "[hat.light_overlay]_[species.get_bodytype()]"
			if (hat.on && light_overlay_cache[cache_key])
				standing.overlays |= light_overlay_cache[cache_key]

		standing.color = head.color

		overlays_standing[HEAD_LAYER] = standing

	else
		overlays_standing[HEAD_LAYER]	= null
		if (body_build.name == "Gorilla")
			var/image/gorillahead = image(icon = 'icons/mob/human_races/r_human.dmi', icon_state = "head_m_gorilla") //its the same for male and female
			overlays_standing[HEAD_LAYER] = gorillahead
	if (update_icons)   update_icons()

/mob/living/carbon/human/update_inv_belt(var/update_icons=1)
	if (belt)
		/*var/new_screen_loc = find_inv_position(slot_belt)
		if (new_screen_loc)
			belt.screen_loc = new_screen_loc	*/
		belt.screen_loc = find_inv_position(slot_belt)

		var/t_state = belt.icon_state
		if (!t_state)	t_state = belt.item_state
		var/image/standing	= image(icon_state = t_state)

		if (belt.icon_override)
			standing.icon = belt.icon_override

		else
			standing.icon = body_build.belt_icon
			//standing.icon = 'icons/mob/belt.dmi'

		var/belt_layer = BELT_LAYER
		if (istype(belt, /obj/item/weapon/storage/belt))
			var/obj/item/weapon/storage/belt/ubelt = belt
			if (ubelt.show_above_suit)
				overlays_standing[BELT_LAYER] = null
				belt_layer = BELT_LAYER_ALT
			else
				overlays_standing[BELT_LAYER_ALT] = null
			if (belt.contents.len)
				for (var/obj/item/i in belt.contents)
					var/i_state = i.item_state
					if (!i_state) i_state = i.icon_state
					standing.overlays	+= image(icon = body_build.belt_icon, icon_state = i_state)

		standing.color = belt.color

		overlays_standing[belt_layer] = standing
	else
		overlays_standing[BELT_LAYER] = null
		overlays_standing[BELT_LAYER_ALT] = null
	if (update_icons)   update_icons()


/mob/living/carbon/human/update_inv_wear_suit(var/update_icons=1)
	var/image/base = image("icon" = 'icons/mob/suit.dmi', "icon_state" = "customcolonialcoat_top")
	var/image/secondary = image("icon" = 'icons/mob/suit.dmi', "icon_state" = "customcolonialcoat_dec")
	var/image/tertiary = image("icon" = 'icons/mob/suit.dmi', "icon_state" = "customcolonialcoat_lines")
	update_surgery(0)
	if ( wear_suit && istype(wear_suit, /obj/item/) )
		/*var/new_screen_loc = find_inv_position(slot_wear_suit)
		if (new_screen_loc)
			wear_suit.screen_loc = new_screen_loc*/
		wear_suit.screen_loc = find_inv_position(slot_wear_suit)

		var/image/standing

		var/t_icon = body_build.suit_icon
		if (wear_suit.icon_override)
			t_icon = wear_suit.icon_override
		else if (wear_suit.item_icons && wear_suit.item_icons[slot_wear_suit_str])
			t_icon = wear_suit.item_icons[slot_wear_suit_str]

		standing = image(icon = t_icon, icon_state = wear_suit.icon_state)
		standing.color = wear_suit.color

		if (istype(wear_suit, /obj/item/clothing/suit/storage/jacket/customcolonialcoat))
			var/obj/item/clothing/suit/storage/jacket/customcolonialcoat/CU = wear_suit
			base = image("icon" = 'icons/mob/suit.dmi', "icon_state" = "customcolonialcoat_top")
			base.color = CU.topcolor
			secondary = image("icon" = 'icons/mob/suit.dmi', "icon_state" = "customcolonialcoat_dec")
			secondary.color = CU.deccolor
			tertiary = image("icon" = 'icons/mob/suit.dmi', "icon_state" = "customcolonialcoat_lines")
			tertiary.color = CU.linescolor
			standing.overlays += base
			standing.overlays += secondary
			standing.overlays += tertiary

		else if (istype(wear_suit, /obj/item/clothing/suit/storage/jacket/customcolonial))
			var/obj/item/clothing/suit/storage/jacket/customcolonial/CU = wear_suit
			base = image("icon" = 'icons/mob/suit.dmi', "icon_state" = "customcolonial_jacket")
			base.color = CU.jacketcolor
			secondary = image("icon" = 'icons/mob/suit.dmi', "icon_state" = "customcolonial_cross")
			secondary.color = CU.crosscolor
			tertiary = image("icon" = 'icons/mob/suit.dmi', "icon_state" = "customcolonial_plain")
			standing.overlays += base
			standing.overlays += secondary
			standing.overlays += tertiary
		if (wear_suit.blood_DNA)
			var/obj/item/clothing/suit/S = wear_suit
			var/image/bloodsies = image("icon" = species.blood_mask, "icon_state" = "[S.blood_overlay_type]blood")
			bloodsies.color = wear_suit.blood_color
			standing.overlays	+= bloodsies

		// Accessories - copied from uniform, BOILERPLATE because fuck this system.
		var/obj/item/clothing/suit/suit = wear_suit
		if (istype(suit) && suit.accessories.len)
			for (var/obj/item/clothing/accessory/A in suit.accessories)
				var/image/NI = A.get_mob_overlay()
				if (istype(A, /obj/item/clothing/accessory/custom))
					NI.color = A.color
				standing.overlays |= NI
		if (!istype(wear_suit, /obj/item/clothing/suit/armor/medieval/chainmail))
			overlays_standing[SUIT_LAYER]	= standing

///chainmail stuff, so it goes under the uniform

		if (wear_suit && istype(wear_suit, /obj/item/clothing/suit/armor/medieval/chainmail))
			overlays_standing[SURGERY_LEVEL] = standing

//fur coat hood

		if (wear_suit && istype(wear_suit, /obj/item/clothing/suit/storage/coat/fur))
			var/obj/item/clothing/suit/storage/coat/fur/WS = wear_suit
			if (WS.hood == TRUE)
				update_hair(1)
			else
				update_hair(1)
		else if (wear_suit && istype(wear_suit, /obj/item/clothing/suit/storage/jacket/kool_kids_klub))
			update_hair(1)
	else
		overlays_standing[SUIT_LAYER]	= null
		update_inv_shoes(0)

	if (update_icons)   update_icons()

/mob/living/carbon/human/update_inv_pockets(var/update_icons=1)
	if (l_store)
		/*var/new_screen_loc = find_inv_position(slot_l_store)
		if (new_screen_loc)
			l_store.screen_loc = new_screen_loc	*/
		l_store.screen_loc = find_inv_position(slot_l_store)
	if (r_store)
		/*var/new_screen_loc = find_inv_position(slot_r_store)
		if (new_screen_loc)
			r_store.screen_loc = new_screen_loc	*/
		r_store.screen_loc = find_inv_position(slot_r_store)
	if (update_icons)	update_icons()


/mob/living/carbon/human/update_inv_wear_mask(var/update_icons=1)
	if ( wear_mask && ( istype(wear_mask, /obj/item/clothing/mask) || istype(wear_mask, /obj/item/clothing/accessory) || istype(wear_mask, /obj/item/weapon/grenade)) && !(head && head.flags_inv & HIDEMASK))

		/*var/new_screen_loc = find_inv_position(slot_wear_mask)
		if (new_screen_loc)
			wear_mask.screen_loc = new_screen_loc	*/
		wear_mask.screen_loc = find_inv_position(slot_wear_mask)

		var/image/standing
		if (wear_mask.icon_override)
			standing = image(icon = wear_mask.icon_override, icon_state = wear_mask.icon_state)

		else
			standing = image(icon = body_build.mask_icon, icon_state = wear_mask.icon_state)
		standing.color = wear_mask.color

		if ( !istype(wear_mask, /obj/item/clothing/mask/smokable/cigarette) && wear_mask.blood_DNA )
			var/image/bloodsies = image("icon" = species.blood_mask, "icon_state" = "maskblood")
			bloodsies.color = wear_mask.blood_color
			standing.overlays	+= bloodsies
		overlays_standing[FACEMASK_LAYER]	= standing
	else
		overlays_standing[FACEMASK_LAYER]	= null
	if (update_icons)   update_icons()


/mob/living/carbon/human/update_inv_back(var/update_icons=1)
	if (back)
		/*var/new_screen_loc = find_inv_position(slot_back)
		if (new_screen_loc)
			back.screen_loc = new_screen_loc	*/
		back.screen_loc = find_inv_position(slot_back)
		//determine the icon to use
		var/icon/overlay_icon
		if (back.icon_override)
			overlay_icon = back.icon_override
		else if (back.item_icons && (slot_back_str in back.item_icons))
			overlay_icon = back.item_icons[slot_back_str]
		else
			overlay_icon = body_build.backpack_icon

		//determine state to use
		var/overlay_state = back.icon_state
		if (back.item_state_slots && back.item_state_slots[slot_back_str])
			overlay_state = back.item_state_slots[slot_back_str]
		//apply color
		var/image/standing = image(icon = overlay_icon, icon_state = overlay_state)
		standing.color = back.color

		overlays_standing[BACK_LAYER]	= standing
	else
		overlays_standing[BACK_LAYER] = null

	if (update_icons)
		update_icons()

////////////SHOULDER
/mob/living/carbon/human/update_inv_shoulder(var/update_icons=1)
	if (shoulder)
		shoulder.screen_loc = find_inv_position(slot_shoulder)
		//determine the icon to use
		var/icon/overlay_icon_shoulder
		if (shoulder.icon_override)
			overlay_icon_shoulder = shoulder.icon_override
		else if (shoulder.item_icons && (slot_shoulder_str in shoulder.item_icons))
			overlay_icon_shoulder = shoulder.item_icons[slot_shoulder_str]
		else
			overlay_icon_shoulder = body_build.shoulder_icon

		//determine state to use
		var/overlay_state_shoulder = shoulder.icon_state
		if (shoulder.item_state_slots && shoulder.item_state_slots[slot_shoulder_str])
			overlay_state_shoulder = back.item_state_slots[slot_shoulder_str]


		//apply color
		var/image/standing2 = image(icon = overlay_icon_shoulder, icon_state = overlay_state_shoulder)
		standing2.color = shoulder.color
		//create the image
		overlays_standing[SHOULDER_LAYER] = standing2
	else
		overlays_standing[SHOULDER_LAYER] = null

	if (update_icons)
		update_icons()


/mob/living/carbon/human/update_inv_handcuffed(var/update_icons=1)
	if (handcuffed)
		drop_r_hand()
		drop_l_hand()
		stop_pulling()	//TODO: should be handled elsewhere

		var/image/standing
		if (handcuffed.icon_override)
			standing = image(icon = handcuffed.icon_override, icon_state = "handcuff1")

		else
			standing = image(icon = body_build.misk_icon, icon_state = "handcuff1")
		overlays_standing[HANDCUFF_LAYER] = standing

	else
		overlays_standing[HANDCUFF_LAYER]	= null
	if (update_icons)   update_icons()

/mob/living/carbon/human/update_inv_legcuffed(var/update_icons=1)
	if (legcuffed)

		var/image/standing
		if (legcuffed.icon_override)
			standing = image(icon = legcuffed.icon_override, icon_state = "legcuff1")

		else
			standing = image(icon = body_build.misk_icon, icon_state = "legcuff1")
		overlays_standing[LEGCUFF_LAYER] = standing

		if (m_intent != "walk")
			m_intent = "walk"
			//if (hud_used && hud_used.move_intent)
			//	hud_used.move_intent.icon_state = "walking"

	else
		overlays_standing[LEGCUFF_LAYER]	= null
	if (update_icons)   update_icons()


/mob/living/carbon/human/update_inv_r_hand(var/update_icons=1)
	if (r_hand)
		/*var/new_screen_loc = find_inv_position(slot_r_hand)
		if (new_screen_loc)
			r_hand.screen_loc = new_screen_loc	*/
		r_hand.screen_loc = find_inv_position(slot_r_hand)
		//determine icon state to use
		var/t_state
		if (r_hand.item_state_slots && r_hand.item_state_slots[slot_r_hand_str])
			t_state = r_hand.item_state_slots[slot_r_hand_str]
		else if (r_hand.item_state)
			t_state = r_hand.item_state
		else
			t_state = r_hand.icon_state

		//determine icon to use
		var/icon/t_icon
		if (r_hand.item_icons && (slot_r_hand_str in r_hand.item_icons))
			t_icon = r_hand.item_icons[slot_r_hand_str]
		else if (r_hand.icon_override)
			t_state += "_r"
			t_icon = r_hand.icon_override
		else
			t_icon = INV_R_HAND_DEF_ICON

		//apply color
		var/image/standing = image(icon = t_icon, icon_state = t_state)
		standing.color = r_hand.color

		overlays_standing[R_HAND_LAYER] = standing

		if (handcuffed) drop_r_hand() //this should be moved out of icon code
	else
		overlays_standing[R_HAND_LAYER] = null

	if (update_icons) update_icons()


/mob/living/carbon/human/update_inv_l_hand(var/update_icons=1)
	if (l_hand)
		var/new_screen_loc = find_inv_position(slot_l_hand)
		if (new_screen_loc)
			l_hand.screen_loc = new_screen_loc
		l_hand.screen_loc = find_inv_position(slot_l_hand)


		//determine icon state to use
		var/t_state
		if (l_hand.item_state_slots && l_hand.item_state_slots[slot_l_hand_str])
			t_state = l_hand.item_state_slots[slot_l_hand_str]
		else if (l_hand.item_state)
			t_state = l_hand.item_state
		else
			t_state = l_hand.icon_state

		//determine icon to use
		var/icon/t_icon
		if (l_hand.item_icons && (slot_l_hand_str in l_hand.item_icons))
			t_icon = l_hand.item_icons[slot_l_hand_str]
		else if (l_hand.icon_override)
			t_state += "_l"
			t_icon = l_hand.icon_override
		else
			t_icon = INV_L_HAND_DEF_ICON

		//apply color
		var/image/standing = image(icon = t_icon, icon_state = t_state)
		standing.color = l_hand.color

		overlays_standing[L_HAND_LAYER] = standing

		if (handcuffed) drop_l_hand() //This probably should not be here
	else
		overlays_standing[L_HAND_LAYER] = null

	if (update_icons) update_icons()

/mob/living/carbon/human/update_fire(var/update_icons=1)
	overlays_standing[FIRE_LAYER] = null
	if (on_fire)
		overlays_standing[FIRE_LAYER] = image("icon"='icons/mob/OnFire.dmi', "icon_state"="Standing", "layer"=FIRE_LAYER)

	if (update_icons)   update_icons()

/mob/living/carbon/human/proc/update_surgery(var/update_icons=1)
	overlays_standing[SURGERY_LEVEL] = null
	var/image/total = new
	for (var/obj/item/organ/external/E in organs)
		if (E.open)
			var/image/I = image("icon"='icons/mob/surgery.dmi', "icon_state"="[E.name][round(E.open)]", "layer"=-SURGERY_LEVEL)
			total = I

	if (disease == TRUE)
		if (disease_type == "plague")
			if (disease_progression >= 1 && disease_progression < 90)
				total.overlays += image(icon = 'icons/mob/human_races/masks/sickness.dmi', icon_state="human_pestilence1")
			else if (disease_progression >= 90 && disease_progression < 180)
				total.overlays += image(icon = 'icons/mob/human_races/masks/sickness.dmi', icon_state="human_pestilence2")
			else if (disease_progression >= 180)
				total.overlays += image(icon = 'icons/mob/human_races/masks/sickness.dmi', icon_state="human_pestilence3")
	if (start_to_rot == TRUE)
		if (rotting_stage == 1)
			total.overlays += image(icon = 'icons/mob/human_races/masks/sickness.dmi', icon_state="rotting1")
		else if (rotting_stage == 2)
			total.overlays += image(icon = 'icons/mob/human_races/masks/sickness.dmi', icon_state="rotting2")

	overlays_standing[SURGERY_LEVEL] = total
	if (update_icons)   update_icons()

/mob/living/carbon/human/proc/update_bandaging(var/update_icons=1)
	var/image/DD = image(icon='icons/mob/human_races/masks/bandages_human.dmi', icon_state="")
	for (var/obj/item/organ/external/O in organs)
		if (O.is_stump())
			continue
		if (O.wounds.len == 0)
			continue
		for (var/datum/wound/W in O.wounds)
			if (W.bandaged || W.clamped || W.salved)
				DD.overlays += image(icon='icons/mob/human_races/masks/bandages_human.dmi', icon_state="[O.limb_name]b")
				continue
	overlays_standing[BANDAGES_LAYER] = DD
	if (update_icons)   update_icons()
//Human Overlays Indexes/////////
#undef MUTATIONS_LAYER
#undef DAMAGE_LAYER
#undef SURGERY_LEVEL
#undef UNIFORM_LAYER
#undef ID_LAYER
#undef SHOES_LAYER
#undef GLOVES_LAYER
#undef EARS_LAYER
#undef SUIT_LAYER
#undef TAIL_LAYER
#undef GLASSES_LAYER
#undef FACEMASK_LAYER
#undef BELT_LAYER
#undef SUIT_STORE_LAYER
#undef BACK_LAYER
#undef SHOULDER_LAYER
#undef HAIR_LAYER
#undef HEAD_LAYER
#undef BANDAGES_LAYER
#undef HANDCUFF_LAYER
#undef LEGCUFF_LAYER
#undef L_HAND_LAYER
#undef R_HAND_LAYER
#undef TARGETED_LAYER
#undef FIRE_LAYER
#undef OVEREFFECTS_LAYER
#undef TOTAL_LAYERS
