//////////////
/* Crucible */
//////////////

/obj/item/heatable/crucible
	name = "\improper clay crucible"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "claycrucible"
	var/itemNum = 0
	var/itemLimit = 24
	var/list/contained = list()
	var/list/meltPoints = list()
	var/list/meltProgress = list()
	var/latentHeat = 300
	var/liquid = 0
	var/minMelt = null
	var/list/valid_reactions = list()



////////////////
/* Initialize */
////////////////

/obj/item/heatable/crucible/New()
	..()
	if(!GLOB.crucible_reactants || !GLOB.crucible_reactions_list)
		initialize_crucible_reactions()



///////////////
/* Attack By */
///////////////

/obj/item/heatable/crucible/attackby(obj/item/I, mob/user)
	if(GLOB.crucible_reactants["[I.type]"] || istype(I, /obj/item/heatable/ingot))
		if(itemNum < itemLimit)
			addItem(I, TRUE)
			to_chat(user, "<span class='italics'>You add \the [I] to \the [src].</span>")
		else
			to_chat(user, "<span class='notice'>\The [src] is full.</span>")
		return
	..()



////////////////////
/* Empty Crucible */
////////////////////

/obj/item/heatable/crucible/attack_self(mob/living/user)
	if(!itemNum)
		return ..()
	to_chat(user, "<span class='notice'>The contents of \the [src] fall on to the ground.</span>")
	for(var/M in contained)
		var/i = contained[M]
		if(ispath(text2path(M), /obj/item/heatable/ingot))
			new M(user.loc, i)
			useMetal(itemLimit, M)
		else
			while(i > 0)
				new M(user.loc)
				i--
			contained.Remove(M)
	itemNum = 0



///////////////
/* Use Metal */
///////////////

/obj/item/heatable/crucible/proc/useMetal(var/value, var/textType, var/fluid = FALSE)
	var/metalVal = contained[textType]
	if(metalVal - value <= 0)
		itemNum -= metalVal*INGOT_VALUE
		contained.Remove(textType)
		meltProgress.Remove(textType)
		meltPoints.Remove(textType)
		resetMinMelt()
	else
		if(fluid)
			meltProgress[textType] = ((meltProgress[textType] * metalVal) - value) / (metalVal - value)
		contained[textType] -= value
		itemNum -= value*INGOT_VALUE



//////////////
/* Add Item */
//////////////

/obj/item/heatable/crucible/proc/addItem(var/obj/item/I, var/changeTemp = TRUE)

	//-- Add Item to "materials" --//
	if(!contained["[I.type]"])
		contained["[I.type]"] = 0
	contained["[I.type]"] += 1
	if(istype(I, /obj/item/heatable/ingot))
		itemNum += INGOT_VALUE
	else
		itemNum++
	updateValidReactions()

	//-- Update Temperature --//
	if(changeTemp)
		var/itemTemp = 20
		if(istype(I, /obj/item/heatable))
			var/obj/item/heatable/H = I
			itemTemp = H.temperature
		temperature = (temperature*(itemNum) + itemTemp)/(1+itemNum)

	//-- Item Specific Functions --//
	if(istype(I, /obj/item/heatable/ingot))
		var/obj/item/heatable/ingot/ingot = I
		//-- Set "minmelt" --//
		if(!minMelt || ingot.meltingpoint < meltPoints[minMelt])
			minMelt = "[I.type]"
		//-- Add Melting Point to List --//
		if(!meltPoints["[I.type]"])
			var/i = meltPoints.len+1
			while(i > 1 && ingot.meltingpoint < meltPoints[meltPoints[i-1]])
				i--
			meltPoints.Insert(i, "[I.type]")
			meltPoints["[I.type]"] = ingot.meltingpoint
		//-- Update Melt Progress --//
		if(meltProgress["[I.type]"])
			if(changeTemp)
				meltProgress["[I.type]"] = (meltProgress["[I.type]"]*contained["[I.type]"])/(1+contained["[I.type]"])
		else
			if(!changeTemp && temperature >= meltPoints["[I.type]"])
				meltProgress["[I.type]"] = 1
			else
				meltProgress["[I.type]"] = 0
		//-- Use (1) Ingot --//
		ingot.consume(1)
	else if(istype(I, /obj/item/stack))
		var/obj/item/stack/stack = I
		stack.use(1)
	else
		qdel(I)



////////////////////////////////
/* Examine (Contents Display) */
////////////////////////////////

/obj/item/heatable/crucible/examine(mob/user)
	..()
	to_chat(user, "\The [src] contains ([itemNum]/[itemLimit]):")
	if(itemNum <= 0)
		to_chat(user, "nothing")
		return
	for(var/C in contained)
		var/obj/item/I = text2path(C)
		to_chat(user, "x[contained[C]] ([initial(I.name)][meltProgress.Find(C) ? " [round(meltProgress[C]*100,1)]% Melted" : ""])")



/////////////
/* Process */
/////////////

/obj/item/heatable/crucible/process()
	..()
	meltSolids()
	processReactions()



//////////////////////
/* Update "minMelt" */
//////////////////////

/obj/item/heatable/crucible/proc/resetMinMelt()
	minMelt = null
	var/highestMeltMetal = null
	var/lowestMeltUnmeltedMetal = null

	// Find the metal that is not fully melted and has the lowest melting point
	for(var/path in meltPoints)
		if(!highestMeltMetal || meltPoints[path] > meltPoints[highestMeltMetal])
			highestMeltMetal = path
		if(meltProgress[path] < 1 && (!lowestMeltUnmeltedMetal || meltPoints[path] < meltPoints[lowestMeltUnmeltedMetal]))
			minMelt = path
	if(minMelt)
		return TRUE

	// If all metals are melted, return the highest melting point metal
	minMelt = highestMeltMetal
	return TRUE



/////////////////
/* Melt Solids */
/////////////////

/obj/item/heatable/crucible/proc/meltSolids()
	if(!minMelt)
		return

	var/repeat = FALSE
	var/MP = meltPoints[minMelt]
	if(temperature != MP)
		var/change = ((temperature - MP) / latentHeat) / contained[minMelt]
		var/newValue = meltProgress[minMelt] + change

		if(newValue < 0 || newValue > 1)
			newValue = clamp(newValue, 0, 1)
			change = newValue - meltProgress[minMelt]
			if(newValue != meltProgress[minMelt])
				repeat = TRUE

		temperature -= change * latentHeat * contained[minMelt]
		meltProgress[minMelt] = newValue

	if(repeat)
		meltSolids()
		resetMinMelt()



//////////////////////////////
/* Update "valid_reactions" */
//////////////////////////////

/obj/item/heatable/crucible/proc/updateValidReactions()
	valid_reactions = list()

	//General Check
	for(var/mat in contained)
		if(GLOB.crucible_reactions_list.Find(mat))
			valid_reactions |= GLOB.crucible_reactions_list[mat]

	//Narrowing Down
	for(var/datum/crucible_reaction/C in valid_reactions)
		for(var/path in C.reqpaths)
			if(!contained[path])
				valid_reactions.Remove(C)
				break



/////////////////////////////
/* Perform Valid Reactions */
/////////////////////////////

/obj/item/heatable/crucible/proc/processReactions()
	for(var/datum/crucible_reaction/C in valid_reactions)
		//-- Temperature Check --//
		if((temperature < C.reactiontemp && C.exothermic) || (temperature > C.reactiontemp && !C.exothermic))
			continue

		//-- Reagent Check --//
		var/list/newMatVals = list()
		var/reqsNotMet = FALSE
		for(var/path in C.reqpaths)
			if(contained[path] >= C.reqpaths[path])
				newMatVals[path] = contained[path] - C.reqpaths[path]
			else
				reqsNotMet = TRUE
				break
		if(reqsNotMet)
			continue

		//-- Reagent Removal --//
		for(var/path in newMatVals)
			if(ispath(text2path(path), /obj/item/heatable/ingot))
				useMetal(contained[path] - newMatVals[path], path)
			else if(newMatVals[path] <= 0)
				itemNum -= contained[path] - newMatVals[path]
				contained.Remove(path)
			else
				itemNum -= contained[path] - newMatVals[path]
				contained[path] = newMatVals[path]

		//-- Product Creation --//
		for(var/path in C.respaths)
			var/amount = C.respaths[path]
			while(amount > 0)
				var/obj/item/I = new path()
				addItem(I, FALSE)
				amount--



///////////////////////////////////
/* Crucible Reactions Initialize */
///////////////////////////////////

/datum/crucible_reaction/
	var/list/reqpaths
	var/list/respaths
	var/reactiontemp = 25
	var/exothermic = TRUE

GLOBAL_LIST(crucible_reactions_list)
GLOBAL_LIST(crucible_reactants)

/proc/initialize_crucible_reactions()
	var/paths = typesof(/datum/crucible_reaction) - /datum/crucible_reaction
	GLOB.crucible_reactions_list = list()
	GLOB.crucible_reactants = list()

	for(var/path in paths)
		var/datum/crucible_reaction/C = new path()

		//-- crucible_reactants --//
		for(var/R in C.reqpaths)
			if(!GLOB.crucible_reactants[R])
				GLOB.crucible_reactants[R] = 1

		//-- crucible_reactions_list --//
		var/reqpath = C.reqpaths[1]
		if(!GLOB.crucible_reactions_list[reqpath])
			GLOB.crucible_reactions_list[reqpath] = list()
		GLOB.crucible_reactions_list[reqpath].Add(C)
