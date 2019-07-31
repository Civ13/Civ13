/obj/item/clothing/under/custom
	var/uncolored = FALSE
	color = "#FFFFFF"
	New()
		..()
		spawn(5)
			uncolored = TRUE


/obj/item/clothing/under/custom/attack_self(mob/user as mob)
	if (uncolored)
		var/input = input(user, "Choose a hex color (without the #):", "Color" , "FFFFFF")
		if (input == null || input == "")
			return
		else
			input = uppertext(input)
			if (lentext(input) != 6)
				return
			var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
			for (var/i = 1, i <= 6, i++)
				var/numtocheck = 0
				if (i < 6)
					numtocheck = copytext(input,i,i+1)
				else
					numtocheck = copytext(input,i,0)
				if (!(numtocheck in listallowed))
					return
			color = addtext("#",input)
//			user << "Color: [color]"
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
		var/input = input(user, "Choose a hex color (without the #):", "Color" , "FFFFFF")
		if (input == null || input == "")
			return
		else
			input = uppertext(input)
			if (lentext(input) != 6)
				return
			var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
			for (var/i = 1, i <= 6, i++)
				var/numtocheck = 0
				if (i < 6)
					numtocheck = copytext(input,i,i+1)
				else
					numtocheck = copytext(input,i,0)
				if (!(numtocheck in listallowed))
					return
			color = addtext("#",input)
//			user << "Color: [color]"
			uncolored1 = FALSE
			return
	else
		..()

/obj/item/clothing/suit/storage/jacket/custom
	var/uncolored = FALSE

/obj/item/clothing/suit/storage/jacket/custom/attack_self(mob/user as mob)
	if (uncolored)
		var/input = input(user, "Choose a hex color (without the #):", "Color" , "FFFFFF")
		if (input == null || input == "")
			return
		else
			input = uppertext(input)
			if (lentext(input) != 6)
				return
			var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
			for (var/i = 1, i <= 6, i++)
				var/numtocheck = 0
				if (i < 6)
					numtocheck = copytext(input,i,i+1)
				else
					numtocheck = copytext(input,i,0)
				if (!(numtocheck in listallowed))
					return
			color = addtext("#",input)
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

/obj/item/clothing/under/custom/celtic
	name = "celtic trousers"
	desc = "Thick cloth celtic trousers."
	icon_state = "customceltic"
	item_state = "customceltic"
	worn_state = "customceltic"

/obj/item/clothing/under/custom/toga/purple
	name = "purple toga"
	desc = "A fancy cloth toga."
	icon_state = "customtoga"
	item_state = "customtoga"
	worn_state = "customtoga"
	uncolored = FALSE
	color = "#66023C"

///////////////MEDIEVAL//////////////////////////////////////
/obj/item/clothing/under/custom/tunic
	name = "tunic"
	desc = "A simple cloth tunic, with a leather belt."
	icon_state = "customtunic"
	item_state = "customtunic"
	worn_state = "customtunic"

/obj/item/clothing/under/custom/arabictunic
	name = "arabic tunic"
	desc = "A light cloth tunic, in arabic style."
	icon_state = "customarabictunic"
	item_state = "customarabictunic"
	worn_state = "customarabictunic"

/obj/item/clothing/suit/storage/jacket/custom/poncho
	name = "poncho"
	desc = "A simple cloth poncho."
	icon_state = "customponcho"
	item_state = "customponcho"
	worn_state = "customponcho"

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
			var/input = input(user, "Top - Choose a hex color (without the #):", "Top Color" , "FFFFFF")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				topcolor = addtext("#",input)

		if (!undercolor)
			var/input = input(user, "Lining - Choose a hex color (without the #):", "Lining Color" , "FFFFFF")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				undercolor = addtext("#",input)

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

/obj/item/clothing/under/custompontificial
	name = "renaissance outfit"
	desc = "A renaissance-style pontificial outfit."
	var/uncolored = FALSE
	var/topcolor = 0
	var/undercolor = 0
	var/linescolor = 0
	var/handcolor = 0
	item_state = "custom_pontificial"
	icon_state = "custom_pontificial"
	worn_state = "custom_pontificial"
	color = "#FFFFFF"
	New()
		..()
		spawn(5)
			uncolored = TRUE


/obj/item/clothing/under/custompontificial/attack_self(mob/user as mob)
	if (uncolored)
		if (!topcolor)
			var/input = input(user, "Top Decore - Choose a hex color (without the #):", "Top Decore Color" , "FFFFFF")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				topcolor = addtext("#",input)

		if (!undercolor)
			var/input = input(user, "Leggings - Choose a hex color (without the #):", "Leggings Color" , "FFFFFF")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				undercolor = addtext("#",input)
		if (!linescolor)
			var/input = input(user, "Top Lines - Choose a hex color (without the #):", "Top Lines Color" , "FFFFFF")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				linescolor = addtext("#",input)
		if (!handcolor)
			var/input = input(user, "Hand Decore - Choose a hex color (without the #):", "Hand Decore Color" , "FFFFFF")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				handcolor = addtext("#",input)

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
			var/input = input(user, "Top - Choose a hex color (without the #):", "Top Color" , "FFFFFF")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				topcolor = addtext("#",input)

		if (!undercolor)
			var/input = input(user, "Under Bottom - Choose a hex color (without the #):", "Under Bottom Color" , "FFFFFF")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				undercolor = addtext("#",input)
		if (!overcolor)
			var/input = input(user, "Over Bottom - Choose a hex color (without the #):", "Over Bottom Color" , "FFFFFF")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				overcolor = addtext("#",input)
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
			var/input = input(user, "Top - Choose a hex color (without the #):", "Sleeves/Skirt Color" , "FFFFFF")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				topcolor = addtext("#",input)

		if (!undercolor)
			var/input = input(user, "Under Bottom - Choose a hex color (without the #):", "Vest/Skirt Line Color" , "FFFFFF")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				undercolor = addtext("#",input)
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
			var/input = input(user, "Main - Choose a hex color (without the #):", "Main Color" , "FFFFFF")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				topcolor = addtext("#",input)
	//			user << "Color: [color]"
		if (!deccolor)
			var/input = input(user, "Decorations - Choose a hex color (without the #):", "Decorations Color" , "FFFFFF")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				deccolor = addtext("#",input)
		if (!linescolor)
			var/input = input(user, "Lines - Choose a hex color (without the #):", "Lines Color" , "FFFFFF")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				linescolor = addtext("#",input)
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
			var/input = input(user, "Jacket - Choose a hex color (without the #):", "Jacket Color" , "FFFFFF")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				jacketcolor = addtext("#",input)
	//			user << "Color: [color]"
		if (!crosscolor)
			var/input = input(user, "Pants - Choose a cross bandolier color (without the #):", "Bandolier Color" , "FFFFFF")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				crosscolor = addtext("#",input)
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
	color = "#FFFFFF"
	New()
		..()
		spawn(5)
			uncolored = TRUE


/obj/item/clothing/under/customtribalrobe/attack_self(mob/user as mob)
	if (uncolored)
		if (!shirtcolor)
			var/input = input(user, "Robe - Choose a hex color (without the #):", "Robe Color" , "FFFFFF")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				shirtcolor = addtext("#",input)
	//			user << "Color: [color]"
		if (!pantscolor)
			var/input = input(user, "Decoration - Choose a hex color (without the #):", "Decoration Color" , "FFFFFF")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				pantscolor = addtext("#",input)

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
/obj/item/clothing/under/customuniform
	name = "uniform"
	desc = "A victorian Era uniform."
	var/uncolored = FALSE
	var/shirtcolor = 0
	var/pantscolor = 0
	var/epaulettescolor = 0
	item_state = "customuni"
	icon_state = "customuni"
	worn_state = "customuni"
	color = "#FFFFFF"
	New()
		..()
		spawn(5)
			uncolored = TRUE


/obj/item/clothing/under/customuniform/attack_self(mob/user as mob)
	if (uncolored)
		if (!shirtcolor)
			var/input = input(user, "Shirt - Choose a hex color (without the #):", "Shirt Color" , "FFFFFF")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				shirtcolor = addtext("#",input)
	//			user << "Color: [color]"
		if (!pantscolor)
			var/input = input(user, "Pants - Choose a hex color (without the #):", "Pants Color" , "FFFFFF")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				pantscolor = addtext("#",input)
		if (!epaulettescolor)
			var/input = input(user, "Epaulettes - Choose a hex color (without the #):", "Epaulettes Color" , "FFFFFF")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				epaulettescolor = addtext("#",input)
		if (shirtcolor && pantscolor && epaulettescolor)
			uncolored = FALSE
			var/image/pants = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "customuni_pants")
			pants.color = pantscolor
			var/image/shirt = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "customuni_shirt")
			shirt.color = shirtcolor
			var/image/belt = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "customuni_over")
			var/image/epaulettes = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "customuni_epaulettes")
			epaulettes.color = epaulettescolor
			overlays += pants
			overlays += shirt
			overlays += belt
			overlays += epaulettes
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
			var/input = input(user, "Cap - Choose a hex color (without the #):", "Cap Color" , "FFFFFF")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				capcolor = addtext("#",input)
	//			user << "Color: [color]"
		if (!bandcolor)
			var/input = input(user, "Band - Choose a hex color (without the #):", "Band Color" , "FFFFFF")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				bandcolor = addtext("#",input)
		if (!symbolcolor)
			var/input = input(user, "Symbol - Choose a hex color (without the #):", "Symbol Color" , "FFFFFF")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				symbolcolor = addtext("#",input)
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
			var/input = input(user, "Cap - Choose a hex color (without the #):", "Cap Color" , "FFFFFF")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				capcolor = addtext("#",input)
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
	New()
		..()
		spawn(5)
			uncolored = TRUE


/obj/item/clothing/under/customuniform_modern/attack_self(mob/user as mob)
	if (uncolored)
		if (!browncolor)
			var/input = input(user, "First Camo Color - Choose a hex color (without the # | default is brown):", "First Camo Color" , "58493d")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				browncolor = addtext("#",input)
		if (!greencolor)
			var/input = input(user, "Second Camo Color - Choose a hex color (without the # | default is green):", "Second Camo Color" , "5b6142")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				greencolor = addtext("#",input)
		if (!blackcolor)
			var/input = input(user, "Third Camo Color - Choose a hex color (without the # | default is dark grey):", "First Camo Color" , "2f323b")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				blackcolor = addtext("#",input)
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
			var/input = input(user, "Stripes - Choose a hex color (without the #):", "Stripes Color" , "FFFFFF")
			if (input == null || input == "")
				return
			else
				input = uppertext(input)
				if (lentext(input) != 6)
					return
				var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
				for (var/i = 1, i <= 6, i++)
					var/numtocheck = 0
					if (i < 6)
						numtocheck = copytext(input,i,i+1)
					else
						numtocheck = copytext(input,i,0)
					if (!(numtocheck in listallowed))
						return
				stripescolor = addtext("#",input)

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