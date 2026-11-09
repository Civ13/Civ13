// Ghillie camouflage, night-vision dazzle, the ghost respawn countdown, cell
// door timers and breaching charges. Ideas from CM-SS13 (cmss13-devs/cmss13,
// AGPL-3.0): the sniper ghillie's stillness camouflage, NVG flare dazzle, the
// observer respawn timer, the brig cell timer and breaching charges.
// Reimplemented for Civ13.

//////////////////////////////////////////////////////////////////////////////
// GHILLIE CAMOUFLAGE: lie still in a ghillie suit on natural ground and you
// fade out until you move, fire, get hit or get bumped.
//////////////////////////////////////////////////////////////////////////////

#define GHILLIE_STILL_TIME 30 // deciseconds lying still before you fade
#define GHILLIE_ALPHA 40

/mob/living/human/var/tmp/ghillie_hidden = FALSE
/mob/living/human/var/tmp/ghillie_moved_at = 0

/mob/living/human/persistence_runtime_var(key)
	return (key in list("ghillie_hidden", "ghillie_moved_at")) || ..()

// A save taken while hidden must not bring the body back faded.
/mob/living/human/after_load()
	..()
	if (alpha == GHILLIE_ALPHA)
		alpha = 255
	ghillie_hidden = FALSE

/proc/ghillie_ground_ok(turf/T, winter)
	if (!isturf(T))
		return FALSE
	if (winter)
		return istype(T, /turf/floor/winter)
	if (istype(T, /turf/floor/grass) || istype(T, /turf/floor/dirt))
		return TRUE
	return locate(/obj/structure/wild) in T

/mob/living/human/proc/ghillie_suit()
	var/obj/item/clothing/suit/storage/ghillie/G = wear_suit
	return istype(G) ? G : null

/mob/living/human/proc/ghillie_can_hide()
	var/obj/item/clothing/suit/storage/ghillie/G = ghillie_suit()
	if (!G || stat != CONSCIOUS || !lying || buckled)
		return FALSE
	if (world.time - ghillie_moved_at < GHILLIE_STILL_TIME)
		return FALSE
	return ghillie_ground_ok(loc, istype(G, /obj/item/clothing/suit/storage/ghillie/winter))

/mob/living/human/proc/ghillie_hide()
	if (ghillie_hidden)
		return FALSE
	ghillie_hidden = TRUE
	alpha = GHILLIE_ALPHA
	to_chat(src, "<span class='notice'>You lie still and blend into the ground.</span>")
	return TRUE

/mob/living/human/proc/ghillie_reveal()
	ghillie_moved_at = world.time
	if (!ghillie_hidden)
		return FALSE
	ghillie_hidden = FALSE
	if (alpha == GHILLIE_ALPHA)
		alpha = 255
	to_chat(src, "<span class='warning'>You are no longer hidden.</span>")
	return TRUE

/mob/living/human/Move()
	. = ..()
	if (.)
		ghillie_reveal()

/mob/living/human/Bumped(atom/movable/AM)
	. = ..()
	if (ismob(AM))
		ghillie_reveal()

/mob/living/human/bullet_act(var/obj/item/projectile/P, var/def_zone)
	ghillie_reveal()
	return ..()

/obj/item/weapon/gun/handle_post_fire(mob/user, atom/target, var/pointblank=0, var/reflex=0)
	if (ishuman(user))
		var/mob/living/human/H = user
		H.ghillie_reveal()
	return ..()

/obj/item/clothing/suit/storage/ghillie/desc = "A camo ghillie suit. Lie still in it on grass, dirt or brush and you blend into the ground until you move or fire."

/obj/item/clothing/suit/storage/ghillie/winter/desc = "A camo winter ghillie suit. Lie still in it on snow and you blend into the ground until you move or fire."

/obj/item/clothing/suit/storage/ghillie/equipped(mob/user, slot)
	..()
	if (ishuman(user) && slot == slot_wear_suit)
		var/mob/living/human/H = user
		H.ghillie_moved_at = world.time
		processing_objects |= src

/obj/item/clothing/suit/storage/ghillie/dropped(mob/user)
	. = ..()
	if (ishuman(user))
		var/mob/living/human/H = user
		H.ghillie_reveal()

/obj/item/clothing/suit/storage/ghillie/after_load()
	..()
	if (ishuman(loc))
		var/mob/living/human/H = loc
		if (H.wear_suit == src)
			processing_objects |= src

/obj/item/clothing/suit/storage/ghillie/process_interval(configured_seconds)
	var/mob/living/human/H = loc
	if (!istype(H) || H.wear_suit != src || H.stat == DEAD)
		if (istype(H))
			H.ghillie_reveal()
		return PROCESS_KILL
	if (H.ghillie_hidden)
		if (!H.lying || H.stat != CONSCIOUS)
			H.ghillie_reveal()
	else if (H.ghillie_can_hide())
		H.ghillie_hide()
	return null

#undef GHILLIE_STILL_TIME

//////////////////////////////////////////////////////////////////////////////
// NIGHT-VISION DAZZLE: a bright light switched on in view of active goggles
// blurs the wearer's sight for a few seconds.
//////////////////////////////////////////////////////////////////////////////

/mob/living/human/proc/nvg_active()
	var/obj/item/clothing/glasses/G = eyes
	return istype(G) && G.active && G.overtype == "nvg"

/mob/living/human/proc/nvg_dazzle()
	if (!nvg_active())
		return FALSE
	eye_blurry = max(eye_blurry, 5)
	to_chat(src, "<span class='warning'>The bright light floods your night-vision goggles!</span>")
	return TRUE

// Everyone with active goggles who can see the light.
/proc/nvg_dazzle_near(atom/source)
	var/n = 0
	if (!source)
		return n
	for (var/mob/living/human/H in viewers(7, get_turf(source)))
		if (H.nvg_dazzle())
			n++
	return n

/obj/item/flashlight/flare/turn_on()
	. = ..()
	if (. && !istype(src, /obj/item/flashlight/flare/glowstick))
		nvg_dazzle_near(src)

/obj/structure/searchlight/attack_hand(mob/user)
	..()
	if (on)
		nvg_dazzle_near(beam ? beam : src)

//////////////////////////////////////////////////////////////////////////////
// RESPAWN COUNTDOWN: ghosts see how long until they may respawn.
//////////////////////////////////////////////////////////////////////////////

// Seconds left, 0 when the player may respawn now.
/proc/respawn_wait_seconds(client/C)
	if (!C || config.no_respawn_delays || C.next_normal_respawn <= world.realtime)
		return 0
	return ceil((C.next_normal_respawn - world.realtime) / 10)

/proc/respawn_wait_text(seconds)
	if (seconds <= 0)
		return "now"
	return "[round(seconds / 60)]:[add_zero("[seconds % 60]", 2)]"

/mob/observer/ghost/Stat()
	. = ..()
	if (client && statpanel("Status"))
		stat("Respawn in:", respawn_wait_text(respawn_wait_seconds(client)))

//////////////////////////////////////////////////////////////////////////////
// CELL TIMERS: a leader sets a sentence on a closed door; it stays shut until
// the time is served, then opens itself. The time left is saved.
//////////////////////////////////////////////////////////////////////////////

#define CELL_MAX_MINUTES 30

/obj/structure/simple_door/var/cell_sentence_left = 0 // deciseconds
/obj/structure/simple_door/var/cell_sentence_by = null
/obj/structure/simple_door/var/tmp/cell_note_time = -100

/obj/structure/simple_door/persistence_runtime_var(key)
	return key == "cell_note_time" || ..()

/obj/structure/simple_door/after_load()
	..()
	if (cell_sentence_left > 0)
		processing_objects |= src

/proc/can_set_cell_timer(mob/living/human/H)
	if (!istype(H) || H.stat != CONSCIOUS)
		return FALSE
	if (team_round_active())
		return H.original_job && (H.original_job.is_officer || H.original_job.is_commander)
	return map && H.civilization && H.civilization != "none" && map.is_faction_leader(H, H.civilization)

/obj/structure/simple_door/canOpen(var/mob/user as mob)
	if (cell_sentence_left > 0)
		if (user && world.time - cell_note_time > 20)
			cell_note_time = world.time
			to_chat(user, "<span class='warning'>The cell timer holds [src] shut: [cell_time_text()] left.</span>")
		return FALSE
	return ..()

/obj/structure/simple_door/proc/cell_time_text()
	return respawn_wait_text(ceil(cell_sentence_left / 10))

/obj/structure/simple_door/proc/start_sentence(minutes, setter_name)
	if (state || minutes <= 0)
		return FALSE
	minutes = min(round(minutes), CELL_MAX_MINUTES)
	if (minutes <= 0)
		return FALSE
	cell_sentence_left = minutes * 600
	cell_sentence_by = setter_name
	processing_objects |= src
	playsound(get_turf(src), 'sound/effects/door_lock_unlock.ogg', 60, TRUE)
	return TRUE

/obj/structure/simple_door/proc/end_sentence(early)
	if (!cell_sentence_by && cell_sentence_left <= 0)
		return FALSE
	cell_sentence_left = 0
	cell_sentence_by = null
	processing_objects -= src
	visible_message("<span class='notice'>The cell timer on [src] clicks[early ? " off" : ""]: the prisoner is free to go.</span>")
	playsound(get_turf(src), 'sound/machines/click.ogg', 50, TRUE)
	if (!state && !isSwitchingStates)
		Open()
	return TRUE

/obj/structure/simple_door/process_interval(configured_seconds)
	if (cell_sentence_left <= 0)
		return PROCESS_KILL
	cell_sentence_left -= configured_seconds * 10
	if (cell_sentence_left <= 0)
		end_sentence(FALSE)
		return PROCESS_KILL
	return null

/obj/structure/simple_door/verb/cell_timer()
	set name = "Cell Timer"
	set category = null
	set src in view(1)
	var/mob/living/human/H = usr
	if (!istype(H) || !H.Adjacent(src))
		return
	if (!can_set_cell_timer(H))
		to_chat(H, "<span class='warning'>Only faction leaders, and officers in battle, can set a cell timer.</span>")
		return
	if (cell_sentence_left > 0)
		var/choice = WWinput(H, "[src] is held shut for [cell_time_text()] more (set by [cell_sentence_by]).", "Cell Timer", "Keep", list("Keep", "Release now"))
		if (choice == "Release now" && H.Adjacent(src))
			end_sentence(TRUE)
		return
	if (state)
		to_chat(H, "<span class='warning'>Close the door first.</span>")
		return
	var/minutes = WWinput(H, "Sentence in minutes (1 to [CELL_MAX_MINUTES]):", "Cell Timer", 5, "num")
	if (!isnum(minutes) || !H.Adjacent(src) || !can_set_cell_timer(H))
		return
	if (start_sentence(minutes, H.real_name))
		H.visible_message("<span class='notice'>[H] sets the cell timer on [src] for [cell_time_text()].</span>", "<span class='notice'>You set the cell timer on [src] for [cell_time_text()].</span>")

/obj/structure/simple_door/examine(mob/user)
	. = ..()
	if (cell_sentence_left > 0)
		to_chat(user, "<span class='notice'>Its cell timer shows [cell_time_text()] left.</span>")

#undef CELL_MAX_MINUTES

//////////////////////////////////////////////////////////////////////////////
// BREACHING CHARGE: blows one door or window open after a short fuse and
// stuns the people right behind it, without the blast of a full charge.
//////////////////////////////////////////////////////////////////////////////

#define BREACH_FUSE 50

/obj/item/weapon/breaching_charge
	name = "breaching charge"
	desc = "A small shaped charge for blowing a door or window open. Fill it with nitroglycerin, then stick it on the door and step aside."
	icon = 'icons/obj/grenade.dmi'
	icon_state = "plastic-explosive0"
	item_state = "zippo"
	flags = NOBLUDGEON
	w_class = ITEM_SIZE_SMALL
	var/filled = FALSE
	var/tmp/obj/structure/target
	var/tmp/plant_dir = 0
	var/tmp/image/plant_overlay

/obj/item/weapon/breaching_charge/persistence_runtime_var(key)
	return (key in list("target", "plant_dir", "plant_overlay")) || ..()

/obj/item/weapon/breaching_charge/filled
	filled = TRUE

/obj/item/weapon/breaching_charge/examine(mob/user)
	..()
	to_chat(user, filled ? "It is filled and ready to plant." : "It is empty. Pour in nitroglycerin to fill it.")

/obj/item/weapon/breaching_charge/attackby(obj/item/W, mob/user)
	if (!filled && istype(W, /obj/item/weapon/reagent_containers))
		var/obj/item/weapon/reagent_containers/RG = W
		if (RG.reagents && RG.reagents.has_reagent("nitroglycerin", 3))
			RG.reagents.remove_reagent("nitroglycerin", 3)
			filled = TRUE
			to_chat(user, "<span class='notice'>You fill \the [src] with nitroglycerin.</span>")
		else
			to_chat(user, "<span class='warning'>You need 3 units of nitroglycerin to fill it.</span>")
		return
	return ..()

/proc/breach_target_ok(atom/A)
	if (istype(A, /obj/structure/simple_door))
		return TRUE
	return istype(A, /obj/structure/window) && !istype(A, /obj/structure/window/barrier)

/obj/item/weapon/breaching_charge/afterattack(atom/A, mob/user, proximity)
	if (!proximity || !breach_target_ok(A))
		return
	if (!filled)
		to_chat(user, "<span class='warning'>\The [src] is empty.</span>")
		return
	if (persistence_save_active())
		to_chat(user, "<span class='warning'>Wait for the save to finish.</span>")
		return
	to_chat(user, "<span class='notice'>You start sticking \the [src] on [A]...</span>")
	if (!do_after(user, 30, A) || !in_range(user, A) || QDELETED(A))
		return
	plant(A, user)

// Hidden in nullspace like other planted charges; the door shows it.
/obj/item/weapon/breaching_charge/proc/plant(obj/structure/A, mob/user)
	if (persistence_save_active())
		return FALSE
	target = A
	plant_dir = user ? get_dir(A, user) : 0
	if (user)
		user.drop_from_inventory(src)
		user.visible_message("<span class='danger'>[user] plants a breaching charge on [A]!</span>", "<span class='danger'>You plant the charge. Five seconds!</span>")
		log_game("[key_name(user)] planted a breaching charge on [A] at ([A.x],[A.y],[A.z])")
	persistence_set_loc(null)
	plant_overlay = image(icon, "plastic-explosive2")
	A.overlays += plant_overlay
	playsound(get_turf(A), 'sound/weapons/armbomb.ogg', 60, TRUE)
	addtimer(CALLBACK(src, PROC_REF(detonate)), BREACH_FUSE)
	return TRUE

/obj/item/weapon/breaching_charge/proc/detonate()
	var/obj/structure/A = target
	target = null
	if (!A || QDELETED(A))
		qdel(src)
		return FALSE
	var/turf/T = get_turf(A)
	A.overlays -= plant_overlay
	playsound(T, "explosion", 80, TRUE)
	for (var/mob/living/human/H in range(2, T))
		// Whoever is right behind the door (not on the planter's side) is stunned;
		// everyone else nearby just has their ears ring.
		var/same_side = plant_dir && (get_dir(T, H) & plant_dir)
		if (same_side || get_dist(T, H) > 1)
			H.ear_deaf = max(H.ear_deaf, 5)
			continue
		H.Weaken(3)
		H.ear_deaf = max(H.ear_deaf, 15)
		H.adjustBruteLoss(5)
		to_chat(H, "<span class='danger'>The blast throws you off your feet!</span>")
	if (istype(A, /obj/structure/window))
		var/obj/structure/window/W = A
		W.shatter()
		if (!QDELETED(W))
			qdel(W)
	else
		A.visible_message("<span class='danger'>[A] is blown off its hinges!</span>")
		qdel(A)
	qdel(src)
	return TRUE

#undef BREACH_FUSE
