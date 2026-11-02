"""Unwired host contract for one hostile scheduler observation."""
import math
import json

EVENTS = frozenset(("life_before", "life_after", "move_before", "move_after",
    "attack_before", "attack_after", "lost_completion_hook", "sample",
    "target_intro_before", "target_intro_after", "target_relocate_before",
    "target_relocate_after", "target_loss_before", "target_loss_after",
    "quiet_start", "quiet_sample", "quiet_end", "cleanup"))
EVENT_FIELDS = frozenset(("event", "phase", "at", "x", "y", "z", "sx", "sy",
    "bx", "by", "bw", "bh", "generation", "stance", "owned", "transaction",
    "transaction_old", "transaction_generation", "transaction_owner", "pulse",
    "pursuit", "pursuit_old", "wild", "follow", "flee", "pet", "recovery",
    "pending", "target_matches", "actor_faction", "target_faction", "target_x",
    "target_y", "target_z", "target_sx", "target_sy", "target_bx", "target_by",
    "target_bw", "target_bh", "target_damage", "target_adjacent", "old_finished",
    "old_completions", "wander_moves", "attacks", "positive_attacks",
    "damage_before", "result", "call_id"))
FLAGS = ("owned", "transaction", "transaction_old", "pulse", "pursuit",
    "pursuit_old", "wild", "follow", "flee", "pet", "recovery", "pending",
    "target_matches", "target_adjacent", "old_finished")
COUNTS = ("generation", "old_completions", "wander_moves", "attacks", "positive_attacks")


def require(ok, message):
    if not ok:
        raise ValueError(message)


def integer(x):
    return type(x) is int


def number(x):
    return type(x) in (int, float) and math.isfinite(x)


def validate(row):
    require(type(row) is dict and row.get("tick_lag_ds") == 0.5
            and row.get("actual_clients") == 0 and row.get("life_interval_ds") == 10
            and row.get("start_delay_ds") == 6 and integer(row.get("process_ticks"))
            and row["process_ticks"] > 0, "scheduler configuration")
    require(number(row.get("started")) and number(row.get("ended"))
            and row["started"] < row["ended"] <= row["started"] + 220, "time bound")
    events = row.get("events")
    require(type(events) is list and 0 < len(events) <= 2048, "event bound")
    previous = row["started"]
    previous_actor = None
    moves = {}
    attacks = {}
    phases = {}
    positive = False
    pursuit_progress = False
    wander_progress = False
    after_loss = False
    for e in events:
        require(type(e) is dict and set(e) == EVENT_FIELDS and len(json.dumps(e, ensure_ascii=True, separators=(",", ":")).encode("ascii")) <= 900,
                "event size")
        require(e.get("event") in EVENTS
                and e.get("phase") in ("wander", "acquire", "reacquire", "lost", "quiet"), "event kind")
        require(number(e.get("at")) and previous <= e["at"] <= row["ended"], "event time")
        previous = e["at"]
        require(all(integer(e.get(k)) and 0 <= e[k] for k in COUNTS), "counter type")
        require(all(type(e.get(k)) in (int, bool) and e[k] in (0, 1) for k in FLAGS), "flag type")
        require(all(integer(e.get(k)) for k in ("x", "y", "z", "sx", "sy", "bx", "by", "bw", "bh"))
                and 1 <= e["x"] <= 18 and 1 <= e["y"] <= 14 and e["z"] == 1
                and 0 <= e["sx"] < 32 and 0 <= e["sy"] < 32
                and (e["bx"], e["by"], e["bw"], e["bh"]) == (0, 0, 32, 32), "actor geometry")
        position = (e["x"], e["y"], e["z"], e["sx"], e["sy"])
        require(previous_actor is None or previous_actor == position or bool(moves), "unobserved actor displacement")
        previous_actor = position
        if e.get("target_x") is not None:
            require(all(integer(e.get(k)) for k in ("target_x", "target_y", "target_z", "target_sx", "target_sy",
                    "target_bx", "target_by", "target_bw", "target_bh"))
                    and 1 <= e["target_x"] <= 18 and 1 <= e["target_y"] <= 14 and e["target_z"] == 1
                    and (e["target_sx"], e["target_sy"]) == (0, 0)
                    and (e["target_bx"], e["target_by"], e["target_bw"], e["target_bh"]) == (0, 0, 32, 32)
                    and number(e.get("target_damage")), "target geometry")
        else:
            require(all(e.get(k) is None for k in ("target_y", "target_z", "target_sx", "target_sy",
                    "target_bx", "target_by", "target_bw", "target_bh", "target_damage")), "absent target")
        require(e.get("actor_faction") == "neutral" and e.get("target_faction") in (None, "fixture-human", "neutral"), "fixture factions")
        if e["transaction"]:
            require(integer(e.get("transaction_generation"))
                    and e.get("transaction_owner") in
                    ("lost_pursuit", "pursuit", "recovery", "other", "wander_or_direct"), "transaction identity")
        else:
            require(e.get("transaction_generation") is None and e.get("transaction_owner") is None
                    and not e["transaction_old"], "absent transaction")
        require(sum(bool(e[k]) for k in ("pursuit", "wild", "follow", "flee", "pet")) <= 1,
                "overlapping continuous owners")
        kind = e["event"]
        if kind in ("target_intro_before", "target_intro_after", "target_relocate_before", "target_relocate_after", "target_loss_before", "target_loss_after", "quiet_start", "quiet_end"):
            require(kind not in phases, "duplicate phase boundary")
            phases[kind] = e
        if kind == "target_loss_after":
            after_loss = True
        if kind == "move_before":
            ident = e.get("call_id")
            require(integer(ident) and ident > 0 and ident not in moves, "move admission identity")
            require(not (after_loss and e["transaction_old"]), "late old move")
            moves[ident] = e
        elif kind == "move_after":
            ident = e.get("call_id")
            require(integer(ident) and ident in moves, "unpaired move return")
            before = moves.pop(ident)
            require(all(before[k] == e[k] for k in
                    ("generation", "transaction", "transaction_generation", "transaction_owner", "transaction_old")),
                    "move authority changed during callback")
            before_xy = (before["x"] * 32 + before["sx"], before["y"] * 32 + before["sy"])
            after_xy = (e["x"] * 32 + e["sx"], e["y"] * 32 + e["sy"])
            if before_xy != after_xy:
                require(before["transaction"] and before["pulse"]
                        and before["transaction_generation"] == before["generation"]
                        and abs(before_xy[0] - after_xy[0]) <= 2 and abs(before_xy[1] - after_xy[1]) <= 2,
                        "unauthenticated or oversized move")
            if before["phase"] == "wander" and not before["target_matches"] and before_xy != after_xy:
                wander_progress = True
            if before["transaction_owner"] == "pursuit" and before["target_matches"] and before_xy != after_xy:
                pursuit_progress = True
            require(not (after_loss and before["transaction_old"]), "late old move return")
        elif kind == "attack_before":
            ident = e["attacks"]
            require(ident > 0 and ident not in attacks and not after_loss, "unexpected attack")
            require(e["target_matches"] and e["target_adjacent"] and not e["transaction"]
                    and not e["pulse"] and not (e["sx"] or e["sy"])
                    and max(abs(e["x"] - e["target_x"]), abs(e["y"] - e["target_y"])) <= 1,
                    "attack before settlement")
            require(number(e.get("damage_before")) and e["damage_before"] == e["target_damage"], "attack damage preimage")
            attacks[ident] = e
        elif kind == "attack_after":
            ident = e["attacks"]
            require(ident in attacks and not after_loss, "unpaired attack return")
            before = attacks.pop(ident)
            require(e.get("damage_before") == before["damage_before"] and number(e.get("target_damage")), "attack damage return")
            if e["target_damage"] > before["damage_before"]:
                positive = True
    require(not moves and not attacks and positive and pursuit_progress and wander_progress, "missing progress or unpaired callback")
    boundary_names = ("target_intro_before", "target_intro_after", "target_relocate_before", "target_relocate_after",
                      "target_loss_before", "target_loss_after", "quiet_start", "quiet_end")
    require(set(phases) == set(boundary_names), "missing boundary")
    intro_before, intro, relocate_before, relocate, loss, lost, quiet, end = (phases[k] for k in boundary_names)
    boundary_order = [e["event"] for e in events if e["event"] in phases]
    require(boundary_order == list(boundary_names), "boundary order")
    order = {"wander": 0, "acquire": 1, "reacquire": 2, "lost": 3, "quiet": 4}
    require(all(order[a["phase"]] <= order[b["phase"]] for a, b in zip(events, events[1:])), "phase order")
    require(intro_before["phase"] == "wander" and intro["phase"] == "acquire"
            and relocate_before["phase"] == "acquire" and relocate["phase"] == "reacquire"
            and loss["phase"] == "reacquire" and lost["phase"] == "lost"
            and quiet["phase"] == end["phase"] == "quiet", "boundary phases")
    actor = lambda e: (e["x"], e["y"], e["z"], e["sx"], e["sy"], e["generation"])
    require(intro_before["target_x"] is None and actor(intro_before) == actor(intro)
            and abs(intro["target_x"] - intro["x"]) == 4 and intro["target_y"] == intro["y"], "target introduction")
    require(actor(relocate_before) == actor(relocate)
            and abs(relocate["target_x"] - relocate["x"]) == 4 and relocate["target_y"] == relocate["y"]
            and (relocate["target_x"], relocate["target_y"]) != (relocate_before["target_x"], relocate_before["target_y"]),
            "target relocation")
    require(intro["wander_moves"] > 0 and intro["actor_faction"] != intro.get("target_faction"), "wander or target eligibility")
    require(relocate["positive_attacks"] > 0, "relocated before contact")
    require(loss["pursuit_old"] and loss["transaction_old"] and loss["transaction"]
            and loss["owned"] and (loss["sx"] or loss["sy"]) and loss["target_matches"], "loss not during owned pursuit")
    require(not lost["target_matches"] and lost.get("target_faction") == lost["actor_faction"], "target remains eligible")
    require(all(number(e["target_damage"]) and e["target_damage"] <= loss["target_damage"]
                for e in events if e["phase"] in ("lost", "quiet")), "post-loss damage")
    require(quiet["old_finished"] and end["old_finished"] and quiet["old_completions"] == end["old_completions"] == 1
            and not quiet["pursuit_old"] and not end["pursuit_old"]
            and end["at"] - quiet["at"] >= 4, "old owner or quiet boundary")
    require(all(not e["transaction_old"] and not e["pursuit_old"] for e in events if e["phase"] == "quiet"), "old authority in quiet")
    cleanup = events[-1]
    require(cleanup["event"] == "cleanup" and cleanup["phase"] == "quiet"
            and all(not cleanup[k] for k in ("transaction", "pulse", "pursuit", "wild", "follow", "flee", "pet", "recovery", "pending")),
            "terminal authority cleanup")
    return {"events": len(events), "old_completions": end["old_completions"],
            "positive_contact": positive, "pursuit_progress": pursuit_progress,
            "quiet_ds": end["at"] - quiet["at"]}
SCOPE = "headless mob scheduler; hostile pursuit and contact; no client parity"

def validate_receipt(receipt, head):
    require(type(receipt) is dict and receipt.get("head") == head and receipt.get("error") is None
            and receipt.get("port") == 0 and (receipt.get("byond_version"), receipt.get("byond_build")) == (516, 1688)
            and receipt.get("scope") == SCOPE and integer(receipt.get("transition_checks"))
            and receipt["transition_checks"] > 0 and receipt.get("transition_phase") == "quiet", "receipt identity")
    rows = receipt.get("transition_rows")
    require(type(rows) is list and len(rows) == 1, "one hostile scenario")
    observed = validate(rows[0])
    require(receipt.get("transition_partial") == rows[0]["events"], "partial trace binding")
    return observed