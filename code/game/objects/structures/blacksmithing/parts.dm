//weapon parts (arrowheads, spearheads, etc) that need to be finished with hood handles and others
/obj/item/weapon/material/part
	name = "weapon part"
	icon = 'icons/obj/metallurgy.dmi'
	icon_state = "crude_axehead"
	desc = "A unfinished weapon part."
	flags = CONDUCT
	sharp = TRUE
	edge = TRUE
	force_divisor = 0.10 // 9 when wielded with hardness 60 (steel)
	attack_verb = list("slashed","sliced")
	unbreakable = TRUE
	w_class = 1.0
	slot_flags = SLOT_BELT|SLOT_POCKET
	var/result = null
	var/result_name = ""
	material = "iron"

/obj/item/weapon/material/part/axehead
	name = "crude axe head"
	icon_state = "crude_axehead"
	desc = "A metallic axe head. Needs a handle to be useful."
	result = /obj/item/weapon/material/hatchet
	result_name = "axe"
	material = null

/obj/item/weapon/material/part/shovel
	name = "crude shovel head"
	icon_state = "crude_shovel"
	desc = "A metallic shovel head. Needs a handle to be useful."
	result = /obj/item/weapon/material/shovel
	result_name = "shovel"
	material = null

/obj/item/weapon/material/part/pickaxe
	name = "crude pickaxe head"
	icon_state = "crude_pickaxe"
	desc = "A metallic pickaxe head. Needs a handle to be useful."
	result = /obj/item/weapon/material/pickaxe
	result_name = "pickaxe"
	material = null

/obj/item/weapon/material/part/spearhead
	name = "crude spearhead"
	icon_state = "crude_spearhead"
	desc = "A metallic spearhead. Needs a handle to be useful."
	result = /obj/item/weapon/material/spear
	result_name = "spear"
	material = null

/obj/item/weapon/material/part/attackby(obj/item/weapon/material/handle/HANDLE, mob/living/human/H)
	if (result && material && src)
		new result(H.loc,material)
		qdel(HANDLE)
		qdel(src)
		H << "You finish assembling the [result_name]."
		return