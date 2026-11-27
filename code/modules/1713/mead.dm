// Mead takes time (bee farming 5). Honey stirred into water makes mead must,
// not mead. Must ferments into mead only in a closed barrel: a little every
// couple of minutes from wild yeast, much faster with a spoonful of yeast from
// a starter jar left in the barrel. Mead left in a closed crock still sours to
// vinegar (preserves.dm).

#define MEAD_SPELL (2 MINUTES)
#define MEAD_STEP_YEAST 10
#define MEAD_STEP_WILD 3

// The mead must reagent and its honey + water reaction live with the other
// drinks in Chemistry-Reagents-Food-Drinks.dm and Chemistry-Recipes.dm.

/obj/item/weapon/reagent_containers/glass/barrel
	var/tmp/mead_timer

/obj/item/weapon/reagent_containers/glass/barrel/persistence_runtime_var(key)
	return key == "mead_timer" || ..()

/obj/item/weapon/reagent_containers/glass/barrel/after_load()
	..()
	mead_schedule()

/obj/item/weapon/reagent_containers/glass/barrel/attack_self(mob/user)
	. = ..()
	if (is_open_container())
		mead_cancel()
	else
		mead_schedule()

/obj/item/weapon/reagent_containers/glass/barrel/examine(mob/user)
	..()
	if (reagents && reagents.get_reagent_amount("honey_must") > 0)
		to_chat(user, is_open_container() ? SPAN_NOTICE("Mead must sits in it. Put the lid on to let it ferment.") : SPAN_NOTICE("It gurgles faintly as the must inside ferments."))

/obj/item/weapon/reagent_containers/glass/barrel/proc/mead_schedule()
	if (mead_timer || QDELETED(src) || is_open_container() || !reagents || reagents.get_reagent_amount("honey_must") <= 0)
		return
	mead_timer = addtimer(CALLBACK(src, PROC_REF(mead_work)), MEAD_SPELL, TIMER_STOPPABLE)

/obj/item/weapon/reagent_containers/glass/barrel/proc/mead_cancel()
	if (mead_timer)
		deltimer(mead_timer)
		mead_timer = null

/obj/item/weapon/reagent_containers/glass/barrel/Destroy()
	mead_cancel()
	return ..()

// One fermenting spell of a closed barrel. Returns the units turned to mead.
/obj/item/weapon/reagent_containers/glass/barrel/proc/mead_work()
	if (QDELETED(src))
		return 0
	mead_timer = null
	if (is_open_container() || !reagents)
		return 0
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		mead_schedule()
		return 0
	var/step = reagents.get_reagent_amount("enzyme") >= 1 ? MEAD_STEP_YEAST : MEAD_STEP_WILD
	var/amount = min(reagents.get_reagent_amount("honey_must"), step)
	if (amount > 0)
		reagents.remove_reagent("honey_must", amount)
		reagents.add_reagent("mead", amount)
	mead_schedule()
	return amount

#undef MEAD_SPELL
#undef MEAD_STEP_YEAST
#undef MEAD_STEP_WILD
