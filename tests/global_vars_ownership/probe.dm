#define GLOBAL_REAL(X, Typepath) var/global##Typepath/##X
#define NAMEOF(datum, X) (#X || ##datum.##X)
#define CRASH(MSG) throw EXCEPTION(MSG)
#define EXCEPTION(MSG) new /exception(MSG)
#define QDEL_IN(D, T) spawn(T) del(D)
#define SHOULD_CALL_PARENT(A)
#define QDEL_HINT_IWILLGC 1
#define TRUE 1
#define FALSE 0
/datum/controller
    var/name
/datum/proc/Destroy(force)
/datum/proc/Initialize()
/datum/proc/stat_entry(msg)
/proc/log_world(message)
    world.log << message
/proc/warning(message)
    world.log << "WARNING [message]"
/datum/controller/global_vars
    var/probe_value
/datum/controller/global_vars/proc/InitGlobalprobe_value()
    probe_value = 77
/world
    hub = ""
    hub_password = ""
    maxx = 1
    maxy = 1
    maxz = 1
/world/OpenPort(port)
    if(port == "none") return ..()
    return FALSE
/world/New()
    OpenPort("none")
    var/datum/controller/global_vars/controller = new
    var/list/witness = controller.gvars_datum_in_built_vars
    sleep(2)
    if(controller.probe_value != 77 || !islist(witness) || !("vars" in witness) || !("gvars_datum_init_order" in witness))
        world.log << "FAIL initialized globals and stable name snapshot"
    else
        world.log << "PASS globals name snapshot"
    del(world)

