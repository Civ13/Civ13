////////////////////////
/* Crucible Reactions */
////////////////////////

// Charcoal
/datum/crucible_reaction/leadingot
	reqpaths = list("/obj/item/stack/ore/coal" = 1)
	respaths = list("/obj/item/stack/ore/coal" = 1)
	reactiontemp = 600

// Lead Ingot
/datum/crucible_reaction/leadingot
	reqpaths = list("/obj/item/stack/ore/lead" = INGOT_VALUE, "/obj/item/stack/ore/charcoal" = 1)
	respaths = list("/obj/item/heatable/ingot/lead" = 1)
	reactiontemp = 700


// Tin Ingot
/datum/crucible_reaction/tiningot
	reqpaths = list("/obj/item/stack/ore/tin" = INGOT_VALUE, "/obj/item/stack/ore/charcoal" = 1)
	respaths = list("/obj/item/heatable/ingot/tin" = 1)
	reactiontemp = 700


// Copper Ingot
/datum/crucible_reaction/copperingot
	reqpaths = list("/obj/item/stack/ore/copper" = INGOT_VALUE, "/obj/item/stack/ore/charcoal" = 1)
	respaths = list("/obj/item/heatable/ingot/copper" = 1)
	reactiontemp = 1100


// Zinc Brass
/datum/crucible_reaction/zincbrass
	reqpaths = list("/obj/item/heatable/ingot/copper" = 2, "/obj/item/stack/ore/zinc" = INGOT_VALUE)
	respaths = list("/obj/item/heatable/ingot/brass" = 3)
	reactiontemp = 910


// Tin Bronze
/datum/crucible_reaction/tinbronze
	reqpaths = list("/obj/item/heatable/ingot/tin" = 1, "/obj/item/heatable/ingot/copper" = 2)
	respaths = list("/obj/item/heatable/ingot/bronze" = 3)
	reactiontemp = 1100


// Blister Steel
/datum/crucible_reaction/blistersteel
	reqpaths = list("/obj/item/heatable/ingot/wroughtiron" = 1, "/obj/item/stack/ore/charcoal" = 1)
	respaths = list("/obj/item/heatable/ingot/blistersteel" = 1)
	reactiontemp = 1100


// Crucible Steel
///datum/crucible_reaction/blistersteel
//	reqpaths = list("/obj/item/heatable/ingot/blistersteel" = 1)
//	respaths = list("/obj/item/heatable/ingot/cruciblesteel" = 1)
//	reactiontemp = 1300	// Above the melting point of blister steel