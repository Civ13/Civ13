// Markers the zombie city generator leaves in the world. They are plain
// invisible effects that describe the layout to other systems; the generator
// (generator.dm) is the only thing that places them, and they never save.
// The horde (horde.dm) takes its blocks straight from the layout pass and the
// loot tables (loot.dm) are rolled at the loot markers when the city is made.
/obj/effect/zombie_city
	icon = null
	anchored = TRUE
	invisibility = 101
	var/layout_id = 0

/obj/effect/zombie_city/New()
	..()
	should_save = FALSE

// One per loot spot. table and tier are the loot.dm contract: residential,
// grocery, pharmacy, hardware, police, garage, military or medical, tier 1-3.
/obj/effect/zombie_city/loot
	name = "zombie city loot marker"
	var/table = "residential"
	var/tier = 1
	var/building_id = 0

// Road-gate arrival points on the ring road, one per edge slot (side).
/obj/effect/zombie_city/entry
	name = "zombie city insertion point"
	var/side = "north"
	var/ordinal = 1

// Evacuation points on the ring road; one of them sits at the checkpoint.
/obj/effect/zombie_city/exit
	name = "zombie city evacuation point"
	var/side = "north"
	var/ordinal = 1
	var/checkpoint = FALSE
