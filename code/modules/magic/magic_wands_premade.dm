
// ============================================================
//  PRE-MADE WAND VARIANTS
//  Ready-to-spawn named wand combinations. Add to loot tables,
//  shop inventories, or wizard spawns as desired.
// ============================================================

// Intermediate type to prevent component-based name/desc overrides for presets
/obj/item/weapon/material/magic/wand/crafted/premade
	parent_type = /obj/item/weapon/material/magic/wand/crafted
	update_name_and_desc()
		return

// ----- The Regulation Wand -----
// Pine + no core + Standard length: solid all-rounder with panic escape
/obj/item/weapon/material/magic/wand/crafted/standard
	parent_type = /obj/item/weapon/material/magic/wand/crafted/premade
	name = "standard wizard's wand"
	desc = "A standard school-issue wand. Smells of pine resin and floor wax. Reliable, if uninspiring."
	icon_state  = "wand_pinewood_long"
	wand_wood   = WAND_WOOD_PINE
	wand_core   = WAND_CORE_NONE
	wand_length = WAND_LENGTH_STANDARD

// ----- The Sniper -----
// Fibreglass + Copper Wire + Overcompensator: blazing fast, long-range, cheap — but violent on overcast
/obj/item/weapon/material/magic/wand/crafted/sniper
	parent_type = /obj/item/weapon/material/magic/wand/crafted/premade
	name = "The Sniper"
	desc = "A ridiculously long, bright green fibreglass rod wrapped in stolen copper wire. It acts like a magical sniper rifle, but one wrong move and you'll electrocute yourself."
	icon_state  = "wand_fibreglass_longest"
	wand_wood   = WAND_WOOD_FIBREGLASS
	wand_core   = WAND_CORE_COPPER
	wand_length = WAND_LENGTH_OVERCOMP

// ----- The Mugger -----
// Snooker Cue + Badger Hair + Stubby: fast-draw, awful cast speed, exceptional bludgeoning
/obj/item/weapon/material/magic/wand/crafted/mugger
	parent_type = /obj/item/weapon/material/magic/wand/crafted/premade
	name = "The Mugger"
	desc = "A sawed-off chunk of a pub snooker cue stuffed with angry badger hair. It takes ages to cast a spell, but it fits in your boot and is perfect for caving someone's head in."
	icon_state  = "wand_snooker_short"
	wand_wood   = WAND_WOOD_SNOOKER
	wand_core   = WAND_CORE_BADGER
	wand_length = WAND_LENGTH_STUBBY

// ----- The Ghost -----
// Balsa + Fox Fur + Stubby: pocket-sized, invisible lightning casts — but snaps if you sneeze on it
/obj/item/weapon/material/magic/wand/crafted/ghost
	parent_type = /obj/item/weapon/material/magic/wand/crafted/premade
	name = "The Ghost"
	desc = "A terrifyingly fragile balsa wood splinter wrapped in smelly fox fur. It casts completely invisible spells, assuming it doesn't snap in your hand first."
	icon_state  = "wand_balsa_short"
	wand_wood   = WAND_WOOD_BALSA
	wand_core   = WAND_CORE_FOX
	wand_length = WAND_LENGTH_STUBBY

// ----- The Gambler -----
// MDF + Pocket Lint + Telescopic: chaotic, cheap, and likely to kill you in the rain
/obj/item/weapon/material/magic/wand/crafted/gambler
	parent_type = /obj/item/weapon/material/magic/wand/crafted/premade
	name = "The Gambler"
	desc = "A modified TV aerial glued to a cheap MDF handle, powered by lint. You have no idea what a spell will cost, and if it rains, it turns into soggy, useless cardboard."
	icon_state  = "wand_mdf_long"
	wand_wood   = WAND_WOOD_MDF
	wand_core   = WAND_CORE_LINT
	wand_length = WAND_LENGTH_TELESCOPIC

// ----- The Swamp Thing -----
// Bog Oak + Asbestos Fibre + Overcompensator: long-range elemental supremacy at personal cost
/obj/item/weapon/material/magic/wand/crafted/swamp_thing
	parent_type = /obj/item/weapon/material/magic/wand/crafted/premade
	name = "The Swamp Thing"
	desc = "A massive, rotting branch of bog oak packed with highly illegal asbestos. It smells like dead fish, but it lets you lob massive fireballs from a mile away... while slowly poisoning you."
	icon_state  = "wand_driftwood_longest"
	wand_wood   = WAND_WOOD_BOGOAK
	wand_core   = WAND_CORE_ASBESTOS
	wand_length = WAND_LENGTH_OVERCOMP

// ----- The Chaos Stick -----
// MDF + Asbestos Fibre + Stubby: fire-immune, toxin-dripping, swells in rain — pocket chaos
/obj/item/weapon/material/magic/wand/crafted/chaos_stick
	parent_type = /obj/item/weapon/material/magic/wand/crafted/premade
	name = "The Chaos Stick"
	desc = "A stubby block of cheap fiberboard stuffed with toxic insulation. It fits in your pocket and makes you entirely fireproof, but it acts as a localized health hazard."
	icon_state  = "wand_mdf_short"
	wand_wood   = WAND_WOOD_MDF
	wand_core   = WAND_CORE_ASBESTOS
	wand_length = WAND_LENGTH_STUBBY

// ----- The Coward's Out -----
// Fibreglass + Pigeon Feather + Standard: fastest movement spells in the game, at the cost of pain
/obj/item/weapon/material/magic/wand/crafted/cowards_out
	parent_type = /obj/item/weapon/material/magic/wand/crafted/premade
	name = "The Coward's Out"
	desc = "A whippy fibreglass rod powered by a nervous pigeon feather. Perfect for panic-teleporting away from trouble, though the overcast backlash might slice your arm open."
	icon_state  = "wand_fibreglass_long"
	wand_wood   = WAND_WOOD_FIBREGLASS
	wand_core   = WAND_CORE_PIGEON
	wand_length = WAND_LENGTH_STANDARD

// ----- Headmaster Tumbledoor's Wand -----
// The legendary bootleg Elder Wand.
/obj/item/weapon/material/magic/wand/crafted/elderly_wand
	parent_type = /obj/item/weapon/material/magic/wand/crafted/premade
	name = "The Elderly Wand"
	desc = "An incredibly old, knobby walking stick. Legend says Tumbledoor won it from Death himself in a high-stakes game of Go Fish."
	icon_state = "elderly_wand"
	wand_wood   = WAND_WOOD_BOGOAK      // Ancient and slightly damp
	wand_core   = WAND_CORE_BADGER      // Extremely powerful combat casts
	wand_length = WAND_LENGTH_OVERCOMP  // Huge range

// ----- Lord Moldywart's Wand -----
// The villain's weapon. Toxic, fast, and silent.
/obj/item/weapon/material/magic/wand/crafted/the_pale_stick
	parent_type = /obj/item/weapon/material/magic/wand/crafted/premade
	name = "The Pale Stick"
	desc = "A chillingly smooth wand carved from shrieking shrub wood. It hums with dark magic and smells faintly of hairspray."
	icon_state = "moldy_wand"
	wand_wood   = WAND_WOOD_SHRUB  // Lethally fast cast speed
	wand_core   = WAND_CORE_FOX         // Completely silent/invisible casts (terrifying for Deadum!)
	wand_length = WAND_LENGTH_STANDARD

// ----- The Moldy Men Standard Issue -----
// Pine + Pigeon Feather + Standard: Unreliable, panic-prone, splinters easily.
/obj/item/weapon/material/magic/wand/crafted/henchman_twig
	parent_type = /obj/item/weapon/material/magic/wand/crafted/premade
	name = "The Henchman's Twig"
	desc = "A mass-produced, poorly sanded pine stick issued to all Moldy Men. The pigeon feather core makes it highly prone to misfiring whenever the user gets scared."
	icon_state = "wand4"
	wand_wood   = WAND_WOOD_PINE
	wand_core   = WAND_CORE_PIGEON
	wand_length = WAND_LENGTH_STANDARD
