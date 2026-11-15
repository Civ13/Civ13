"""Offline checks for Ada's need tracking and need-driven routines (tools/agent-control/needs.py and
routines.py) and for the autopilot loop that runs them between the model's decisions. No BYOND runtime."""

import concurrent.futures
import json
import sys
import types
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "agent-control"))

import autopilot  # noqa: E402
import needs  # noqa: E402
import routines  # noqa: E402
import scripts  # noqa: E402


def me(**over):
    row = {"ref": "[0xme]", "name": "Ada", "stat": 0, "health": 100, "max_health": 100, "water": 340, "max_water": 350,
           "nutrition": 390, "max_nutrition": 400, "bodytemperature": 310, "bladder": 0, "bowels": 0, "hygiene": 240,
           "stamina": 100, "max_stamina": 100, "left_hand": "empty", "right_hand": "empty", "active_hand": "right",
           "intent": "help", "x": 10, "y": 10, "carried": [], "worn": [], "wounds": []}
    row.update(over)
    return row


RIVER = {"ref": "[0xriver]", "name": "river", "type": "/turf/floor/beach/water/shallow", "dx": 2, "dy": 0}
TREE = {"ref": "[0xtree]", "name": "oak tree", "type": "/obj/structure/wild/tree/live_tree", "branches": 2, "dx": 1, "dy": 1}
FIRE = {"ref": "[0xfire]", "name": "campfire", "type": "/obj/structure/oven/fireplace", "lit": False, "fuel": 5, "dx": 1, "dy": 0}


def observe(self_row, nearby=(), terrain=()):
    return {"self": self_row, "nearby": list(nearby), "terrain": list(terrain), "messages": []}


def situation(observation, **kw):
    refs = [observation["self"]["ref"]] + [row["ref"] for row in observation["terrain"] + observation["nearby"]]
    return routines.Situation(observation, refs, autopilot.routine_kit(), **kw), refs


def quiet(**kw):
    """A scheduler with no implicit ladder work, so need routines are tested on their own."""
    scheduler = routines.Routines(**kw)
    scheduler.implicit = False
    return scheduler


class NeedsTests(unittest.TestCase):
    def test_levels_follow_the_players_bars(self):
        levels = needs.read(me(water=175, nutrition=100, bladder=250, hygiene=125, stamina=40))
        self.assertEqual(levels["thirst"], 50.0)
        self.assertEqual(levels["hunger"], 25.0)
        self.assertEqual(levels["relief"], 50.0)
        self.assertEqual(levels["hygiene"], 50.0)
        self.assertEqual(levels["energy"], 40.0)
        self.assertEqual(levels["warmth"], 100.0)
        self.assertEqual(levels["safety"], 100.0)
        self.assertNotIn("social", levels)  # only when the loop knows how long she has been alone

    def test_missing_bars_are_left_out(self):
        levels = needs.read({"ref": "x", "health": 50, "max_health": 100})
        self.assertEqual(set(levels), {"safety", "health"})

    def test_cold_and_heat_both_empty_warmth(self):
        self.assertEqual(needs.warmth_level(310), 100.0)
        self.assertEqual(needs.warmth_level(260), 0.0)
        self.assertEqual(needs.warmth_level(330), 0.0)
        self.assertGreater(needs.warmth_level(290), needs.warmth_level(275))

    def test_bleeding_and_serious_illness_cap_health(self):
        self.assertEqual(needs.health_level(me(wounds=[{"zone": "chest", "bleeding": True}])), 30.0)
        self.assertEqual(needs.health_level(me(illness={"type": "cholera", "severe": True, "remedy": 0})), 20.0)
        self.assertEqual(needs.health_level(me(illness={"type": "cholera", "severe": True, "remedy": 5})), 50.0)

    def test_urgency_is_quadratic_and_critical_wins(self):
        self.assertEqual(needs.urgency("thirst", 100), 0.0)
        self.assertLess(needs.urgency("thirst", 60), needs.urgency("thirst", 40))
        self.assertGreaterEqual(needs.urgency("thirst", 10), needs.CRITICAL_URGENCY)
        self.assertGreater(needs.urgency("hunger", 50, {"hunger": 2}), needs.urgency("hunger", 50))
        self.assertEqual(needs.urgency("hunger", 5, {"hunger": 0}), 0.0)  # the director may switch a need off

    def test_describe_flags_low_and_critical(self):
        line = needs.describe({"thirst": 10, "hunger": 40, "energy": 90}, {"hygiene": 0.5})
        self.assertIn("thirst 10 CRITICAL", line)
        self.assertIn("hunger 40 low", line)
        self.assertIn("energy 90", line)
        self.assertIn("hygiene x0.5", line)


class RoutineTests(unittest.TestCase):
    def test_thirst_sends_her_to_clean_water_with_a_list_number(self):
        obs = observe(me(water=60), terrain=[RIVER])
        sit, refs = situation(obs)
        choice = quiet().choose(sit)
        self.assertEqual(choice.name, "drink")
        self.assertEqual(choice.plan, [{"do": "drink", "target": 1}])
        # The plan is the model's own vocabulary: the ordinary parser accepts it.
        self.assertEqual(autopilot.parse_plan(choice.answer(), refs), [{"skill": "drink", "target": "[0xriver]"}])

    def test_contented_and_idle_means_the_director_decides(self):
        sit, _ = situation(observe(me()))
        scheduler = quiet()
        self.assertIsNone(scheduler.choose(sit))
        self.assertIn("nothing to do", scheduler.problem)

    def test_relieve_uses_the_players_emote_verbs(self):
        sit, _ = situation(observe(me(bladder=420)))
        self.assertEqual(quiet().choose(sit).plan, [{"do": "verb", "name": "pee"}])
        sit, _ = situation(observe(me(bowels=470, bladder=420)))
        self.assertEqual(quiet().choose(sit).plan, [{"do": "verb", "name": "poop"}])

    def test_eats_cooked_food_but_raw_only_when_starving(self):
        roasted = me(nutrition=120, left_hand={"ref": "[0xm]", "name": "roasted meat"})
        self.assertEqual(quiet().choose(situation(observe(roasted))[0]).name, "eat")
        raw = me(nutrition=120, left_hand={"ref": "[0xm]", "name": "raw meat"})
        self.assertIsNone(quiet().choose(situation(observe(raw))[0]))
        starving = me(nutrition=40, left_hand={"ref": "[0xm]", "name": "raw meat"})
        self.assertEqual(quiet().choose(situation(observe(starving))[0]).name, "eat")

    def test_cooks_raw_meat_then_lights_the_fire(self):
        scheduler = quiet()
        hungry = me(nutrition=150, left_hand={"ref": "[0xm]", "name": "raw meat"})
        choice = scheduler.choose(situation(observe(hungry, nearby=[FIRE]))[0])
        self.assertEqual((choice.name, choice.plan), ("cook", [{"do": "cook", "target": 1}]))
        scheduler.record(choice, "click ok (put the meat in)")
        choice = scheduler.choose(situation(observe(me(nutrition=150), nearby=[FIRE]))[0])
        self.assertEqual((choice.name, choice.plan), ("cook", [{"do": "light_fire", "target": 1}]))
        roasted = {"ref": "[0xr]", "name": "roasted meat", "item": True, "dx": 1, "dy": 1}
        choice = quiet().choose(situation(observe(me(nutrition=150), nearby=[FIRE, roasted]))[0])
        self.assertEqual(choice.plan, [{"do": "pick_up", "target": 2}])

    def test_standing_order_repeats_a_skill_until_done(self):
        scheduler = quiet()
        scheduler.directed(json.dumps({"plan": [], "routine": {"skill": "chop", "times": 2}}))
        sit, _ = situation(observe(me(), nearby=[TREE]))
        choice = scheduler.choose(sit)
        self.assertEqual((choice.name, choice.plan), ("work: chop", [{"do": "chop", "target": 1}]))
        scheduler.record(choice, "click ok (chopped)")
        self.assertEqual(scheduler.order["times"], 1)
        scheduler.record(choice, "click ok (chopped)")
        self.assertIsNone(scheduler.order)
        self.assertIn("is done", scheduler.problem)
        self.assertEqual(scheduler.director_reason(sit), scheduler.problem)

    def test_work_yields_only_to_pressing_needs(self):
        scheduler = quiet()
        scheduler.directed(json.dumps({"routine": {"skill": "chop", "times": 9}}))
        mild = situation(observe(me(water=230), nearby=[TREE], terrain=[RIVER]))[0]
        self.assertEqual(scheduler.choose(mild).name, "work: chop")
        parched = situation(observe(me(water=50), nearby=[TREE], terrain=[RIVER]))[0]
        self.assertEqual(scheduler.choose(parched).name, "drink")

    def test_director_priorities_reorder_needs(self):
        obs = observe(me(water=200, bladder=220), terrain=[RIVER])
        scheduler = quiet()
        self.assertEqual(scheduler.choose(situation(obs)[0]).name, "drink")
        scheduler.directed(json.dumps({"priorities": {"relief": 3, "thirst": 0.5, "bogus": 2}}))
        self.assertNotIn("bogus", scheduler.priorities)
        self.assertEqual(scheduler.choose(situation(obs)[0]).name, "relieve")

    def test_order_with_nothing_to_work_on_goes_back_to_the_director(self):
        scheduler = quiet()
        scheduler.directed(json.dumps({"routine": {"skill": "chop", "times": 3}}))
        self.assertIsNone(scheduler.choose(situation(observe(me()))[0]))
        self.assertIn("nothing to work on", scheduler.problem)
        self.assertIsNone(scheduler.order)

    def test_repeated_failure_drops_the_routine(self):
        scheduler = quiet()
        sit = situation(observe(me(water=60), terrain=[RIVER]))[0]
        choice = scheduler.choose(sit)
        scheduler.record(choice, "go failed (blocked)")
        scheduler.record(choice, "go failed (blocked)")
        self.assertIn("failed 2 times", scheduler.problem)
        self.assertIsNone(scheduler.choose(sit))  # drink is benched until the director has looked
        scheduler.directed("{}")
        self.assertEqual(scheduler.choose(sit).name, "drink")

    def test_project_in_memory_is_an_implicit_order(self):
        sit = situation(observe(me()), box={"project": {"name": "hut"}})[0]
        self.assertEqual(routines.Routines().choose(sit).plan, [{"do": "build_next"}])
        sit = situation(observe(me()), box={"leather": "belt"})[0]
        self.assertEqual(routines.Routines().choose(sit).plan, [{"do": "leather_next", "make": "belt"}])

    def test_director_triggers(self):
        scheduler = routines.Routines(director_every=2)
        sit = situation(observe(me()))[0]
        self.assertEqual(scheduler.director_reason(sit), "first look")
        scheduler.directed("{}")
        self.assertEqual(scheduler.director_reason(sit), "")
        self.assertEqual(scheduler.director_reason(sit, talk="Bob says hi"), "someone is talking")
        self.assertEqual(scheduler.director_reason(sit, alarm="DANGER"), "danger")
        self.assertEqual(scheduler.director_reason(sit, prompted=True), "a question is open")
        choice = routines.Choice("drink", [], 1.0, "thirst")
        scheduler.record(choice, "ok")
        scheduler.record(choice, "ok")
        self.assertEqual(scheduler.director_reason(sit), "time to review")
        self.assertEqual(routines.Routines(enabled=False).director_reason(sit), "routines off")

    def test_lonely_with_company_asks_the_director(self):
        scheduler = routines.Routines()
        scheduler.directed("{}")
        bob = {"ref": "[0xbob]", "name": "Bob", "mob": True, "type": "/mob/living/human", "stat": 0, "dx": 2, "dy": 0}
        sit = situation(observe(me(), nearby=[bob]), social_age=3600)[0]
        self.assertEqual(scheduler.director_reason(sit), "lonely, and someone is near")

    def test_parse_order(self):
        self.assertEqual(routines.parse_order({"skill": "Mine", "times": 500, "word": "ore"}), {"times": 40, "skill": "mine", "word": "ore"})
        self.assertEqual(routines.parse_order("build_next"), {"times": 5, "do": "build_next"})
        self.assertEqual(routines.parse_order("none"), "none")
        self.assertIsNone(routines.parse_order({"do": "attack_everyone"}))

    def test_report_tells_the_director_what_ran(self):
        scheduler = routines.Routines()
        sit = situation(observe(me(water=60), terrain=[RIVER]))[0]
        scheduler.record(scheduler.choose(sit), "drink ok (you drink)")
        report = scheduler.report(sit)
        self.assertIn("NEEDS (0 empty, 100 full): ", report)
        self.assertIn("ROUTINE: none", report)
        self.assertIn("drink: drink ok", report)


ROCK = {"ref": "[0xrock]", "name": "rock", "type": "/obj/covers/rock", "dx": 1, "dy": 0}
GRASS = {"ref": "[0xgrass]", "name": "tall grass", "type": "/obj/structure/wild/tallgrass", "dx": 0, "dy": 1}
DEER = {"ref": "[0xdeer]", "name": "deer", "mob": True, "type": "/mob/living/simple_animal/deer", "stat": 0, "dx": 3, "dy": 0}
WOLF = {"ref": "[0xwolf]", "name": "wolf", "mob": True, "type": "/mob/living/simple_animal/hostile/wolf", "stat": 0, "dx": 2, "dy": 0}


def holding(*names, items=None):
    hands = {"left_hand": "empty", "right_hand": "empty"}
    for slot, name in zip(("right_hand", "left_hand"), names):
        hands[slot] = {"ref": f"[0x{slot}]", "name": name}
    return me(items=items or [], **hands)


def next_step(script, self_row, nearby=()):
    sit, _ = situation(observe(self_row, nearby=nearby))
    return script(sit)


class ScriptTests(unittest.TestCase):
    def test_flint_searches_then_sharpens(self):
        self.assertEqual(next_step(scripts.flint, holding(), [ROCK]), [{"do": "find_flint", "target": "[0xrock]"}])
        self.assertEqual(next_step(scripts.flint, holding("flint"), [ROCK]), [{"do": "sharpen_flint", "target": "[0xrock]"}])
        self.assertEqual(next_step(scripts.flint, holding("sharpened flint"), [ROCK]), scripts.DONE)
        self.assertEqual(next_step(scripts.flint, holding()), [{"do": "explore", "dir": "north"}])

    def test_spear_builds_on_flint_and_a_stick(self):
        branch = {"ref": "[0xbr]", "name": "branch", "item": True, "branch": "leafy", "dx": 1, "dy": 0}
        self.assertEqual(next_step(scripts.spear, holding(), [ROCK, TREE]), [{"do": "find_flint", "target": "[0xrock]"}])
        self.assertEqual(next_step(scripts.spear, holding("sharpened flint"), [TREE]), [{"do": "break_branch", "target": "[0xtree]"}])
        self.assertEqual(next_step(scripts.spear, holding("sharpened flint"), [TREE, branch]), [{"do": "pick_leaves", "target": "[0xbr]"}])
        self.assertEqual(next_step(scripts.spear, holding("sharpened flint", "stick")), [{"do": "sharpen_stick", "target": 0}])
        self.assertEqual(next_step(scripts.spear, holding("sharpened stick")), scripts.DONE)

    def test_axe_twists_two_cuttings_then_binds(self):
        kit = ("sharpened flint", "sharpened stick")
        self.assertEqual(next_step(scripts.axe, holding(*kit), [GRASS]), [{"do": "cut_grass", "target": "[0xgrass]"}])
        one = holding(*kit, items=[{"name": "grass cuttings", "amount": 1}])
        self.assertEqual(next_step(scripts.axe, one, [GRASS]), [{"do": "cut_grass", "target": "[0xgrass]"}])
        two = holding(*kit, items=[{"name": "grass cuttings", "amount": 2}])
        self.assertEqual(next_step(scripts.axe, two, [GRASS]), [{"do": "twist_twine", "target": 0}])
        bound = holding(*kit)
        bound["carried"] = ["crude twine (pocket)"]
        self.assertEqual(next_step(scripts.axe, bound), [{"do": "bind_axe", "target": 0}])
        self.assertEqual(next_step(scripts.axe, holding("flint axe")), scripts.DONE)

    def test_wood_and_campfire(self):
        self.assertEqual(next_step(scripts.campfire, holding("flint axe"), [TREE]), [{"do": "chop", "target": "[0xtree]"}])
        logs = holding("flint axe", items=[{"name": "wood log", "amount": 4}])
        self.assertEqual(next_step(scripts.campfire, logs, [TREE]), [{"do": "craft", "recipe": "campfire", "material": "wood log"}])
        self.assertEqual(next_step(scripts.campfire, holding("flint axe"), [FIRE]), scripts.DONE)

    def test_hunt_kills_prey_not_predators_then_butchers(self):
        armed = holding("sharpened stick", "sharpened flint")
        self.assertEqual(next_step(scripts.hunt, armed, [DEER, WOLF]), [{"do": "attack", "target": "[0xdeer]"}])
        self.assertEqual(next_step(scripts.hunt, armed, [WOLF]), [{"do": "explore", "dir": "north"}])
        dead = dict(DEER, stat=2)
        self.assertEqual(next_step(scripts.hunt, armed, [dead]), [{"do": "butcher", "target": "[0xdeer]"}])
        self.assertEqual(next_step(scripts.hunt, holding("raw meat")), scripts.DONE)

    def test_ladder_order(self):
        rows = [ROCK, TREE]
        self.assertEqual(scripts.ladder(situation(observe(holding(), nearby=rows))[0]), "flint")
        self.assertEqual(scripts.ladder(situation(observe(holding("sharpened flint"), nearby=rows))[0]), "spear")
        self.assertEqual(scripts.ladder(situation(observe(holding("sharpened stick", "sharpened flint"), nearby=rows))[0]), "axe")
        self.assertEqual(scripts.ladder(situation(observe(holding("flint axe"), nearby=rows))[0]), "campfire")
        self.assertEqual(scripts.ladder(situation(observe(holding("flint axe"), nearby=[FIRE]))[0]), "")

    def test_ladder_runs_without_an_order_and_none_pauses_it(self):
        scheduler = routines.Routines()
        sit = situation(observe(holding(), nearby=[ROCK]))[0]
        choice = scheduler.choose(sit)
        self.assertEqual((choice.name, choice.plan), ("work: make flint", [{"do": "find_flint", "target": 1}]))
        scheduler.directed(json.dumps({"routine": "none"}))
        self.assertIsNone(scheduler.choose(sit))
        scheduler.directed(json.dumps({"routine": {"script": "make_axe"}}))
        self.assertEqual(scheduler.order["script"], "axe")
        self.assertEqual(scheduler.choose(sit).name, "work: make axe")

    def test_script_order_ends_when_the_product_is_made(self):
        scheduler = routines.Routines()
        scheduler.directed(json.dumps({"routine": {"script": "wood", "logs": 2}}))
        self.assertEqual(scheduler.order, {"script": "wood", "times": routines.SCRIPT_BUDGET, "logs": 2})
        done = holding("flint axe", items=[{"name": "wood log", "amount": 2}])
        sit = situation(observe(done, nearby=[TREE, FIRE]))[0]
        self.assertIsNone(scheduler.choose(sit))
        self.assertIn("make wood) is done", scheduler.problem)

    def test_hunger_with_no_food_goes_hunting(self):
        sit = situation(observe(holding("sharpened stick", "sharpened flint") | {"nutrition": 120}, nearby=[DEER]))[0]
        choice = quiet().choose(sit)
        self.assertEqual((choice.name, choice.plan), ("hunt", [{"do": "attack", "target": 1}]))

    def test_script_names_and_aliases(self):
        self.assertEqual(routines.parse_order("campfire"), {"script": "campfire", "times": routines.SCRIPT_BUDGET})
        self.assertEqual(routines.parse_order({"script": "gather_wood", "logs": 99})["logs"], 40)
        self.assertIsNone(routines.parse_order({"script": "spaceship"}))


class FakeGame:
    """Answers the agent-control requests the autopilot loop makes for one standing character."""

    def __init__(self, observation):
        self.observation = observation
        self.queued = []

    def request(self, action, params=None):
        if action == "character_observe":
            if params and "queue_since" in params:
                return {"ok": True, "result": {"self": self.observation["self"], "queue": {"results": [{"id": len(self.queued), "do": "x", "ok": True, "detail": "done"}]}}}
            return {"ok": True, "result": json.loads(json.dumps(self.observation))}
        if action == "character_queue":
            self.queued.append(params["actions"])
            return {"ok": True}
        return {"ok": False, "error": "unexpected", "detail": action}


class FakeModel:
    def __init__(self, answer):
        self.answer, self.calls = answer, 0

    def submit(self, fn, *args, **kwargs):
        self.calls += 1
        future = concurrent.futures.Future()
        future.set_result(self.answer)
        return future


def run_args(**over):
    args = types.SimpleNamespace(goal="Survive.", steps=4, minutes=None, memory="none", catalog="none", leather="", timeout=5,
                                 ollama_url="http://127.0.0.1:1", model="m", num_ctx=2048, think=False, keep_alive="1m",
                                 interval=0, follow=False, pause_file="", routines=True, director_every=8)
    vars(args).update(over)
    return args


class LoopTests(unittest.TestCase):
    def run_loop(self, observation, answer, **over):
        game, model = FakeGame(observation), FakeModel(answer)
        with mock.patch.object(autopilot, "load_tips", return_value=[]), mock.patch("builtins.print"):
            code = autopilot._run(game, run_args(**over), "[0xme]", None, model)
        return code, game, model

    def test_director_sets_an_order_and_routines_carry_it_out(self):
        answer = json.dumps({"plan": [{"do": "wait", "ticks": 5}], "routine": {"skill": "chop", "times": 9}})
        code, game, model = self.run_loop(observe(me(right_hand={"ref": "[0xaxe]", "name": "flint axe"}), nearby=[TREE]), answer, steps=4)
        self.assertEqual(code, 0)
        self.assertEqual(model.calls, 1)  # first look only; three chops ran as routines
        chops = [actions for actions in game.queued if any(a.get("target") == "[0xtree]" for a in actions)]
        self.assertEqual(len(chops), 3)

    def test_needs_are_met_without_the_model(self):
        answer = json.dumps({"plan": [{"do": "wait", "ticks": 5}]})
        code, game, model = self.run_loop(observe(me(bladder=420)), answer, steps=3)
        self.assertEqual(model.calls, 1)
        self.assertEqual(sum(1 for actions in game.queued if {"do": "verb", "name": "pee"} in actions), 2)

    def test_survival_ladder_runs_without_the_model(self):
        answer = json.dumps({"plan": [{"do": "wait", "ticks": 5}]})
        code, game, model = self.run_loop(observe(holding(), nearby=[ROCK]), answer, steps=4)
        self.assertEqual(model.calls, 1)
        self.assertEqual(sum(1 for actions in game.queued if any(a.get("target") == "[0xrock]" for a in actions)), 3)

    def test_no_routines_asks_the_model_every_turn(self):
        answer = json.dumps({"plan": [{"do": "wait", "ticks": 5}]})
        code, game, model = self.run_loop(observe(me(bladder=420)), answer, steps=3, routines=False)
        self.assertEqual(model.calls, 3)

    def test_director_prompt_carries_needs_and_reason(self):
        answer = json.dumps({"plan": [{"do": "wait", "ticks": 5}]})
        game, seen = FakeGame(observe(me(water=200))), []

        class Recording(FakeModel):
            def submit(self, fn, url, model, messages, *args, **kwargs):
                seen.append(messages[-1]["content"])
                return super().submit(fn)

        with mock.patch.object(autopilot, "load_tips", return_value=[]), mock.patch("builtins.print"):
            autopilot._run(game, run_args(steps=1), "[0xme]", None, Recording(answer))
        self.assertIn("NEEDS (0 empty, 100 full): ", seen[0])
        self.assertIn("YOU ARE ASKED BECAUSE: first look", seen[0])


class RouteClient:
    """A game that answers walk_to with a scripted receipt and counts tile-by-tile moves."""

    def __init__(self, receipt, accept=True, target_offset=(1, 0)):
        self.receipt, self.accept, self.offset = receipt, accept, target_offset
        self.steps, self.moves, self.results = [], 0, []

    def request(self, action, params=None):
        if action == "character_queue":
            step = params["actions"][0]
            self.steps.append(step)
            if step["do"] == "walk_to":
                if not self.accept:
                    return {"ok": False, "error": "bad_args", "detail": "unknown action walk_to"}
                ok, detail = self.receipt
                self.results = [{"id": len(self.steps), "do": "walk_to", "ok": ok, "detail": detail}]
            else:
                self.moves += 1
                self.results = [{"id": len(self.steps), "do": "move", "ok": True, "detail": "done"}]
            return {"ok": True}
        dx, dy = self.offset
        nearby = [{"ref": "[0xt]", "name": "tree", "dx": dx, "dy": dy}]
        return {"ok": True, "result": {"self": {"x": 50, "y": 50, "can_move": True}, "nearby": nearby, "surroundings": {},
                                       "queue": {"pending": [], "running": False, "results": self.results}}}


class RouteTests(unittest.TestCase):
    def test_go_uses_the_games_route_then_stands_next_to_it(self):
        client = RouteClient((True, "arrived"))
        ok, detail, _ = autopilot.approach(client, "[0xme]", "[0xt]", 0)
        self.assertEqual((ok, detail), (True, "next to it"))
        self.assertEqual(client.steps[0], {"do": "walk_to", "target": "[0xt]"})
        self.assertEqual(client.moves, 0)

    def test_a_stopped_route_is_not_retried_tile_by_tile(self):
        client = RouteClient((False, "stopped: the wolf is close"), target_offset=(6, 0))
        ok, detail, _ = autopilot.approach(client, "[0xme]", "[0xt]", 0)
        self.assertEqual((ok, detail), (False, "the wolf is close"))
        self.assertEqual(client.moves, 0)

    def test_an_older_server_falls_back_to_tile_steps(self):
        client = RouteClient(None, accept=False, target_offset=(2, 0))
        ok, _, _ = autopilot.approach(client, "[0xme]", "[0xt]", 0, limit=1)
        self.assertGreaterEqual(client.moves, 1)

    def test_explore_routes_toward_a_point_in_that_direction(self):
        client = RouteClient((True, "arrived"))
        ok, detail, _ = autopilot.explore_route(client, "[0xme]", 0, "east")
        self.assertTrue(ok)
        self.assertEqual(client.steps[0], {"do": "walk_to", "x": 50 + autopilot.EXPLORE_TILES, "y": 50})
        self.assertIn("walked about", detail)


class SourceTests(unittest.TestCase):
    def test_character_state_reports_every_need_bar(self):
        source = (ROOT / "code/modules/agent_control/agent_characters.dm").read_text(encoding="utf-8")
        for key in ("max_nutrition", "max_water", "hygiene", "bowels", "stamina", "max_stamina", "nude"):
            self.assertIn(f'out["{key}"]', source)

    def test_system_prompt_explains_the_director_role(self):
        self.assertIn("You are the director", autopilot.SYSTEM)
        self.assertIn('"routine"', autopilot.SYSTEM)
        self.assertIn('"priorities"', autopilot.SYSTEM)


SNARE_SET = {"ref": "[0xsnare]", "name": "snare", "type": "/obj/structure/stone_age_trap/snare", "trap": "set", "mine": True, "dx": 2, "dy": 0}
TRAP_GRASS = {"ref": "turf:12,10,1", "name": "grass", "type": "/turf/floor/grass", "dx": 2, "dy": 0}
CAVE = {"ref": "turf:11,10,1", "name": "underground", "type": "/turf/floor/dirt/underground", "dx": 1, "dy": 0}


def trap_step(script, self_row, nearby=(), terrain=()):
    sit, _ = situation(observe(self_row, nearby=nearby, terrain=terrain))
    return script(sit)


class NorthAmericaTests(unittest.TestCase):
    def test_fixed_amounts_scale_to_the_larger_pools(self):
        self.assertEqual(needs.scaled(me(max_water=500), "water", 350), 500)
        self.assertEqual(needs.scaled(me(max_nutrition=600), "nutrition", 200), 300)
        self.assertEqual(needs.scaled({}, "water", 250), 250)  # an older server without the max bars
        # 300 water of a 500 pool is not "very thirsty", 300 of the old 350 pool would be close.
        self.assertIsNone(autopilot.thirst_plan(observe(me(water=300, max_water=500), terrain=[RIVER])))
        self.assertIsNotNone(autopilot.thirst_plan(observe(me(water=250, max_water=500), terrain=[RIVER])))

    def test_deep_floodwater_walks_her_to_the_shallow_side(self):
        obs = observe(me())
        obs["here"] = {"turf": "grass", "flood": "waist-deep", "flood_band": 3}
        obs["surroundings"] = {"north": {"flood_band": 3}, "south": {"blocked": True}, "east": {}, "west": {"flood_band": 4}}
        sit, _ = situation(obs)
        self.assertLess(sit.levels["safety"], needs.CRITICAL["safety"])
        choice = quiet().choose(sit)
        self.assertEqual(choice.name, "leave flood")
        self.assertEqual(choice.plan, [{"do": "explore", "dir": "east"}])
        obs["here"] = {"flood_band": 1}  # ankle-deep is no reason to move
        sit, _ = situation(obs)
        self.assertEqual(sit.levels["safety"], 100.0)
        self.assertIsNone(routines.plan_leave_flood(sit))

    def test_traps_craft_set_and_tend(self):
        stones = holding(items=[{"name": "stone", "amount": 3}])
        self.assertEqual(trap_step(scripts.traps, stones), [{"do": "craft", "recipe": "deadfall trap", "material": "stone"}])
        rope = holding(items=[{"name": "rope", "amount": 2}, {"name": "stone pickaxe"}])
        self.assertEqual(trap_step(scripts.traps, rope), [{"do": "craft", "recipe": "snare", "material": "rope"}])
        kit = holding("snare")
        self.assertEqual(trap_step(scripts.traps, kit, terrain=[CAVE, TRAP_GRASS]), [{"do": "set_trap", "target": "turf:12,10,1"}])
        # A set trap is never touched (an empty hand takes it up); a caught or sprung one of hers is.
        self.assertEqual(trap_step(scripts.traps, holding(), [SNARE_SET]), scripts.DONE)
        caught = dict(SNARE_SET, trap="caught")
        self.assertEqual(trap_step(scripts.traps, holding(), [caught]), [{"do": "check_trap", "target": "[0xsnare]"}])
        self.assertEqual(trap_step(scripts.traps, holding(), [dict(caught, mine=False)]), scripts.DONE)
        weir = {"ref": "[0xweir]", "name": "fish weir", "fish": 2, "mine": True, "dx": 1, "dy": 0}
        self.assertEqual(trap_step(scripts.traps, holding(), [weir]), [{"do": "check_trap", "target": "[0xweir]"}])
        self.assertEqual(scripts.name_of("snares"), "traps")

    def test_a_caught_trap_comes_before_hunting(self):
        armed = holding("sharpened stick", "sharpened flint")
        caught = dict(SNARE_SET, trap="caught")
        self.assertEqual(next_step(scripts.hunt, armed, [DEER, caught]), [{"do": "check_trap", "target": "[0xsnare]"}])

    def test_trap_skills_expand_to_player_clicks(self):
        rows = {TRAP_GRASS["ref"]: dict(TRAP_GRASS, dx=1), SNARE_SET["ref"]: dict(SNARE_SET, dx=1)}
        steps, error = autopilot.expand_skill({"skill": "set_trap", "target": TRAP_GRASS["ref"]}, holding("snare"), rows)
        self.assertEqual(error, "")
        self.assertEqual(steps[-1], {"do": "click", "target": TRAP_GRASS["ref"]})
        steps, error = autopilot.expand_skill({"skill": "check_trap", "target": SNARE_SET["ref"]}, holding(), rows)
        self.assertTrue(error)  # a set trap is refused: an empty hand would take it up
        rows[SNARE_SET["ref"]]["trap"] = "sprung"
        steps, error = autopilot.expand_skill({"skill": "check_trap", "target": SNARE_SET["ref"]}, holding("spear"), rows)
        self.assertEqual(error, "")
        self.assertEqual(steps[-1], {"do": "click", "target": SNARE_SET["ref"]})

    def test_north_american_predators(self):
        for name in ("jaguar", "polar bear", "constrictor", "cobra"):
            self.assertTrue(autopilot.is_predator({"name": name, "type": "/mob/living/simple_animal/x", "mob": True}), name)
        self.assertFalse(autopilot.is_predator({"name": "bison", "type": "/mob/living/simple_animal/bison", "mob": True}))


class AutospawnSourceTests(unittest.TestCase):
    def test_autospawn_config_and_round_start_hook(self):
        control = (ROOT / "code/modules/agent_control/agent_control.dm").read_text(encoding="utf-8")
        self.assertIn('if ("autospawn")', control)
        source = (ROOT / "code/modules/agent_control/agent_autospawn.dm").read_text(encoding="utf-8")
        self.assertIn("/hook/roundstart/proc/agent_autospawn_start()", source)
        self.assertIn("persistence_owner_ckey = agent_account_for(agent_name)", source)
        self.assertIn("C.awaiting_driver = TRUE", source)
        self.assertIn("adopt_travellers(A)", source)  # a restored body is adopted, not doubled
        dme = (ROOT / "civ13.dme").read_text(encoding="utf-8")
        self.assertIn("code\\modules\\agent_control\\agent_autospawn.dm", dme)

    def test_restored_bodies_wait_for_a_driver_but_arrivals_do_not(self):
        travel = (ROOT / "code/modules/agent_control/agent_travel.dm").read_text(encoding="utf-8")
        self.assertIn("var/restored = !H.region_arrival_pending", travel)
        self.assertIn("if (restored)\n\t\t\tC.awaiting_driver = TRUE", travel)

    def test_observe_reports_floods_and_traps_but_not_hidden_pits(self):
        source = (ROOT / "code/modules/agent_control/agent_characters.dm").read_text(encoding="utf-8")
        self.assertIn('here_row["flood_band"]', source)
        self.assertIn('side["flood_band"]', source)
        self.assertIn('!istype(AM, /obj/structure/stone_age_trap/pit)', source)


if __name__ == "__main__":
    unittest.main()
