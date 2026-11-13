// Handloading: empty brass casings, gunpowder and bullets become cartridges.
//
// One table lists every cartridge a player can load by hand, with the casing it
// takes and the research that teaches it. The same table names which spent
// cartridges give their brass back, so the two cannot drift apart.
//
// A casing stack remembers the powder and bullets put into it. Rounds are
// produced from whole sets only (one casing, its powder charge and one bullet),
// splitting or merging a stack carries those sets along, and nothing is paid
// twice when a menu is left open.

// Casing classes.
#define HANDLOAD_PISTOL "pistol"
#define HANDLOAD_RIFLE "rifle"

/datum/handload_cartridge
	var/label = ""
	var/path = null
	var/caliber = ""
	var/casing_class = HANDLOAD_RIFLE
	var/node = "rifling"
	// Normal, armor-piercing and hollow-point loads; shotgun shells have one load.
	var/bullet_types = TRUE

/datum/handload_cartridge/New(_label, _path, _class, _node, _bullet_types = TRUE)
	..()
	label = _label
	path = _path
	casing_class = _class
	node = _node
	bullet_types = _bullet_types
	var/obj/item/ammo_casing/C = _path
	caliber = initial(C.caliber)

// Every hand-loadable cartridge, oldest first. Heavy machine-gun, cannon,
// training and broken legacy rounds are left out on purpose.
/proc/handload_cartridges()
	var/static/list/rows = null
	if (rows)
		return rows
	rows = list(
		// Industrial Age: Rifling teaches the first brass cartridges.
		new /datum/handload_cartridge(".41 Short", /obj/item/ammo_casing/a41, HANDLOAD_PISTOL, "rifling"),
		new /datum/handload_cartridge(".32 S&W", /obj/item/ammo_casing/a32, HANDLOAD_PISTOL, "rifling"),
		new /datum/handload_cartridge(".38", /obj/item/ammo_casing/a38, HANDLOAD_PISTOL, "rifling"),
		new /datum/handload_cartridge(".43 Spanish", /obj/item/ammo_casing/a43, HANDLOAD_PISTOL, "rifling"),
		new /datum/handload_cartridge(".44-40 Winchester", /obj/item/ammo_casing/a44, HANDLOAD_PISTOL, "rifling"),
		new /datum/handload_cartridge(".45 Long Colt", /obj/item/ammo_casing/a45, HANDLOAD_PISTOL, "rifling"),
		new /datum/handload_cartridge(".455 Webley", /obj/item/ammo_casing/a455, HANDLOAD_PISTOL, "rifling"),
		new /datum/handload_cartridge("8x27mmR French ordnance", /obj/item/ammo_casing/a8x27, HANDLOAD_PISTOL, "rifling"),
		new /datum/handload_cartridge("9x22mm Type 26", /obj/item/ammo_casing/c9mm_jap_revolver, HANDLOAD_PISTOL, "rifling"),
		new /datum/handload_cartridge(".45-70 Government", /obj/item/ammo_casing/a4570, HANDLOAD_RIFLE, "rifling"),
		new /datum/handload_cartridge(".577/450 Martini-Henry", /obj/item/ammo_casing/a577, HANDLOAD_RIFLE, "rifling"),
		new /datum/handload_cartridge("7.65x53mm Mauser", /obj/item/ammo_casing/a765x53, HANDLOAD_RIFLE, "rifling"),
		new /datum/handload_cartridge("8x53mm Murata", /obj/item/ammo_casing/a8x53, HANDLOAD_RIFLE, "rifling"),
		new /datum/handload_cartridge("8x50mmR Lebel", /obj/item/ammo_casing/a8x50, HANDLOAD_RIFLE, "rifling"),
		new /datum/handload_cartridge("12 gauge buckshot", /obj/item/ammo_casing/shotgun/buckshot, HANDLOAD_RIFLE, "rifling", FALSE),
		new /datum/handload_cartridge("12 gauge slug", /obj/item/ammo_casing/shotgun/slug, HANDLOAD_RIFLE, "rifling", FALSE),
		// WW1: Cartridge Firearms.
		new /datum/handload_cartridge("7.65x25mm Borchardt", /obj/item/ammo_casing/a765x25, HANDLOAD_PISTOL, "cartridge_ammo"),
		new /datum/handload_cartridge("7.62x38mmR Nagant", /obj/item/ammo_casing/a762x38, HANDLOAD_PISTOL, "cartridge_ammo"),
		new /datum/handload_cartridge(".32 ACP", /obj/item/ammo_casing/a32acp, HANDLOAD_PISTOL, "cartridge_ammo"),
		new /datum/handload_cartridge(".380 ACP", /obj/item/ammo_casing/a380acp, HANDLOAD_PISTOL, "cartridge_ammo"),
		new /datum/handload_cartridge("9x19mm Parabellum", /obj/item/ammo_casing/a9x19, HANDLOAD_PISTOL, "cartridge_ammo"),
		new /datum/handload_cartridge(".45 ACP", /obj/item/ammo_casing/a45acp, HANDLOAD_PISTOL, "cartridge_ammo"),
		new /datum/handload_cartridge("8x22mm Nambu", /obj/item/ammo_casing/c8mmnambu, HANDLOAD_PISTOL, "cartridge_ammo"),
		new /datum/handload_cartridge("6.5x50mm Arisaka", /obj/item/ammo_casing/a65x50, HANDLOAD_RIFLE, "cartridge_ammo"),
		new /datum/handload_cartridge("6.5x52mm Carcano", /obj/item/ammo_casing/a65x52, HANDLOAD_RIFLE, "cartridge_ammo"),
		new /datum/handload_cartridge("7x57mm Mauser", /obj/item/ammo_casing/a7x57, HANDLOAD_RIFLE, "cartridge_ammo"),
		new /datum/handload_cartridge("7.92x57mm Mauser", /obj/item/ammo_casing/a792x57, HANDLOAD_RIFLE, "cartridge_ammo"),
		new /datum/handload_cartridge("7.62x54mmR", /obj/item/ammo_casing/a762x54, HANDLOAD_RIFLE, "cartridge_ammo"),
		new /datum/handload_cartridge(".303 British", /obj/item/ammo_casing/a303, HANDLOAD_RIFLE, "cartridge_ammo"),
		new /datum/handload_cartridge(".30-06 Springfield", /obj/item/ammo_casing/a3006, HANDLOAD_RIFLE, "cartridge_ammo"),
		// Machine-gun loads: belt and strip guns take only these.
		new /datum/handload_cartridge("8x50mmR Lebel, machine-gun load", /obj/item/ammo_casing/a8x50/weak, HANDLOAD_RIFLE, "cartridge_ammo"),
		new /datum/handload_cartridge("6.5x50mm Arisaka, machine-gun load", /obj/item/ammo_casing/a65x50/weak, HANDLOAD_RIFLE, "cartridge_ammo"),
		new /datum/handload_cartridge("7.92x57mm Mauser, machine-gun load", /obj/item/ammo_casing/a792x57/weak, HANDLOAD_RIFLE, "cartridge_ammo"),
		new /datum/handload_cartridge("7.62x54mmR, machine-gun load", /obj/item/ammo_casing/a762x54/weak, HANDLOAD_RIFLE, "cartridge_ammo"),
		new /datum/handload_cartridge(".303 British, machine-gun load", /obj/item/ammo_casing/a303/weak, HANDLOAD_RIFLE, "cartridge_ammo"),
		new /datum/handload_cartridge(".30-06 Springfield, machine-gun load", /obj/item/ammo_casing/a3006/weak, HANDLOAD_RIFLE, "cartridge_ammo"),
		new /datum/handload_cartridge("12 gauge beanbag", /obj/item/ammo_casing/shotgun/beanbag, HANDLOAD_RIFLE, "cartridge_ammo", FALSE),
		new /datum/handload_cartridge("12 gauge rubber shot", /obj/item/ammo_casing/shotgun/rubber, HANDLOAD_RIFLE, "cartridge_ammo", FALSE),
		// WW2: Self-Loading Firearms.
		new /datum/handload_cartridge("7.62x25mm Tokarev", /obj/item/ammo_casing/a762x25, HANDLOAD_PISTOL, "selfloading_firearms"),
		new /datum/handload_cartridge(".357 Magnum", /obj/item/ammo_casing/a357, HANDLOAD_PISTOL, "selfloading_firearms"),
		new /datum/handload_cartridge("7.7x58mm Arisaka", /obj/item/ammo_casing/a77x58, HANDLOAD_RIFLE, "selfloading_firearms"),
		new /datum/handload_cartridge("7.62x33mm carbine", /obj/item/ammo_casing/a762x33, HANDLOAD_RIFLE, "selfloading_firearms"),
		new /datum/handload_cartridge("7.92x33mm Kurz", /obj/item/ammo_casing/a792x33, HANDLOAD_RIFLE, "selfloading_firearms"),
		new /datum/handload_cartridge("7.62x39mm", /obj/item/ammo_casing/a762x39, HANDLOAD_RIFLE, "selfloading_firearms"),
		// Cold War onward: Automatic Weapons.
		new /datum/handload_cartridge("9x18mm Makarov", /obj/item/ammo_casing/a9x18, HANDLOAD_PISTOL, "automatic_weapons"),
		new /datum/handload_cartridge(".44 Magnum", /obj/item/ammo_casing/a44magnum, HANDLOAD_PISTOL, "automatic_weapons"),
		new /datum/handload_cartridge("5.7x28mm", /obj/item/ammo_casing/a57x28, HANDLOAD_PISTOL, "automatic_weapons"),
		new /datum/handload_cartridge("5.56x45mm NATO", /obj/item/ammo_casing/a556x45, HANDLOAD_RIFLE, "automatic_weapons"),
		new /datum/handload_cartridge("5.45x39mm", /obj/item/ammo_casing/a545x39, HANDLOAD_RIFLE, "automatic_weapons"),
		new /datum/handload_cartridge("5.8x42mm", /obj/item/ammo_casing/a58x42, HANDLOAD_RIFLE, "automatic_weapons"),
		new /datum/handload_cartridge("9x39mm", /obj/item/ammo_casing/a9x39, HANDLOAD_RIFLE, "automatic_weapons"),
		new /datum/handload_cartridge("7.62x51mm NATO", /obj/item/ammo_casing/a762x51, HANDLOAD_RIFLE, "automatic_weapons"),
		new /datum/handload_cartridge("7.62x51mm NATO, machine-gun load", /obj/item/ammo_casing/a762x51/weak, HANDLOAD_RIFLE, "automatic_weapons"))
	return rows

// caliber => casing class, for giving spent brass back.
/proc/handload_brass_classes()
	var/static/list/classes = null
	if (!classes)
		classes = list()
		for (var/datum/handload_cartridge/R in handload_cartridges())
			classes[R.caliber] = R.casing_class
	return classes

/proc/handload_casing_path(casing_class)
	return casing_class == HANDLOAD_PISTOL ? /obj/item/stack/ammopart/casing/pistol : /obj/item/stack/ammopart/casing/rifle

// ------------------------------------------------------------
// Casing stacks
// ------------------------------------------------------------

/obj/item/stack/ammopart/casing/var/casing_class = null
/obj/item/stack/ammopart/casing/rifle/casing_class = HANDLOAD_RIFLE
/obj/item/stack/ammopart/casing/pistol/casing_class = HANDLOAD_PISTOL

// Whole sets ready to become rounds: a casing, its powder charge and a bullet.
/obj/item/stack/ammopart/casing/proc/handload_ready()
	if (gunpowder_max <= 0)
		return 0
	return max(0, min(amount, round((gunpowder + 0.001) / gunpowder_max), bulletn))

// Moves the charge of n casings (powder first, then bullets) to another stack.
/obj/item/stack/ammopart/casing/proc/move_charge(obj/item/stack/ammopart/casing/S, n)
	if (!istype(S) || n <= 0 || S == src)
		return
	var/powder = min(gunpowder, n * gunpowder_max)
	var/bullets = min(bulletn, n)
	gunpowder -= powder
	bulletn -= bullets
	S.gunpowder += powder
	S.bulletn += bullets

/obj/item/stack/ammopart/casing/merge(obj/item/stack/S)
	. = ..()
	if (casing_class && . > 0)
		move_charge(S, .)

/obj/item/stack/ammopart/casing/transfer_to(obj/item/stack/S, _amount = null)
	var/before = amount
	. = ..()
	if (casing_class && .)
		move_charge(S, before - max(0, amount))

/obj/item/stack/ammopart/casing/split(_amount)
	var/before = amount
	. = ..()
	var/obj/item/stack/ammopart/casing/S = .
	if (casing_class && istype(S))
		move_charge(S, min(S.amount, before))

/obj/item/stack/ammopart/casing/examine(mob/user)
	..()
	if (!casing_class)
		return
	var/sets = handload_ready()
	to_chat(user, "<span class='notice'>Gunpowder: [gunpowder]/[gunpowder_max * amount] units. Bullets seated: [bulletn]/[amount].</span>")
	if (sets)
		to_chat(user, "<span class='notice'>[sets] round\s ready. Use the casings in hand to choose a cartridge.</span>")
	else
		to_chat(user, "<span class='notice'>Fill them from a container of gunpowder, then seat iron bullets. Spent brass of the same size can be added back.</span>")

/obj/item/stack/ammopart/casing/rifle/attackby(obj/item/W, mob/user)
	if (handload_attackby(W, user))
		return
	return ..()

/obj/item/stack/ammopart/casing/pistol/attackby(obj/item/W, mob/user)
	if (handload_attackby(W, user))
		return
	return ..()

/obj/item/stack/ammopart/casing/rifle/attack_self(mob/user)
	handload_make_rounds(user)

/obj/item/stack/ammopart/casing/pistol/attack_self(mob/user)
	handload_make_rounds(user)

// TRUE when the click was a handloading step.
/obj/item/stack/ammopart/casing/proc/handload_attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/reagent_containers))
		var/obj/item/weapon/reagent_containers/RC = W
		var/needed = gunpowder_max * amount - gunpowder
		if (needed <= 0)
			to_chat(user, "<span class='notice'>The casings are already full of gunpowder.</span>")
			return TRUE
		var/available = RC.reagents ? RC.reagents.get_reagent_amount("gunpowder") : 0
		if (available <= 0)
			to_chat(user, "<span class='notice'>There is no gunpowder in [RC].</span>")
			return TRUE
		var/poured = min(needed, available)
		RC.reagents.remove_reagent("gunpowder", poured)
		gunpowder += poured
		to_chat(user, "You pour [poured] unit\s of gunpowder into the casings ([gunpowder]/[gunpowder_max * amount]).")
		handload_offer(user)
		return TRUE
	if (istype(W, /obj/item/stack/ammopart/bullet))
		var/obj/item/stack/ammopart/bullet/B = W
		// A bullet goes into a casing that already holds its powder.
		var/room = min(amount, round((gunpowder + 0.001) / gunpowder_max)) - bulletn
		if (room <= 0)
			to_chat(user, "<span class='notice'>Fill the casings with gunpowder before seating bullets.</span>")
			return TRUE
		var/seated = min(room, B.amount)
		if (!B.use(seated))
			return TRUE
		bulletn += seated
		to_chat(user, "You seat [seated] bullet\s in the casings ([bulletn]/[amount]).")
		handload_offer(user)
		return TRUE
	if (istype(W, /obj/item/ammo_casing))
		var/obj/item/ammo_casing/C = W
		if (C.spent_brass_class() == casing_class)
			if (C.loc == user)
				if (amount >= max_amount)
					to_chat(user, "<span class='notice'>The stack of casings is full.</span>")
					return TRUE
				user.drop_from_inventory(C)
				qdel(C)
				amount++
				update_icon()
				update_strings()
				to_chat(user, "You add the spent casing to the stack for reloading.")
			else
				handload_collect_brass(get_turf(C), user, C)
			return TRUE
	return FALSE

// Opens the cartridge menu once every casing in the stack is ready.
/obj/item/stack/ammopart/casing/proc/handload_offer(mob/user)
	if (handload_ready() >= amount)
		handload_make_rounds(user)

/obj/item/stack/ammopart/casing/proc/handload_choices(mob/user)
	. = list()
	for (var/datum/handload_cartridge/R in handload_cartridges())
		if (R.casing_class == casing_class && research_node_known(user, R.node))
			.[R.label] = R

/obj/item/stack/ammopart/casing/var/tmp/handloading = FALSE

/obj/item/stack/ammopart/casing/proc/handload_make_rounds(mob/user)
	if (!casing_class || handloading)
		return
	if (handload_ready() <= 0)
		to_chat(user, "<span class='notice'>The casings need gunpowder and a bullet each first.</span>")
		return
	var/list/choices = handload_choices(user)
	if (!choices.len)
		to_chat(user, "<span class='warning'>You don't know how to load any [casing_class] cartridges yet.</span>")
		return
	handloading = TRUE
	var/choice = WWinput(user, "Which cartridge do you want to load?", "Handloading", "Cancel", list("Cancel") + choices)
	var/datum/handload_cartridge/R = choices[choice]
	var/btype = "normal"
	if (R && R.bullet_types)
		btype = WWinput(user, "Normal, hollow point (HP) or armor-piercing (AP)?", "Handloading", "normal", list("normal", "HP", "AP"))
	handloading = FALSE
	if (!R || !(btype in list("normal", "HP", "AP")))
		return
	// The menus wait for the player: check everything again before paying.
	if (QDELETED(src) || QDELETED(user) || !(loc == user || user.Adjacent(src)) || user.incapacitated())
		return
	var/sets = handload_produce(R, btype, get_turf(user))
	if (sets)
		to_chat(user, "You load [sets] [R.label] round\s[btype == "normal" ? "" : " ([btype])"].")

// Turns every ready set into a round of R on T and pays for exactly those sets.
/obj/item/stack/ammopart/casing/proc/handload_produce(datum/handload_cartridge/R, btype, turf/T)
	var/sets = handload_ready()
	if (sets <= 0 || !R || R.casing_class != casing_class || !T)
		return 0
	gunpowder = max(0, gunpowder - sets * gunpowder_max)
	bulletn -= sets
	for (var/i = 1, i <= sets, i++)
		var/obj/item/ammo_casing/NC = new R.path(T)
		NC.btype = btype
		NC.checktype()
	use(sets)
	return sets

// Gathers every spent cartridge of this size on a tile into the stack.
/obj/item/stack/ammopart/casing/proc/handload_collect_brass(turf/T, mob/user, obj/item/ammo_casing/first = null)
	if (!T || !casing_class)
		return 0
	var/taken = 0
	var/list/brass = list()
	if (first)
		brass += first
	for (var/obj/item/ammo_casing/C in T)
		if (C != first)
			brass += C
	for (var/obj/item/ammo_casing/C in brass)
		if (amount >= max_amount)
			break
		if (C.spent_brass_class() != casing_class)
			continue
		qdel(C)
		amount++
		taken++
	if (taken)
		update_icon()
		update_strings()
		to_chat(user, "You gather [taken] spent [casing_class] casing\s for reloading.")
	else if (amount >= max_amount)
		to_chat(user, "<span class='notice'>The stack of casings is full.</span>")
	return taken

// Clicking a tile with a casing stack picks up the spent brass on it.
/obj/item/stack/ammopart/casing/afterattack(atom/target, mob/user, proximity_flag, params)
	if (casing_class && proximity_flag && isturf(target))
		handload_collect_brass(target, user)
		return
	return ..()

// ------------------------------------------------------------
// Spent cartridges
// ------------------------------------------------------------

// The casing class a fired cartridge gives back, or null. Only loose spent
// brass counts, never a round still in a magazine or gun.
/obj/item/ammo_casing/proc/spent_brass_class()
	if (BB || !isturf(loc) && !ismob(loc))
		return null
	return handload_brass_classes()[caliber]

/obj/item/ammo_casing/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/ammopart/casing))
		var/obj/item/stack/ammopart/casing/S = W
		if (S.casing_class && spent_brass_class() == S.casing_class)
			S.handload_collect_brass(get_turf(src), user, src)
			return
	return ..()

// A spent cartridge used in hand becomes an empty casing for reloading.
/obj/item/ammo_casing/attack_self(mob/user)
	var/casing_class = spent_brass_class()
	if (!casing_class || loc != user)
		return ..()
	var/path = handload_casing_path(casing_class)
	user.drop_from_inventory(src)
	qdel(src)
	var/obj/item/stack/ammopart/casing/S = new path(get_turf(user), 1)
	user.put_in_hands(S)
	to_chat(user, "You knock the spent primer out. The brass can be loaded again.")

#undef HANDLOAD_PISTOL
#undef HANDLOAD_RIFLE
