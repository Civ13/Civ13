"""Validate the bounded species-fallback native receipt; no runtime launcher."""
import math

CASES = ("crab_legacy", "crab_mixed", "mosquito_legacy", "mosquito_mixed", "setter", "partial")
MIN_CHECKS = 187  # Six cases plus eight validated samples in each of four quiet windows.
EVENTS = frozenset(("start", "end", "move_before", "move_after", "completion",
    "life_before", "life_after", "command_before", "command_after", "before_stop",
    "after_stop", "before_disable", "after_disable", "replacement_stop",
    "partial_before", "partial_after", "fault_base_off", "fallback_refused", "partial_stopped",
    "quiet_sample", "wild_before", "wild_after", "step_before", "step_after"))


def require(ok, reason):
    if not ok:
        raise ValueError(reason)


def number(value):
    return type(value) in (int, float) and math.isfinite(value)


def one(events, label):
    result = [e for e in events if e.get("event") == label]
    require(len(result) == 1, "expected exactly one " + label)
    return result[0]


def position(e):
    require(all(type(e.get(k)) is int for k in ("x", "y", "z", "sx", "sy")), "coordinate types")
    require(1 <= e["x"] <= 18 and 1 <= e["y"] <= 14 and e["z"] == 1
            and 0 <= e["sx"] < 32 and 0 <= e["sy"] < 32, "coordinate bounds")
    return (e["x"] * 32 + e["sx"], e["y"] * 32 + e["sy"])


def owner_identity(event):
    detail = event.get("detail")
    require(isinstance(detail, dict), "missing owner details")
    require(all(type(detail.get(k)) is int and detail[k] >= 0
                for k in ("owner_generation", "owner_revision")), "malformed owner identity")
    return detail["owner_generation"], detail["owner_revision"]


def quiet(events, stop):
    index = events.index(stop)
    tail = events[index + 1:-1]
    require(len(tail) >= 8 and all(e.get("event") == "quiet_sample" for e in tail), "quiet coverage or unexpected admission")
    previous = stop["time"]
    for e in tail:
        require(0 < e["time"] - previous <= 0.500001, "quiet sampling gap")
        require(not e["transaction"] and not e["pulse"] and not e["wild"]
                and e["generation"] == stop["generation"] and position(e) == position(stop), "quiet owner or motion")
        previous = e["time"]
    require(tail[-1]["time"] - stop["time"] >= 4 and events[-1]["time"] == tail[-1]["time"], "truncated quiet window")


def validate(receipt, head):
    require(isinstance(head, str) and len(head) == 40 and all(c in "0123456789abcdef" for c in head), "head")
    require(isinstance(receipt, dict) and receipt.get("head") == head and receipt.get("error") is None
            and receipt.get("port") == 0 and (receipt.get("byond_version"), receipt.get("byond_build")) == (516, 1688),
            "failed fixture or wrong engine/head")
    require(receipt.get("scope") == "manual crab Life and mosquito helper; no scheduler/client parity", "scope")
    rows = receipt.get("species_rows")
    require(isinstance(rows, list) and len(rows) == len(CASES) and
            [r.get("case") for r in rows] == list(CASES), "incomplete case set")
    require(type(receipt.get("species_checks")) is int and receipt["species_checks"] >= MIN_CHECKS, "missing assertions")
    previous_case_end = None
    for ident, (case, row) in enumerate(zip(CASES, rows), 1):
        require(type(row.get("id")) is int and row["id"] == ident, "case lifetime")
        ev = row.get("events")
        require(isinstance(ev, list) and 2 <= len(ev) <= 512 and
                ev[0].get("event") == "start" and ev[-1].get("event") == "end", "event boundaries")
        require(number(ev[0].get("time")) and (previous_case_end is None or ev[0]["time"] >= previous_case_end),
                "overlapping case lifetimes")
        stack = []
        physical = position(ev[0])
        previous = None
        moves = 0
        calls = []
        health = ev[0].get("health")
        for e in ev:
            require(isinstance(e, dict) and e.get("case") == case and type(e.get("id")) is int and e["id"] == ident
                    and type(e.get("generation")) is int and e["generation"] >= 0
                    and e.get("event") in EVENTS and number(e.get("time")) and number(e.get("ticks"))
                    and number(e.get("tick_lag")) and e["tick_lag"] == 0.5
                    and 0 <= e["ticks"] < 100 and number(e.get("health")) and e["health"] == health, "event")
            require(previous is None or e["time"] >= previous, "event order")
            previous = e["time"]
            position(e)
            require(all(type(e.get(k)) is int for k in ("bx", "by", "bw", "bh", "step_size", "locs", "map_x", "map_y", "icon_size"))
                    and (e["bx"], e["by"], e["bw"], e["bh"]) == (0, 0, 32, 32)
                    and (e["map_x"], e["map_y"], e["icon_size"]) == (18, 14, 32)
                    and 1 <= e["step_size"] <= 32 and 1 <= e["locs"] <= 4, "physical shape")
            for key in ("enabled", "species_enabled", "owned", "transaction", "pulse", "wild"):
                require(type(e.get(key)) is int and e[key] in (0, 1), "boolean state")
            if e["event"] in ("wild_before", "step_before", "move_before"):
                calls.append(e["event"][:-7])
            elif e["event"] in ("wild_after", "step_after", "move_after"):
                require(calls and calls.pop() == e["event"][:-6], "unpaired admission callback")
            if e["event"] == "move_before":
                require(stack or position(e) == physical, "unobserved movement before Move")
                stack.append(position(e))
            elif e["event"] == "move_after":
                require(stack, "unpaired move exit")
                before = stack.pop()
                after = position(e)
                require(abs(after[0] - before[0]) <= 32 and abs(after[1] - before[1]) <= 32, "move displacement")
                moves += 1
                if not stack:
                    physical = after
            elif not stack:
                require(position(e) == physical, "unobserved displacement")
        require(not stack and not calls, "missing callback exit")
        require(not ev[-1]["transaction"] and not ev[-1]["pulse"] and not ev[-1]["wild"], "terminal ownership")
        require(type(row.get("completions")) is int and row["completions"] >= 0
                and row["completions"] == sum(e["event"] == "completion" for e in ev), "completion count")
        require(ev[-1]["time"] - ev[0]["time"] <= 32, "case deadline")
        previous_case_end = ev[-1]["time"]
        require(position(ev[0]) == (6 * 32, (5 if case.startswith("crab") else 8 if case.startswith("mosquito") else 11) * 32), "initial geometry")
        require(not ev[0]["enabled"] and not ev[0]["owned"] and not ev[0]["transaction"] and not ev[0]["pulse"] and not ev[0]["wild"], "initial ownership")
        if case.startswith("crab"):
            before, after = one(ev, "life_before"), one(ev, "life_after")
            require(ev.index(before) < ev.index(after) and any(e["event"] == "move_before" for e in ev[ev.index(before) + 1:ev.index(after)]), "crab Life ordering")
            require(before["species_enabled"] == (case == "crab_mixed") and not before["enabled"], "crab flags")
            require(abs(position(after)[0] - position(before)[0]) == 32
                    and position(after)[1] == position(before)[1] and moves > 0
                    and not after["transaction"] and not after["pulse"] and after.get("turns") == 0, "crab movement")
        elif case.startswith("mosquito"):
            command, returned, pre_stop, stop = (one(ev, k) for k in
                ("command_before", "command_after", "before_stop", "after_stop"))
            require(ev.index(command) < ev.index(returned) < ev.index(pre_stop) < ev.index(stop)
                    and position(pre_stop) == position(stop) and stop["time"] - command["time"] >= 7
                    and ev[-1]["time"] - stop["time"] >= 4, "native timing window")
            require(command["species_enabled"] == (case == "mosquito_mixed") and not command["enabled"], "mosquito flags")
            quiet(ev, stop)
            require(position(stop)[0] > position(command)[0] and position(stop)[1] == position(command)[1]
                    and position(ev[-1]) == position(stop) and moves > 0
                    and not stop["transaction"] and not stop["pulse"] and not stop["wild"], "native movement or stop")
        elif case == "setter":
            before, after, stop = one(ev, "before_disable"), one(ev, "after_disable"), one(ev, "replacement_stop")
            require(ev.index(before) < ev.index(after) < ev.index(stop) and stop["time"] - after["time"] >= 7
                    and ev[-1]["time"] - stop["time"] >= 4, "replacement timing window")
            require(before["enabled"] and before["species_enabled"] and before["wild"]
                    and not before["transaction"] and not before["pulse"]
                    and before["sx"] == before["sy"] == after["sx"] == after["sy"] == 0
                    and position(before) == position(after), "aligned owner")
            require(not after["enabled"] and not after["wild"] and isinstance(after.get("detail"), dict)
                    and type(after["detail"].get("old_cancelled")) is int and after["detail"]["old_cancelled"] == 1
                    and owner_identity(before) == owner_identity(after)
                    and owner_identity(before)[0] == before["generation"], "old owner retirement")
            require(sum(e["event"] == "wild_before" for e in ev[:ev.index(before)]) == 1, "wild observation not reached")
            quiet(ev, stop)
            require(position(stop)[0] > position(after)[0] and position(ev[-1]) == position(stop)
                    and not stop["transaction"] and not stop["pulse"] and not stop["wild"] and moves > 0, "replacement")
        else:
            before, after, fault, refused, stopped = (one(ev, k) for k in
                ("partial_before", "partial_after", "fault_base_off", "fallback_refused", "partial_stopped"))
            require(ev.index(before) < ev.index(after) < ev.index(fault) < ev.index(refused) < ev.index(stopped)
                    and ev[-1]["time"] - stopped["time"] >= 4, "partial ordering")
            require(not fault["enabled"] and not refused["enabled"] and position(fault) == position(refused)
                    and refused["transaction"] and refused["wild"] and isinstance(refused.get("detail"), dict)
                    and refused["detail"].get("result") == 0 and refused["detail"].get("same_owner") == 1
                    and refused["detail"].get("same_tx") == 1, "partial fallback refused")
            require(before["enabled"] and before["wild"] and before["transaction"] and before["owned"]
                    and (before["sx"] or before["sy"]) and position(before) == position(after)
                    and after["enabled"] and after["wild"] and after["transaction"]
                    and before["generation"] == after["generation"]
                    and owner_identity(before) == owner_identity(after)
                    and owner_identity(before)[0] == before["generation"], "active opt-out")
            require(sum(e["event"] == "wild_before" for e in ev[:ev.index(before)]) == 1
                    and sum(e["event"] == "step_before" for e in ev[:ev.index(before)]) >= 1, "admission observation not reached")
            quiet(ev, stopped)
            require(not stopped["transaction"] and not stopped["pulse"] and not stopped["wild"]
                    and row.get("completions") == 1 and len([e for e in ev if e["event"] == "completion"]) == 1
                    and position(ev[-1]) == position(stopped), "partial cleanup")
    return {"head": head, "cases": list(CASES), "native_coverage": "manual crab Life and mosquito helper only"}
