/obj/structure/farming/plant
    name = "tomato plant"
    var/stage = 1
    var/readyStageMax = 10
    var/vstatic = FALSE
    var/water = 60
    var/max_water = 60
    var/plant_nutrition = 100
    var/max_plant_nutrition = 150
/proc/check(condition, message)
    if (!condition)
        world.log << "FAIL [message]"
        del(world)
/proc/contains(list/messages, fragment)
    for (var/message in messages)
        if (findtext(message, fragment))
            return TRUE
    return FALSE
/world/New()
    var/obj/structure/farming/plant/P = new
    check(!P.farming_diagnostics(1.29).len, "novice learns hidden crop stats")
    check(contains(P.farming_diagnostics(1.3), "extra crops"), "yield guidance threshold")
    check(!contains(P.farming_diagnostics(1.59), "<b>"), "water guidance threshold")
    check(contains(P.farming_diagnostics(1.6), "healthy"), "moderate water guidance")
    P.max_water = 100
    P.water = 33
    check(contains(P.farming_diagnostics(1.6), "dry"), "one-third water boundary")
    P.water = 32
    check(contains(P.farming_diagnostics(1.6), "wilted"), "below one-third water")
    P.water = 66
    check(contains(P.farming_diagnostics(1.6), "healthy"), "two-thirds water boundary")
    P.water = 65
    check(contains(P.farming_diagnostics(1.6), "dry"), "below two-thirds water")
    check(!contains(P.farming_diagnostics(2.19), "/100"), "expert precision threshold")
    check(contains(P.farming_diagnostics(2.2), "65/100"), "expert water precision")
    check(contains(P.farming_diagnostics(2.2), "100/150"), "expert nutrition precision")
    P.plant_nutrition = 0
    check(contains(P.farming_diagnostics(1.6), "exhausted"), "exhausted soil guidance")
    P.plant_nutrition = 39
    check(contains(P.farming_diagnostics(1.6), "poor"), "poor soil guidance")
    P.plant_nutrition = 40
    check(contains(P.farming_diagnostics(1.6), "some nutrients"), "forty nutrition boundary")
    P.plant_nutrition = 80
    check(!contains(P.farming_diagnostics(1.6), "extra crops"), "eighty yield boundary")
    P.plant_nutrition = 81
    check(contains(P.farming_diagnostics(1.3), "extra crops"), "above eighty yield boundary")
    P.max_water = 0
    P.water = 0
    check(contains(P.farming_diagnostics(1.6), "does not need watering"), "mushroom watering advice")
    check(!contains(P.farming_diagnostics(2.2), "0/0"), "mushroom expert zero denominator")
    P.stage = 11
    check(contains(P.farming_diagnostics(1.3), "dead"), "dead crop actionable guidance")
    check(!contains(P.farming_diagnostics(2.2), "extra crops"), "dead crop yield false claim")
    check(!contains(P.farming_diagnostics(2.2), "nutrition level"), "dead crop resource false claim")
    check(!P.farming_diagnostics(1.29).len, "dead novice skill preserved")
    P.vstatic = TRUE
    check(!P.farming_diagnostics(2.2).len, "display prop farming advice")
    check(P.stage == 11 && P.water == 0 && P.plant_nutrition == 81, "diagnostics mutate crop")
    world.log << "PASS plant diagnostics"
    del(world)

