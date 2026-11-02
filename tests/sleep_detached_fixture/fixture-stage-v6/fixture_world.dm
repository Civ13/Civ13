// Isolated synthetic process only; not a production or authenticated-client test.
/world
    maxx = 1
    maxy = 1
    maxz = 1
    hub = ""
    hub_password = ""
var/sleep_probe_runtime = FALSE
/world/OpenPort(port)
    if(port == "none") return ..("none")
    return FALSE
/world/Error(exception/E)
    sleep_probe_runtime = TRUE
    world.log << "Synthetic runtime failure: [E]"
/world/New()
    OpenPort("none")
    ..()
    var/mode = world.params["mode"]
    var/result = "FAIL"
    try
        sleep_graph_fixture_check((mode == "writer" || mode == "reader") && !world.port && !OpenPort(0) && !world.port, "invalid mode or listener was not closed")
        if(mode == "writer") sleep_graph_fixture_check(sleep_graph_fixture_case(), "graph writer failed")
        else sleep_graph_fixture_check(sleep_graph_fixture_reader_case(), "graph reader failed")
        sleep_graph_fixture_check(!sleep_probe_runtime, "runtime diagnostic observed")
        result = "PASS"
    catch(var/exception/E)
        world.log << "Synthetic graph probe failed: [E]"
    var/list/receipt = list("schema" = 1, "mode" = mode, "result" = result, "runtime" = sleep_probe_runtime, "port" = world.port, "synthetic_authority" = TRUE)
    if(!(mode in list("writer", "reader")) || fexists("[mode]-result.json") || !text2file(json_encode(receipt), "[mode]-result.json")) world.log << "Receipt write failed"
    del(world)