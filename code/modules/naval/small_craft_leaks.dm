// ============================================================
// Small craft take water when they are stove in (docs/hull-ledger.md)
// ------------------------------------------------------------
// A raft, a dugout canoe, an outrigger or an inflatable is one object, far
// too small for a hull ledger. A sound one never leaks. One knocked below
// half her strength ships water as she is paddled or driven: the worse the
// damage, the faster. Ten bucketfuls swamp her, and a swamped craft lies
// awash and will not answer until she is bailed. Nothing is lost and nobody
// is thrown out.
//
// - Damage: a weapon swung in anger (harm intent), or a shot that hits her.
//   Blows never break her up; they leave a hulk that has to be mended.
// - Bailing: an empty bucket used on her, three bucketfuls a go.
// - Mending: wood used on her (cloth on an inflatable), a quarter of her
//   strength a piece.
//
// There is no timer: water comes aboard only on a move, so a craft left
// alone stays as she was. The water is not saved; she loads dry.
//
// The raft's move check in transports.dm calls swamped_refusal() directly so
// the swamping and water admission rules share one guard.
// ============================================================

// Bucketfuls that swamp her, and that one go with a bucket takes out.
#define SMALL_CRAFT_SWAMPED 10
#define SMALL_CRAFT_BAIL 3
// Deciseconds to bail one go, and to fit one piece of wood.
#define SMALL_CRAFT_BAIL_TIME 30
#define SMALL_CRAFT_MEND_TIME 50
// The least force of a blow that harms her.
#define SMALL_CRAFT_MIN_FORCE 10

/obj/structure/vehicle
	var/tmp/bilge = 0          // Bucketfuls of water in her.
	var/tmp/mob/swamp_told     // The driver last told she is swamped.
	var/tmp/mending = FALSE

// TRUE for the craft this file covers.
/obj/structure/vehicle/proc/takes_water()
	return FALSE

/obj/structure/vehicle/raft/takes_water()
	return TRUE

/obj/structure/vehicle/boat/takes_water()
	return TRUE

// What mends her: wood or planks, and cloth for an inflatable.
/obj/structure/vehicle/proc/mends_with(obj/item/W)
	return istype(W, /obj/item/stack/material/wood) || istype(W, /obj/item/stack/material/woodplank)

/obj/structure/vehicle/boat/rhib/mends_with(obj/item/W)
	return istype(W, /obj/item/stack/material/cloth)

/obj/structure/vehicle/proc/mend_name()
	return "Wood or planks"

/obj/structure/vehicle/boat/rhib/mend_name()
	return "Cloth"

// TRUE when she is damaged enough to ship water.
/obj/structure/vehicle/proc/leaky()
	return takes_water() && !isnull(health) && health < initial(health) / 2

/obj/structure/vehicle/proc/swamped()
	return takes_water() && bilge >= SMALL_CRAFT_SWAMPED

// The chance in a hundred that a move ships one bucketful: 30 just under
// half strength, 100 for a hulk.
/obj/structure/vehicle/proc/leak_chance()
	if (!leaky())
		return 0
	var/half = initial(health) / 2
	return round(30 + 70 * (1 - max(health, 0) / half))

/obj/structure/vehicle/proc/small_craft_message(text)
	for (var/mob/living/M in ontop)
		to_chat(M, text)

// One move's worth of leaking. Returns the bucketfuls shipped.
/obj/structure/vehicle/proc/ship_water(amount = 1)
	if (!takes_water() || bilge >= SMALL_CRAFT_SWAMPED)
		return 0
	var/was = bilge
	bilge = min(SMALL_CRAFT_SWAMPED, bilge + amount)
	if (was < 1 && bilge >= 1)
		small_craft_message(SPAN_WARNING("Water is coming into \the [src]. She needs mending, and an empty bucket will bail her."))
	else if (was < SMALL_CRAFT_SWAMPED / 2 && bilge >= SMALL_CRAFT_SWAMPED / 2)
		small_craft_message(SPAN_WARNING("\The [src] is half full of water and getting heavy."))
	else if (bilge >= SMALL_CRAFT_SWAMPED)
		small_craft_message(SPAN_DANGER("\The [src] is swamped! She lies awash and will not move until she is bailed."))
	return bilge - was

// A swamped craft refuses to move, and tells whoever takes her paddle once.
// Thick ice ahead stops her too, and thin ice breaks under her bow
// (ice_breaking.dm); every small craft's move check asks here first.
/obj/structure/vehicle/proc/swamped_refusal()
	if (!small_craft_ice_ok(small_craft_ahead()))
		return TRUE
	if (!swamped())
		return FALSE
	if (driver && swamp_told != driver)
		swamp_told = driver
		to_chat(driver, SPAN_WARNING("\The [src] is swamped. Bail her with an empty bucket."))
	return TRUE

/obj/structure/vehicle/boat/do_vehicle_check()
	if (swamped_refusal())
		moving = FALSE
		stopmovementloop()
		return FALSE
	return ..()

/obj/structure/vehicle/raft/do_move(m_dir = null, interval = null)
	var/turf/was = loc
	. = ..()
	if (loc != was)
		boat_wear() // naval/small_boat_upkeep.dm
		if (prob(leak_chance()))
			ship_water()

/obj/structure/vehicle/boat/do_move(m_dir = null, interval = null)
	var/turf/was = loc
	. = ..()
	if (loc != was && prob(leak_chance()))
		ship_water()

// ---- Damage ----

// Blows and shots wear her down to a hulk and no further.
/obj/structure/vehicle/proc/small_craft_damage(amount)
	if (!takes_water() || isnull(health) || amount <= 0)
		return FALSE
	var/sound_before = !leaky()
	health = max(1, health - amount)
	if (sound_before && leaky())
		visible_message(SPAN_DANGER("\The [src] is stove in! She will take water when she moves."))
	return TRUE

/obj/structure/vehicle/raft/bullet_act(obj/item/projectile/P, def_zone)
	if (P)
		small_craft_damage(P.damage / 4)
	return ..()

/obj/structure/vehicle/boat/bullet_act(obj/item/projectile/P, def_zone)
	if (P)
		small_craft_damage(P.damage / 4)
	return ..()

// ---- Bailing and mending ----

// Why H cannot work on her, or null.
/obj/structure/vehicle/proc/small_craft_work_refusal(mob/living/human/H)
	if (!istype(H) || H.stat || H.lying || H.restrained())
		return "you are in no state for it"
	if (get_dist(H, src) > 1)
		return "you are too far away"
	return null

/obj/structure/vehicle/proc/small_craft_bucket_ready(obj/item/weapon/reagent_containers/glass/bucket/B)
	return !QDELETED(B) && B.is_open_container() && B.reagents && B.reagents.total_volume <= 0

// H bails with W until she is dry or they stop. Returns the bucketfuls out.
/obj/structure/vehicle/proc/small_craft_bail(mob/living/human/H, obj/item/weapon/reagent_containers/glass/bucket/W)
	. = 0
	var/why = small_craft_work_refusal(H)
	if (why)
		to_chat(H, SPAN_WARNING("You cannot bail \the [src]: [why]."))
		return
	H.visible_message(SPAN_NOTICE("[H] starts bailing \the [src] with \a [W]."), SPAN_NOTICE("You start bailing \the [src]."))
	while (bilge > 0)
		if (!do_after(H, SMALL_CRAFT_BAIL_TIME, src))
			break
		if (QDELETED(src) || !small_craft_bucket_ready(W) || H.get_active_hand() != W || small_craft_work_refusal(H))
			break
		var/out = min(bilge, SMALL_CRAFT_BAIL)
		bilge -= out
		swamp_told = null
		. += out
		playsound(get_turf(src), 'sound/effects/slosh.ogg', 25, TRUE)
	if (. && !QDELETED(src))
		to_chat(H, SPAN_NOTICE("You bail \the [src]. [bilge > 0 ? "There is still water in her." : "She is dry."]"))

// H fits one piece of S. TRUE when her strength came back.
/obj/structure/vehicle/proc/small_craft_mend(mob/living/human/H, obj/item/stack/S)
	var/why = small_craft_work_refusal(H)
	if (why)
		to_chat(H, SPAN_WARNING("You cannot mend \the [src]: [why]."))
		return FALSE
	if (mending)
		return FALSE
	mending = TRUE
	H.visible_message(SPAN_NOTICE("[H] starts mending \the [src]."), SPAN_NOTICE("You start mending \the [src] with \the [S]."))
	var/done = do_after(H, SMALL_CRAFT_MEND_TIME, src)
	mending = FALSE
	if (!done || QDELETED(src) || QDELETED(S) || health >= initial(health) || small_craft_work_refusal(H) || !S.use(1))
		return FALSE
	health = min(initial(health), health + initial(health) / 4)
	playsound(get_turf(src), 'sound/items/Screwdriver.ogg', 50, TRUE)
	if (health >= initial(health))
		to_chat(H, SPAN_NOTICE("\The [src] is sound again."))
	else if (leaky())
		to_chat(H, SPAN_NOTICE("You mend part of the damage. \The [src] still leaks: she needs more."))
	else
		to_chat(H, SPAN_NOTICE("You mend the worst of it. \The [src] no longer leaks."))
	return TRUE

// An empty bucket bails, her mending stuff mends, a weapon swung in anger
// harms. Everything else does what it always did. TRUE when handled here.
/obj/structure/vehicle/proc/small_craft_attackby(obj/item/W, mob/user)
	if (!takes_water() || !W || !ishuman(user))
		return FALSE
	var/mob/living/human/H = user
	if (take_rollers(W, user)) // naval/boat_hauling.dm
		return TRUE
	if (istype(W, /obj/item/weapon/reagent_containers/glass/bucket))
		var/obj/item/weapon/reagent_containers/glass/bucket/B = W
		if (bilge > 0 && small_craft_bucket_ready(B))
			small_craft_bail(H, B)
			return TRUE
		return FALSE
	if (mends_with(W) && health < initial(health))
		small_craft_mend(H, W)
		return TRUE
	if (H.a_intent == I_HARM && W.force >= SMALL_CRAFT_MIN_FORCE && !is_tool(W, TOOL_HAMMER) && !istype(W, /obj/item/vehicleparts/wheel))
		H.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		H.do_attack_animation(src)
		playsound(get_turf(src), 'sound/effects/wood_cutting.ogg', 75, TRUE)
		H.visible_message(SPAN_DANGER("[H] hits \the [src] with \the [W]!"), SPAN_DANGER("You hit \the [src] with \the [W]."))
		small_craft_damage(W.force)
		return TRUE
	return FALSE

/obj/structure/vehicle/raft/attackby(obj/item/O as obj, mob/user as mob)
	if (ishuman(user) && O && upkeep_work(O, user)) // naval/small_boat_upkeep.dm
		return TRUE
	if (small_craft_attackby(O, user))
		return TRUE
	return ..()

/obj/structure/vehicle/boat/attackby(obj/item/weapon/W as obj, mob/living/human/user as mob)
	if (small_craft_attackby(W, user))
		return TRUE
	return ..()

// ---- What a look tells ----

/obj/structure/vehicle/proc/small_craft_text()
	if (!takes_water())
		return null
	. = ""
	if (health <= 1)
		. = "She is a stove-in hulk."
	else if (leaky())
		. = "She is badly damaged and takes water when she moves."
	else if (health < initial(health))
		. = "She is damaged, but still tight."
	if (health < initial(health))
		. += " [mend_name()] used on her mends her."
	if (swamped())
		. += " She is swamped: bail her with an empty bucket."
	else if (bilge >= 1)
		. += " There is water in her: [round(bilge)] bucketful\s of the [SMALL_CRAFT_SWAMPED] that would swamp her."
	var/haul = haul_text() // naval/boat_hauling.dm
	if (haul)
		. += " [haul]"
	return trim(.)

/obj/structure/vehicle/raft/examine(mob/user, distance)
	. = ..()
	var/text = small_craft_text()
	if (text)
		to_chat(user, SPAN_WARNING(text))
	text = upkeep_text() // naval/small_boat_upkeep.dm
	if (text)
		to_chat(user, SPAN_NOTICE(text))

/obj/structure/vehicle/boat/examine(mob/user, distance)
	. = ..()
	var/text = small_craft_text()
	if (text)
		to_chat(user, SPAN_WARNING(text))

#undef SMALL_CRAFT_BAIL
#undef SMALL_CRAFT_BAIL_TIME
#undef SMALL_CRAFT_MEND_TIME
#undef SMALL_CRAFT_MIN_FORCE
