// Magic Projectile Definitions
/obj/item/projectile/magic
	name = "magic bolt"
	icon = 'icons/obj/magic_projectiles.dmi'
	icon_state = "spell"
	damage = 10
	damage_type = BURN
	nodamage = FALSE
	check_armor = "energy"
	embed = FALSE
	sharp = FALSE
	color = "#cbd600"
	light_color = "#cbd600"
	light_range = 3
	tracer_type = /obj/effect/projectile/tracer/magic/yellow

/obj/item/projectile/magic/spark
	name = "spark"
	icon_state = "spark"
	damage = 5
	damage_type = BURN
	color = "#cbd600"
	light_color = "#cbd600"
	tracer_type = /obj/effect/projectile/tracer/magic/yellow

/obj/item/projectile/magic/spark/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (isliving(target))
			var/mob/living/L = target
			L.apply_effects(agony = 10, blocked = blocked)

/obj/item/projectile/magic/flare
	name = "flare"
	icon_state = "flare"
	damage = 12
	damage_type = BURN
	color = "#7f0000"
	light_color = "#7f0000"
	tracer_type = /obj/effect/projectile/tracer/magic/red

/obj/item/projectile/magic/flare/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (ishuman(target))
			var/mob/living/human/H = target
			H.fire_stacks += 1
			H.IgniteMob()

/obj/item/projectile/magic/root
	name = "root spell"
	icon_state = "root"
	damage = 0
	nodamage = TRUE
	color = "#00bf33"
	light_color = "#00bf33"
	tracer_type = /obj/effect/projectile/tracer/magic/green

/obj/item/projectile/magic/root/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (isliving(target))
			var/mob/living/L = target
			L.apply_effects(paralyze = 2, blocked = blocked)
			to_chat(L, SPAN_DANGER("Vines rise from the ground, rooting you in place!"))

/obj/item/projectile/magic/ice_shard
	name = "ice shard"
	icon_state = "ice_shard"
	damage = 10
	damage_type = BRUTE
	sharp = TRUE
	color = "#5ca8ff"
	light_color = "#5ca8ff"
	tracer_type = /obj/effect/projectile/tracer/magic/white

/obj/item/projectile/magic/ice_shard/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (isliving(target))
			var/mob/living/L = target
			L.bodytemperature -= 60
			to_chat(L, SPAN_DANGER("You feel a sudden chilling cold!"))

/obj/item/projectile/magic/shock_bolt
	name = "shock bolt"
	icon_state = "shock"
	damage = 15
	damage_type = BURN
	color = "#cbd600"
	light_color = "#cbd600"
	tracer_type = /obj/effect/projectile/tracer/magic/yellow

/obj/item/projectile/magic/shock_bolt/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (isliving(target))
			var/mob/living/L = target
			L.apply_effects(agony = 20, stun = 1, blocked = blocked)

/obj/item/projectile/magic/fire_bolt
	name = "fire bolt"
	icon_state = "fire"
	damage = 22
	damage_type = BURN
	color = "#7f0000"
	light_color = "#7f0000"
	tracer_type = /obj/effect/projectile/tracer/magic/red

/obj/item/projectile/magic/fire_bolt/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (ishuman(target))
			var/mob/living/human/H = target
			H.fire_stacks += 2
			H.IgniteMob()

/obj/item/projectile/magic/vine_shot
	name = "vine shot"
	icon_state = "vines"
	damage = 5
	damage_type = BRUTE
	color = "#38a100"
	light_color = "#38a100"
	tracer_type = /obj/effect/projectile/tracer/magic/green

/obj/item/projectile/magic/vine_shot/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (isliving(target))
			var/mob/living/L = target
			L.apply_effects(paralyze = 4, blocked = blocked)
			to_chat(L, SPAN_DANGER("Vines wrap tightly around you!"))

/obj/item/projectile/magic/ice_blast
	name = "ice blast"
	icon_state = "ice"
	damage = 18
	damage_type = BURN
	color = "#5ca8ff"
	light_color = "#5ca8ff"
	tracer_type = /obj/effect/projectile/tracer/magic/white

/obj/item/projectile/magic/ice_blast/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (isliving(target))
			var/mob/living/L = target
			L.bodytemperature -= 120
			L.apply_effects(agony = 15, blocked = blocked)

/obj/item/projectile/magic/lightning_strike
	name = "lightning strike"
	icon_state = "lightning"
	damage = 35
	damage_type = BURN
	color = "#cbd600"
	light_color = "#cbd600"
	tracer_type = /obj/effect/projectile/tracer/magic/yellow

/obj/item/projectile/magic/lightning_strike/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (isliving(target))
			var/mob/living/L = target
			L.electrocute_act(25, src, 1.0)

/obj/item/projectile/magic/fire_ball
	name = "fireball"
	icon_state = "fireball"
	damage = 30
	damage_type = BURN

/obj/item/projectile/magic/fire_ball/on_impact(var/atom/A)
	var/turf/T = get_turf(A)
	if (T)
		explosion(T, 0, 1, 2, 3)
	return ..()

/obj/item/projectile/magic/ensnare
	name = "ensnare spell"
	icon_state = "ensnare"
	damage = 10
	damage_type = BRUTE
	color = "#38a100"
	light_color = "#38a100"
	tracer_type = /obj/effect/projectile/tracer/magic/green

/obj/item/projectile/magic/ensnare/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (isliving(target))
			var/mob/living/L = target
			L.apply_effects(paralyze = 6, weaken = 2, blocked = blocked)
			to_chat(L, SPAN_DANGER("You are completely ensnared in thick magical roots!"))

/obj/item/projectile/magic/frozen_rain
	name = "frozen rain"
	icon_state = "frozen_rain"
	damage = 30
	damage_type = BURN

/obj/item/projectile/magic/frozen_rain/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (isliving(target))
			var/mob/living/L = target
			L.bodytemperature -= 200
			L.apply_effects(paralyze = 2, agony = 30, blocked = blocked)

/obj/item/projectile/magic/zappus
	name = "zappus"
	icon_state = "spark"
	damage = 5
	damage_type = BRUTE
	color = "#cbd600"
	light_color = "#cbd600"
	tracer_type = /obj/effect/projectile/tracer/magic/yellow

/obj/item/projectile/magic/explodus
	name = "explodus"
	icon_state = "fireball"
	color = "#FF0000"
	light_color = "#FF0000"
	damage = 0
	nodamage = TRUE
	tracer_type = /obj/effect/projectile/tracer/magic/red

/obj/item/projectile/magic/explodus/on_impact(var/atom/A)
	var/turf/T = get_turf(A)
	if (T)
		explosion(T, 0, 1, 2, 3)
	return ..()

/obj/item/projectile/magic/deadum
	name = "deadum"
	icon_state = "spell"
	color = "#00FF00"
	light_color = "#00FF00"
	tracer_type = /obj/effect/projectile/tracer/magic/green
	damage = 0
	nodamage = TRUE

/obj/item/projectile/magic/deadum/on_hit(var/atom/target, var/blocked = FALSE)
	if (isliving(target))
		var/mob/living/L = target
		L.stat = DEAD // Bypasses health math and critical state
	return ..()

/obj/item/projectile/magic/sliceum
	name = "sliceum"
	icon_state = "spell"
	invisibility = 101 // Invisible hit-scan
	damage = 15
	damage_type = BRUTE
	sharp = TRUE
	color = "#939393"
	light_color = "#939393"
	tracer_type = /obj/effect/projectile/tracer/magic/white

/obj/item/projectile/magic/sliceum/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (ishuman(target))
			var/mob/living/human/H = target
			H.apply_damage(0, BRUTE, "chest", blocked, 0, 0, 1) // Force bleeding
			to_chat(H, SPAN_DANGER("An invisible blade slices through you!"))

/obj/item/projectile/magic/freezum
	name = "freezum"
	icon_state = "spell"
	damage = 5
	damage_type = BURN
	color = "#5ca8ff"
	light_color = "#5ca8ff"
	tracer_type = /obj/effect/projectile/tracer/magic/white

/obj/item/projectile/magic/freezum/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (isliving(target))
			var/mob/living/L = target
			L.bodytemperature -= 120
			L.Paralyse(5)

/obj/item/projectile/magic/pushum
	name = "pushum"
	icon_state = "spell"
	damage = 4
	damage_type = BRUTE
	color = "#f400bf"
	light_color = "#f400bf"
	tracer_type = /obj/effect/projectile/tracer/magic/pink

/obj/item/projectile/magic/pushum/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (isliving(target))
			var/mob/living/L = target
			var/atom/f = firer ? firer : src
			var/turf/T = get_edge_target_turf(L, get_dir(f, L))
			if (T)
				L.throw_at(T, 5, 2, f)
				to_chat(L, SPAN_DANGER("You are violently pushed back by magical force!"))

/obj/item/projectile/magic/pullus
	name = "pullus"
	icon_state = "spell"
	damage = 4
	damage_type = BRUTE
	color = "#f400bf"
	light_color = "#f400bf"
	tracer_type = /obj/effect/projectile/tracer/magic/pink

/obj/item/projectile/magic/pullus/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (isliving(target))
			var/mob/living/L = target
			var/atom/f = firer ? firer : src
			var/turf/T = get_turf(f)
			if (T)
				L.throw_at(T, 5, 2, f)
				to_chat(L, SPAN_DANGER("You are pulled by magical force!"))

/obj/item/projectile/magic/blockum
	name = "blockum"
	icon_state = "spell"
	color = "#00ffff"
	light_color = "#00ffff"
	tracer_type = /obj/effect/projectile/tracer/magic/white
	damage = 0
	nodamage = TRUE

/obj/item/projectile/magic/blockum/launch(atom/target, mob/user, obj/item/projectile_source, var/target_zone, var/x_offset = 0, var/y_offset = 0)
	if (user && ishuman(user))
		var/mob/living/human/H = user
		H.apply_magic_shield(40)
	qdel(src)
	return TRUE

/obj/item/projectile/magic/painum
	name = "painum"
	icon_state = "spell"
	color = "#37530a"
	light_color = "#37530a"
	tracer_type = /obj/effect/projectile/tracer/magic/green
	damage = 10
	damage_type = BURN

/obj/item/projectile/magic/painum/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (isliving(target))
			var/mob/living/L = target
			L.apply_effects(agony = 80, stun = 3, blocked = blocked)
			L.emote("painscream")
			to_chat(L, SPAN_DANGER("You feel unimaginable agony!"))

/obj/item/projectile/magic/dropus
	name = "dropus"
	icon_state = "spell"
	damage = 4
	damage_type = BRUTE
	color = "#6800a0"
	light_color = "#6800a0"
	tracer_type = /obj/effect/projectile/tracer/magic/purple

/obj/item/projectile/magic/dropus/on_hit(var/atom/target, var/blocked = FALSE)
	if (..())
		if (isliving(target))
			var/mob/living/L = target
			if (L.l_hand)
				// Disarm left hand
				L.visible_message("<span class='danger'>[target] drops \the [target.l_hand]!</span>")
				L.drop_l_hand()
			if (L.r_hand)
				// Disarm right hand
				L.visible_message("<span class='danger'>[target] drops \the [target.r_hand]!</span>")
				L.drop_r_hand()

/obj/effect/projectile/tracer/magic
	icon_state = "tracer_green"

/obj/effect/projectile/tracer/magic/red
	icon_state = "tracer_red"

/obj/effect/projectile/tracer/magic/blue
	icon_state = "tracer_white"
	color = "#2a37f0"

/obj/effect/projectile/tracer/magic/yellow
	icon_state = "tracer_white"
	color = "#cbd600"

/obj/effect/projectile/tracer/magic/pink
	icon_state = "tracer_white"
	color = "#f400bf"

/obj/effect/projectile/tracer/magic/purple
	icon_state = "tracer_white"
	color = "#6800a0"

/obj/effect/projectile/tracer/magic/white
	icon_state = "tracer_white"
	color = "#ffffff"