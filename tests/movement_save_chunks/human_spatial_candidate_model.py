"""Proposed conservative spatial proof over decoded fixtures, not DM or savefiles.

This model deliberately treats audit/default assertions as supplied inputs. It
must not be used as evidence that the native loader honors those assertions.
"""
SPECIAL = {"/obj/item/tape", "/obj/item/weapon/gun/projectile/automatic/stationary",
           "/obj/effect/effect/smoke/bad", "/obj/covers", "/obj/structure/TV",
           "/obj/structure/barricade", "/obj/structure/closet", "/obj/structure/simple_door",
           "/obj/structure/grille", "/obj/structure/iv_drip", "/obj/structure/optable",
           "/obj/structure/plant_pot", "/obj/structure/railing", "/obj/structure/bed",
           "/obj/structure/table", "/obj/structure/window", "/obj/structure/barbwire",
           "/obj/structure/vehicleparts/frame", "/obj/structure/lamp", "/obj/structure/props",
           "/obj/structure/basketball_hoop", "/obj/structure/multiz"}


def generic_object(path):
    return (isinstance(path, str) and path.startswith('/obj/') and
            not any(path == root or path.startswith(root + '/') for root in SPECIAL))
LINKS = {"buckled", "riding", "riding_mob", "using_drone", "control_object",
         "incorporeal_move", "pulledby", "using_object", "using_cannon", "football"}
RECIPROCAL = {"buckled_mob", "rider", "riding_mob", "pulledby", "pulling",
              "driver", "driver_vehicle", "control_object", "owner"}


def supported(case):
    if case.get("human_type") != "/mob/living/human" or case.get("bounds") != (0, 0, 32, 32):
        return False
    if not case.get("constructors_and_defaults_audited"):
        return False
    position = case.get("position", {})
    if set(position) != {"x", "y", "z", "sx", "sy"}:
        return False
    if not all(type(position[k]) is int for k in position):
        return False
    if not (0 <= position["sx"] < 32 and 0 <= position["sy"] < 32):
        return False
    dimensions = case.get("dimensions")
    if (not isinstance(dimensions, tuple) or len(dimensions) != 3
            or any(type(v) is not int or v < 1 for v in dimensions)):
        return False
    if any(not 1 <= position[k] <= limit for k, limit in zip(("x", "y", "z"), dimensions)):
        return False
    fields = case.get("links", {})
    if set(fields) != LINKS or any(value not in (None, False, 0) for value in fields.values()):
        return False
    parents = {}
    for parent, child in case.get("saved_edges", []):
        if child in parents:
            return False
        parents[child] = parent
    human = case["human_ref"]
    if parents.get(human) != case.get("origin_turf_ref"):
        return False
    if any(value is not None and parents.get(value) != human for value in case.get("slots", {}).values()):
        return False
    for source, field, target in case.get("incoming_references", []):
        if field in RECIPROCAL and target == human and source != human:
            return False
    x, y, z = position["x"], position["y"], position["z"]
    footprint = {(x + dx, y + dy, z)
                 for dx in range(1 + (position["sx"] > 0))
                 for dy in range(1 + (position["sy"] > 0))}
    if any(cx > dimensions[0] or cy > dimensions[1] for cx, cy, _ in footprint):
        return False
    cells = case.get("cells", {})
    if set(cells) != footprint:
        return False
    human_matches = 0
    for coordinate, cell in cells.items():
        if not cell.get("type", "").startswith('/turf/floor/') or cell.get("density") != 0 or cell.get("transforming"):
            return False
        for occupant in cell.get("occupants", []):
            if occupant.get("ref") == human and coordinate == (x, y, z):
                human_matches += 1
                continue
            if (not generic_object(occupant.get("type")) or occupant.get("density") != 0
                    or not occupant.get("hooks_audited")):
                return False
    return human_matches == 1
