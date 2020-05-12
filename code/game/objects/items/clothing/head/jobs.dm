
//Bartender
/obj/item/clothing/head/chefhat
	name = "chef's hat"
	desc = "It's a hat used by chefs to keep hair out of your food. Judging by the food in the mess, they don't work."
	icon_state = "chefhat"
	item_state = "chefhat"

//Captain
/obj/item/clothing/head/caphat
	name = "captain's hat"
	icon_state = "captain"
	desc = "It's good being the king."
	item_state_slots = list(
		slot_l_hand_str = "caphat",
		slot_r_hand_str = "caphat",
		)
	body_parts_covered = FALSE

/obj/item/clothing/head/caphat/cap
	name = "captain's cap"
	desc = "You fear to wear it for the negligence it brings."
	icon_state = "capcap"

/obj/item/clothing/head/caphat/formal
	name = "parade hat"
	desc = "No one in a commanding position should be without a perfect, white hat of ultimate authority."
	icon_state = "officercap"

//HOP
/obj/item/clothing/head/caphat/hop
	name = "crew resource's hat"
	desc = "A stylish hat that both protects you from enraged former-crewmembers and gives you a false sense of authority."
	icon_state = "hopcap"

//Chaplain // Nuns & Plague Doctor -> relocated to apparel medieval
/obj/item/clothing/head/chaplain_hood
	name = "preacher's hood"
	desc = "It's hood that covers the head."
	icon_state = "chaplain_hood"
	flags_inv = BLOCKHAIR
	body_parts_covered = HEAD

/obj/item/clothing/under/chaplain
	name = "preacher's clothing"
	desc = "Typical priest clothing."
	icon_state = "chaplain"

/obj/item/clothing/suit/storage/jacket/chaplain
	name = "preacher's hood"
	desc = "Typical priest hood."
	icon_state = "chaplain_hoodie"

//Mime
/obj/item/clothing/head/beret
	name = "beret"
	desc = "A beret, an artists favorite headwear."
	icon_state = "beret"
	body_parts_covered = FALSE

/obj/item/clothing/head/beret
	name = "black beret"
	desc = "A beret, used by fancy military people."
	icon_state = "blackberret"
	body_parts_covered = FALSE