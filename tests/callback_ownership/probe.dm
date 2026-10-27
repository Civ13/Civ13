#define GLOBAL_PROC null
var/failures = 0
/datum/target
    var/calls = 0
/datum/target/proc/receive(prefix, value)
    calls++
    return "[prefix]-[value]"
/datum/target/proc/delayed(prefix, value)
    sleep(2)
    calls++
    return "[prefix]-[value]"
/proc/check(condition, message)
    if(!condition)
        failures++
        world.log << "FAIL [message]"
        del(world)
/world/OpenPort(port)
    if(port == "none")
        return ..()
    return FALSE
/world/New()
    world.OpenPort("none")
    var/datum/target/first = new
    var/datum/target/second = new
    var/datum/callback/dynamic/C = new("receive", "stored")
    check(C.Invoke(first, "one") == "stored-one", "dynamic invocation arguments")
    check(!C.object, "dynamic callback releases target")
    check(!C.Invoke() && first.calls == 1, "argumentless invocation cannot reuse stale target")
    check(C.Invoke(second, "two") == "stored-two" && second.calls == 1, "independent invocation target")
    check(C.arguments.len == 1 && C.arguments[1] == "stored", "stored args preserved")
    var/datum/callback/ordinary = new(first, "receive", "ordinary")
    check(ordinary.Invoke("call") == "ordinary-call" && ordinary.object == first, "ordinary reusable target preserved")
    var/datum/callback/dynamic/async_callback = new("delayed", "async")
    async_callback.InvokeAsync(first, "one")
    check(!async_callback.object, "async target is local before wait completes")
    async_callback.InvokeAsync(second, "two")
    check(!async_callback.object, "overlapping async target remains local")
    sleep(4)
    check(first.calls == 3 && second.calls == 2, "sleeping calls finish on their own targets")
    check(!async_callback.InvokeAsync(), "argumentless async call ignored")
    if(!failures)
        world.log << "PASS callback ownership"
    shutdown()
