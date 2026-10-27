var/failures = 0
/datum/proc/Destroy()
    return 2
var/qdel_calls = 0
/proc/qdel(datum/D)
    if(D)
        qdel_calls++
/atom
    var/datum/reagents/reagents
/datum/reagent
    var/datum/reagents/holder
/datum/reagents
    var/list/reagent_list = list()
    var/atom/my_atom
/datum/chemistry
    var/list/active_holders = list()
/datum/processes
    var/datum/chemistry/chemistry = new
var/datum/processes/processes = new
/proc/check(condition, message)
    if(!condition)
        failures++
        world.log << "FAIL [message]"
/world/OpenPort(port)
    if(port == "none")
        return ..()
    return FALSE
/world/New()
    world.OpenPort("none")
    var/atom/owner = new /obj
    var/datum/reagents/holder = new
    holder.my_atom = owner
    owner.reagents = holder
    holder.reagent_list += new /datum/reagent
    processes.chemistry.active_holders += holder
    holder.Destroy()
    check(!owner.reagents, "matching owner backlink detached")
    check(!holder.my_atom, "destroyed holder releases owner")
    check(!holder.reagent_list && qdel_calls == 1, "owned reagents released")
    check(!(holder in processes.chemistry.active_holders), "chemistry registry detached")
    var/datum/reagents/old_holder = new
    var/datum/reagents/new_holder = new
    old_holder.my_atom = owner
    owner.reagents = new_holder
    old_holder.Destroy()
    check(owner.reagents == new_holder, "replacement owner association preserved")
    check(!old_holder.my_atom, "obsolete holder releases owner")
    var/datum/reagents/deleting = new
    var/datum/reagent/ingredient = new
    ingredient.holder = deleting
    deleting.reagent_list += ingredient
    deleting.my_atom = owner
    owner.reagents = new_holder
    deleting.delete()
    check(owner.reagents == new_holder, "delete preserves replacement owner association")
    check(!deleting.my_atom && !ingredient.holder, "delete releases backlinks")
    var/datum/reagents/matching = new
    matching.my_atom = owner
    owner.reagents = matching
    matching.delete()
    check(!owner.reagents && !matching.my_atom, "delete detaches matching owner association")
    if(!failures)
        world.log << "PASS reagent ownership"
    shutdown()
