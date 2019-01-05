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
///////////////IMPERIAL//////////////////////////////////////