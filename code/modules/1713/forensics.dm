//Messy port of forensics from other servers, may need to be splitted into multiple .dm files


/obj/item/weapon/forensics
	icon = 'icons/obj/forensics.dmi'
	w_class = ITEM_SIZE_SMALL

var/const/FINGERPRINT_COMPLETE = 6
proc/is_complete_print(var/print)
	return stringpercent(print) <= FINGERPRINT_COMPLETE

/obj/item/weapon/storage/briefcase/crimekit/New()
	..()
	new /obj/item/weapon/storage/box/swabs(src)
	new /obj/item/weapon/storage/box/fingerprints(src)
	new /obj/item/weapon/reagent_containers/spray/luminol(src)
	new /obj/item/weapon/forensics/sample_kit(src)
	new /obj/item/weapon/forensics/sample_kit/powder(src)
	new /obj/item/weapon/storage/box/csi_markers(src)
	new /obj/item/clothing/gloves/color/white
	new /obj/item/device/uv_light(src)

// Crime scene kit

/obj/item/weapon/storage/briefcase/crimekit
	name = "crime scene kit"
	desc = "A stainless steel-plated carrycase for all your forensic needs. Feels heavy."
	icon = 'icons/obj/forensics.dmi'
	icon_state = "case"
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand.dmi',
		)
	item_state_slots = list(
		slot_l_hand_str = "case",
		slot_r_hand_str = "case",
		)
	storage_slots = 14

// Evidence bag
/obj/item/weapon/evidencebag
	name = "evidence bag"
	desc = "An empty evidence bag."
	icon = 'icons/obj/storage.dmi'
	icon_state = "evidenceobj"
	item_state = null
	w_class = ITEM_SIZE_SMALL
	var/obj/item/stored_item = null

/obj/item/weapon/evidencebag/MouseDrop(var/obj/item/I as obj)
	if (!ishuman(usr))
		return
	if(!istype(I) || I.anchored)
		return  ..()

	var/mob/living/human/user = usr

	if(!user.item_is_in_hands(src))
		return //bag must be in your hands to use

	if (isturf(I.loc))
		if (!user.Adjacent(I))
			return
	else
		//If it isn't on the floor. Do some checks to see if it's in our hands or a box. Otherwise give up.
		if(istype(I.loc,/obj/item/weapon/storage))	//in a container.
			var/sdepth = I.storage_depth(user)
			if (sdepth == -1 || sdepth > 1)
				return	//too deeply nested to access

			var/obj/item/weapon/storage/U = I.loc
			user.client.screen -= I
			U.contents.Remove(I)
		else if(user.item_is_in_hands(I))
			user.drop_from_inventory(I)
		else
			return

	if(istype(I, /obj/item/weapon/evidencebag))
		user << "<span class='notice'>You find putting an evidence bag in another evidence bag to be slightly absurd.</span>"
		return

	if(I.w_class > 3)
		user << "<span class='notice'>[I] won't fit in [src].</span>"
		return

	if(contents.len)
		user << "<span class='notice'>[src] already has something inside it.</span>"
		return

	user.visible_message("[user] puts [I] into [src]", "You put [I] inside [src].",\
	"You hear a rustle as someone puts something into a plastic bag.")

	icon_state = "evidence"

	var/xx = I.pixel_x	//save the offset of the item
	var/yy = I.pixel_y
	I.pixel_x = 0		//then remove it so it'll stay within the evidence bag
	I.pixel_y = 0
	var/image/img = image("icon"=I, "layer"=FLOAT_LAYER)	//take a snapshot. (necessary to stop the underlays appearing under our inventory-HUD slots ~Carn
	I.pixel_x = xx		//and then return it
	I.pixel_y = yy
	overlays += img
	overlays += "evidence"	//should look nicer for transparent stuff. not really that important, but hey.

	desc = "An evidence bag containing [I]."
	I.loc = src
	stored_item = I
	w_class = I.w_class
	return

/obj/item/weapon/evidencebag/attack_self(mob/user as mob)
	if(contents.len)
		var/obj/item/I = contents[1]
		user.visible_message("[user] takes [I] out of [src]", "You take [I] out of [src].",\
		"You hear someone rustle around in a plastic bag, and remove something.")
		overlays.Cut()	//remove the overlays

		user.put_in_hands(I)
		stored_item = null

		w_class = initial(w_class)
		icon_state = "evidenceobj"
		desc = "An empty evidence bag."
	else
		user << "[src] is empty."
		icon_state = "evidenceobj"
	return

/obj/item/weapon/evidencebag/examine(mob/user)
	..(user)
	if (stored_item) user.examinate(stored_item)

//Luminol bottle

/obj/item/weapon/reagent_containers/spray/luminol
	name = "luminol bottle"
	desc = "A bottle containing an odourless, colorless liquid used to reveal bloodstains."
	icon = 'icons/obj/forensics.dmi'
	icon_state = "luminol"
	item_state = "cleaner"
	amount_per_transfer_from_this = 10
	possible_transfer_amounts = list(5,10)
	volume = 250

/obj/item/weapon/reagent_containers/spray/luminol/New()
	..()
	reagents.add_reagent("luminol", 250)

//Scene cards

/obj/item/weapon/csi_marker
	name = "crime scene marker"
	desc = "Plastic cards used to mark points of interests on the scene. Just like in the holoshows!"
	icon = 'icons/obj/forensics.dmi'
	icon_state = "card1"
	w_class = ITEM_SIZE_TINY
	layer = MOB_LAYER + 1  //so you can mark bodies
	var/number = 1

/obj/item/weapon/csi_marker/initialize(mapload)
	. = ..()
	desc += " This one is marked with [number]"
	update_icon()

/obj/item/weapon/csi_marker/update_icon()
	icon_state = "card[Clamp(number,1,7)]"

/obj/item/weapon/csi_marker/n1
	number = 1
/obj/item/weapon/csi_marker/n2
	number = 2
/obj/item/weapon/csi_marker/n3
	number = 3
/obj/item/weapon/csi_marker/n4
	number = 4
/obj/item/weapon/csi_marker/n5
	number = 5
/obj/item/weapon/csi_marker/n6
	number = 6
/obj/item/weapon/csi_marker/n7
	number = 7


//Fibers proc

atom/var/list/suit_fibers = list()

atom/proc/add_fibers(mob/living/human/M)
	if(M.gloves && istype(M.gloves,/obj/item/clothing/gloves))
		var/obj/item/clothing/gloves/G = M.gloves
		if(G.transfer_blood) //bloodied gloves transfer blood to touched objects
			if(add_blood(G.bloody_hands_mob)) //only reduces the bloodiness of our gloves if the item wasn't already bloody
				G.transfer_blood--
	else if(M.bloody_hands)
		if(add_blood(M.bloody_hands_mob))
			M.bloody_hands--

	if(!suit_fibers) suit_fibers = list()
	var/fibertext
	var/item_multiplier = istype(src,/obj/item)?1.2:1
	var/suit_coverage = 0
	if(M.wear_suit)
		fibertext = "Material from \a [M.wear_suit]."
		if(prob(10*item_multiplier) && !(fibertext in suit_fibers))
			suit_fibers += fibertext
		suit_coverage = M.wear_suit.body_parts_covered

	if(M.w_uniform && (M.w_uniform.body_parts_covered & ~suit_coverage))
		fibertext = "Fibers from \a [M.w_uniform]."
		if(prob(15*item_multiplier) && !(fibertext in suit_fibers))
			suit_fibers += fibertext

	if(M.gloves && (M.gloves.body_parts_covered & ~suit_coverage))
		fibertext = "Material from a pair of [M.gloves.name]."
		if(prob(20*item_multiplier) && !(fibertext in suit_fibers))
			suit_fibers += "Material from a pair of [M.gloves.name]."

	truncate_oldest(suit_fibers, 20)

//Sample kits

/obj/item/weapon/forensics/sample
	name = "forensic sample"
	w_class = ITEM_SIZE_TINY
	var/list/evidence = list()

/obj/item/weapon/forensics/sample/New(var/newloc, var/atom/supplied)
	..(newloc)
	if(supplied)
		copy_evidence(supplied)
		name = "[initial(name)] (\the [supplied])"

/obj/item/weapon/forensics/sample/print/New(var/newloc, var/atom/supplied)
	..(newloc, supplied)
	if(evidence && evidence.len)
		icon_state = "fingerprint1"

/obj/item/weapon/forensics/sample/proc/copy_evidence(var/atom/supplied)
	if(supplied.suit_fibers && supplied.suit_fibers.len)
		evidence = supplied.suit_fibers.Copy()
		supplied.suit_fibers.Cut()

/obj/item/weapon/forensics/sample/proc/merge_evidence(var/obj/item/weapon/forensics/sample/supplied, var/mob/user)
	if(!supplied.evidence || !supplied.evidence.len)
		return 0
	evidence |= supplied.evidence
	name = "[initial(name)] (combined)"
	user << "<span class='notice'>You transfer the contents of \the [supplied] into \the [src].</span>"
	return 1

/obj/item/weapon/forensics/sample/print/merge_evidence(var/obj/item/weapon/forensics/sample/supplied, var/mob/user)
	if(!supplied.evidence || !supplied.evidence.len)
		return 0
	for(var/print in supplied.evidence)
		if(evidence[print])
			evidence[print] = stringmerge(evidence[print],supplied.evidence[print])
		else
			evidence[print] = supplied.evidence[print]
	name = "[initial(name)] (combined)"
	user << "<span class='notice'>You overlay \the [src] and \the [supplied], combining the print records.</span>"
	return 1

/obj/item/weapon/forensics/sample/attackby(var/obj/O, var/mob/user)
	if(O.type == src.type)
		user.unEquip(O)
		if(merge_evidence(O, user))
			qdel(O)
		return 1
	return ..()

/obj/item/weapon/forensics/sample/fibers
	name = "fiber bag"
	desc = "Used to hold fiber evidence for the detective."
	icon_state = "fiberbag"

/obj/item/weapon/forensics/sample/print
	name = "fingerprint card"
	desc = "Records a set of fingerprints."
	icon_state = "fingerprint0"
	item_state = "paper"

/obj/item/weapon/forensics/sample/print/attack_self(var/mob/user)
	if(evidence && evidence.len)
		return
	if(!ishuman(user))
		return
	var/mob/living/human/H = user
	if(H.gloves)
		user << "<span class='warning'>Take \the [H.gloves] off first.</span>"
		return

	user << "<span class='notice'>You firmly press your fingertips onto the card.</span>"
	var/fullprint = H.get_full_print()
	evidence[fullprint] = fullprint
	name = "[initial(name)] (\the [H])"
	icon_state = "fingerprint1"

/obj/item/weapon/forensics/sample/print/attack(var/mob/living/M, var/mob/user)

	if(!ishuman(M))
		return ..()

	if(evidence && evidence.len)
		return 0

	var/mob/living/human/H = M

	if(H.gloves)
		user << "<span class='warning'>\The [H] is wearing gloves.</span>"
		return 1

	if(user != H && H.a_intent != "help" && !H.lying)
		user.visible_message("<span class='danger'>\The [user] tries to take prints from \the [H], but they move away.</span>")
		return 1

	if(user.zone_sel.selecting == "r_hand" || user.zone_sel.selecting == "l_hand")
		var/has_hand
		var/obj/item/organ/external/O = H.organs_by_name["r_hand"]
		if(istype(O) && !O.is_stump())
			has_hand = 1
		else
			O = H.organs_by_name["l_hand"]
			if(istype(O) && !O.is_stump())
				has_hand = 1
		if(!has_hand)
			user << "<span class='warning'>They don't have any hands.</span>"
			return 1
		user.visible_message("[user] takes a copy of \the [H]'s fingerprints.")
		var/fullprint = H.get_full_print()
		evidence[fullprint] = fullprint
		copy_evidence(src)
		name = "[initial(name)] (\the [H])"
		icon_state = "fingerprint1"
		return 1
	return 0

/obj/item/weapon/forensics/sample/print/copy_evidence(var/atom/supplied)
	if(supplied.fingerprints && supplied.fingerprints.len)
		for(var/print in supplied.fingerprints)
			evidence[print] = supplied.fingerprints[print]
		supplied.fingerprints.Cut()

/obj/item/weapon/forensics/sample_kit
	name = "fiber collection kit"
	desc = "A magnifying glass and tweezers. Used to lift suit fibers."
	icon_state = "m_glass"
	w_class = ITEM_SIZE_SMALL
	var/evidence_type = "fiber"
	var/evidence_path = /obj/item/weapon/forensics/sample/fibers

/obj/item/weapon/forensics/sample_kit/proc/can_take_sample(var/mob/user, var/atom/supplied)
	return (supplied.suit_fibers && supplied.suit_fibers.len)

/obj/item/weapon/forensics/sample_kit/proc/take_sample(var/mob/user, var/atom/supplied)
	var/obj/item/weapon/forensics/sample/S = new evidence_path(get_turf(user), supplied)
	user << "<span class='notice'>You transfer [S.evidence.len] [S.evidence.len > 1 ? "[evidence_type]s" : "[evidence_type]"] to \the [S].</span>"

/obj/item/weapon/forensics/sample_kit/afterattack(var/atom/A, var/mob/user, var/proximity)
	if(!proximity)
		return
	add_fingerprint(user)
	if(can_take_sample(user, A))
		take_sample(user,A)
		return 1
	else
		user << "<span class='warning'>You are unable to locate any [evidence_type]s on \the [A].</span>"
		return ..()

/obj/item/weapon/forensics/sample_kit/powder
	name = "fingerprint powder"
	desc = "A jar containing aluminum powder and a specialized brush."
	icon_state = "dust"
	evidence_type = "fingerprint"
	evidence_path = /obj/item/weapon/forensics/sample/print

/obj/item/weapon/forensics/sample_kit/powder/can_take_sample(var/mob/user, var/atom/supplied)
	return (supplied.fingerprints && supplied.fingerprints.len)

//Swabs

/obj/item/weapon/forensics/swab
	name = "swab kit"
	desc = "A sterilized cotton swab and vial used to take forensic samples."
	icon_state = "swab"
	var/gsr = 0
	var/list/dna
	var/used

/obj/item/weapon/forensics/swab/proc/is_used()
	return used

/obj/item/weapon/forensics/swab/attack(var/mob/living/M, var/mob/user)

	if(!ishuman(M))
		return ..()

	if(is_used())
		return

	var/mob/living/human/H = M
	var/sample_type

	if(H.wear_mask)
		user << "<span class='warning'>\The [H] is wearing a mask.</span>"
		return

	if(!H.dna || !H.dna.unique_enzymes)
		user << "<span class='warning'>They don't seem to have DNA!</span>"
		return

	if(user != H && H.a_intent != I_HELP && !H.lying)
		user.visible_message("<span class='danger'>\The [user] tries to take a swab sample from \the [H], but they move away.</span>")
		return

	if(user.targeted_organ == "mouth")
		if(!H.organs_by_name["head"])
			user << "<span class='warning'>They don't have a head.</span>"
			return
		if(!H.check_has_mouth())
			user << "<span class='warning'>They don't have a mouth.</span>"
			return
		user.visible_message("[user] swabs \the [H]'s mouth for a saliva sample.")
		dna = list(H.dna.unique_enzymes)
		sample_type = "DNA"

	else if(user.targeted_organ == "r_hand" || user.targeted_organ == "l_hand")
		var/has_hand
		var/obj/item/organ/external/O = H.organs_by_name["r_hand"]
		if(istype(O) && !O.is_stump())
			has_hand = 1
		else
			O = H.organs_by_name["l_hand"]
			if(istype(O) && !O.is_stump())
				has_hand = 1
		if(!has_hand)
			user << "<span class='warning'>They don't have any hands.</span>"
			return
		user.visible_message("[user] swabs [H]'s palm for a sample.")
		sample_type = "GSR"
		gsr = H.gunshot_residue
	else
		return

	if(sample_type)
		set_used(sample_type, H)
		return
	return 1

/obj/item/weapon/forensics/swab/afterattack(var/atom/A, var/mob/user, var/proximity)

	if(!proximity)
		return
	if(!proximity || istype(A, /obj/machinery/dnaforensics))
		return

	if(is_used())
		user << "<span class='warning'>This swab has already been used.</span>"
		return

	add_fingerprint(user)

	var/list/choices = list()
	if(A.blood_DNA)
		choices |= "Blood"
	if(istype(A, /obj/item/clothing))
		choices |= "Gunshot Residue"

	var/choice
	if(!choices.len)
		user << "<span class='warning'>There is no evidence on \the [A].</span>"
		return
	else if(choices.len == 1)
		choice = choices[1]
	else
		choice = input("What kind of evidence are you looking for?","Evidence Collection") as null|anything in choices

	if(!choice)
		return

	var/sample_type
	if(choice == "Blood")
		if(!A.blood_DNA || !A.blood_DNA.len) return
		dna = A.blood_DNA.Copy()
		sample_type = "blood"

	else if(choice == "Gunshot Residue")
		var/obj/item/clothing/B = A
		if(!istype(B) || !B.gunshot_residue)
			user << "<span class='warning'>There is no residue on \the [A].</span>"
			return
		gsr = B.gunshot_residue
		sample_type = "residue"

	if(sample_type)
		user.visible_message("\The [user] swabs \the [A] for a sample.", "You swab \the [A] for a sample.")
		set_used(sample_type, A)

/obj/item/weapon/forensics/swab/proc/set_used(var/sample_str, var/atom/source)
	name = "[initial(name)] ([sample_str] - [source])"
	desc = "[initial(desc)] The label on the vial reads 'Sample of [sample_str] from [source].'."
	icon_state = "swab_used"
	used = 1

// UV Light

/obj/item/device/uv_light
	name = "UV light"
	desc = "A small handheld black light."
	icon = 'icons/obj/forensics.dmi'
	icon_state = "uv_off"
	slot_flags = SLOT_BELT
	w_class = ITEM_SIZE_SMALL
	item_state = "electronic"
	action_button_name = "Toggle UV light"

	var/list/scanned = list()
	var/list/stored_alpha = list()
	var/list/reset_objects = list()

	range = 3
	var/on = 0
	var/step_alpha = 50

/obj/item/device/uv_light/attack_self(var/mob/user)
	on = !on
	if(on)
		set_light(range, 2, "#007fff")
		processing_objects |= src
		icon_state = "uv_on"
	else
		set_light(0)
		clear_last_scan()
		processing_objects -= src
		icon_state = "uv_off"

/obj/item/device/uv_light/proc/clear_last_scan()
	if(scanned.len)
		for(var/atom/O in scanned)
			O.invisibility = scanned[O]
			if(O.fluorescent == 2) O.fluorescent = 1
		scanned.Cut()
	if(stored_alpha.len)
		for(var/atom/O in stored_alpha)
			O.alpha = stored_alpha[O]
			if(O.fluorescent == 2) O.fluorescent = 1
		stored_alpha.Cut()
	if(reset_objects.len)
		for(var/obj/item/I in reset_objects)
			I.overlays -= I.blood_overlay
			if(I.fluorescent == 2) I.fluorescent = 1
		reset_objects.Cut()

/obj/item/device/uv_light/process()
	clear_last_scan()
	if(on)
		step_alpha = round(255/range)
		var/turf/origin = get_turf(src)
		if(!origin)
			return
		for(var/turf/T in range(range, origin))
			var/use_alpha = 255 - (step_alpha * get_dist(origin, T))
			for(var/atom/A in T.contents)
				if(A.fluorescent == 1)
					A.fluorescent = 2 //To prevent light crosstalk.
					if(A.invisibility)
						scanned[A] = A.invisibility
						A.invisibility = 0
						stored_alpha[A] = A.alpha
						A.alpha = use_alpha
					if(istype(A, /obj/item))
						var/obj/item/O = A
						if(O.was_bloodied && !(O.blood_overlay in O.overlays))
							O.overlays |= O.blood_overlay
							reset_objects |= O

//Slides

/obj/item/weapon/forensics/slide
	name = "microscope slide"
	desc = "A pair of thin glass panes used in the examination of samples beneath a microscope. Used with fibers and GSR swab tests to examine the samples in the microscope. To empty them, use in hand."
	icon_state = "slide"
	w_class = ITEM_SIZE_TINY
	var/obj/item/weapon/forensics/swab/has_swab
	var/obj/item/weapon/forensics/sample/fibers/has_sample

/obj/item/weapon/forensics/slide/attackby(var/obj/item/W, var/mob/living/human/user)
	if(has_swab || has_sample)
		usr << "<span class='warning'>There is already a sample in the slide.</span>"
		return
	if(istype (W, /obj/item/weapon/forensics/swab))
		has_swab = W
	else if(istype(W, /obj/item/weapon/forensics/sample/fibers))
		has_sample = W
	else
		usr << "<span class='warning'>You don't think this will fit.</span>"
		return
	usr << "<span class='notice'>You insert the sample in the slide.</span>"
	user.unEquip(W)
	W.forceMove(src)
	update_icon()

/obj/item/weapon/forensics/slide/attack_self(var/mob/user)
	if(has_swab || has_sample)
		usr << "<span class='notice'>You remove the sample from the [src]."
		if(has_swab)
			user.put_in_hands(has_swab)
			has_swab = null
		if(has_sample)
			user.put_in_hands(has_sample)
			has_sample = null
		update_icon()
		return

/obj/item/weapon/forensics/slide/update_icon()
	if(!has_swab && !has_sample)
		icon_state = "slide"
	else if(has_swab)
		icon_state = "slideswab"
	else if(has_sample)
		icon_state = "slidefiber"

//MACHINERY

/obj/machinery/microscope
	name = "high powered electron microscope"
	desc = "A highly advanced microscope capable of zooming up to 3000x.<br> Use a microscope slide or a fingerprint card on this machine to analyze it. <br> Alt click to remove any object within it."
	icon = 'icons/obj/forensics.dmi'
	icon_state = "microscope_adv"
	anchored = 1
	density = 1

	var/obj/item/weapon/forensics/sample = null
	var/report_num = 0

/obj/machinery/microscope/attackby(obj/item/weapon/W as obj, mob/user as mob)

	if(sample)
		user << "<span class='warning'>There is already a slide in the microscope.</span>"
		return

	if(istype(W, /obj/item/weapon/forensics/slide) || istype(W, /obj/item/weapon/forensics/sample/print))
		user << "<span class='notice'>You insert \the [W] into the microscope.</span>"
		user.unEquip(W)
		W.forceMove(src)
		sample = W
		update_icon()
		return

/obj/machinery/microscope/attack_hand(mob/user)

	if(!sample)
		user << "<span class='warning'>The microscope has no sample to examine.</span>"
		return

	user << "<span class='notice'>The microscope whirrs as you examine \the [sample].</span>"

	if(!do_after(user, 25) || !sample)
		user << "<span class='notice'>You stop examining \the [sample].</span>"
		return

	user << "<span class='notice'>Printing findings now...</span>"
	var/obj/item/weapon/paper/report = new(get_turf(src))
	report.stamped = list(/obj/item/weapon/stamp)
	report.overlays = list("paper_stamped")
	report_num++

	if(istype(sample, /obj/item/weapon/forensics/slide))
		var/obj/item/weapon/forensics/slide/slide = sample
		if(slide.has_swab)
			var/obj/item/weapon/forensics/swab/swab = slide.has_swab

			report.name = "GSR report #[++report_num]: [swab.name]"
			report.info = "<b>Scanned item:</b><br>[swab.name]<br><br>"

			if(swab.gsr)
				report.info += "Residue from a [swab.gsr] detected."
			else
				report.info += "No gunpowder residue found."

		else if(slide.has_sample)
			var/obj/item/weapon/forensics/sample/fibers/fibers = slide.has_sample
			report.name = "Fiber report #[++report_num]: [fibers.name]"
			report.info = "<b>Scanned item:</b><br>[fibers.name]<br><br>"
			if(fibers.evidence)
				report.info += "Miscroscopic analysis on provided sample has determined the presence of unique fiber strings.<br><br>"
				for(var/fiber in fibers.evidence)
					report.info += "<span class='notice'>Most likely match for fibers: [fiber]</span><br><br>"
			else
				report.info += "No fibers found."
		else
			report.name = "Empty slide report #[report_num]"
			report.info = "Analysis suggests that there's nothing in this slide."

	else if(istype(sample, /obj/item/weapon/forensics/sample/print))
		report.name = "Fingerprint report #[report_num]: [sample.name]"
		report.info = "<b>Fingerprint analysis report #[report_num]</b>: [sample.name]<br>"
		var/obj/item/weapon/forensics/sample/print/card = sample
		if(card.evidence && card.evidence.len)
			report.info += "Surface analysis has determined unique fingerprint strings:<br><br>"
			for(var/prints in card.evidence)
				report.info += "<span class='notice'>Fingerprint string: </span>"
				if(!is_complete_print(prints))
					report.info += "INCOMPLETE PRINT"
				else
					report.info += "[prints]"
				report.info += "<br>"
		else
			report.info += "No information available."

	if(report)
		report.update_icon()
		if(report.info)
			user << report.info
	return

/obj/machinery/microscope/proc/remove_sample(var/mob/living/remover)
	if(!istype(remover) || remover.incapacitated() || !Adjacent(remover))
		return
	if(!sample)
		remover << "<span class='warning'>\The [src] does not have a sample in it.</span>"
		return
	remover << "<span class='notice'>You remove \the [sample] from \the [src].</span>"
	sample.forceMove(get_turf(src))
	remover.put_in_hands(sample)
	sample = null
	update_icon()

/obj/machinery/microscope/AltClick()
	remove_sample(usr)

/obj/machinery/microscope/MouseDrop(var/atom/other)
	if(usr == other)
		remove_sample(usr)
	else
		return ..()

/obj/machinery/microscope/update_icon()
	icon_state = "microscope_adv"
	if(sample)
		icon_state += "slide"

//DNA scanner

/obj/machinery/dnaforensics
	name = "DNA analyzer"
	desc = "A high tech machine that is designed to read DNA samples properly."
	icon = 'icons/obj/forensics.dmi'
	icon_state = "dnaopen"
	anchored = 1
	density = 1
	powered = TRUE
	powerneeded = FALSE

	var/obj/item/weapon/forensics/swab/bloodsamp = null
	var/closed = 0
	var/scanning = 0
	var/scanner_rate = 2.50
	var/report_num = 0

/obj/machinery/dnaforensics/attackby(var/obj/item/W, mob/user as mob)

	if(bloodsamp)
		user << "<span class='warning'>There is already a sample in the machine.</span>"
		return

	if(closed)
		user << "<span class='warning'>Open the cover before inserting the sample.</span>"
		return

	var/obj/item/weapon/forensics/swab/swab = W
	if(istype(swab) && swab.is_used())
		user.unEquip(W)
		src.bloodsamp = swab
		swab.loc = src
		user << "<span class='notice'>You insert \the [W] into \the [src].</span>"
	else
		user << "<span class='warning'>\The [src] only accepts used swabs.</span>"
		return

/obj/machinery/dnaforensics/proc/complete_scan()
	src.visible_message("<span class='notice'>\icon[src] makes an insistent chime.</span>", 2)
	playsound(loc, 'sound/machines/computer/beep.ogg', 80, TRUE)
	update_icon()
	if(bloodsamp)
		var/obj/item/weapon/paper/P = new(src)
		P.name = "[src] report #[++report_num]: [bloodsamp.name]"
		P.stamped = list(/obj/item/weapon/stamp)
		P.overlays = list("paper_stamped")
		//dna data itself
		var/data = "No scan information available."
		if(bloodsamp.dna != null)
			data = "Spectrometric analysis on provided sample has determined the presence of [bloodsamp.dna.len] strings of DNA.<br><br>"
			for(var/blood in bloodsamp.dna)
				data += "<font color='blue'>Blood type: [bloodsamp.dna[blood]]<br>\nDNA: [blood]<br><br></font>"
		else
			data += "No DNA found.<br>"
		P.info = "<b>[src] analysis report #[report_num]</b><br>"
		P.info += "<b>Scanned item:</b><br>[bloodsamp.name]<br>[bloodsamp.desc]<br><br>" + data
		P.forceMove(src.loc)
		P.update_icon()
		scanning = 0
		update_icon()
	return

/obj/machinery/dnaforensics/attack_hand(mob/user as mob)
	if(scanning)
		scanning = 0
		usr << "<span class='notice'>You abort the scan.</span>"
		update_icon()
	else
		if(bloodsamp && bloodsamp.loc == src)
			if(closed == 1)
				scanning = 1
				usr << "<span class='notice'>Scan initiated. Please wait.</span>"
				update_icon()
				spawn(900)
					usr << "<span class='notice'>Scan finished. </span>"
					complete_scan()
			else
				usr << "<span class='notice'>Please close sample lid before initiating scan.</span>"
		else
			usr << "<span class='warning'>Insert an item to scan.</span>"
			scanning = 0

/obj/machinery/dnaforensics/verb/toggle_lid()
	set category = "IC"
	set name = "Toggle Lid"
	set src in oview(1)

	if(usr.stat || !isliving(usr))
		return

	if(scanning)
		usr << "<span class='warning'>You can't do that while [src] is scanning!</span>"
		return

	closed = !closed
	src.update_icon()

/obj/machinery/dnaforensics/verb/eject_item()
	set category = "IC"
	set name = "Eject item"
	set src in oview(1)

	if(usr.stat || !isliving(usr))
		return
	if(scanning)
		usr << "<span class='warning'>You can't do that while [src] is scanning!</span>"
		return
	else
		if (closed)
			usr << "<span class='warning'>You can't do that while the lid is closed!</span>"
			return
		else
			if(bloodsamp)
				bloodsamp.forceMove(src.loc)
				bloodsamp = null
			else
				usr << "<span class='warning'>There's no sample in the scanner!</span>"
				return

/obj/machinery/dnaforensics/update_icon()
	..()
	if(scanning)
		icon_state = "dnaworking"
	else if(closed)
		icon_state = "dnaclosed"
	else
		icon_state = "dnaopen"

//STORAGE

/obj/item/weapon/storage/box/evidence
	name = "evidence bag box"
	desc = "A box containing evidence bags."
	storage_slots = 7
	can_hold = list(/obj/item/weapon/evidencebag)

/obj/item/weapon/storage/box/evidence/New()
	..()
	for(var/i = 1 to storage_slots)
		new /obj/item/weapon/evidencebag(src)

/obj/item/weapon/storage/box/csi_markers
	name = "crime scene markers box"
	desc = "A cardboard box for crime scene marker cards."
	icon = 'icons/obj/forensics.dmi'
	icon_state = "cards"
	w_class = ITEM_SIZE_TINY

/obj/item/weapon/storage/box/csi_markers/New()
	..()
	new /obj/item/weapon/csi_marker/n1(src)
	new /obj/item/weapon/csi_marker/n2(src)
	new /obj/item/weapon/csi_marker/n3(src)
	new /obj/item/weapon/csi_marker/n4(src)
	new /obj/item/weapon/csi_marker/n5(src)
	new /obj/item/weapon/csi_marker/n6(src)
	new /obj/item/weapon/csi_marker/n7(src)
	return

/obj/item/weapon/storage/box/fingerprints
	name = "box of fingerprint cards"
	desc = "Sterilized equipment within. Do not contaminate."
	icon = 'icons/obj/forensics.dmi'
	icon_state = "dnakit"
	can_hold = list(/obj/item/weapon/forensics/sample/print)
	storage_slots = 14

/obj/item/weapon/storage/box/fingerprints/New()
	..()
	for(var/i = 1 to storage_slots)
		new /obj/item/weapon/forensics/sample/print(src)

/obj/item/weapon/storage/box/swabs
	name = "box of swab kits"
	desc = "Sterilized equipment within. Do not contaminate."
	icon = 'icons/obj/forensics.dmi'
	icon_state = "dnakit"
	can_hold = list(/obj/item/weapon/forensics/swab)
	storage_slots = 14

/obj/item/weapon/storage/box/swabs/New()
	..()
	for(var/i = 1 to storage_slots)
		new /obj/item/weapon/forensics/swab(src)

/obj/item/weapon/storage/box/slides
	name = "microscope slide box"
	icon_state = "solution_trays"
	can_hold = list(/obj/item/weapon/forensics/slide)
	storage_slots = 8

/obj/item/weapon/storage/box/slides/New()
	..()
	for(var/i = 1 to storage_slots)
		new /obj/item/weapon/forensics/slide(src)

