"""Offline FPS policy/source contracts. Does not start BYOND or measure frames."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
PREFERENCES = "code/modules/client/preferencesSQLite/preferences.dm"
SAVE = "code/modules/client/preferencesSQLite/preferences_saving&loading&del.dm"
SETUP = "code/modules/client/preferencesSQLite/character_setup_ui.dm"
MOVEMENT = "code/game/mob/living/carbon/human/subtile_movement.dm"


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def body(source, signature):
    match = re.search(r"^" + re.escape(signature) + r"\n(.*?)(?=^/|\Z)", source, re.M | re.S)
    if not match:
        raise AssertionError(signature)
    return match[1]


def sanitizer(source):
    """Execute the production scalar guard after a deliberately small translation.

    This projection checks policy values, not BYOND types or client lifecycle.
    Unknown statements fail instead of silently becoming model behavior.
    """
    default = int(re.search(r"^#define DEFAULT_CLIENT_FPS (\d+)$", read("code/__defines/__game.dm"), re.M)[1])
    choices = body(source, "/proc/client_fps_choices()")
    choice_match = re.fullmatch(r"\s*return list\(([\d, ]+)\)\s*", choices)
    if not choice_match:
        raise AssertionError("unsupported choice definition")
    targets = tuple(int(value) for value in choice_match[1].split(","))
    lines = ["def sanitize(value):"]
    for line in body(source, "/proc/sanitize_client_fps(value)").splitlines():
        if not line.strip() or line.lstrip().startswith("//"):
            continue
        indent = len(line) - len(line.lstrip("\t"))
        statement = line.strip()
        if statement.startswith("if (") and statement.endswith(")"):
            condition = statement[4:-1].replace("||", "or").replace("!", "not ")
            statement = "if " + condition + ":"
        elif not re.fullmatch(r"return (?:DEFAULT_CLIENT_FPS|value)", statement):
            raise AssertionError("unsupported sanitizer statement: " + statement)
        lines.append("    " * indent + statement)
    namespace = {
        "DEFAULT_CLIENT_FPS": default,
        "client_fps_choices": lambda: targets,
        "isnum": lambda value: isinstance(value, (int, float)),
    }
    exec("\n".join(lines), namespace)
    return namespace["sanitize"], targets


def check_movement_owner(source):
    # Restoring a previous FPS can overwrite an explicit preference change.
    if re.search(r"\bfps\s*=|human_subtile_(?:previous|applied)_fps", source):
        raise AssertionError("movement still owns FPS")
    for setting in ("owner.glide_size = glide_size", "glide_size = human_subtile_previous_glide"):
        if setting not in source:
            raise AssertionError("lost glide ownership: " + setting)


class ClientFpsContracts(unittest.TestCase):
    def test_default_and_supported_low_high_targets(self):
        sanitize, targets = sanitizer(read(PREFERENCES))
        self.assertEqual(targets, (30, 60, 100, 120, 144, 165, 240))
        for value in targets:
            self.assertEqual(sanitize(value), value)
        for value in (None, "60", "bad", [], 0, -1, 59, 60.5, 241, float("inf"), float("nan")):
            with self.subTest(value=value):
                self.assertEqual(sanitize(value), 100)
        self.assertIn("var/client_fps = DEFAULT_CLIENT_FPS", read(PREFERENCES))
        self.assertIn("fps = DEFAULT_CLIENT_FPS", read("code/modules/client/client_defines.dm"))

    def test_saved_choice_load_and_cached_reconnect_apply_before_login(self):
        source = read(SAVE)
        fields = re.search(r"var/list/vars_to_save = list\(([^\n]+)\)", source)[1]
        self.assertIn('"client_fps"', fields)
        self.assertIn("if (isnum(vars[varname]))", source)
        self.assertIn("vars[varname] = text2num(key_val_pairs[varname])", source)
        self.assertIn("vars[varname] = initial(vars[varname])", source)
        self.assertIn("client_fps = sanitize_client_fps(client_fps)", source)
        self.assertIn("if (client && client.prefs == src)\n\t\tclient.apply_client_fps_preference()", source)
        login = body(read("code/modules/client/client_procs.dm"), "/client/New(TopicData)")
        # Both newly loaded and retained preference datums reach this call.
        self.assertIn("\n\tapply_client_fps_preference()\n", login)
        self.assertLess(login.index("apply_client_fps_preference()"), login.index(". = ..()"))
        apply = body(read(PREFERENCES), "/client/proc/apply_client_fps_preference()")
        self.assertIn("prefs.client_fps = sanitize_client_fps(prefs.client_fps)", apply)
        self.assertIn("fps = prefs.client_fps", apply)
        self.assertNotIn("world.fps", apply)
        self.assertNotIn("world.tick_lag", apply)

    def test_movement_cannot_raise_30_60_or_restore_old_100(self):
        source = read(MOVEMENT)
        check_movement_owner(source)
        for addition in ("\n\tfps = 60\n", "\n\towner.fps = 100\n", "\n\tfps = human_subtile_previous_fps\n"):
            with self.subTest(addition=addition), self.assertRaises(AssertionError):
                check_movement_owner(source + addition)

    def test_setup_window_checks_owner_and_choice_before_applying(self):
        source = read(SETUP)
        act = body(source, "/datum/preferences/ui_act(action, list/params, mob/user, datum/nanoui/ui)")
        self.assertLess(act.index("if (!user || !user.client || user.client.prefs != src)\n\t\treturn"), act.index("setup_settings_act(action, value, user)"))
        settings = body(source, "/datum/preferences/proc/setup_settings_act(action, value, mob/user)")
        branch = settings[settings.index('if ("client_fps")'):settings.index('if ("reset_tutorial")')]
        guard = branch.index("if (isnum(value) && (value in client_fps_choices()))")
        publication = branch.index("client_fps = value", guard)
        self.assertLess(publication, branch.index("user.client.apply_client_fps_preference()"))
        self.assertIn("save_preferences()", branch[publication:])
        # The choice arrives with the press: nothing waits between check and write.
        self.assertNotIn("input(", source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
