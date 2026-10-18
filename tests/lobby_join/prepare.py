"""Stage a tiny offline control fixture. This module never launches processes.

Actor/client access and native input are injected because no networked client is
created. Admission branches and real job/map construction are covered separately
by source preservation and the complete game compilation, not by these stubs.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

from test_source import procedure
from visibility import visibility_verbs

ROOT = Path(__file__).resolve().parents[2]
NAMES = (
    "lobby_join_trace",
    "lobby_join_mode", "lobby_join_current", "handle_lobby_join",
    "clear_lobby_join", "lobby_join_admission_current", "lobby_join_input",
    "lobby_join_confirmation", "lobby_join_campaign_faction",
    "lobby_join_job_available",
)


def stage(output):
    output.mkdir(parents=True, exist_ok=False)
    source = (ROOT / "code/game/mob/new_player/new_player.dm").read_text()
    helpers = (ROOT / "code/game/mob/new_player/late_choices_helpers.dm").read_text()
    parts = [procedure(source, "/mob/new_player/proc/" + name + "(") for name in NAMES]
    renderer = procedure(helpers, "/mob/new_player/proc/show_latechoices_window(")
    renderer = renderer[:renderer.index('\n\tvar/data = ""')] + "\n\treturn FALSE"
    parts.append(renderer)
    adapted = "\n\n".join(parts)
    # Explicit boundary adapters: deterministic actor/client and prompt transport.
    adapted = re.sub(r"\bclient\b", "test_client", adapted)
    adapted = re.sub(r"\busr\b", "test_actor", adapted)
    native_input = 'input(src, message) in list("Yes", "No")'
    assert adapted.count(native_input) == 1
    adapted = adapted.replace(native_input, 'WWinput(src, message, "Confirmation")')
    # Inert generated mutants establish that the stale-round and stale-role
    # assertions distinguish the unsafe alternatives in this same process.
    current = procedure(adapted, "/mob/new_player/proc/lobby_join_current(")
    unsafe_round = current.replace("/mob/new_player/proc/", "/mob/new_player/unsafe_round/", 1)
    round_guard = " && map == lobby_join_map && game_id == lobby_join_game_id"
    assert unsafe_round.count(round_guard) == 1
    unsafe_round = unsafe_round.replace(round_guard, "")
    confirmation = procedure(adapted, "/mob/new_player/proc/lobby_join_confirmation(")
    unsafe_role = confirmation.replace("/mob/new_player/proc/", "/mob/new_player/unsafe_role/", 1)
    role_guard = " || !lobby_join_job_available(selected_job)"
    assert unsafe_role.count(role_guard) == 1
    unsafe_role = unsafe_role.replace(role_guard, "")
    fixture = (Path(__file__).with_name("probe.dm")).read_text()
    # Keep the actual verb metadata unadapted. These checks inspect native
    # metadata only; no connected client or actual command dispatch is claimed.
    (output / "control.dm").write_text(fixture + "\n" + adapted + "\n" + unsafe_round + "\n" + unsafe_role + "\n" + visibility_verbs(source) + "\n", encoding="utf-8")
    (output / "control.dme").write_text('#include "control.dm"\n', encoding="utf-8")
    manifest = {
        "schema": 1,
        "purpose": "isolated production Join ownership and prompt-control fixture",
        "adapters": ["client/actor references", "native input transport", "map/job admission collaborators"],
        "limits": ["does not execute full SelectedJob body", "does not construct game jobs or a connected client", "does not establish delayed callback behavior"],
        "sha256": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in output.iterdir()},
        "production_sha256": {
            path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
            for path in ("code/game/mob/new_player/new_player.dm", "code/game/mob/new_player/late_choices_helpers.dm")
        },
    }
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    stage(parser.parse_args().output.resolve())
