/obj/item/clothing/under/custom
	var/uncolored = FALSE
	color = "#FFFFFF"
	New()
		..()
		spawn(5)
			uncolored = TRUE


/obj/item/clothing/under/custom/attack_self(mob/user as mob)
	if (uncolored)
		var/input = WWinput(user, "Choose the color:", "Color" , "#FFFFFF", "color")
		if (input == null || input == "")
			return
		else
			color = input
			uncolored = FALSE
			return
	else
		..()

/obj/item/clothing/head/custom
	var/uncolored1 = FALSE
	color = "#FFFFFF"
	New()
		..()
		spawn(5)
			uncolored1 = TRUE


/obj/item/clothing/head/custom/attack_self(mob/user as mob)
	if (uncolored1)
		var/input = WWinput(user, "Choose the color:", "Color" , "#FFFFFF", "color")
		if (input == null || input == "")
			return
		else

			color = input
//			user << "Color: [color]"
			uncolored1 = FALSE
			return
	else
		..()

/obj/item/clothing/suit/storage/jacket/custom
	var/uncolored = FALSE

/obj/item/clothing/suit/storage/jacket/custom/attack_self(mob/user as mob)
	if (uncolored)
		var/input = WWinput(user, "Choose the color:", "Color" , "#FFFFFF", "color")
		if (input == null || input == "")
			return
		else

			color = input
			uncolored = FALSE
			return
	else
		..()
///////////////ANCIENT//////////////////////////////////////
/obj/item/clothing/under/custom/toga
	name = "toga"
	desc = "A simple cloth toga."
	icon_state = "customtoga"
	item_state = "customtoga"
	worn_state = "customtoga"

/obj/item/clothing/under/custom/stola
	name = "stola"
	desc = "A simple cloth stola, roman clothing for women."
	icon_state = "fem_roman"
	item_state = "fem_roman"
	worn_state = "fem_roman"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO

/obj/item/clothing/under/custom/roman
	name = "long tunic"
	desc = "A simple cloth tunic, with a brass and leather belt."
	icon_state = "customroman"
	item_state = "customroman"
	worn_state = "customroman"

/obj/item/clothing/under/custom/spartan
	name = "short loincloth"
	desc = "A simple, small loincloth."
	icon_state = "customspartan"
	item_state = "customspartan"
	worn_state = "customspartan"

/obj/item/clothing/under/custom/shendyt
	name = "shendyt"
	desc = "A kilt-like cloth used around the waist."
	icon_state = "customshendyt"
	item_state = "customshendyt"
	worn_state = "customshendyt"
	heat_protection = LOWER_TORSO

/obj/item/clothing/under/custom/celtic
	name = "celtic trousers"
	desc = "Thick cloth celtic trousers."
	icon_state = "customceltic"
	item_state = "customceltic"
	worn_state = "customceltic"
	heat_protection = LOWER_TORSO|LEGS

/obj/item/clothing/under/custom/toga/purple
	name = "purple toga"
	desc = "A fancy cloth toga."
	icon_state = "customtoga"
	item_state = "customtoga"
	worn_state = "customtoga"
	uncolored = FALSE
	color = "#66023C"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO

///////////////MEDIEVAL//////////////////////////////////////
/obj/item/clothing/under/custom/tunic
	name = "tunic"
	desc = "A simple cloth tunic, with a leather belt."
	icon_state = "customtunic"
	item_state = "customtunic"
	worn_state = "customtunic"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO|ARMS

/obj/item/clothing/under/custom/haori
	name = "haori"
	desc = "A light, loose fitting bit of clothes, worn in japan."
	icon_state = "haori_custom"
	item_state = "haori_custom"
	worn_state = "haori_custom"
	uncolored = TRUE
/obj/item/clothing/suit/storage/jacket/custom/haori_jacket
	name = "haori jacket"
	desc = "A simple jacket worn over a haori outfit."
	icon_state = "haori_jacket_custom"
	item_state = "haori_jacket_custom"
	worn_state = "haori_jacket_custom"
	uncolored = TRUE
/obj/item/clothing/under/custom/arabictunic
	name = "arabic tunic"
	desc = "A light cloth tunic, in arabic style."
	icon_state = "customarabictunic"
	item_state = "customarabictunic"
	worn_state = "customarabictunic"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO|ARMS

/obj/item/clothing/suit/storage/jacket/custom/poncho
	name = "poncho"
	desc = "A simple cloth poncho."
	icon_state = "customponcho"
	item_state = "customponcho"
	worn_state = "customponcho"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO|ARMS
	uncolored = TRUE

/obj/item/clothing/under/customren
	name = "renaissance outfit"
	desc = "A renaissance-style outfit."
	var/uncolored = FALSE
	var/topcolor = 0
	var/undercolor = 0
	item_state = "customren"
	icon_state = "customren"
	worn_state = "customren"
	color = "#FFFFFF"
	New()
		..()
		spawn(5)
			uncolored = TRUE


/obj/item/clothing/under/customren/attack_self(mob/user as mob)
	if (uncolored)
		if (!topcolor)
			var/input = WWinput(user, "Top - Choose a color:", "Top Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				topcolor = input

		if (!undercolor)
			var/input = WWinput(user, "Lining - Choose a color:", "Lining Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				undercolor = input

		if (topcolor && undercolor)
			uncolored = FALSE
			var/image/top = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "customren_top")
			top.color = topcolor
			var/image/under = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "customren_lining")
			under.color = undercolor
			overlays += top
			overlays += under
			return
	else
		..()

/obj/item/clothing/under/custompontifical
	name = "renaissance outfit"
	desc = "A renaissance-style pontifical outfit."
	var/uncolored = FALSE
	var/topcolor = 0
	var/undercolor = 0
	var/linescolor = 0
	var/handcolor = 0
	item_state = "custom_pontifical"
	icon_state = "custom_pontifical"
	worn_state = "custom_pontifical"
	color = "#FFFFFF"
	New()
		..()
		spawn(5)
			uncolored = TRUE


/obj/item/clothing/under/custompontifical/attack_self(mob/user as mob)
	if (uncolored)
		if (!topcolor)
			var/input = WWinput(user, "Top Decore - Choose a color:", "Top Decore Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				topcolor = input

		if (!undercolor)
			var/input = WWinput(user, "Leggings - Choose a color:", "Leggings Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				undercolor = input
		if (!linescolor)
			var/input = WWinput(user, "Top Lines - Choose a color:", "Top Lines Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				linescolor = input
		if (!handcolor)
			var/input = WWinput(user, "Hand Decore - Choose a color:", "Hand Decore Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				handcolor = input

		if (topcolor && undercolor && linescolor && handcolor)
			uncolored = FALSE
			var/image/top = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "custompont_decore")
			top.color = topcolor
			var/image/under = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "custompont_leggings")
			under.color = undercolor
			var/image/lines = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "custompont_mclines")
			lines.color = linescolor
			var/image/hand = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "custompont_handdecore")
			hand.color = handcolor
			overlays += top
			overlays += under
			overlays += lines
			overlays += hand
			return
	else
		..()
///////////////IMPERIAL//////////////////////////////////////
/obj/item/clothing/under/customdress
	name = "dress"
	desc = "A female dress."
	var/uncolored = FALSE
	var/topcolor = 0
	var/undercolor = 0
	var/overcolor = 0
	item_state = "customdress"
	icon_state = "customdress"
	worn_state = "customdress"
	color = "#FFFFFF"
	New()
		..()
		spawn(5)
			uncolored = TRUE


/obj/item/clothing/under/customdress/attack_self(mob/user as mob)
	if (uncolored)
		if (!topcolor)
			var/input = WWinput(user, "Top - Choose a color:", "Top Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				topcolor = input

		if (!undercolor)
			var/input = WWinput(user, "Under Bottom - Choose a color:", "Under Bottom Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				undercolor = input
		if (!overcolor)
			var/input = WWinput(user, "Over Bottom - Choose a color:", "Over Bottom Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				overcolor = input
		if (topcolor && undercolor && overcolor)
			uncolored = FALSE
			var/image/top = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "customdress_top")
			top.color = topcolor
			var/image/under = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "customdress_under")
			under.color = undercolor
			var/image/over = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "customdress_over")
			over.color = overcolor
			overlays += top
			overlays += under
			overlays += over
			return
	else
		..()

//////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////
/obj/item/clothing/under/customdress2
	name = "dress"
	desc = "A female dress."
	var/uncolored = FALSE
	var/topcolor = 0
	var/undercolor = 0
	item_state = "custombuttonup_full"
	icon_state = "custombuttonup_full"
	worn_state = "custombuttonup_full"
	color = "#FFFFFF"
	New()
		..()
		spawn(5)
			uncolored = TRUE


/obj/item/clothing/under/customdress2/attack_self(mob/user as mob)
	if (uncolored)
		if (!topcolor)
			var/input = WWinput(user, "Top - Choose a color:", "Sleeves/Skirt Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				topcolor = input

		if (!undercolor)
			var/input = WWinput(user, "Under Bottom - Choose a color:", "Vest/Skirt Line Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				undercolor = input
		if (topcolor && undercolor)
			uncolored = FALSE
			var/image/top = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "custombuttonup_lines")
			top.color = topcolor
			var/image/under = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "custombuttonup_bottom")
			under.color = undercolor
			overlays += top
			overlays += under
			return
	else
		..()

/////////////////COLONIAL COAT////////////////////////////////////
/obj/item/clothing/suit/storage/jacket/customcolonialcoat
	name = "colonial coat"
	desc = "A colonial coat of the XVIIIth century."
	var/uncolored = FALSE
	var/topcolor = 0
	var/deccolor = 0
	var/linescolor = 0
	item_state = "customcolonialcoat_full"
	icon_state = "customcolonialcoat_full"
	worn_state = "customcolonialcoat_full"
	color = "#FFFFFF"
	New()
		..()
		spawn(5)
			uncolored = TRUE


/obj/item/clothing/suit/storage/jacket/customcolonialcoat/attack_self(mob/user as mob)
	if (uncolored)
		if (!topcolor)
			var/input = WWinput(user, "Main - Choose a color:", "Main Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				topcolor = input
	//			user << "Color: [color]"
		if (!deccolor)
			var/input = WWinput(user, "Decorations - Choose a color:", "Decorations Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				deccolor = input
		if (!linescolor)
			var/input = WWinput(user, "Lines - Choose a color:", "Lines Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				linescolor = input
		if (topcolor && deccolor && linescolor)
			uncolored = FALSE
			var/image/top = image("icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "customcolonialcoat_top")
			top.color = topcolor
			var/image/dec = image("icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "customcolonialcoat_dec")
			dec.color = deccolor
			var/image/lines = image("icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "customcolonialcoat_lines")
			lines.color = linescolor
			overlays += top
			overlays += dec
			overlays += lines
			return
	else
		..()


/obj/item/clothing/suit/storage/jacket/customcolonial
	name = "colonial jacket"
	desc = "A colonial jacket of the XVIIIth century."
	var/uncolored = FALSE
	var/jacketcolor = 0
	var/crosscolor = 0
	item_state = "customcolonial_full"
	icon_state = "customcolonial_full"
	worn_state = "customcolonial_full"
	color = "#FFFFFF"
	New()
		..()
		spawn(5)
			uncolored = TRUE


/obj/item/clothing/suit/storage/jacket/customcolonial/attack_self(mob/user as mob)
	if (uncolored)
		if (!jacketcolor)
			var/input = WWinput(user, "Jacket - Choose a color:", "Jacket Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				jacketcolor = input
	//			user << "Color: [color]"
		if (!crosscolor)
			var/input = WWinput(user, "Bandolier - Choose a cross bandolier color:", "Bandolier Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				crosscolor = input
		if (jacketcolor && crosscolor)
			uncolored = FALSE
			var/image/jacket = image("icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "customcolonial_jacket")
			jacket.color = jacketcolor
			var/image/cross = image("icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "customcolonial_cross")
			cross.color = crosscolor
			var/image/plain = image("icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "customcolonial_plain")
			overlays += jacket
			overlays += cross
			overlays += plain
			return
	else
		..()

/////////////////CUSTOM TRIBAL////////////////////////////////////
/obj/item/clothing/under/customtribalrobe
	name = "tribal robe"
	desc = "A tribal robe."
	var/uncolored = FALSE
	var/shirtcolor = 0
	var/pantscolor = 0
	item_state = "tribalrobe"
	icon_state = "tribalrobe"
	worn_state = "tribalrobe"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO|ARMS
	color = "#FFFFFF"
	New()
		..()
		spawn(5)
			uncolored = TRUE


/obj/item/clothing/under/customtribalrobe/attack_self(mob/user as mob)
	if (uncolored)
		if (!shirtcolor)
			var/input = WWinput(user, "Robe - Choose a color:", "Robe Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				shirtcolor = input
	//			user << "Color: [color]"
		if (!pantscolor)
			var/input = WWinput(user, "Decoration - Choose a color:", "Decoration Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				pantscolor = input

		if (shirtcolor && pantscolor)
			uncolored = FALSE
			var/image/pants = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "tribalrobe_decoration")
			pants.color = pantscolor
			var/image/shirt = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "tribalrobe_robe")
			shirt.color = shirtcolor
			var/image/belt = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "tribalrobe_robebelt")
			overlays += pants
			overlays += shirt
			overlays += belt
			return
	else
		..()

/////////////////UNIFORMS////////////////////////////////////
/obj/item/clothing/under/customvicuniform
	name = "uniform"
	desc = "A victorian Era uniform."
	var/uncolored = FALSE
	var/shirtcolor = 0
	var/buttonscolor = 0
	var/beltcolor = 0
	var/bucklecolor = 0
	var/pantscolor = 0
	item_state = "customuni"
	icon_state = "customuni"
	worn_state = "customuni"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO|ARMS
	color = "#FFFFFF"
	New()
		..()
		spawn(5)
			uncolored = TRUE


/obj/item/clothing/under/customvicuniform/attack_self(mob/user as mob)
	if (uncolored)
		if (!shirtcolor)
			var/input = WWinput(user, "Shirt - Choose a color:", "Shirt Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				shirtcolor = input
	//			user << "Color: [color]"
		if (!buttonscolor)
			var/input = WWinput(user, "Buttons - Choose a color:", "Buttons Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				buttonscolor = input
		if (!beltcolor)
			var/input = WWinput(user, "Belt - Choose a color:", "Belt Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				beltcolor = input
		if (!bucklecolor)
			var/input = WWinput(user, "Buckle - Choose a color:", "Buckle Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				bucklecolor = input
		if (!pantscolor)
			var/input = WWinput(user, "Pants - Choose a color:", "Pants Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				pantscolor = input
		if (shirtcolor && buttonscolor && beltcolor && bucklecolor && pantscolor)
			uncolored = FALSE
			var/image/shirt = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "customuni_shirt")
			shirt.color = shirtcolor
			var/image/buttons = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "customuni_buttons")
			buttons.color = buttonscolor
			var/image/belt = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "customuni_belt")
			belt.color = beltcolor
			var/image/buckle = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "customuni_buckle")
			buckle.color = bucklecolor
			var/image/pants = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "customuni_pants")
			pants.color = pantscolor
			overlays += shirt
			overlays += buttons
			overlays += belt
			overlays += buckle
			overlays += pants
			return
	else
		..()


///////////////WW2-MODERN//////////////////////////////////////

/obj/item/clothing/head/custom_off_cap
	name = "officer cap"
	desc = "An officer cap."
	var/uncolored1 = FALSE
	var/capcolor = 0
	var/bandcolor = 0
	var/symbolcolor = 0
	item_state = "customcap"
	icon_state = "customcap"
	worn_state = "customcap"
	color = "#FFFFFF"
	New()
		..()
		spawn(5)
			uncolored1 = TRUE


/obj/item/clothing/head/custom_off_cap/attack_self(mob/user as mob)
	if (uncolored1)
		if (!capcolor)
			var/input = WWinput(user, "Cap - Choose a color:", "Cap Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				capcolor = input
	//			user << "Color: [color]"
		if (!bandcolor)
			var/input = WWinput(user, "Band - Choose a color:", "Band Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				bandcolor = input
		if (!symbolcolor)
			var/input = WWinput(user, "Symbol - Choose a color:", "Symbol Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				symbolcolor = input
		if (bandcolor && capcolor && symbolcolor)
			uncolored1 = FALSE
			var/image/band = image("icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "customcap_l2")
			band.color = bandcolor
			var/image/cap = image("icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "customcap_l1")
			cap.color = capcolor
			var/image/symbol = image("icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "customcap_l3")
			symbol.color = symbolcolor
			overlays += band
			overlays += cap
			overlays += symbol
			return
	else
		..()

/obj/item/clothing/head/custom/fieldcap
	name = "field cap"
	desc = "A cap often worn by military personnel."
	icon_state = "fieldcap_custom"
	item_state = "fieldcap_custom"
	worn_state = "fieldcap_custom"
	var/capcolor = 0

/obj/item/clothing/head/custom/fieldcap/attack_self(mob/user as mob)
	if (uncolored1)
		if (!capcolor)
			var/input = WWinput(user, "Cap - Choose a color:", "Cap Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				capcolor = input
	//			user << "Color: [color]"
		if (capcolor)
			uncolored1 = FALSE
			var/image/cap = image("icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "fieldcap_custom")
			cap.color = capcolor
			overlays += cap
			return
	else
		..()

/////////////////UNIFORMS////////////////////////////////////
/obj/item/clothing/under/customuniform_modern
	name = "camo uniform"
	desc = "A modern era camouflaged uniform."
	var/uncolored = FALSE
	var/browncolor = 0
	var/greencolor = 0
	var/blackcolor = 0
	item_state = "modern_camo_custom"
	icon_state = "modern_camo_custom"
	worn_state = "modern_camo_custom"
	color = "#FFFFFF"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO|ARMS
	New()
		..()
		spawn(5)
			uncolored = TRUE


/obj/item/clothing/under/customuniform_modern/attack_self(mob/user as mob)
	if (uncolored)
		if (!browncolor)
			var/input = WWinput(user, "First Camo Color - Choose a color (default is brown):", "First Camo Color" , "#58493d", "color")
			if (input == null || input == "")
				return
			else
				browncolor = input
		if (!greencolor)
			var/input = WWinput(user, "Second Camo Color - Choose a color (default is green):", "Second Camo Color" , "#5b6142", "color")
			if (input == null || input == "")
				return
			else
				greencolor = input
		if (!blackcolor)
			var/input = WWinput(user, "Third Camo Color - Choose a color (default is dark grey):", "First Camo Color" , "#2f323b", "color")
			if (input == null || input == "")
				return
			else
				blackcolor = input
		if (greencolor && browncolor && blackcolor)
			uncolored = FALSE
			var/image/brown = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "modern_camo_custom_l1")
			brown.color = browncolor
			var/image/green = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "modern_camo_custom_l2")
			green.color = greencolor
			var/image/black = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "modern_camo_custom_l3")
			black.color = blackcolor
			var/image/belt = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "modern_camo_custom_objs")
			overlays += brown
			overlays += green
			overlays += black
			overlays += belt
			return
	else
		..()

//////////////////CIVILIAN STUFF////////////////////////////
/obj/item/clothing/under/custompyjamas
	name = "pyjamas"
	desc = "Basic striped pyjamas."
	icon_state = "custompyjamas"
	item_state = "custompyjamas"
	worn_state = "custompyjamas"
	var/stripescolor = 0
	var/uncolored = TRUE

/obj/item/clothing/under/custompyjamas/attack_self(mob/user as mob)
	if (uncolored)
		if (!stripescolor)
			var/input = WWinput(user, "Stripes - Choose a color:", "Stripes Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				stripescolor = input

		if (stripescolor)
			uncolored = FALSE
			var/image/base = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "custompyjamas_base")
			var/image/stripes = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "custompyjamas_stripes")
			stripes.color = stripescolor
			overlays += base
			overlays += stripes
			return
	else
		..()


/////////////////////HATS////////////////////
/obj/item/clothing/head/custom/customberet
	name = "beret"
	desc = "A simple cloth beret."
	icon_state = "customberet_hat"
	item_state = "customberet_hat"
	worn_state = "customberet_hat"

/obj/item/clothing/head/custom/custombandana
	name = "bandana"
	desc = "A simple cloth bandana."
	icon_state = "custombandana_hat"
	item_state = "custombandana_hat"
	worn_state = "custombandana_hat"

/obj/item/clothing/head/custom/customnoblehat
	name = "noble hat"
	desc = "A fancy noble hat."
	icon_state = "customnoblehat_hat"
	item_state = "customnoblehat_hat"
	worn_state = "customnoblehat_hat"

/obj/item/clothing/head/custom/customhood
	name = "wool_hood"
	desc = "A wool hood."
	icon_state = "wool_hood"
	item_state = "wool_hood"
	worn_state = "wool_hood"
	cold_protection = HEAD

/obj/item/clothing/head/custom/custom_beanie
	name = "beanie"
	desc = "A warm winter beanie."
	icon_state = "custom_beanie"
	item_state = "custom_beanie"
	worn_state = "custom_beanie"
	cold_protection = HEAD

/obj/item/clothing/head/custom/drill_hat
    name = "Drill hat"
    desc = "The hat of a drill sergeant sir yes sir!!"
    icon_state = "drill_hat"
    item_state = "drill_hat"
    worn_state = "drill_hat"
    heat_protection = HEAD

/obj/item/clothing/head/custom/taqiyah
	name = "taqiyah"
	desc = "A short, rounded skullcap usually worn for religious purposes."
	icon_state = "taqiyah"
	item_state = "taqiyah"
	worn_state = "taqiyah"

/obj/item/clothing/head/custom/hijab
	name = "hijab"
	desc = "A veil which is wrapped to cover the head and chest."
	icon_state = "hijab"
	item_state = "hijab"
	worn_state = "hijab"
	flags_inv = BLOCKHAIR
	body_parts_covered = HEAD

/obj/item/clothing/head/custom/kippa
	name = "kippa"
	desc = "A small, brimless cap."
	icon_state = "kippa"
	item_state = "kippa"
	worn_state = "kippa"

/obj/item/clothing/head/custom_keffiyeh
	name = "keffiyeh"
	desc = "A headdress fashioned from a scarf with a checkered pattern."
	icon_state = "keffiyeh_custom"
	item_state = "keffiyeh_custom"
	worn_state = "keffiyeh_custom"
	heat_protection = HEAD
	var/uncolored1 = TRUE
	var/patterncolor = 0

/obj/item/clothing/head/custom_keffiyeh/attack_self(mob/user as mob)
	if (uncolored1)
		if (!patterncolor)
			var/input = WWinput(user, "Pattern - Choose a color:", "Cap Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				patterncolor = input
	//			user << "Color: [color]"

		if (patterncolor)
			uncolored1 = FALSE
			var/image/pattern = image("icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "keffiyeh_custom_color")
			pattern.color = patterncolor
			overlays += pattern
			return
	else
		..()

//Helmets

/obj/item/clothing/head/helmet/montefortino
	name = "bronze montefortino helmet"
	desc = "A conical bronce helmet with cheekplates."
	icon_override = "code/modules/1713/clothing/head.dmi"
	icon_state = "montefortino"
	item_state = "montefortino"
	worn_state = "montefortino"
	body_parts_covered = HEAD
	armor = list(melee = 38, arrow = 25, gun = FALSE, energy = 15, bomb = 30, bio = 20, rad = FALSE)
	health = 30
	var/uncolored1 = TRUE
	var/patterncolor = 0

/obj/item/clothing/head/helmet/montefortino/attack_self(mob/user as mob)
	if (uncolored1)
		if (!patterncolor)
			var/input = WWinput(user, "Pattern - Choose a color:", "Cap Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				patterncolor = input
	//			user << "Color: [color]"

		if (patterncolor)
			uncolored1 = FALSE
			var/image/pattern = image("icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "montefortino_color")
			pattern.color = patterncolor
			overlays += pattern
			return
	else
		..()


/obj/item/clothing/head/helmet/roman_decurion/nomads
	name = "roman decurion helmet"
	desc = "An iron helmet, used by decurions. Officers within the cavalry of the roman army."
	icon_override = "code/modules/1713/clothing/head.dmi"
	icon_state = "roman_d"
	item_state = "roman_d"
	worn_state = "roman_d"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 50, arrow = 40, gun = 5, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 40
	var/uncolored1 = TRUE
	var/patterncolor = 0

/obj/item/clothing/head/helmet/roman_decurion/nomads/attack_self(mob/user as mob)
	if (uncolored1)
		if (!patterncolor)
			var/input = WWinput(user, "Pattern - Choose a color:", "Cap Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				patterncolor = input
	//			user << "Color: [color]"

		if (patterncolor)
			uncolored1 = FALSE
			var/image/pattern = image("icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "roman_d_color")
			pattern.color = patterncolor
			overlays += pattern
			return
	else
		..()

/obj/item/clothing/head/helmet/roman_centurion/nomads
	name = "roman centurion helmet"
	desc = "An iron helmet, used by centurions. Officers within the infantry of the roman army."
	icon_override = "code/modules/1713/clothing/head.dmi"
	icon_state = "roman_c"
	item_state = "roman_c"
	worn_state = "roman_c"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 50, arrow = 40, gun = 5, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 40
	var/uncolored1 = TRUE
	var/patterncolor = 0

/obj/item/clothing/head/helmet/roman_centurion/nomads/attack_self(mob/user as mob)
	if (uncolored1)
		if (!patterncolor)
			var/input = WWinput(user, "Pattern - Choose a color:", "Cap Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				patterncolor = input
	//			user << "Color: [color]"

		if (patterncolor)
			uncolored1 = FALSE
			var/image/pattern = image("icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "roman_c_color")
			pattern.color = patterncolor
			overlays += pattern
			return
	else
		..()

/obj/item/clothing/head/custom_feathered_hat
	name = "feathered cap"
	desc = "A feathered cap."
	var/uncolored1 = FALSE
	var/capcolor = 0
	var/bandcolor = 0
	item_state = "custfeathercap_hat"
	icon_state = "custfeathercap_hat"
	worn_state = "custfeathercap_hat"
	color = "#FFFFFF"
	New()
		..()
		spawn(5)
			uncolored1 = TRUE


/obj/item/clothing/head/custom_feathered_hat/attack_self(mob/user as mob)
	if (uncolored1)
		if (!capcolor)
			var/input = WWinput(user, "Cap - Choose a color:", "Cap Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				capcolor = input
	//			user << "Color: [color]"
		if (!bandcolor)
			var/input = WWinput(user, "Feather - Choose a color:", "Feather Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				bandcolor = input
		if (bandcolor && capcolor)
			uncolored1 = FALSE
			var/image/band = image("icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "custfeathercap_f_hat")
			band.color = bandcolor
			var/image/cap = image("icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "customcap_b_hat")
			cap.color = capcolor
			overlays += band
			overlays += cap
			return
	else
		..()

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
/obj/item/clothing/under/crinoline_dress
	name = "crinoine dress"
	desc = "A laced dress."
	var/uncolored = FALSE
	var/topcolor = 0
	var/undercolor = 0
	item_state = "crinoline_dress"
	icon_state = "crinoline_dress"
	worn_state = "crinoline_dress"
	color = "#FFFFFF"
	New()
		..()
		spawn(5)
			uncolored = TRUE


/obj/item/clothing/under/crinoline_dress/attack_self(mob/user as mob)
	if (uncolored)
		if (!topcolor)
			var/input = WWinput(user, "Top - Choose a color:", "Dress Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				topcolor = input

		if (!undercolor)
			var/input = WWinput(user, "Under Bottom - Choose a color:", "Vest/Skirt Line Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				undercolor = input
		if (topcolor && undercolor)
			uncolored = FALSE
			var/image/top = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "crinoline_dress_dress")
			top.color = topcolor
			var/image/under = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "crinoline_dress_under")
			under.color = undercolor
			var/image/lining = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "crinoline_dress_lining")
			overlays += top
			overlays += under
			overlays += lining
			return
	else
		..()
///////////////////////////////////////////////////////////////////////////////////////
/obj/item/clothing/head/custom_hennin
	name = "hennin"
	desc = "A headdress fashioned from cloth with a nice lining."
	icon_state = "custom_hennin"
	item_state = "custom_hennin"
	worn_state = "custom_hennin"
	heat_protection = HEAD
	var/uncolored1 = TRUE
	var/patterncolor = 0

/obj/item/clothing/head/custom_hennin/attack_self(mob/user as mob)
	if (uncolored1)
		if (!patterncolor)
			var/input = WWinput(user, "Pattern - Choose a color:", "Cap Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				patterncolor = input
	//			user << "Color: [color]"

		if (patterncolor)
			uncolored1 = FALSE
			var/image/pattern = image("icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "custom_hennin_point")
			pattern.color = patterncolor
			overlays += pattern
			return
	else
		..()

/////////////////CUSTOM GENERIC UNIFORMS////////////////////////////////////
/obj/item/clothing/under/customuniform
	name = "modern outfit"
	desc = "A generic outfit."
	var/uncolored = FALSE
	var/shirtcolor = 0
	var/pantscolor = 0
	item_state = "custom_mod_full"
	icon_state = "custom_mod_full"
	worn_state = "custom_mod_full"
	var/base_icon = "custom_mod"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO|ARMS
	color = "#FFFFFF"
	New()
		..()
		spawn(5)
			uncolored = TRUE


/obj/item/clothing/under/customuniform/attack_self(mob/user as mob)
	if (uncolored)
		if (!shirtcolor)
			var/input = WWinput(user, "Shirt - Choose a color:", "Shirt Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				shirtcolor = input
	//			user << "Color: [color]"
		if (!pantscolor)
			var/input = WWinput(user, "Pants - Choose a color:", "Pants Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				pantscolor = input

		if (shirtcolor && pantscolor)
			uncolored = FALSE
			var/image/pants = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "[base_icon]_pants")
			pants.color = pantscolor
			var/image/shirt = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "[base_icon]_shirt")
			shirt.color = shirtcolor
			var/image/belt = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "custom_belt")
			overlays += pants
			overlays += shirt
			overlays += belt
			return
	else
		..()

/obj/item/clothing/under/customuniform/facilityg
	name = "Facility uniform"
	desc = "A sterile white uniform."
	shirtcolor = "#FFFFFF"
	pantscolor = "#FFFFFF"
	color = "#FFFFFF"

/obj/item/clothing/under/customuniform/baggy
	name = "baggy modern outfit"
	item_state = "custom_modbaggy_full"
	icon_state = "custom_modbaggy_full"
	worn_state = "custom_modbaggy_full"
	base_icon = "custom_modbaggy"

/obj/item/clothing/under/customuniform/short
	name = "short modern outfit"
	item_state = "custom_modshort_full"
	icon_state = "custom_modshort_full"
	worn_state = "custom_modshort_full"
	base_icon = "custom_modshort"

/obj/item/clothing/under/customuniform/colonial
	name = "colonial outfit"
	item_state = "custom_col_full"
	icon_state = "custom_col_full"
	worn_state = "custom_col_full"
	base_icon = "custom_col"

/obj/item/clothing/under/customuniform/colonial/short
	name = "short colonial outfit"
	item_state = "custom_col_short_full"
	icon_state = "custom_col_short_full"
	worn_state = "custom_col_short_full"
	base_icon = "custom_col_short"

/obj/item/clothing/suit/storage/jacket/custom/hoodie
	name = "hoodie"
	desc = "A simple comfy cloth hoodie."
	icon_state = "customhoodie"
	item_state = "customhoodie"
	worn_state = "customhoodie"
	uncolored = TRUE

/obj/item/clothing/suit/storage/jacket/custom/cloth_jacket
	name = "cloth jacket"
	desc = "A simple cloth jacket."
	icon_state = "customjacket"
	item_state = "customjacket"
	worn_state = "customjacket"
	uncolored = TRUE

/obj/item/clothing/suit/storage/jacket/custom/blazer
	name = "suit blazer"
	desc = "A simple cloth blazer."
	icon_state = "customblazer"
	item_state = "customblazer"
	worn_state = "customblazer"
	uncolored = TRUE

////////////Track suit////////////////

/obj/item/clothing/under/customtrackpants
	name = "track pants"
	desc = "A shirt with tracksuit pants."
	var/uncolored = FALSE
	var/pantscolor = 0
	var/sidescolor = 0
	var/shirtcolor = 0
	item_state = "trackpants_custom"
	icon_state = "trackpants_custom"
	worn_state = "trackpants_custom"
	color = "#FFFFFF"
	New()
		..()
		spawn(5)
			uncolored = TRUE


/obj/item/clothing/under/customtrackpants/attack_self(mob/user as mob)
	if (uncolored)
		if (!pantscolor)
			var/input = WWinput(user, "Pants - Choose a base color:", "Pants Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				pantscolor = input
		if (!sidescolor)
			var/input = WWinput(user, "Pants Stripes - Choose a color:", "Pants Stripes Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				sidescolor = input
		if (!shirtcolor)
			var/input = WWinput(user, "Shirt - Choose a color:", "Shirt Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				shirtcolor = input
		if (pantscolor && sidescolor && shirtcolor)
			uncolored = FALSE
			var/image/pants = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "trackpants_custom_pants")
			pants.color = pantscolor
			var/image/sides = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "trackpants_custom_sides")
			sides.color = sidescolor
			var/image/shirt = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "trackpants_custom_shirt")
			shirt.color = shirtcolor
			overlays += pants
			overlays += sides
			overlays += shirt
			return
	else
		..()

/obj/item/clothing/suit/storage/jacket/customtracksuit
	name = "track suit"
	desc = "A sporty track suit."
	var/uncolored = FALSE
	var/basecolor = 0
	var/linescolor = 0
	item_state = "customtracksuit"
	icon_state = "customtracksuit"
	worn_state = "customtracksuit"
	color = "#FFFFFF"
	New()
		..()
		spawn(5)
			uncolored = TRUE


/obj/item/clothing/suit/storage/jacket/customtracksuit/attack_self(mob/user as mob)
	if (uncolored)
		if (!basecolor)
			var/input = WWinput(user, "Jacket - Choose a base color:", "Jacket Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				basecolor = input
		if (!linescolor)
			var/input = WWinput(user, "Jacket Lines - Choose a color:", "Jacket Lines Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				linescolor = input
		if (basecolor && linescolor)
			uncolored = FALSE
			var/image/base = image("icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "customtracksuit_base")
			base.color = basecolor
			var/image/lines = image("icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "customtracksuit_lines")
			lines.color = linescolor
			overlays += base
			overlays += lines
			return
	else
		..()