// Inert dependencies only. None is the production actor, chat, food or refill.
var/global/obj/structure/fish/fish_probe_school
var/global/mob/living/human/fish_probe_outer
var/global/mob/living/human/fish_probe_inner
var/global/obj/item/fish_probe_inner_tool
var/global/list/fish_probe_owned = list()
var/global/list/fish_probe_outputs = list()
var/global/list/fish_probe_wait_delays = list()
var/global/list/fish_probe_wait_stocks = list()
var/global/list/fish_probe_chances = list()
var/global/fish_probe_mode = "pass"
var/global/fish_probe_nested = 0
var/global/fish_probe_bite = 1
var/global/fish_probe_refills = 0
var/global/fish_probe_success_messages = 0
var/global/fish_probe_failure_messages = 0
var/global/fish_probe_starts = 0
var/global/list/fish_probe_errors = list()

/obj/structure/fish
	var/counter = 1
	var/species = "fish"

/obj/structure/fish/proc/get_fish()
	// Count the production call, but do not schedule or emulate regeneration.
	fish_probe_refills++

/obj/proc/attackby(obj/item/W, mob/living/human/H)
	return

/obj/item/weapon/fishing
	name = "inert ordinary pole"
/obj/item/weapon/fishing/modern
	name = "inert modern rod"
/obj/item/weapon/fishing/net
	name = "inert net"
/obj/item/weapon/branch
	var/sharpened = 1

/mob/living/human/proc/visible_message(message)
	fish_probe_starts++

/proc/to_chat(mob/target, message)
	if (message == "You got a fish!")
		fish_probe_success_messages++
	else if (message == "You can't seem to get anything to bite...")
		fish_probe_failure_messages++
	else
		fish_probe_errors += "unexpected chat message"

/proc/fish_probe_prob(chance)
	fish_probe_chances += chance
	return fish_probe_bite

/proc/do_after(mob/user, delay, atom/target = null)
	// Reuse digging_probe.dm's nested competing-completion pattern. This is
	// an explicit wait barrier, NOT real elapsed waiting or production do_after.
	fish_probe_wait_delays += delay
	fish_probe_wait_stocks += fish_probe_school.counter
	if (target != fish_probe_school)
		fish_probe_errors += "wrong wait target"
	if (fish_probe_mode == "cancel")
		return 0
	if (fish_probe_mode == "compete" && !fish_probe_nested)
		fish_probe_nested = 1
		fish_probe_school.attackby(fish_probe_inner_tool, fish_probe_inner)
	return 1

/obj/item/weapon/reagent_containers/food/snacks/rawfish/New()
	..()
	fish_probe_owned += src
	fish_probe_outputs += list(list("type" = "[type]", "stock" = fish_probe_school.counter, "x" = x, "y" = y, "z" = z))
/obj/item/weapon/reagent_containers/food/snacks/rawfish/salmon
	name = "inert salmon product"
/obj/item/weapon/reagent_containers/food/snacks/rawfish/cod
	name = "inert cod product"
