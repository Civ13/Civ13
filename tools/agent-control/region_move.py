#!/usr/bin/env python3
"""Move a player's character to another region of a shard group, keeping what they have.

For an admin on the host, through each region's operator agent (docs/agent-control.md,
"Host operator agent"). One player at a time:

  1. snapshot  - every item they wear and hold with what is inside it (names, stack
                 amounts, reagents), knowledge, skills, languages, faction, food and
                 water, saved as JSON before anything moves;
  2. hold      - anything the source build refuses to send (region_travel_items) goes
                 into a crate at their feet, never deleted;
  3. send      - a hidden temporary gate at their feet runs the normal departure
                 (region_gate/depart), then is deleted;
  4. arrive    - waits for the character on the destination (the player logs in there);
  5. place     - optionally moves them to a tile (--at x,y,z) and takes their crate along;
  6. rebuild   - remakes the held items in a crate beside them from the snapshot, with
                 materials, names, amounts, reagents, contents, attached accessories and
                 a boot's knife, then reads it back and compares;
  7. restore   - only adds: missing languages, recipe knowledge, role verbs, and food
                 and water as they were. A faction is reported, never forced: the
                 destination rejoins a traveller to it only where it or its colony lives;
  8. clean up  - deletes the source holding crate once the rebuilt one matched.

Without --apply it only takes the snapshot and lists what would be held back. A run
that stops after the departure (the player has not logged in yet) writes a state file
next to the snapshot; --resume <state file> picks up from the arrival.

The rebuild remakes items by type, name, material, stack amount, reagents and
contents. Wear, quality, written text and tool parts are not carried; on a build
that sends everything natively (#5557 and later) nothing is held back at all.

  py -3 tools/agent-control/region_move.py --group D:/Civ13Regions/earth.json \\
      --from northamerica --to gaia --ckey somebody --at 87,290,2 --apply

Exact restore is limited by the agent protocol: partial language scores and skill
values are compared and reported, not written. A destination on a newer build may
take more natively; the restore steps are then no-ops.
"""
import argparse
import json
import os
import re
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from civ13_agent import AgentClient  # noqa: E402

SLOTS = ("l_hand", "r_hand", "back", "belt", "w_uniform", "wear_suit", "head", "shoes", "gloves",
         "wear_mask", "glasses", "l_ear", "r_ear", "wear_id", "l_store", "r_store", "s_store")
MOB_VARS = ("real_name", "gender", "age", "stats", "known_recipe_nodes", "recipe_knowledge_initialized",
            "scholarship", "study_progress", "partial_languages", "civilization", "nutrition", "water",
            "riding", "riding_mob", "pulling", "buckled", "persistence_owner_ckey", "original_job_title")
MATERIALS = {"bronze", "flint", "stone", "iron", "copper", "steel", "bone", "wood", "wooden", "obsidian",
             "tin", "gold", "silver", "lead", "brass"}
# Quality words a name may carry before its material ("fine iron hatchet").
QUALITY = {"crude", "poor", "fine", "good", "excellent", "masterwork", "superior", "legendary"}
GATE = "/obj/structure/region_gate/sea_crossing"
CRATE = "/obj/structure/closet/crate"


# ---------------------------------------------------------------- pure helpers

def flat(value):
    """An agent-encoded value as plain JSON: lists, assoc lists and refs."""
    if isinstance(value, dict):
        if "assoc" in value:
            out = {}
            for key, item in value["assoc"]:
                out[str(key.get("name", key) if isinstance(key, dict) else key)] = flat(item)
            return out
        if "list" in value:
            return [flat(x) for x in value["list"]]
    return value


def refused_names(message):
    """Top-level item names from a refusal such as
    'Leave these behind first: backpack (take out a, b and c), torch and pack basket.'"""
    if not isinstance(message, str) or "first:" not in message:
        return []
    body = message.split("first:", 1)[1].strip().rstrip(".")
    body = re.sub(r"\s*\(take out [^)]*\)", "", body)
    return [n.strip() for n in re.split(r", | and ", body) if n.strip()]


def item_rows(entries, depth=0, out=None):
    """(depth, type, name, amount) for an item tree, for comparison."""
    out = [] if out is None else out
    for e in entries:
        held = tuple(sorted((r[0], round(float(r[1] or 0), 1)) for r in e.get("reagents") or [] if r and r[0]))
        out.append((depth, e["type"], e.get("name"), e.get("amount"), held))
        item_rows(e.get("contents") or [], depth + 1, out)
    return out


def compare(want, got):
    """Rows missing from got and rows got has extra, each as a list."""
    missing = list(want)
    extra = []
    for row in got:
        if row in missing:
            missing.remove(row)
        else:
            extra.append(row)
    return missing, extra


def parse_at(text):
    parts = text.split(",")
    if len(parts) != 3 or not all(p.strip().isdigit() for p in parts):
        raise SystemExit(f"--at must be x,y,z, not {text!r}")
    return [int(p) for p in parts]


def material_of(type_path, name):
    """The material word an item's name starts with (after a quality word), for material items."""
    if not type_path.startswith("/obj/item/weapon/material") or not name:
        return None
    for word in name.lower().split()[:3]:
        if word in MATERIALS:
            return word
        if word not in QUALITY:
            return None
    return None


# ---------------------------------------------------------------- one region

class Region:
    def __init__(self, group, region_id, client=None):
        self.id = region_id
        self.c = client or AgentClient.for_group_region(group, region_id)

    def req(self, action, args=None):
        return self.c.request(action, args)

    def call(self, target, proc, args=None, wait=0):
        r = self.req("call_proc", {"target": target, "proc": proc, "arguments": args or []})
        if not r.get("ok"):
            return {"error": r.get("detail") or r.get("error")}
        res = r["result"]
        deadline = time.monotonic() + wait
        while wait and not res.get("done") and time.monotonic() < deadline:
            time.sleep(1.5)
            res = self.req("job", {"job": res.get("job")}).get("result", res)
        return res.get("result") if res.get("done", True) else {"pending": res.get("job")}

    def vars(self, target, names):
        r = self.req("get_vars", {"target": target, "names": list(names)})
        return r.get("result", {}).get("vars", {}) if r.get("ok") else {}

    def inspect(self, target):
        r = self.req("inspect", {"target": target})
        return r.get("result") if r.get("ok") else None

    def setv(self, target, name, value):
        return self.req("set_var", {"target": target, "name": name, "value": value}).get("ok")

    def spawn(self, path, target):
        r = self.req("spawn_atom", {"type": path, "target": target})
        return r["result"]["spawned"][0]["ref"] if r.get("ok") else None

    def delete(self, target):
        return self.req("delete_atom", {"target": target}).get("ok")


# ---------------------------------------------------------------- steps

def snapshot_item(src, entry, depth=0):
    v = src.vars(entry["ref"], ["name", "amount", "reagents"])
    e = {"ref": entry["ref"], "type": entry["type"], "name": v.get("name"), "amount": v.get("amount")}
    holder = v.get("reagents")
    if isinstance(holder, dict) and holder.get("ref"):
        held = []
        for d in (src.vars(holder["ref"], ["reagent_list"]).get("reagent_list") or {}).get("list", []):
            if isinstance(d, dict) and d.get("ref"):
                rv = src.vars(d["ref"], ["id", "volume"])
                if rv.get("id"):
                    held.append([rv["id"], rv.get("volume")])
        if held:
            e["reagents"] = held
    if depth < 5:
        found = src.inspect(entry["ref"]) or {}
        kids = [snapshot_item(src, k, depth + 1) for k in found.get("contents", []) if not k["type"].startswith("/obj/item/organ")]
        if kids:
            e["contents"] = kids
    return e


def snapshot(src, ckey):
    mob = src.inspect(f"ckey:{ckey}")
    if not mob:
        raise SystemExit(f"{ckey} has no character on {src.id}")
    ref = mob["ref"]
    snap = {"region": src.id, "ckey": ckey, "taken": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "mob": {k: mob.get(k) for k in ("ref", "type", "name", "x", "y", "z", "area", "stat", "health")}}
    snap["items"] = [snapshot_item(src, m) for m in mob.get("contents", []) if not m["type"].startswith("/obj/item/organ")]
    slot_vars = src.vars(ref, SLOTS)
    snap["slots"] = {s: v["ref"] for s, v in slot_vars.items() if isinstance(v, dict) and v.get("ref")}
    raw = src.vars(ref, MOB_VARS)
    snap["vars"] = {k: flat(v) for k, v in raw.items()}
    # Lists past the agent's cap come back cut short; never write one back.
    snap["truncated"] = [k for k, v in raw.items() if isinstance(v, dict) and v.get("truncated")]
    langs = src.vars(ref, ["languages", "default_language"])
    names = []
    for d in (langs.get("languages") or {}).get("list", []):
        if isinstance(d, dict) and d.get("ref"):
            names.append(src.vars(d["ref"], ["name"]).get("name"))
    default = langs.get("default_language")
    snap["languages"] = [n for n in names if n]
    snap["default_language"] = src.vars(default["ref"], ["name"]).get("name") if isinstance(default, dict) and default.get("ref") else None
    snap["damage"] = {k: src.call(ref, p) for k, p in (("brute", "getBruteLoss"), ("oxy", "getOxyLoss"), ("tox", "getToxLoss"))}
    snap["refusal"] = src.call(ref, "region_travel_items")
    return snap


def hold(src, ckey, names):
    """Moves the named top-level items into a crate at the character's feet."""
    mob = src.inspect(f"ckey:{ckey}")
    crate = src.spawn(CRATE, mob["ref"])
    for k in (src.inspect(crate) or {}).get("contents", []):
        src.delete(k["ref"])
    pending = list(names)
    moved = []
    for m in mob.get("contents", []):
        if m["name"] in pending and not m["type"].startswith("/obj/item/organ"):
            pending.remove(m["name"])
            src.call(mob["ref"], "drop_from_inventory", [{"ref": m["ref"]}])
            src.call(m["ref"], "forceMove", [{"ref": crate}])
            moved.append(m["ref"])
    # Taking off a uniform drops its pockets and ID to the ground; those go in the crate too.
    still = {k["ref"] for k in (src.inspect(f"ckey:{ckey}") or {}).get("contents", [])}
    for m in mob.get("contents", []):
        if m["ref"] in moved or m["ref"] in still or m["type"].startswith("/obj/item/organ"):
            continue
        found = src.inspect(m["ref"]) or {}
        if str((found.get("loc") or {}).get("type", "")).startswith("/turf"):
            src.call(m["ref"], "forceMove", [{"ref": crate}])
            moved.append(m["ref"])
    return crate, moved, pending


def send(src, ckey, destination):
    mob = src.inspect(f"ckey:{ckey}")
    ref, at = mob["ref"], [mob["x"], mob["y"], mob["z"]]
    gate = src.spawn(GATE, ref)
    src.setv(gate, "destination", destination)
    result = src.call(gate, "depart", [{"ref": ref}], wait=300)
    if isinstance(result, dict) and result.get("pending"):
        # Still recording the trip: pulling them out now could lose what they carry.
        return f"still departing after 5 minutes (job {result['pending']}); gate {gate} left in place for an admin"
    if result != "departed":
        # Never leave anyone inside the gate.
        src.call(ref, "forceMove", [{"turf": at}])
    src.delete(gate)
    return result


def wait_arrival(dst, ckey, seconds):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        mob = dst.inspect(f"ckey:{ckey}")
        if mob and mob.get("type", "").startswith("/mob/living/human"):
            return mob
        time.sleep(3)
    return None


def build_item(dst, e, parent, parent_type, made_here, at):
    reuse = None
    for pair in list(made_here or []):
        if pair[1] == e["type"]:
            reuse = pair[0]
            made_here.remove(pair)
            break
    ref = reuse or dst.spawn(e["type"], at)
    if not ref:
        return [f"could not make {e.get('name')} ({e['type']})"]
    problems = []
    mat = material_of(e["type"], e.get("name"))
    if mat:
        dst.call(ref, "set_material", [mat])
    if e.get("name"):
        dst.setv(ref, "name", e["name"])
    if e["type"].startswith("/obj/item/stack") and isinstance(e.get("amount"), (int, float)):
        dst.setv(ref, "amount", int(e["amount"]))
        dst.call(ref, "update_icon")
    held = [p for p in e.get("reagents") or [] if p and p[0]]
    if held:
        holder = dst.vars(ref, ["reagents"]).get("reagents")
        if isinstance(holder, dict) and holder.get("ref"):
            dst.call(holder["ref"], "clear_reagents")
            for rid, volume in held:
                dst.call(holder["ref"], "add_reagent", [rid, volume])
        else:
            problems.append(f"{e.get('name')}: nowhere to put {held}")
    if not reuse:
        if e["type"].startswith("/obj/item/clothing/accessory") and parent_type.startswith("/obj/item/clothing"):
            current = (dst.vars(parent, ["accessories"]).get("accessories") or {}).get("list", [])
            refs = [x["ref"] for x in current if isinstance(x, dict) and x.get("ref")]
            dst.setv(parent, "accessories", {"list": [{"ref": r} for r in refs + [ref]]})
            dst.call(ref, "on_attached", [{"ref": parent}])
        else:
            dst.call(ref, "forceMove", [{"ref": parent}])
            if parent_type.startswith("/obj/item/clothing/shoes"):
                dst.setv(parent, "holding", {"ref": ref})
    fresh = [[k["ref"], k["type"]] for k in (dst.inspect(ref) or {}).get("contents", [])]
    for child in e.get("contents") or []:
        problems += build_item(dst, child, ref, e["type"], fresh, at)
    # What a new item made itself that the snapshot did not hold goes, so nothing doubles.
    for pair in fresh:
        if not pair[1].startswith("/obj/item/organ"):
            dst.delete(pair[0])
    return problems


def read_tree(dst, ref):
    out = []
    for k in (dst.inspect(ref) or {}).get("contents", []):
        e = snapshot_item(dst, k, 5)
        e["contents"] = read_tree(dst, k["ref"])
        out.append(e)
    return out


def rebuild(dst, ckey, entries):
    mob = dst.inspect(f"ckey:{ckey}")
    crate = dst.spawn(CRATE, mob["ref"])
    for k in (dst.inspect(crate) or {}).get("contents", []):
        dst.delete(k["ref"])
    problems = []
    for e in entries:
        problems += build_item(dst, e, crate, CRATE, None, mob["ref"])
    # A crate may be open; close it and gather anything left at its feet that we made.
    dst.call(crate, "close")
    missing, extra = compare(item_rows(entries), item_rows(read_tree(dst, crate)))
    return crate, missing, extra, problems


def restore(dst, ckey, snap):
    target = f"ckey:{ckey}"
    done = []
    have = dst.vars(target, ["known_recipe_nodes", "civilization", "languages"])
    known = flat(have.get("known_recipe_nodes")) or []
    wanted = snap["vars"].get("known_recipe_nodes") or []
    union = list(known) + [n for n in wanted if n not in known]
    if (have.get("known_recipe_nodes") or {}).get("truncated") or "known_recipe_nodes" in snap.get("truncated", []):
        done.append("knowledge not written (more than the agent lists; use Restore Research Knowledge)")
    elif len(union) > len(known):
        dst.setv(target, "known_recipe_nodes", {"list": union})
        done.append(f"knowledge +{len(union) - len(known)}")
    spoken = []
    for d in (have.get("languages") or {}).get("list", []):
        if isinstance(d, dict) and d.get("ref"):
            spoken.append(dst.vars(d["ref"], ["name"]).get("name"))
    order = ([snap.get("default_language")] if snap.get("default_language") else []) + snap.get("languages", [])
    for name in dict.fromkeys(n for n in order if n):
        if name not in spoken and dst.call(target, "add_language", [name]) == 1:
            done.append(f"language {name}")
    civ = snap["vars"].get("civilization")
    if civ and civ != "none" and have.get("civilization") != civ:
        # Reported, not forced: rejoining is the destination's call (colony_arrival).
        done.append(f"faction not restored: was {civ}, now {have.get('civilization')}; an admin can add them")
    verbs = dst.call(target, "restore_role_verbs")
    failed = isinstance(verbs, dict) and verbs.get("error")
    done.append(f"role verbs failed: {verbs['error']}" if failed else "role verbs")
    for key in ("nutrition", "water"):
        if isinstance(snap["vars"].get(key), (int, float)):
            dst.setv(target, key, snap["vars"][key])
    done.append("food and water")
    # Reported, not written: the agent cannot set keyed lists.
    after = dst.vars(target, ["stats", "partial_languages"])
    skills = flat(after.get("stats")) or {}
    lower = {k: (v, skills.get(k)) for k, v in (snap["vars"].get("stats") or {}).items()
             if isinstance(v, list) and isinstance(skills.get(k), list) and skills[k][0] < v[0]}
    partial = flat(after.get("partial_languages")) or {}
    lost = {k: (v, partial.get(k, 0)) for k, v in (snap["vars"].get("partial_languages") or {}).items()
            if isinstance(v, (int, float)) and v > (partial.get(k) or 0)}
    return done, lower, lost


# ---------------------------------------------------------------- main

def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--group", required=True, help="shard group json, e.g. D:/Civ13Regions/earth.json")
    p.add_argument("--from", dest="source", required=True, help="region id the character is on")
    p.add_argument("--to", dest="destination", required=True, help="region id to move them to")
    p.add_argument("--ckey", required=True)
    p.add_argument("--at", help="x,y,z on the destination to place them (dry, open ground)")
    p.add_argument("--snapshots", default="data/transfer-snapshots", help="where snapshots are written")
    p.add_argument("--arrival-wait", type=int, default=240, help="seconds to wait for them on the destination")
    p.add_argument("--apply", action="store_true", help="move them; without it only snapshot and report")
    p.add_argument("--resume", help="state file written by a run that stopped after the departure")
    args = p.parse_args(argv)
    at = parse_at(args.at) if args.at else None
    if args.resume:
        with open(args.resume, encoding="utf-8") as f:
            return after_departure(args, json.load(f), at)

    src = Region(args.group, args.source)
    snap = snapshot(src, args.ckey)
    os.makedirs(args.snapshots, exist_ok=True)
    path = os.path.join(args.snapshots, f"{args.source}-{args.ckey}-{time.strftime('%Y%m%dT%H%M%S', time.gmtime())}.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(snap, f, indent=1, ensure_ascii=False)
    v = snap["vars"]
    names = refused_names(snap["refusal"])
    print(f"{snap['mob']['name']} ({args.ckey}) on {args.source} at {snap['mob']['x']},{snap['mob']['y']},{snap['mob']['z']}")
    print(f"  snapshot: {path}")
    print(f"  items: {len(item_rows(snap['items']))}, knowledge: {len(v.get('known_recipe_nodes') or [])}, "
          f"languages: {snap['languages']}, faction: {v.get('civilization')}")
    print(f"  held back by {args.source}: {names or 'nothing'}")
    if v.get("riding") or v.get("riding_mob") or v.get("pulling") or v.get("buckled"):
        print("  NOTE: riding, pulling or buckled; that does not come along")
    if not args.apply:
        print("dry run: nothing moved (add --apply)")
        return 0

    crate, moved, missing_names = hold(src, args.ckey, names) if names else (None, [], [])
    if missing_names:
        print(f"  could not find to hold: {missing_names}; stopping before anything leaves")
        return 1
    after = src.call(f"ckey:{args.ckey}", "region_travel_items")
    if isinstance(after, str):
        print(f"  still refused after holding: {after}; their items are in crate {crate}")
        return 1
    result = send(src, args.ckey, args.destination)
    print(f"  departure: {result}")
    if isinstance(result, str) and result.startswith("still departing"):
        print(f"  check {args.destination} for them before doing anything else; held items are in crate {crate}")
        return 1
    if result != "departed":
        print(f"  not sent; held items are in crate {crate} at their feet on {args.source}")
        return 1

    state = {"snapshot": path, "crate": crate, "moved": moved, "ckey": args.ckey,
             "source": args.source, "destination": args.destination, "group": args.group}
    state_path = path[:-5] + ".state.json"
    with open(state_path, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=1)
    return after_departure(args, state, at, snap, state_path)


def after_departure(args, state, at, snap=None, state_path=None):
    """Arrival, placing, rebuilding and restoring. Safe to run again with --resume."""
    if snap is None:
        with open(state["snapshot"], encoding="utf-8") as f:
            snap = json.load(f)
    group, ckey = state["group"], state["ckey"]
    src = Region(group, state["source"])
    dst = Region(group, state["destination"])
    by_ref = {e["ref"]: e for e in snap["items"]}
    resume = f"--resume {state_path or args.resume}"
    try:
        mob = wait_arrival(dst, ckey, args.arrival_wait)
        if not mob:
            print(f"  {ckey} has not arrived on {state['destination']} yet (they must log in); run again with {resume}")
            return 2
        print(f"  arrived at {mob['x']},{mob['y']},{mob['z']}")
        if at:
            moved_ok = dst.call(f"ckey:{ckey}", "forceMove", [{"turf": at}])
            print(f"  placed at {at[0]},{at[1]},{at[2]}: {'yes' if moved_ok == 1 else moved_ok}")
        if state.get("moved") and not state.get("rebuilt"):
            new_crate, missing, extra, problems = rebuild(dst, ckey, [by_ref[r] for r in state["moved"]])
            print(f"  rebuilt crate {new_crate}: missing {missing or 'none'}, extra {extra or 'none'}, problems {problems or 'none'}")
            state["rebuilt"] = new_crate
            if not missing and not extra:
                print(f"  source crate {state['crate']} deleted: {src.delete(state['crate'])}")
            else:
                print(f"  source crate {state['crate']} kept on {state['source']}: items exist in both crates until an admin compares and deletes one")
        done, lower, lost = restore(dst, ckey, snap)
    except Exception as exc:  # noqa: BLE001 - report and leave the way to resume
        print(f"  stopped after the departure: {exc!r}; the held items are safe in crate {state.get('crate')} on {state['source']}; run again with {resume}")
        return 3
    finally:
        if state_path or args.resume:
            with open(state_path or args.resume, "w", encoding="utf-8") as f:
                json.dump(state, f, indent=1)
    print(f"  restored: {', '.join(done)}")
    print(f"  skills now lower than before: {lower or 'none'}")
    print(f"  partial languages lower than before: {lost or 'none'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
