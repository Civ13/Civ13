// Renderer feasibility only. No production compositor or gameplay sources.
/world
    name = "Civ13 DreamSeeker smoke"
    hub = ""
    visibility = 0
    maxx = 7
    maxy = 7
    maxz = 1
    view = 3
    turf = /turf/tile
    fps = 10

/turf/tile
    icon = 'tile.png'
    color = "#ff0000"

/mob
    icon = 'tile.png'
    color = "#00ff00"

/world/OpenPort(port)
    if(port == "none")
        return ..()
    return 0

/world/New()
    ..()
    spawn(600)
        del(world)
    text2file("ready", "ready.txt")

/client/New()
    if(address != "127.0.0.1" || !(copytext(key, 1, 7) == "Guest-") || clients_present || byond_version != 516 || byond_build != 1688)
        del(src)
        return
    . = ..()
    clients_present++
    mob.loc = locate(4,4,1)
    eye = mob
    perspective = MOB_PERSPECTIVE
    view = 3
    var/is_guest = (copytext(key, 1, 7) == "Guest-")
    text2file("guest=[is_guest];version=[byond_version];build=[byond_build]", "client.txt")
    spawn(10)
        text2file("red", "phase.txt")
        while(!fexists("red-captured.txt"))
            sleep(1)
        for(var/turf/T in world)
            T.color = "#0000ff"
        sleep(10)
        fdel("phase.txt")
        text2file("blue", "phase.txt")
        while(!fexists("blue-captured.txt"))
            sleep(1)
        text2file("complete", "complete.txt")

var/clients_present = 0
