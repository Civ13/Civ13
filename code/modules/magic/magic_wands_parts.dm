// ============================================================
// WAND COMPONENT SYSTEM
// magic_wands_parts.dm
//
// Modular wand assembly: Wood + Core + Length = custom wand.
// Each combination produces a unique playstyle, trading off
// cast speed, juice cost, melee capability, and side-effects.
//
// See /obj/item/weapon/material/magic/wand/crafted for the
// assembled type. Pre-made named variants are at the bottom.
// ============================================================


// ============================================================
//  COMPONENT CONSTANTS
// ============================================================

// -- Wood types (chassis) --
#define WAND_WOOD_PINE        "pine"        // Baseline. Mild splinter on overcast.
#define WAND_WOOD_MDF         "mdf"         // Cheap juice; dissolves when wet.
#define WAND_WOOD_BALSA       "balsa"       // Fast but fragile; snaps on melee.
#define WAND_WOOD_SNOOKER     "snooker"     // Slow caster; excellent bludgeon.
#define WAND_WOOD_FIBREGLASS  "fibreglass"  // Whippy fast; lashes you on overcast.
#define WAND_WOOD_DRIFTWOOD   "driftwood"   // Driftwood chassis; elemental discount; emits stink.
#define WAND_WOOD_CHIP        "stale_chip"  // Stale Chip / French Fry.
#define WAND_WOOD_SHRUB       "shrub_root"  // Shrieking Shrub Root.
#define WAND_WOOD_TRUNCHEON   "truncheon"   // C.A.P. Truncheon.

// -- Core types (engine) --
#define WAND_CORE_NONE     "none"      // No bonuses or penalties.
#define WAND_CORE_BADGER   "badger"    // Combat boosted; defensive penalised.
#define WAND_CORE_PIGEON   "pigeon"    // Movement near-instant; panic auto-blink.
#define WAND_CORE_COPPER   "copper"    // -25% all costs; lethal overcast.
#define WAND_CORE_LINT     "lint"      // Wildly random juice cost per cast.
#define WAND_CORE_ASBESTOS "asbestos"  // Fire immunity; passive toxin damage.
#define WAND_CORE_FOX      "fox"       // Silent casts; +2 s cast delay.
#define WAND_CORE_GUM        "chewing_gum" // Used Chewing Gum.
#define WAND_CORE_TAPE       "cassette_tape" // Tangled Cassette Tape.
#define WAND_CORE_WOOL       "sheep_wool"  // Damp Sheep Wool.
#define WAND_CORE_RAT        "rat_tail"    // Feral Rat Tail.
#define WAND_CORE_SPARKPLUG  "spark_plug"  // Rusted Spark Plug.
#define WAND_CORE_GNAT       "gnat_wing"   // Golden Gnat Wing.
#define WAND_CORE_GLOOM      "gloom_thread" // Gloom-Weave Thread.

// -- Length types (form factor) --
#define WAND_LENGTH_STUBBY      "stubby"       // Tiny, fast-draw, -2 tile range.
#define WAND_LENGTH_STANDARD    "standard"     // Balanced baseline.
#define WAND_LENGTH_OVERCOMP    "overcomp"     // Long, +3 range, -15% proj cost.
#define WAND_LENGTH_TELESCOPIC  "telescopic"   // Alt-click to collapse/extend; 10% collapse per cast.

// -- Spell categories (for targeted bonuses/penalties) --
#define WAND_CAT_COMBAT    "combat"    // Pushum, Sliceum, Explodus, Zappus, Burnus, Painum, Deadum
#define WAND_CAT_DEFENSIVE "defensive" // Blockum, Wallus, Fixae
#define WAND_CAT_MOVEMENT  "movement"  // Floatus, Blinkae


/obj/structure/magic/wand_assembly_bench
	name = "wand assembly bench"
	desc = "A sturdy workbench used to assemble magical wand parts into a functioning wand."
	icon = 'icons/obj/structures.dmi'
	icon_state = "gunbench1"
	density = TRUE
	anchored = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE
	var/selected_wand_length = WAND_LENGTH_STANDARD

	attack_hand(mob/user as mob)
		if (!user || user.lying)
			return
		do_html(user)
		return

	attackby(obj/item/W as obj, mob/user as mob)
		if (!istype(W, /obj/item/wand_part))
			to_chat(user, "<span class='notice'>This bench only assembles wand parts.</span>")
			return

		user.drop_item()
		W.loc = src
		to_chat(user, "<span class='notice'>You place [W] on the wand assembly bench.</span>")
		do_html(user)
		return

	Topic(href, href_list, hsrc)
		var/mob/user = usr
		if (!user || user.lying)
			return

		if (href_list["eject_wood"])
			var/obj/item/wand_part/wood_part = get_bench_wood_part()
			if (wood_part)
				if (!user.get_active_hand() && user.put_in_active_hand(wood_part))
					to_chat(user, "<span class='notice'>You take [wood_part] from the bench.</span>")
				else
					wood_part.loc = get_turf(user)
					to_chat(user, "<span class='notice'>You remove [wood_part] from the bench.</span>")
			else
				to_chat(user, "<span class='notice'>There is no wood part on the bench.</span>")
			do_html(user)
			return

		if (href_list["eject_core"])
			var/obj/item/wand_part/core_part = get_bench_core_part()
			if (core_part)
				if (!user.get_active_hand() && user.put_in_active_hand(core_part))
					to_chat(user, "<span class='notice'>You take [core_part] from the bench.</span>")
				else
					core_part.loc = get_turf(user)
					to_chat(user, "<span class='notice'>You remove [core_part] from the bench.</span>")
			else
				to_chat(user, "<span class='notice'>There is no core part on the bench.</span>")
			do_html(user)
			return

		if (href_list["assemble"])
			var/obj/item/wand_part/wood_part = get_bench_wood_part()
			var/obj/item/wand_part/core_part = get_bench_core_part()
			if (wood_part && core_part)
				var/obj/item/weapon/material/magic/wand/crafted/new_wand = new /obj/item/weapon/material/magic/wand/crafted(get_turf(src))
				if (istype(wood_part, /obj/item/wand_part/pine_wood))
					new_wand.wand_wood = WAND_WOOD_PINE
				else if (istype(wood_part, /obj/item/wand_part/mdf_board))
					new_wand.wand_wood = WAND_WOOD_MDF
				else if (istype(wood_part, /obj/item/wand_part/balsa_wood))
					new_wand.wand_wood = WAND_WOOD_BALSA
				else if (istype(wood_part, /obj/item/wand_part/snooker_cue))
					new_wand.wand_wood = WAND_WOOD_SNOOKER
				else if (istype(wood_part, /obj/item/wand_part/fibreglass))
					new_wand.wand_wood = WAND_WOOD_FIBREGLASS
				else if (istype(wood_part, /obj/item/wand_part/driftwood))
					new_wand.wand_wood = WAND_WOOD_DRIFTWOOD
				else if (istype(wood_part, /obj/item/wand_part/stale_chip))
					new_wand.wand_wood = WAND_WOOD_CHIP
				else if (istype(wood_part, /obj/item/wand_part/shrub_root))
					new_wand.wand_wood = WAND_WOOD_SHRUB
				else if (istype(wood_part, /obj/item/wand_part/cap_truncheon))
					new_wand.wand_wood = WAND_WOOD_TRUNCHEON
				else
					new_wand.wand_wood = WAND_WOOD_PINE
				if (istype(core_part, /obj/item/wand_part/badger_hair))
					new_wand.wand_core = WAND_CORE_BADGER
				else if (istype(core_part, /obj/item/wand_part/pigeon_feather))
					new_wand.wand_core = WAND_CORE_PIGEON
				else if (istype(core_part, /obj/item/wand_part/copper_wire))
					new_wand.wand_core = WAND_CORE_COPPER
				else if (istype(core_part, /obj/item/wand_part/pocket_lint))
					new_wand.wand_core = WAND_CORE_LINT
				else if (istype(core_part, /obj/item/wand_part/asbestos))
					new_wand.wand_core = WAND_CORE_ASBESTOS
				else if (istype(core_part, /obj/item/wand_part/fox_fur))
					new_wand.wand_core = WAND_CORE_FOX
				else if (istype(core_part, /obj/item/wand_part/chewing_gum))
					new_wand.wand_core = WAND_CORE_GUM
				else if (istype(core_part, /obj/item/wand_part/cassette_tape))
					new_wand.wand_core = WAND_CORE_TAPE
				else if (istype(core_part, /obj/item/wand_part/sheep_wool))
					new_wand.wand_core = WAND_CORE_WOOL
				else if (istype(core_part, /obj/item/wand_part/rat_tail))
					new_wand.wand_core = WAND_CORE_RAT
				else if (istype(core_part, /obj/item/wand_part/spark_plug))
					new_wand.wand_core = WAND_CORE_SPARKPLUG
				else if (istype(core_part, /obj/item/wand_part/gnat_wing))
					new_wand.wand_core = WAND_CORE_GNAT
				else if (istype(core_part, /obj/item/wand_part/gloom_thread))
					new_wand.wand_core = WAND_CORE_GLOOM
				else
					new_wand.wand_core = WAND_CORE_NONE
				new_wand.wand_length = selected_wand_length
				new_wand.apply_wood_stats()
				new_wand.apply_core_stats()
				new_wand.apply_length_stats()
				new_wand.update_name_and_desc()

				to_chat(user, "<span class='notice'>The wand assembly bench finishes assembling a [new_wand.name].</span>")
				playsound(get_turf(src), 'sound/effects/woodfile.ogg', 75, TRUE)
				qdel(wood_part)
				qdel(core_part)
				if (user && ishuman(user) && user.client && map && istype(map, /obj/map_metadata/wizard_boy))
					var/obj/map_metadata/wizard_boy/WB = map
					if (WB.check_level(user.client.ckey) == "0")
						WB.change_level(user.client.ckey, "1")
						WB.save_wand(user.client.ckey,"[new_wand.wand_wood],[new_wand.wand_core],[new_wand.wand_length]")
						to_chat(world, "<font size=3 class='wizard'><b>[user.real_name]</b> ([user.key]) has progressed to qualification level 1 (<b>U.N.G.A.</b>) by assembling a wand!</font>")
			else
				to_chat(user, "<span class='notice'>The bench needs one wand chassis and one wand core to assemble a wand.</span>")
			do_html(user)
			return

		if (href_list["length_stubby"])
			selected_wand_length = WAND_LENGTH_STUBBY
			do_html(user)
			return

		if (href_list["length_standard"])
			selected_wand_length = WAND_LENGTH_STANDARD
			do_html(user)
			return

		if (href_list["length_overcomp"])
			selected_wand_length = WAND_LENGTH_OVERCOMP
			do_html(user)
			return

		if (href_list["length_telescopic"])
			selected_wand_length = WAND_LENGTH_TELESCOPIC
			do_html(user)
			return

		if (href_list["refresh"])
			do_html(user)
			return

		return

	proc/get_bench_wood_part()
		for (var/obj/item/O in contents)
			if (istype(O, /obj/item/wand_part/pine_wood) || istype(O, /obj/item/wand_part/mdf_board) || istype(O, /obj/item/wand_part/balsa_wood) || istype(O, /obj/item/wand_part/snooker_cue) || istype(O, /obj/item/wand_part/fibreglass) || istype(O, /obj/item/wand_part/driftwood) || istype(O, /obj/item/wand_part/stale_chip) || istype(O, /obj/item/wand_part/shrub_root) || istype(O, /obj/item/wand_part/cap_truncheon))
				return O
		return null

	proc/get_bench_core_part()
		for (var/obj/item/O in contents)
			if (istype(O, /obj/item/wand_part/badger_hair) || istype(O, /obj/item/wand_part/pigeon_feather) || istype(O, /obj/item/wand_part/copper_wire) || istype(O, /obj/item/wand_part/pocket_lint) || istype(O, /obj/item/wand_part/asbestos) || istype(O, /obj/item/wand_part/fox_fur) || istype(O, /obj/item/wand_part/chewing_gum) || istype(O, /obj/item/wand_part/cassette_tape) || istype(O, /obj/item/wand_part/sheep_wool) || istype(O, /obj/item/wand_part/rat_tail) || istype(O, /obj/item/wand_part/spark_plug) || istype(O, /obj/item/wand_part/gnat_wing) || istype(O, /obj/item/wand_part/gloom_thread))
				return O
		return null

	proc/get_wood_effects(var/obj/item/wand_part/wood_part)
		if (!wood_part)
			return ""
		if (istype(wood_part, /obj/item/wand_part/pine_wood)) return "Baseline balance; 5% splinter chance on overcast."
		if (istype(wood_part, /obj/item/wand_part/mdf_board)) return "-10% juice cost. Swells and misfires when wet."
		if (istype(wood_part, /obj/item/wand_part/balsa_wood)) return "-40% cast time, +20% juice cost. Snaps in melee."
		if (istype(wood_part, /obj/item/wand_part/snooker_cue)) return "+20% cast time. Lethal melee bludgeoning power."
		if (istype(wood_part, /obj/item/wand_part/fibreglass)) return "-25% cast time. Lashes caster on overcast."
		if (istype(wood_part, /obj/item/wand_part/driftwood)) return "-20% elemental juice cost. Emits a passive stink cloud."
		if (istype(wood_part, /obj/item/wand_part/stale_chip)) return "+30% healing speed. May crumble on non-healing spells."
		if (istype(wood_part, /obj/item/wand_part/shrub_root)) return "-20% cast time. Stun-shriek nearby mobs on every cast."
		if (istype(wood_part, /obj/item/wand_part/cap_truncheon)) return "+20% cast time. High melee force and impossible to dislodge."
		return "Unknown wood effects."

	proc/get_core_effects(var/obj/item/wand_part/core_part)
		if (!core_part)
			return ""
		if (istype(core_part, /obj/item/wand_part/badger_hair)) return "+20% combat spell speed; +50% defensive juice cost."
		if (istype(core_part, /obj/item/wand_part/pigeon_feather)) return "Near-instant movement spells. Critical HP panic-blink."
		if (istype(core_part, /obj/item/wand_part/copper_wire)) return "-25% all juice costs. Lethal electrical backlash on overcast."
		if (istype(core_part, /obj/item/wand_part/pocket_lint)) return "Chaos energy: Spells cost 0x or 2x juice at random."
		if (istype(core_part, /obj/item/wand_part/asbestos)) return "Fire immunity while held. Slow passive toxin damage."
		if (istype(core_part, /obj/item/wand_part/fox_fur)) return "Silent spells with no visual cues. Adds +2s cast delay."
		if (istype(core_part, /obj/item/wand_part/chewing_gum)) return "Extremely sticky; very difficult to drop or unequip."
		if (istype(core_part, /obj/item/wand_part/cassette_tape)) return "15% chance to echo cast. 5% chance to jumble spell choice."
		if (istype(core_part, /obj/item/wand_part/sheep_wool)) return "+30% juice regen. Scalding steam on fire/explosion spells."
		if (istype(core_part, /obj/item/wand_part/rat_tail)) return "Projectiles deal backstab damage. Misfires when user is injured."
		if (istype(core_part, /obj/item/wand_part/spark_plug)) return "All spells cost 30% less juice. Shatters hand bones on overcast."
		if (istype(core_part, /obj/item/wand_part/gnat_wing)) return "-50% cast time and 0% misfire chance."
		if (istype(core_part, /obj/item/wand_part/gloom_thread)) return "-50% juice cost. Projectiles slow targets on hit."
		return "Unknown core effects."

	proc/do_html(var/mob/m)
		if (!m || m.lying)
			return

		var/obj/item/wand_part/wood_part = get_bench_wood_part()
		var/obj/item/wand_part/core_part = get_bench_core_part()

		var/wood_name = wood_part ? wood_part.name : "<span style='color:#888'>None</span>"
		var/core_name = core_part ? core_part.name : "<span style='color:#888'>None</span>"

		var/wood_effects = wood_part ? "<br><small><i>[get_wood_effects(wood_part)]</i></small>" : ""
		var/core_effects = core_part ? "<br><small><i>[get_core_effects(core_part)]</i></small>" : ""

		var/wood_action = wood_part ? " <a href='?src=\ref[src];eject_wood=1'>Eject</a>" : ""
		var/core_action = core_part ? " <a href='?src=\ref[src];eject_core=1'>Eject</a>" : ""
		var/len = selected_wand_length
		var/stubby_btn = (len == WAND_LENGTH_STUBBY) ? "<b>Stubby</b>" : "<a href='?src=\ref[src];length_stubby=1'>Stubby</a>"
		var/standard_btn = (len == WAND_LENGTH_STANDARD) ? "<b>Standard</b>" : "<a href='?src=\ref[src];length_standard=1'>Standard</a>"
		var/overcomp_btn = (len == WAND_LENGTH_OVERCOMP) ? "<b>Overcomp</b>" : "<a href='?src=\ref[src];length_overcomp=1'>Overcomp</a>"
		var/telescopic_btn = (len == WAND_LENGTH_TELESCOPIC) ? "<b>Telescopic</b>" : "<a href='?src=\ref[src];length_telescopic=1'>Telescopic</a>"
		var/assembly_button = (wood_part && core_part) ? "<center><a href='?src=\ref[src];assemble=1'><big><b>Assemble Wand</b></big></a></center>" : "<center><span style='color:#888'>Place both a chassis and a core, then assemble the wand.</span></center>"

		m << browse({"

		<br>
		<html>

		<head>
		[common_browser_style]
		</head>

		<body>

		<center>
		<font size=6 style='font-family: "Wizard"'>Wand Assembly Bench</font><br><br>
		</center>

		<table width='100%' style='border-collapse:collapse;'>
		<tr><td width='30%'><b>Wood chassis</b></td><td width='50%'>[wood_name][wood_effects]</td><td width='20%'>[wood_action]</td></tr>
		<tr><td><b>Core engine</b></td><td>[core_name][core_effects]</td><td>[core_action]</td></tr>
		<tr><td><b>Length</b></td><td colspan='2'>[stubby_btn] | [standard_btn] | [overcomp_btn] | [telescopic_btn]</td></tr>
		</table>

		<br>
		[assembly_button]
		<br><br>
		<div style='font-size:90%; color:#cccccc; text-align:center;'>
		Click this bench with a wand part in your hand to place it here.<br>
		Then use the interface to assemble or remove parts.
		</div>

		</body>
		</html>
		<br>
		"}, "window=wandbench;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=520x520")
		return

	examine(mob/user)
		..(user, 2)
		var/list/wood_items = list()
		var/list/core_items = list()
		for (var/obj/item/O in contents)
			if (istype(O, /obj/item/wand_part/badger_hair) || istype(O, /obj/item/wand_part/pigeon_feather) || istype(O, /obj/item/wand_part/copper_wire) || istype(O, /obj/item/wand_part/pocket_lint) || istype(O, /obj/item/wand_part/asbestos) || istype(O, /obj/item/wand_part/fox_fur) || istype(O, /obj/item/wand_part/chewing_gum) || istype(O, /obj/item/wand_part/cassette_tape) || istype(O, /obj/item/wand_part/sheep_wool) || istype(O, /obj/item/wand_part/rat_tail) || istype(O, /obj/item/wand_part/spark_plug) || istype(O, /obj/item/wand_part/gnat_wing) || istype(O, /obj/item/wand_part/gloom_thread))
				core_items += O.name
			else if (istype(O, /obj/item/wand_part/pine_wood) || istype(O, /obj/item/wand_part/mdf_board) || istype(O, /obj/item/wand_part/balsa_wood) || istype(O, /obj/item/wand_part/snooker_cue) || istype(O, /obj/item/wand_part/fibreglass) || istype(O, /obj/item/wand_part/driftwood) || istype(O, /obj/item/wand_part/stale_chip) || istype(O, /obj/item/wand_part/shrub_root) || istype(O, /obj/item/wand_part/cap_truncheon))
				wood_items += O.name
		if (wood_items.len || core_items.len)
			to_chat(user, "<span class='notice'>On the bench: [english_list(wood_items + core_items)]</span>")


// ============================================================
//  EXTEND BASE WAND TYPE WITH COMPONENT VARS
//  These are readable on all wands; only crafted uses them.
// ============================================================

/obj/item/weapon/material/magic/wand
	// Component identifiers
	var/wand_wood           = WAND_WOOD_PINE
	var/wand_core           = WAND_CORE_PIGEON
	var/wand_length         = WAND_LENGTH_STANDARD

	// Derived modifiers - recomputed by apply_*_stats()
	var/cast_time_mod       = 1.0   // < 1 faster, > 1 slower
	var/juice_cost_mod      = 1.0   // < 1 cheaper, > 1 costlier
	var/wand_melee_force    = WEAPON_FORCE_WEAK  // melee brute force
	var/misfire_chance      = 0     // % chance of fizzle before cast
	var/range_bonus         = 0     // tile range modifier (Blinkae etc.)

	// Wood flags
	var/splinter_chance     = 0     // % splinter on overcast (Pine)
	var/snaps_on_melee      = FALSE // wand destroyed on melee hit (Balsa)
	var/lash_on_overcast    = FALSE // caster lacerates on overcast (Fibreglass)
	var/emit_stink          = FALSE // passive stink cloud (Driftwood)
	var/bog_elem_discount   = FALSE // -20% juice on elemental spells (Driftwood)
	var/wand_wet            = FALSE // MDF swelling state
	var/wand_wet_timer      = 0     // ds counter for drying
	var/carb_loaded         = FALSE // stale chip
	var/shrub_shriek        = FALSE // shrieking shrub root
	var/truncheon_grip      = FALSE // C.A.P. truncheon

	// Core flags
	var/silent_cast         = FALSE // suppress VFX/SFX (Fox)
	var/fox_extra_cast_ds   = 0     // extra deciseconds on cast (Fox: +20 ds = 2 s)
	var/panic_blink         = FALSE // auto-blink at critical HP (Pigeon)
	var/overcast_lethal     = FALSE // stun + fire on overcast (Copper)
	var/fireproof           = FALSE // suppress on_fire while held (Asbestos)
	var/asbestos_tox        = FALSE // passive toxin drip (Asbestos)
	var/lint_random_cost    = FALSE // random cost each cast (Lint)
	var/badger_combat       = FALSE // combat spells 20% faster (Badger)
	var/badger_defensive    = FALSE // defensive spells 50% costlier (Badger)
	var/pigeon_movement     = FALSE // movement spells near-instant (Pigeon)
	var/chewing_gum_sticky  = FALSE // Used chewing gum
	var/echo_tape_chance    = 0     // cassette tape echo chance
	var/jumble_tape_chance  = 0     // cassette tape jumble chance
	var/wool_damp           = FALSE // damp sheep wool
	var/backstabber         = FALSE // feral rat tail
	var/sparkplug_discount = FALSE // rusted spark plug
	var/gloom_weave         = FALSE // gloom-weave thread

	// Length flags
	var/overcomp_proj_disc  = FALSE // -15% juice on projectile spells (Overcomp)
	var/telescopic_extended = FALSE // current collapse state (Telescopic)

	// Internal timers for process()
	var/stink_timer         = 0
	var/tox_timer           = 0

// Define a threshold for "low juice" to trigger overcast effects.
#define LOW_JUICE_THRESHOLD 10


// ============================================================
//  CRAFTED WAND - THE MODULAR SUBTYPE
// ============================================================

/obj/item/weapon/material/magic/wand/crafted
	name = "crafted wand"
	desc = "A wand assembled from whatever was lying around. It hums with uncertain potential."
	icon = 'icons/obj/magic_weapons.dmi'

/obj/item/weapon/material/magic/wand/crafted/New()
	..()
	apply_wood_stats()
	apply_core_stats()
	apply_length_stats()
	update_name_and_desc()


// ============================================================
//  APPLY COMPONENT STATS
// ============================================================

/// Apply wood-specific base modifiers. Call after setting wand_wood.
/obj/item/weapon/material/magic/wand/crafted/proc/apply_wood_stats()
	// Reset wood-derived state to neutral
	cast_time_mod    = 1.0
	juice_cost_mod   = 1.0   // Reset here; apply_core_stats multiplies on top
	wand_melee_force = WEAPON_FORCE_WEAK
	misfire_chance   = 0
	splinter_chance  = 0
	snaps_on_melee   = FALSE
	lash_on_overcast = FALSE
	emit_stink       = FALSE
	bog_elem_discount = FALSE
	carb_loaded      = FALSE
	shrub_shriek     = FALSE
	truncheon_grip   = FALSE

	switch (wand_wood)
		if (WAND_WOOD_PINE)
			// Baseline - no bonuses, no penalties.
			// 5% chance of splinter to active hand when overcasting.
			splinter_chance = 5

		if (WAND_WOOD_MDF)
			// Conductive cheap material: -10% juice cost.
			// When wet: cast time doubled, +20% misfire chance.
			// Wetness penalties applied dynamically in get_effective_*.
			juice_cost_mod = 0.9

		if (WAND_WOOD_BALSA)
			// Light as air: -40% cast time, +20% juice cost, 0 melee, snaps.
			cast_time_mod    = 0.6
			juice_cost_mod   = 1.2
			wand_melee_force = 0
			snaps_on_melee   = TRUE

		if (WAND_WOOD_SNOOKER)
			// Heavy and unbalanced: +20% cast time, brutal melee.
			cast_time_mod    = 1.2
			wand_melee_force = WEAPON_FORCE_LETHAL

		if (WAND_WOOD_FIBREGLASS)
			// Incredibly whippy: -25% cast time, lashes caster on overcast.
			cast_time_mod    = 0.75
			lash_on_overcast = TRUE

		if (WAND_WOOD_DRIFTWOOD)
			// Soggy and elemental: -20% elemental juice, passive stink.
			bog_elem_discount = TRUE
			emit_stink        = TRUE

		if (WAND_WOOD_CHIP)
			carb_loaded = TRUE

		if (WAND_WOOD_SHRUB)
			shrub_shriek = TRUE
			cast_time_mod = 0.8

		if (WAND_WOOD_TRUNCHEON)
			truncheon_grip = TRUE
			wand_melee_force = 30
			cast_time_mod = 1.2


/// Apply core-specific modifiers. Call after setting wand_core.
/obj/item/weapon/material/magic/wand/crafted/proc/apply_core_stats()
	// Reset core-derived state to neutral
	silent_cast      = FALSE
	fox_extra_cast_ds = 0
	panic_blink      = FALSE
	overcast_lethal  = FALSE
	fireproof        = FALSE
	asbestos_tox     = FALSE
	lint_random_cost = FALSE
	badger_combat    = FALSE
	badger_defensive = FALSE
	pigeon_movement  = FALSE
	chewing_gum_sticky = FALSE
	echo_tape_chance   = 0
	jumble_tape_chance = 0
	wool_damp          = FALSE
	backstabber        = FALSE
	sparkplug_discount = FALSE
	gloom_weave         = FALSE

	switch (wand_core)
		if (WAND_CORE_NONE)
			return // Baseline stats remain unchanged

		if (WAND_CORE_BADGER)
			// Aggressive: combat spells 20% faster; defensive spells 50% costlier.
			badger_combat    = TRUE
			badger_defensive = TRUE

		if (WAND_CORE_PIGEON)
			// Flighty: movement spells cast near-instantly; panic auto-blink at low HP.
			pigeon_movement = TRUE
			panic_blink     = TRUE

		if (WAND_CORE_COPPER)
			// Efficient but dangerous: -25% all juice costs; lethal short on overcast.
			juice_cost_mod  = max(0.1, juice_cost_mod * 0.75)
			overcast_lethal = TRUE

		if (WAND_CORE_LINT)
			// Chaos: every cast rolls 0x or 2x cost at random.
			lint_random_cost = TRUE

		if (WAND_CORE_ASBESTOS)
			// Fire immunity while held; slow passive toxin damage.
			fireproof    = TRUE
			asbestos_tox = TRUE

		if (WAND_CORE_FOX)
			// Silent casts with no visual/audio cues; +2 s cast time to "sneak" magic out.
			silent_cast       = TRUE
			fox_extra_cast_ds = 20  // 2 seconds in deciseconds

		if (WAND_CORE_GUM)
			chewing_gum_sticky = TRUE

		if (WAND_CORE_TAPE)
			echo_tape_chance = 15
			jumble_tape_chance = 5

		if (WAND_CORE_WOOL)
			wool_damp = TRUE

		if (WAND_CORE_RAT)
			backstabber = TRUE

		if (WAND_CORE_SPARKPLUG)
			sparkplug_discount = TRUE

		if (WAND_CORE_GNAT)
			cast_time_mod = cast_time_mod * 0.5
			misfire_chance = 0

		if (WAND_CORE_GLOOM)
			gloom_weave = TRUE
			juice_cost_mod = max(0.1, juice_cost_mod * 0.5)


/// Apply length-specific modifiers. Call after setting wand_length.
/obj/item/weapon/material/magic/wand/crafted/proc/apply_length_stats()
	// Reset length-derived state to neutral
	range_bonus       = 0
	overcomp_proj_disc = FALSE

	switch (wand_length)
		if (WAND_LENGTH_STUBBY)
			// Pocket-sized: tiny w_class, fast-draw, -2 tile range.
			w_class    = ITEM_SIZE_TINY
			slot_flags = SLOT_BELT | SLOT_POCKET
			range_bonus = -2

		if (WAND_LENGTH_STANDARD)
			// No-frills baseline.
			w_class    = ITEM_SIZE_SMALL
			slot_flags = SLOT_BELT
			range_bonus = 0

		if (WAND_LENGTH_OVERCOMP)
			// Long sniper barrel: big, +3 range, -15% targeted projectile cost.
			w_class    = ITEM_SIZE_NORMAL
			slot_flags = 0  // Too big for belt or pockets
			range_bonus = 3
			overcomp_proj_disc = TRUE

		if (WAND_LENGTH_TELESCOPIC)
			// Starts collapsed. Alt-click to toggle. 10% chance to collapse per cast.
			telescopic_extended = FALSE
			_update_telescopic_length()


/// Internal helper - syncs telescopic wand's length stats to its current state.
/obj/item/weapon/material/magic/wand/crafted/proc/_update_telescopic_length()
	if (telescopic_extended)
		// Extended acts like Overcompensator
		w_class    = ITEM_SIZE_NORMAL
		slot_flags = 0
		range_bonus = 3
		overcomp_proj_disc = TRUE
	else
		// Collapsed acts like Stubby
		w_class    = ITEM_SIZE_TINY
		slot_flags = SLOT_BELT | SLOT_POCKET
		range_bonus = -2
		overcomp_proj_disc = FALSE


// ============================================================
//  NAME AND DESCRIPTION UPDATE
// ============================================================

/// Regenerates the wand's name and desc from its current components.
/obj/item/weapon/material/magic/wand/crafted/proc/update_name_and_desc()
	var/wood_str = ""
	switch (wand_wood)
		if (WAND_WOOD_PINE)       wood_str = "pine"
		if (WAND_WOOD_MDF)        wood_str = "MDF fibreboard"
		if (WAND_WOOD_BALSA)      wood_str = "balsa"
		if (WAND_WOOD_SNOOKER)    wood_str = "snooker cue"
		if (WAND_WOOD_FIBREGLASS) wood_str = "fibreglass"
		if (WAND_WOOD_DRIFTWOOD)     wood_str = "driftwood"
		if (WAND_WOOD_CHIP)       wood_str = "stale chip"
		if (WAND_WOOD_SHRUB)      wood_str = "shrieking shrub"
		if (WAND_WOOD_TRUNCHEON)  wood_str = "C.A.P. truncheon"

	var/core_str = ""
	switch (wand_core)
		if (WAND_CORE_NONE)     core_str = "no core"
		if (WAND_CORE_BADGER)   core_str = "badger hair"
		if (WAND_CORE_PIGEON)   core_str = "pigeon feather"
		if (WAND_CORE_COPPER)   core_str = "copper wire"
		if (WAND_CORE_LINT)     core_str = "pocket lint"
		if (WAND_CORE_ASBESTOS) core_str = "asbestos"
		if (WAND_CORE_FOX)      core_str = "fox fur"
		if (WAND_CORE_GUM)      core_str = "chewing gum"
		if (WAND_CORE_TAPE)     core_str = "cassette tape"
		if (WAND_CORE_WOOL)     core_str = "sheep wool"
		if (WAND_CORE_RAT)      core_str = "rat tail"
		if (WAND_CORE_SPARKPLUG) core_str = "spark plug"
		if (WAND_CORE_GNAT)     core_str = "golden gnat wing"
		if (WAND_CORE_GLOOM)    core_str = "gloom-weave thread"

	var/len_str = ""
	switch (wand_length)
		if (WAND_LENGTH_STUBBY)    len_str = "stubby"
		if (WAND_LENGTH_STANDARD)  len_str = "standard"
		if (WAND_LENGTH_OVERCOMP)  len_str = "overcompensating"
		if (WAND_LENGTH_TELESCOPIC)
			len_str = telescopic_extended ? "extended telescopic" : "collapsed telescopic"

	name = "[len_str] [wood_str] [core_str] wand"
	if (core_str == "no core")
		core_str = "no"
	desc = "A [len_str] wand made of [wood_str] with [core_str] core. It crackles with dubious magical potential."

	var/wood_icon = ""
	switch (wand_wood)
		if (WAND_WOOD_PINE)       wood_icon = "wand_pinewood"
		if (WAND_WOOD_MDF)        wood_icon = "wand_mdf"
		if (WAND_WOOD_BALSA)      wood_icon = "wand_balsa"
		if (WAND_WOOD_SNOOKER)    wood_icon = "wand_snooker"
		if (WAND_WOOD_FIBREGLASS) wood_icon = "wand_fibreglass"
		if (WAND_WOOD_DRIFTWOOD)     wood_icon = "wand_driftwood"
		if (WAND_WOOD_CHIP)       wood_icon = "wand_chip"
		if (WAND_WOOD_SHRUB)      wood_icon = "wand_shrub"
		if (WAND_WOOD_TRUNCHEON)  wood_icon = "wand_truncheon"

	var/len_icon = ""
	switch (wand_length)
		if (WAND_LENGTH_STUBBY)    len_icon = "short"
		if (WAND_LENGTH_STANDARD)  len_icon = "long"
		if (WAND_LENGTH_OVERCOMP)  len_icon = "longest"
		if (WAND_LENGTH_TELESCOPIC)
			len_icon = telescopic_extended ? "longest" : "short"

	if (wood_icon != "" && len_icon != "")
		icon_state = "[wood_icon]_[len_icon]"


// ============================================================
//  EFFECTIVE STAT CALCULATORS
// ============================================================

/// Returns the actual cast time (deciseconds) to use for spell S on this wand.
/obj/item/weapon/material/magic/wand/crafted/proc/get_effective_cast_time(datum/spell/S)
	var/mod = cast_time_mod

	// Badger core: combat spells 20% faster
	if (badger_combat && _is_combat_spell(S))
		mod *= 0.8

	// Pigeon core: movement spells near-instant (10% of normal)
	if (pigeon_movement && _is_movement_spell(S))
		mod *= 0.1

	// Stale Chip: healing spells cast 30% faster
	if (carb_loaded && S.name == "Fixae")
		mod *= 0.7

	// MDF wet: cast time doubled
	if (wand_wood == WAND_WOOD_MDF && wand_wet)
		mod *= 2.0

	var/eff = max(1, round(S.cast_time * mod))

	// Fox fur: +2 s stealth delay on top
	eff += fox_extra_cast_ds

	return eff


/// Returns the actual juice cost to use for spell S on this wand.
/obj/item/weapon/material/magic/wand/crafted/proc/get_effective_juice_cost(datum/spell/S)
	var/mod = juice_cost_mod

	// Badger core: defensive spells cost 50% more
	if (badger_defensive && _is_defensive_spell(S))
		mod *= 1.5

	// Driftwood: elemental spells cost 20% less
	if (bog_elem_discount && _is_elemental_spell(S))
		mod *= 0.8

	// Overcompensator: projectile spells cost 15% less
	if (overcomp_proj_disc && S.proj_type)
		mod *= 0.85

	// Rusted Spark Plug: all spells cost 30% less juice
	if (sparkplug_discount)
		mod *= 0.7

	// Lint core: random modifier - 0x (free!) or 2x (ouch)
	if (lint_random_cost)
		mod *= pick(0, 2.0)

	// MDF wet: juice cost doubled on top of other modifiers
	if (wand_wood == WAND_WOOD_MDF && wand_wet)
		mod *= 2.0

	return max(0, round(S.juice_cost * mod))


/// Returns the maximum tile range for targeted spells (default 7).
/obj/item/weapon/material/magic/wand/crafted/proc/get_max_range()
	return max(1, 7 + range_bonus)


// ============================================================
//  SPELL CATEGORY HELPERS
// ============================================================

/obj/item/weapon/material/magic/wand/crafted/proc/_is_combat_spell(datum/spell/S)
	switch (S.name)
		if ("Pushum", "Sliceum", "Explodus", "Zappus", "Burnus", "Painum", "Deadum")
			return TRUE
	return FALSE

/obj/item/weapon/material/magic/wand/crafted/proc/_is_defensive_spell(datum/spell/S)
	switch (S.name)
		if ("Blockum", "Wallus", "Fixae")
			return TRUE
	return FALSE

/obj/item/weapon/material/magic/wand/crafted/proc/_is_movement_spell(datum/spell/S)
	switch (S.name)
		if ("Floatus", "Blinkae")
			return TRUE
	return FALSE

/obj/item/weapon/material/magic/wand/crafted/proc/_is_elemental_spell(datum/spell/S)
	// Elemental spells include the "gross" or environmental force spells.
	switch (S.name)
		if ("Stinkaeum", "Floatus", "Burnus")
			return TRUE
	return FALSE


// ============================================================
//  OVERCAST HANDLER
// ============================================================

/// Called when a cast drains juice below 0. Applies wood/core overcast penalties.
/obj/item/weapon/material/magic/wand/crafted/proc/on_overcast(mob/living/human/H)
	if (!H) return

	// Pine: 5% chance for a splinter to the active hand
	if (wand_wood == WAND_WOOD_PINE && prob(splinter_chance))
		to_chat(H, SPAN_DANGER("You get a splinter from \the [src]! Ow!"))
		var/target_hand = (H.l_hand == src) ? "l_hand" : "r_hand"
		H.apply_damage(3, BRUTE, target_hand)
	// Fibreglass: wand snaps back and lacerates the caster's arm
	if (lash_on_overcast)
		to_chat(H, SPAN_DANGER("\The [src] snaps back violently and lacerates your arm!"))
		H.visible_message(SPAN_DANGER("[H]'s wand whips back and cuts their arm!"))
		// Sharp+edge damage = laceration (bleeding)
		H.apply_damage(8, BRUTE, pick("l_hand", "r_hand"), 0, null, TRUE, TRUE)

	// Copper wire: catastrophic short-circuit - stun + ignition
	if (overcast_lethal)
		to_chat(H, SPAN_DANGER("The copper wiring in \the [src] short-circuits! Electricity surges through you!"))
		H.visible_message(SPAN_DANGER("[H]'s wand erupts in a shower of sparks and shorts out!"))
		playsound(H.loc, 'sound/weapons/magic/spell3.ogg', 80, TRUE)
		H.apply_effects(stun = 5)   // 5-second stun
		H.fire_stacks += 3
		H.IgniteMob()

	// Rusted Spark Plug: overcast backfire - shatters hand bones, deals 30 brute, forces drop
	if (sparkplug_discount)
		to_chat(H, SPAN_DANGER("\The [src]'s juice siphon backfires! The arcane feedback shatters the bones in your hand!"))
		H.visible_message(SPAN_DANGER("[H]'s wand backfires with a sickening crunch!"))
		var/target_hand = (H.l_hand == src) ? "l_hand" : "r_hand"
		H.apply_damage(30, BRUTE, target_hand)
		var/obj/item/organ/external/E = H.organs_by_name[target_hand]
		if (E)
			E.fracture()
		playsound(H.loc, 'sound/effects/snap.ogg', 80, TRUE)
		H.unEquip(src, force = TRUE)
		return


// ============================================================
//  WET THE WAND (called by rain/mop systems)
// ============================================================

/// Mark this MDF wand as soaked. Can be called from weather or mop bucket code.
/obj/item/weapon/material/magic/wand/crafted/proc/get_wet()
	if (wand_wood != WAND_WOOD_MDF)
		return
	if (!wand_wet)
		wand_wet = TRUE
		wand_wet_timer = 0
		if (istype(loc, /mob))
			to_chat(loc, SPAN_WARNING("\The [src] soaks up moisture. It begins to swell alarmingly."))


// ============================================================
//  AFTERATTACK - FULL CRAFTED CASTING OVERRIDE
// ============================================================

/obj/item/weapon/material/magic/wand/crafted/afterattack(atom/target, mob/user, proximity_flag, params)
	if (!user || !target) return
	if (casting) return
	var/mob/living/human/H = null // Declare H at the top for wider scope
	if (ishuman(user))
		H = user

	// MDF wet check: soak the wand if the caster is outside in precipitation.
	// Checked at cast time so it catches anyone already standing in rain,
	// not just people present when the weather first changed.
	if (wand_wood == WAND_WOOD_MDF && !wand_wet)
		var/area/F_area = get_area(H || user) // Use H if available, otherwise user
		if (F_area && F_area.location == AREA_OUTSIDE && is_wet_weather_icon(F_area.icon_state))
			get_wet()

	// Skill gate
	if (ishuman(user))
		if (H.getStat("magic") < minimum_level)
			to_chat(user, SPAN_WARNING("You do not have the magical knowledge required to use this wand!"))
			return

	// Validate or auto-select active spell
	var/list/usable = get_usable_spells(user)
	if (!usable.len)
		to_chat(user, SPAN_WARNING("You don't know any spells you can cast with this wand!"))
		return
	if (!active_spell || !(active_spell in usable))
		active_spell = usable[1]
		to_chat(user, SPAN_NOTICE("Spell auto-selected: <b>[active_spell.name]</b>."))
		if (user.hud_used)
			user.hud_used.update_spell_selector(user)
			user.hud_used.update_spellshow(user)

	var/datum/spell/S = active_spell

	// Tangled Cassette Tape: jumble check
	if (jumble_tape_chance && prob(jumble_tape_chance))
		usable = get_usable_spells(user)
		if (usable.len)
			var/datum/spell/jumbled_S = pick(usable)
			to_chat(user, SPAN_WARNING("\The [src] crackles with unstable looping energy! The spell jumbles!"))
			S = jumbled_S

	// Calculate effective stats for this cast
	var/eff_cast_time  = get_effective_cast_time(S)
	var/eff_juice_cost = get_effective_juice_cost(S)

	// --- PRE-CAST CHECKS ---

	// Misfire check (always, amplified by MDF wet)
	var/total_misfire = misfire_chance
	if (wand_wood == WAND_WOOD_MDF && wand_wet)
		total_misfire += 20
	if (backstabber && H) // Use the globally declared H
		if (H.health < (H.maxHealth * 0.5))
			total_misfire += 30
	if (prob(total_misfire))
		to_chat(user, SPAN_WARNING("\The [src] fizzles! The spell half-forms and dissipates uselessly."))
		playsound(user.loc, 'sound/items/matchstick_lit.ogg', 40, TRUE)
		return

	// Telescopic collapse check - 10% chance to collapse mid-cast, fizzling spell
	if (wand_length == WAND_LENGTH_TELESCOPIC && telescopic_extended && prob(10))
		telescopic_extended = FALSE
		_update_telescopic_length()
		update_name_and_desc()
		to_chat(user, SPAN_WARNING("\The [src] collapses back on itself mid-cast! The spell fizzles!"))
		return

	// Juice check: Refuse to cast if not enough juice for the effective spell cost.
	if (ishuman(user))
		if (H.juice < eff_juice_cost)
			to_chat(user, SPAN_WARNING("You don't have enough magical juice to cast this spell!"))
			return

		// NEW: Trigger overcast effects if juice is low (below threshold), even if sufficient to cast.
		if (H.juice > 0 && H.juice < LOW_JUICE_THRESHOLD)
			to_chat(user, SPAN_WARNING("Your magical reserves are dangerously low! Casting now is risky."))
			on_overcast(H) // Apply the penalties for low juice.
	// --- CASTING ---
	casting = TRUE

	if (do_after(user, eff_cast_time, target))
		if (!src || !user || !target || !S)
			casting = FALSE
			return

		if (ishuman(user))
			if (user.get_active_hand() == src) // H.juice > 0 is guaranteed by the checks above if eff_juice_cost > 0
				H.juice -= eff_juice_cost // Deduct juice
				// Cast feedback - suppressed for Fox fur silent cast
				if (!silent_cast)
					for (var/mob/living/human/M in view(7, H))
						if (M.client)
							M.show_chat_overlay(H, "<i>[S.name]!</i>", "#dea30d")
					if (S.sound_effect)
						playsound(user.loc, S.sound_effect, 75, FALSE)
					H.visible_message("<span style=color:'#dea30d'><b>[user]</b> uses <i>[S.name]!</i></span>")
					playsound(user.loc, pick('sound/weapons/magic/spell1.ogg','sound/weapons/magic/spell2.ogg','sound/weapons/magic/spell3.ogg','sound/weapons/magic/spell4.ogg'), 50, TRUE)
				
				// Bobby wizard witness alert
				if (S.skill_level >= 80)
					for (var/mob/living/simple_animal/wizard/bobby/B in view(7, H))
						B.witness_spell(H, S)

				spawn(5)
					if (!src || !user || !target || !S)
						casting = FALSE
						return

					// --- NON-PROJECTILE SPELL HANDLING ---

					if (S.name == "Wallus")
						var/turf/T = get_turf(target)
						if (T && !T.density)
							new /obj/structure/barricade/magic(T)
							T.visible_message(SPAN_NOTICE("A magical barricade suddenly appears!"))
						else
							to_chat(H, SPAN_WARNING("You cannot summon a barricade there!"))
							H.juice = min(H.max_juice, H.juice + eff_juice_cost)

					else if (S.name == "Lightus")
						new /obj/effect/magic_light_effect(H, H)
						to_chat(H, SPAN_NOTICE("You glow with a soft magical light!"))

					else if (S.name == "Blinkae")
						var/turf/T = get_turf(target)
						var/max_range = get_max_range()
						if (T && get_dist(H, T) <= max_range && !T.density)
							H.forceMove(T)
							to_chat(H, SPAN_NOTICE("You blink to [T]!"))
							H.visible_message(SPAN_NOTICE("[H] suddenly disappears and reappears!"))
						else
							to_chat(H, SPAN_WARNING("You cannot blink there!"))
							H.juice = min(H.max_juice, H.juice + eff_juice_cost)

					// --- PROJECTILE SPELLS ---
					if (S.proj_type)
						var/obj/item/projectile/magic/P = new S.proj_type(user.loc)
						if (P)
							// Apply per-cast trait flags to the projectile
							if (istype(P, /obj/item/projectile/magic))
								P.backstabber_damage  = backstabber
								P.frostbite_effect    = gloom_weave
								P.shrub_shriek_effect = shrub_shriek
							var/tgt_zone = H.targeted_organ || "chest"
							process_projectile(P, user, target, tgt_zone, params)

							// Shrieking Shrub Root: scream at nearby mobs on every cast
							if (shrub_shriek)
								playsound(user.loc, 'sound/weapons/magic/spell4.ogg', 100, TRUE)
								H.visible_message(SPAN_DANGER("\The [src] lets out a horrible, ear-splitting SHRIEK!"))
								for (var/mob/living/M in view(4, H))
									if (M != H)
										M.apply_effects(agony = 5)
										to_chat(M, SPAN_WARNING("Your ears ring from the terrible shriek!"))

							// Tangled Cassette Tape: 15% chance to echo a second identical projectile
							if (echo_tape_chance && prob(echo_tape_chance))
								to_chat(H, SPAN_NOTICE("\The [src] crackles with a looping echo - the spell fires twice!"))
								var/obj/item/projectile/magic/P2 = new S.proj_type(user.loc)
								if (P2 && istype(P2, /obj/item/projectile/magic))
									P2.backstabber_damage  = backstabber
								P2.frostbite_effect    = gloom_weave
								P2.shrub_shriek_effect = shrub_shriek
								process_projectile(P2, user, target, tgt_zone, params)

					// Damp Sheep Wool: Burnus/Explodus scorches the caster's lungs
					if (wool_damp && (S.name == "Burnus" || S.name == "Explodus"))
						to_chat(H, SPAN_DANGER("The wet wool superheats from the fire spell - you inhale scalding steam and start coughing!"))
						H.cough_duration = max(H.cough_duration, 40)  // 4 seconds of coughing
						H.apply_damage(5, BURN, "chest")
						H.stats["stamina"][1] = max(0, H.stats["stamina"][1] - 20)

					// Stale Chip: non-healing casts have a 20% chance to crumble a bit
					if (carb_loaded && S.name != "Fixae" && prob(20))
						to_chat(H, SPAN_WARNING("\The [src]'s chip crumbles slightly from the magical strain! It's getting weaker..."))
						// Gradually reduce the cast time bonus as the chip degrades
						cast_time_mod = min(1.0, cast_time_mod + 0.05)

	casting = FALSE


// ============================================================
//  MELEE ATTACK OVERRIDE (Balsa snap / Snooker bash)
// ============================================================

/obj/item/weapon/material/magic/wand/crafted/attack(mob/living/M, mob/living/user, var/target_zone)
	// Balsa: wand atomically destroys itself on melee contact
	if (snaps_on_melee)
		user.visible_message(SPAN_DANGER("[user] swings \the [src] at [M]... and it snaps clean in half!"))
		to_chat(user, SPAN_DANGER("\The [src] splinters apart in your hand!"))
		playsound(user.loc, 'sound/effects/snap.ogg', 80, TRUE)
		qdel(src)
		return TRUE

	// All other woods: deal melee brute damage instead of casting
	if (wand_melee_force <= 0)
		to_chat(user, SPAN_WARNING("\The [src] is too flimsy to deal any damage in melee!"))
		return TRUE

	M.apply_damage(wand_melee_force, BRUTE, target_zone || "chest")
	M.visible_message(SPAN_DANGER("[user] hits [M] with \the [src]!"))
	playsound(user.loc, hitsound, 75, TRUE)
	return TRUE


// ============================================================
//  ALT-CLICK: TELESCOPIC TOGGLE
// ============================================================

/obj/item/weapon/material/magic/wand/crafted/AltClick(mob/living/user)
	if (wand_length != WAND_LENGTH_TELESCOPIC)
		return ..()
	if (!istype(user, /mob/living/human))
		return
	if (!user.get_active_hand() || user.get_active_hand() != src)
		to_chat(user, SPAN_WARNING("You need to be holding \the [src] to collapse or extend it."))
		return

	telescopic_extended = !telescopic_extended
	_update_telescopic_length()
	update_name_and_desc()

	if (telescopic_extended)
		to_chat(user, SPAN_NOTICE("You extend \the [src] to its full length. It's quite impressive."))
		user.visible_message(SPAN_NOTICE("[user] extends \the [src] to its full length."))
	else
		to_chat(user, SPAN_NOTICE("You collapse \the [src] down to pocket-size."))
		user.visible_message(SPAN_NOTICE("[user] collapses \the [src] with a sharp click."))


// ============================================================
//  EXAMINE: SHOW COMPONENT BREAKDOWN
// ============================================================

/obj/item/weapon/material/magic/wand/crafted/examine(mob/user as mob)
	..()  // Base examine: juice level, active spell, known spells
	if (ishuman(user))
		var/parsed_wood = replacetext(wand_wood,"_"," ")
		var/parsed_core = replacetext(wand_core,"_"," ")
		to_chat(user, SPAN_NOTICE("Wood: <b>[parsed_wood]</b> | Core: <b>[parsed_core]</b> | Length: <b>[wand_length]</b>"))
		if (wand_wet)
			to_chat(user, SPAN_WARNING("The MDF body has swollen with moisture. It looks very sorry for itself."))
		if (wand_length == WAND_LENGTH_TELESCOPIC)
			var/tele_state = telescopic_extended ? "extended" : "collapsed"
			to_chat(user, SPAN_NOTICE("It is currently <b>[tele_state]</b>. Alt-click to toggle."))


// ============================================================
//  PROCESS: PASSIVE CONTINUOUS EFFECTS
// ============================================================

/obj/item/weapon/material/magic/wand/crafted/process()
	..()  // Base: charge regeneration

	// Determine if a human is holding this wand in their active hand
	var/mob/living/human/holder = null
	if (ishuman(loc))
		var/mob/living/human/H = loc
		if (H.get_active_hand() == src)
			holder = H

	// --- MDF: DRY-OUT TIMER ---
	if (wand_wet)
		wand_wet_timer += 2
		if (wand_wet_timer >= 600)  // 60 seconds to fully dry
			wand_wet = FALSE
			wand_wet_timer = 0
			if (holder)
				to_chat(holder, SPAN_NOTICE("\The [src] has dried out. It's back to its normal, mediocre self."))

	// --- DRIFTWOOD: PASSIVE STINK CLOUD ---
	if (emit_stink && holder)
		stink_timer += 2
		if (stink_timer >= 30)  // Every 3 seconds
			stink_timer = 0
			holder.visible_message(SPAN_NOTICE("[holder] exudes an absolutely revolting smell from \the [src]."))
			for (var/mob/living/M in view(2, holder))
				if (M != holder)
					M.emote("cough")
					if (ishuman(M))
						var/mob/living/human/H = M
						H.mood -= 1.5
	// --- ASBESTOS: PASSIVE TOXIN DRIP ---
	if (asbestos_tox && holder)
		tox_timer += 2
		if (tox_timer >= 40)  // 2 tox damage every 4 seconds
			tox_timer = 0
			holder.apply_damage(2, TOX, "chest")

	// --- ASBESTOS: FIRE IMMUNITY (suppress flames while held) ---
	if (fireproof && holder && holder.on_fire)
		holder.on_fire = FALSE
		holder.fire_stacks = min(0, holder.fire_stacks)  // Clamp to ≤ 0 (wet/neutral)

	// --- PIGEON: PANIC BLINK AT CRITICAL HP ---
	if (panic_blink && holder)
		if (holder.health <= (holder.maxHealth * 0.15) && !casting)
			if (prob(5))  // 5% chance per process tick (~0.5 s intervals)
				var/list/candidates = list()
				for (var/turf/T in view(5, holder))
					if (!T.density)
						candidates += T
				if (candidates.len)
					var/turf/dest = pick(candidates)
					holder.visible_message(SPAN_DANGER("[holder]'s wand panics and teleports them wildly!"))
					to_chat(holder, SPAN_WARNING("Your wand panics! It blinks you somewhere - hopefully not into a wall."))
					playsound(holder.loc, 'sound/weapons/magic/spell2.ogg', 60, TRUE)
					holder.forceMove(dest)


/obj/item/weapon/material/magic/wand/nodrop_special_check()
	if (chewing_gum_sticky || truncheon_grip)
		return TRUE
	return ..()

/obj/item/weapon/material/magic/wand/var/peeling_gum = 0

/obj/item/weapon/material/magic/wand/mob_can_unequip(mob/M, slot, disable_warning = FALSE)
	if (chewing_gum_sticky && ishuman(M))
		var/mob/living/human/H = M
		if (peeling_gum == 2)
			peeling_gum = 0
			return TRUE
		if (peeling_gum == 1)
			if (!disable_warning)
				to_chat(H, SPAN_WARNING("You are already peeling \the [src]!"))
			return FALSE

		peeling_gum = 1
		to_chat(H, SPAN_WARNING("You start peeling \the [src] off your fingers... it's incredibly sticky!"))
		var/old_loc = H.loc
		spawn(0)
			if (H && src && do_after(H, 30, old_loc))
				if (H && src && (H.get_active_hand() == src || H.get_inactive_hand() == src) && H.loc == old_loc)
					to_chat(H, SPAN_NOTICE("You finally peel \the [src] off your sticky fingers."))
					peeling_gum = 2
					H.unEquip(src, force = TRUE)
				else
					peeling_gum = 0
			else
				peeling_gum = 0
		return FALSE
	return ..()


/mob/living/human/var/cough_duration = 0
/mob/living/human/var/frostbitten = FALSE

/mob/living/human/Life()
	..()
	if (cough_duration > 0)
		cough_duration = max(0, cough_duration - 2)
		emote("cough")
		stats["stamina"][1] = max(0, stats["stamina"][1] - 15)

/mob/living/human/get_run_delay()
	. = ..()
	if (frostbitten > world.time)
		. += 1.5
	if (cough_duration > 0)
		. += 0.8
	return .
