/*
 * Pill Bottles
 */
/obj/item/weapon/storage/pill_bottle
	name = "pill bottle"
	desc = "It's an airtight container for storing medication."
	icon_state = "pill_canister"
	icon = 'icons/obj/chemical.dmi'
	item_state = "contsolid"
	w_class = 2.0
	can_hold = list(/obj/item/weapon/reagent_containers/pill,/obj/item/weapon/dice,/obj/item/weapon/paper)
	allow_quick_gather = TRUE
	use_to_pickup = TRUE
	use_sound = null
	max_storage_space = 20

/obj/item/weapon/storage/pill_bottle/attackby(var/obj/item/I, var/mob/user)
	if (istype(I, /obj/item/weapon/pen))
		var/label = sanitize(input(user, "What do you want to label the pill bottle as?") as text, 50)
		name = label
		return TRUE
	return ..(I, user)

/obj/item/weapon/storage/pill_bottle/antitox
	name = "bottle of Dylovene pills"
	desc = "Contains pills used to counter toxins."

	New()
		..()
		new /obj/item/weapon/reagent_containers/pill/antitox( src )
		new /obj/item/weapon/reagent_containers/pill/antitox( src )
		new /obj/item/weapon/reagent_containers/pill/antitox( src )
		new /obj/item/weapon/reagent_containers/pill/antitox( src )
		new /obj/item/weapon/reagent_containers/pill/antitox( src )
		new /obj/item/weapon/reagent_containers/pill/antitox( src )
		new /obj/item/weapon/reagent_containers/pill/antitox( src )

/obj/item/weapon/storage/pill_bottle/bicaridine
	name = "bottle of Bicaridine pills"
	desc = "Contains pills used to stabilize the severely injured."

/obj/item/weapon/storage/pill_bottle/bicaridine/New()
    ..()
    new /obj/item/weapon/reagent_containers/pill/bicaridine(src)
    new /obj/item/weapon/reagent_containers/pill/bicaridine(src)
    new /obj/item/weapon/reagent_containers/pill/bicaridine(src)
    new /obj/item/weapon/reagent_containers/pill/bicaridine(src)
    new /obj/item/weapon/reagent_containers/pill/bicaridine(src)
    new /obj/item/weapon/reagent_containers/pill/bicaridine(src)
    new /obj/item/weapon/reagent_containers/pill/bicaridine(src)

/obj/item/weapon/storage/pill_bottle/dexalin_plus
	name = "bottle of Dexalin Plus pills"
	desc = "Contains pills used to treat extreme cases of oxygen deprivation."

/obj/item/weapon/storage/pill_bottle/dexalin_plus/New()
    ..()
    new /obj/item/weapon/reagent_containers/pill/dexalin_plus(src)
    new /obj/item/weapon/reagent_containers/pill/dexalin_plus(src)
    new /obj/item/weapon/reagent_containers/pill/dexalin_plus(src)
    new /obj/item/weapon/reagent_containers/pill/dexalin_plus(src)
    new /obj/item/weapon/reagent_containers/pill/dexalin_plus(src)
    new /obj/item/weapon/reagent_containers/pill/dexalin_plus(src)
    new /obj/item/weapon/reagent_containers/pill/dexalin_plus(src)

/obj/item/weapon/storage/pill_bottle/dermaline
	name = "bottle of Dermaline pills"
	desc = "Contains pills used to treat burn wounds."

/obj/item/weapon/storage/pill_bottle/dermaline/New()
    ..()
    new /obj/item/weapon/reagent_containers/pill/dermaline(src)
    new /obj/item/weapon/reagent_containers/pill/dermaline(src)
    new /obj/item/weapon/reagent_containers/pill/dermaline(src)
    new /obj/item/weapon/reagent_containers/pill/dermaline(src)
    new /obj/item/weapon/reagent_containers/pill/dermaline(src)
    new /obj/item/weapon/reagent_containers/pill/dermaline(src)
    new /obj/item/weapon/reagent_containers/pill/dermaline(src)

/obj/item/weapon/storage/pill_bottle/dylovene
	name = "bottle of Dylovene pills"
	desc = "Contains pills used to treat toxic substances in the blood."

/obj/item/weapon/storage/pill_bottle/dylovene/New()
    ..()
    new /obj/item/weapon/reagent_containers/pill/dylovene(src)
    new /obj/item/weapon/reagent_containers/pill/dylovene(src)
    new /obj/item/weapon/reagent_containers/pill/dylovene(src)
    new /obj/item/weapon/reagent_containers/pill/dylovene(src)
    new /obj/item/weapon/reagent_containers/pill/dylovene(src)
    new /obj/item/weapon/reagent_containers/pill/dylovene(src)
    new /obj/item/weapon/reagent_containers/pill/dylovene(src)

/obj/item/weapon/storage/pill_bottle/inaprovaline
	name = "bottle of Inaprovaline pills"
	desc = "Contains pills used to stabilize patients."

	New()
		..()
		new /obj/item/weapon/reagent_containers/pill/inaprovaline( src )
		new /obj/item/weapon/reagent_containers/pill/inaprovaline( src )
		new /obj/item/weapon/reagent_containers/pill/inaprovaline( src )
		new /obj/item/weapon/reagent_containers/pill/inaprovaline( src )
		new /obj/item/weapon/reagent_containers/pill/inaprovaline( src )
		new /obj/item/weapon/reagent_containers/pill/inaprovaline( src )
		new /obj/item/weapon/reagent_containers/pill/inaprovaline( src )

/obj/item/weapon/storage/pill_bottle/kelotane
	name = "bottle of kelotane pills"
	desc = "Contains pills used to treat burns."

	New()
		..()
		new /obj/item/weapon/reagent_containers/pill/kelotane( src )
		new /obj/item/weapon/reagent_containers/pill/kelotane( src )
		new /obj/item/weapon/reagent_containers/pill/kelotane( src )
		new /obj/item/weapon/reagent_containers/pill/kelotane( src )
		new /obj/item/weapon/reagent_containers/pill/kelotane( src )
		new /obj/item/weapon/reagent_containers/pill/kelotane( src )
		new /obj/item/weapon/reagent_containers/pill/kelotane( src )

/obj/item/weapon/storage/pill_bottle/penicillin
	name = "bottle of penicillin pills"
	desc = "A theta-lactam antibiotic. Effective against many diseases likely to be encountered in space."

/obj/item/weapon/storage/pill_bottle/penicillin/New()
    ..()
    new /obj/item/weapon/reagent_containers/pill/penicillin(src)
    new /obj/item/weapon/reagent_containers/pill/penicillin(src)
    new /obj/item/weapon/reagent_containers/pill/penicillin(src)
    new /obj/item/weapon/reagent_containers/pill/penicillin(src)
    new /obj/item/weapon/reagent_containers/pill/penicillin(src)
    new /obj/item/weapon/reagent_containers/pill/penicillin(src)
    new /obj/item/weapon/reagent_containers/pill/penicillin(src)

/obj/item/weapon/storage/pill_bottle/tramadol
	name = "bottle of Tramadol pills"
	desc = "Contains pills used to relieve pain."

	New()
		..()
		new /obj/item/weapon/reagent_containers/pill/tramadol( src )
		new /obj/item/weapon/reagent_containers/pill/tramadol( src )
		new /obj/item/weapon/reagent_containers/pill/tramadol( src )
		new /obj/item/weapon/reagent_containers/pill/tramadol( src )
		new /obj/item/weapon/reagent_containers/pill/tramadol( src )
		new /obj/item/weapon/reagent_containers/pill/tramadol( src )
		new /obj/item/weapon/reagent_containers/pill/tramadol( src )

/obj/item/weapon/storage/pill_bottle/citalopram
	name = "bottle of Citalopram pills"
	desc = "Contains pills used to stabilize a patient's mood."

	New()
		..()
		new /obj/item/weapon/reagent_containers/pill/citalopram( src )
		new /obj/item/weapon/reagent_containers/pill/citalopram( src )
		new /obj/item/weapon/reagent_containers/pill/citalopram( src )
		new /obj/item/weapon/reagent_containers/pill/citalopram( src )
		new /obj/item/weapon/reagent_containers/pill/citalopram( src )
		new /obj/item/weapon/reagent_containers/pill/citalopram( src )
		new /obj/item/weapon/reagent_containers/pill/citalopram( src )
