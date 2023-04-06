/obj/structure/sign
	icon = 'icons/obj/decals.dmi'
	anchored = TRUE
	opacity = FALSE
	density = FALSE
	layer = 3.5
	w_class = ITEM_SIZE_NORMAL

/obj/structure/sign/ex_act(severity)
	switch(severity)
		if (1.0)
			qdel(src)
			return
		if (2.0)
			qdel(src)
			return
		if (3.0)
			qdel(src)
			return
		else
	return

/obj/structure/sign/attackby(obj/item/tool as obj, mob/user as mob)	//deconstruction
	if (istype(tool, /obj/item/weapon/hammer))
		var/obj/item/sign/S = new(loc)
		S.name = name
		S.desc = desc
		S.icon_state = icon_state
		//var/icon/I = icon('icons/obj/decals.dmi', icon_state)
		//S.icon = I.Scale(24, 24)
		S.sign_state = icon_state
		user << "You unfasten \the [S] with your [tool]."
		qdel(src)
	else ..()

/obj/item/sign
	name = "sign"
	desc = "This sign has come loose, maybe you could fasten it somewhere."
	icon = 'icons/obj/decals.dmi'
	w_class = ITEM_SIZE_NORMAL		//big
	var/sign_state = ""
	value = 0
/obj/item/sign/attackby(obj/item/tool as obj, mob/user as mob)	//construction
	if (istype(tool, /obj/item/weapon/hammer) && isturf(user.loc))
		var/direction = WWinput(user, "Fasten it to which direction?", "Select a direction.", "North", WWinput_list_or_null(list("North", "East", "South", "West")))
		if (direction)
			var/obj/structure/sign/S = new(user.loc)
			switch(direction)
				if ("North")
					S.pixel_y = 32
				if ("East")
					S.pixel_x = 32
				if ("South")
					S.pixel_y = -32
				if ("West")
					S.pixel_x = -32
				else return
			S.name = name
			S.desc = desc
			S.icon_state = sign_state
			user << "You fasten \the [S] with your [tool]."
			qdel(src)
	else ..()

/obj/structure/sign/securearea
	name = "\improper SECURE AREA"
	desc = "A warning sign which reads 'SECURE AREA'."
	icon_state = "securearea"

/obj/structure/sign/redcross
	name = "medbay"
	desc = "The Intergalactic symbol of Medical institutions. You'll probably get help here."
	icon_state = "redcross"

/obj/structure/sign/mcd
	name = "Mc Dondald's"
	desc = "The fast-food giant that guarantees to supersize your misery with every order."
	icon_state = "mcd3"

/obj/structure/sign/mcd/menu
	name = "Mc Dondald's menu"
	desc = "Fueling the obesity epidemic, one Big Mac at a time."
	icon_state = "mcd2"

/obj/structure/sign/mcd/pole
	name = "Mc Donald's"
	desc = "A towering tribute to humanity's insatiable appetite for processed food and regret."
	icon_state = "mcd-pole"

/obj/structure/sign/mcd/pole/New()
	..()
	overlays.Cut()
	var/image/img = image(icon='icons/obj/decals.dmi', icon_state = "mcd")
	img.pixel_x = 32
	overlays += img

/obj/structure/sign/mcd/pole/Destroy()
	..()
	overlays.Cut()

/obj/structure/sign/tfc
	name = "Texas Fried Chicken"
	desc = "A sign Texas people usually like."
	icon_state = "tfc"

/obj/structure/sign/weedshop
	name = "Weed Shop"
	desc = "A sign stoners usually like."
	icon_state = "weedshop"

/obj/structure/sign/mckellens
	name = "McKellen's"
	desc = "A sign for the McKellen's Franchise establishment."
	icon_state = "mckellens"

/obj/structure/sign/sheriff
	name = "Sheriff's Office"
	desc = "A sign for the local Sheriff's Office."
	icon_state = "sheriff"

/obj/structure/sign/bank
	name = "bank"
	desc = "A sign for the local bank."
	icon_state = "bank"

/obj/structure/sign/bar
	name = "BAR"
	desc = "A sign that says bar on it."
	icon_state = "barsign"

/obj/structure/sign/barbershop
	name = "barbershop"
	desc = "A swirly object indicating a barbershop."
	icon_state = "barber"

/obj/structure/sign/baily
	name = "Baily post"
	desc = "Protection service."
	icon_state = "bailypost"

/obj/structure/sign/baily2
	name = "Baily post"
	desc = "Protection service."
	icon_state = "bailypost2"

/obj/structure/sign/greencross
	name = "medbay"
	desc = "The Intergalactic symbol of Medical institutions. You'll probably get help here."
	icon_state = "greencross"

/obj/structure/sign/goldenplaque
	name = "The Most Robust Men Award for Robustness"
	desc = "To be Robust is not an action or a way of life, but a mental state. Only those with the force of Will strong enough to act during a crisis, saving friend from foe, are truly Robust. Stay Robust my friends."
	icon_state = "goldenplaque"

/obj/structure/sign/ogoldenplaque
	name = "Bank"
	desc = "Deposit valuables within."
	icon_state = "atmosplaque"

/obj/structure/sign/kiddieplaque
	name = "\improper AI developers plaque"
	desc = "Next to the extremely long list of names and job titles, there is a drawing of a little child. The child appears to be retarded. Beneath the image, someone has scratched the word \"PACKETS\""
	icon_state = "kiddieplaque"

/obj/structure/sign/armory
	name = "Armory"
	desc = "Armory this way."
	icon_state = "armory1"

/obj/structure/sign/abashiri
	name = "Shisetsu"
	desc = "Shisetsu (Farming Facility)."
	icon_state = "farming"
/obj/structure/sign/abashiri/wing1
	name = "Ichi Tsubasa"
	desc = "Ichi Tsubasa (Wing 1)."
	icon_state = "wing1"
/obj/structure/sign/abashiri/wing2
	name = "Ni Tsubasa"
	desc = "Ni Tsubasa (Wing 2)."
	icon_state = "wing2"
/obj/structure/sign/abashiri/wing3
	name = "San Tsubasa"
	desc = "San Tsubasa (Wing 3)."
	icon_state = "wing3"
/obj/structure/sign/abashiri/solitary
	name = "Kodoku"
	desc = "Kodoku (Solitary)."
	icon_state = "wing3"

/obj/structure/sign/japsign
	name = "street sign"
	desc = "A japanese street sign."
	icon = 'icons/obj/decals_wide.dmi'
	icon_state = "japsign"
/obj/structure/sign/japsign/New()
	..()
	var/picksign = pick("japsign", "japsign2", "japsign3", "japsign4", "japsign5", "japsign6")
	icon_state = picksign

/obj/structure/sign/mugshot
	name = "police lineup screen"
	desc = "A measure scale fixated to a wall. Useful for mugshots."
	icon = 'icons/obj/decals_wide.dmi'
	icon_state = "mugshot"

/obj/structure/sign/exit
	name = "Exit"
	desc = "Points to the exit."
	icon_state = "exit"

/obj/structure/sign/galacticbattles/unite
	name = "UNITE Poster"
	desc = "Seems to be a Galactic Republic Propaganda Poster for the fight against the Sepretists."
	icon_state = "unite"

/obj/structure/sign/galacticbattles/care
	name = "CARE Poster"
	desc = "Seems to be a Galactic Republic Propaganda Poster to make the public aware of infiltrators"
	icon_state = "care"

/obj/structure/sign/galacticbattles/repair
	name = "Corelian Repair Advertisement Poster"
	desc = "Seems to be a Corelian advertisement for Robot repairs"
	icon_state = "repair"


/obj/structure/sign/minefield
	name = "Minefield"
	desc = "Achtung! Minen."
	icon_state = "minefield"
	flammable = FALSE

/obj/structure/sign/exit/New()
	..()
	if (dir == WEST)
		desc = "Exit to the left."
	else if (dir == EAST)
		desc = "Exit to the right."
	else if (dir == NORTH)
		desc = "Exit to the north."
	else if (dir == SOUTH)
		desc = "Exit to the south."

/obj/structure/sign/custom
	name = "sign"
	desc = "Signs something."
	icon_state = "woodsign2"

/obj/structure/sign/custom/plaque
	name = "sign"
	desc = "Signs something."
	icon_state = "Colonial_Sign"

/obj/structure/sign/custom/golden
	name = "sign"
	desc = "Signs something."
	icon_state = "customsign2"

/obj/structure/sign/custom/metallic
	name = "sign"
	desc = "Signs something."
	icon_state = "customsign"
/obj/structure/sign/signpost
	name = "signpost"
	desc = "Signs something."
	icon_state = "signpost_pole"

/obj/structure/sign/signpost/New()
	..()
	spawn(1)
		if (findtext(desc, "<b>West:</b>"))
			overlays += icon(icon, "signpost_west")
		if (findtext(desc, "<b>North:</b>"))
			overlays += icon(icon, "signpost_north")
		if (findtext(desc, "<b>East:</b>"))
			overlays += icon(icon, "signpost_east")
		if (findtext(desc, "<b>South:</b>"))
			overlays += icon(icon, "signpost_south")
		update_icon()

/obj/structure/sign/signpost/update_icon()
	overlays.Cut()
	if (findtext(desc, "<b>West:</b>"))
		overlays += icon(icon, "signpost_west")
	if (findtext(desc, "<b>North:</b>"))
		overlays += icon(icon, "signpost_north")
	if (findtext(desc, "<b>East:</b>"))
		overlays += icon(icon, "signpost_east")
	if (findtext(desc, "<b>South:</b>"))
		overlays += icon(icon, "signpost_south")
/obj/structure/sign/signpost/everywhere/New()
	..()
	spawn(1)
		overlays += icon(icon, "signpost_west")
		overlays += icon(icon, "signpost_north")
		overlays += icon(icon, "signpost_east")
		overlays += icon(icon, "signpost_south")

//numbers
/obj/structure/sign/n1
	desc = "A silver sign which reads 'I'."
	name = "ONE"
	icon_state = "n1"
/obj/structure/sign/n2
	desc = "A silver sign which reads 'II'."
	name = "TWO"
	icon_state = "n2"
/obj/structure/sign/n3
	desc = "A silver sign which reads 'III'."
	name = "THREE"
	icon_state = "n3"
/obj/structure/sign/n4
	desc = "A silver sign which reads 'IV'."
	name = "FOUR"
	icon_state = "n4"
/obj/structure/sign/n5
	desc = "A silver sign which reads 'V'."
	name = "FIVE"
	icon_state = "n5"
/obj/structure/sign/n6
	desc = "A silver sign which reads 'VI'."
	name = "SIX"
	icon_state = "n6"

/obj/structure/sign/torii
	desc = "A tall red gate structure."
	name = "torii gate"
	icon_state = "torii"
	icon = 'icons/turf/64x64.dmi'

/obj/structure/sign/painting1
	desc = "A large foamy wave crashes into the rocky shore. A bit of sunlight passes through the clouds, glistening on the sea surface and wet boulders."
	name = "painting"
	icon_state = "painting1"

/obj/structure/sign/painting2
	desc = "A serene city street with a few people on a summer day. Two- and three-storey houses stand to the left and right, separated by a cobblestone road. A massive building with spires could be seen in the distance."
	name = "painting"
	icon_state = "painting2"

/obj/structure/sign/painting3
	desc = "A blazing sunset seen from a steep cliff above the sea."
	name = "painting"
	icon_state = "painting3"

/obj/structure/sign/painting4
	desc = "A wooded mountain valley with a small pond at the clearing, where a group of horsemen could be seen. The mountains themselves loom farther ahead, obscured by a thin haze."
	name = "painting"
	icon_state = "painting4"

/obj/structure/sign/painting5
	desc = "A still life painting, depicting a table with a piece of white cloth, several fruits and a human skull."
	name = "painting"
	icon_state = "painting5"

/obj/structure/sign/painting6
	desc = "A long-tailed bird with black, olive green and white plumage, resembling a magpie, perches on a tree branch, surrounded by white cherry blossoms."
	name = "painting"
	icon_state = "painting6"

/obj/structure/sign/painting7
	desc = "A lone figure with a carrying pole on their shoulders stands under a tall pine on the sloping shore, gazing at the snow-peaked mountain across the strait. The sky is colored dark orange by the setting sun."
	name = "painting"
	icon_state = "painting7"

/obj/structure/sign/painting8
	desc = "A hilly landscape, where a large temple with red timber beams and sweeping roofs stands on the bank of a river."
	name = "painting"
	icon_state = "painting8"

/obj/structure/sign/painting9
	desc = "A small encampment in the desert, with a few tents, several horses and loaded camels. A faraway river crosses the expanse of barren dunes."
	name = "painting"
	icon_state = "painting9"

/obj/structure/sign/painting10
	desc = "A barque at sea, lit by the full moon."
	name = "painting"
	icon_state = "painting10"

/obj/structure/sign/medal
	name = "presence recognition"
	icon_state = "medal"
	desc = "A recognition plaque staight from the ministy of admission! This one seems to be for the persons presence, what an award!"

/obj/structure/sign/painting11
	desc = "A famous painting with a starry sky."
	name = "painting"
	icon_state = "painting11"

/obj/structure/sign/painting12
	desc = "An arrid desert, with some tents in the middle."
	name = "painting"
	icon_state = "painting12"

/obj/structure/sign/painting13
	desc = "A still life."
	name = "painting"
	icon_state = "painting13"

////Restroom signs////

/obj/structure/sign/restroom
	desc = "A sign indicating the presence of a restroom."
	name = "restroom"
	icon_state = "restroom"

/obj/structure/sign/restroom/male
	desc = "A sign indicating the presence of a male restroom."
	name = "restroom"
	icon_state = "restroom_male"

/obj/structure/sign/restroom/female
	desc = "A sign indicating the presence of a female restroom."
	name = "restroom"
	icon_state = "restroom_female"

/obj/structure/sign/justice
	desc = "A justice sign."
	name = "justice"
	icon_state = "justice"

/obj/structure/sign/court
	name = "court"
	desc = "The court house."
	icon = 'icons/obj/decals_wide.dmi'
	icon_state = "court"
	bound_width = 64

/obj/structure/sign/townhall
	name = "town hall"
	desc = "The town hall."
	icon = 'icons/obj/decals_wide.dmi'
	icon_state = "townhall"
	bound_width = 64

/obj/structure/sign/nosmoking
	desc = "Smoking is prohibited in this area."
	name = "no smoking"
	icon_state = "nosmoking"

/obj/structure/sign/nosmoking2
	desc = "Smoking is prohibited in this area."
	name = "no smoking"
	icon_state = "nosmoking2"

/obj/structure/sign/anatomy
	desc = "A poster detailing the complexity of the human body."
	name = "anatomy poster"
	icon_state = "anatomy"

/obj/structure/sign/xray
	desc = "A medical lightbox used to examine X-ray images."
	name = "lightbox"
	icon_state = "xray_on"

/obj/structure/sign/periodic
	desc = "A tabular display of the chemical elements."
	name = "periodic table"
	icon_state = "periodic"

/obj/structure/sign/casino
	name = "casino"
	desc = "A blinking casino sign."
	icon = 'icons/obj/decals_wider.dmi'
	icon_state = "casino"

/obj/structure/sign/open
	name = "open"
	desc = "A blinking open sign."
	icon_state = "open"

/obj/structure/sign/guns
	name = "gun store"
	desc = "A blinking gun store sign."
	icon_state = "gunshop"

/obj/structure/sign/gas
	name = "gas"
	desc = "A flashing gas station sign."
	icon_state = "gas"

/obj/structure/sign/sale
	name = "SALE sign"
	desc = "A sign indicating a sale."
	icon_state = "sale"

/obj/structure/sign/rent
	name = "FOR RENT sign"
	desc = "A sign indicating something for rent."
	icon_state = "rent"

/obj/structure/sign/deer_trophy
	name = "hunting deer trophy"
	desc = "Looks like we finally found Bambi..."
	icon_state = "deer_trophy"

/obj/structure/sign/orthodox1
	name = "icon of Mary"
	desc = "An icon depicting Mary, mother of Jesus. Often used in Eastern Orthodox cultures."
	icon_state = "orthodox1"

/obj/structure/sign/orthodox2
	name = "icon of Trinity"
	desc = "An icon depicting the saint Trinity. Often used in Eastern Orthodox cultures."
	icon_state = "orthodox2"

/obj/structure/sign/orthodox3
	name = "icon of Archangel Michael"
	desc = "An icon depicting Archangel Michael. Often used in Eastern Orthodox cultures."
	icon_state = "orthodox3"

/obj/structure/sign/khalif_ali1
	name = "portrait of Khalif Ali"
	desc = "A portrait of Khalif Ali."
	icon_state = "khalif_ali1"

/obj/structure/sign/khalif_ali2
	icon_state = "khalif_ali2"

//BILLBOARDS

/obj/structure/billboard
	name = "billboard ad"
	desc = "Goodness, what are they selling us this time?"
	icon = 'icons/obj/billboards.dmi'
	icon_state = "billboard"
	light_range = 4
	light_power = 2
	light_color = "#fcf8f0"
	density = TRUE
	anchored = TRUE
	not_movable = TRUE
	layer = MOB_LAYER + 0.1
	bound_width = 64
	bound_height = 64
	var/adnumber

/obj/structure/billboard/Destroy()
	set_light(0)
	return ..()

/obj/structure/billboard/New()
	..()
	adnumber = rand(1,14)
	overlays += "ad[adnumber]"
	update_icon()


///CHRISTMAS

/obj/structure/sign/christmas/lights
	name = "christmas lights"
	desc = "Flashy."
	icon = 'icons/obj/christmas.dmi'
	icon_state = "xmaslights"
	layer = 6.2

/obj/structure/sign/christmas/wreath
	name = "wreath"
	desc = "Prickly and overrated."
	icon = 'icons/obj/christmas.dmi'
	icon_state = "doorwreath"
	layer = 6.3
