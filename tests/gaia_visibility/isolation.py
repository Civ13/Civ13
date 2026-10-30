"""Exact entry-point adapters for the staged fixture, never production files."""
PREFIX = b'''// Test-only native/shell boundaries; no operating-system settings are changed.
#define shell gaia_visibility_denied_shell
#define call_ext(X,Y) call(/proc/gaia_visibility_denied_native)
#define SetConfig gaia_visibility_denied_setting
'''

# Guards precede every original body, including global construction before New.
GUARDS = {
    'code/world.dm': (
        ('/datum/global_init/New()', '\treturn gaia_visibility_global_init()\n'),
        ('/world/New()', '\treturn gaia_visibility_start()\n'),
        ('/proc/load_configuration()', '\tconfig = new /datum/configuration()\n\treturn\n'),
        ('/world/Topic(T, addr, master, key)', '\treturn null\n'),
        ('/world/Reboot(var/reason, recovery_generation)', '\treturn FALSE\n'),
    ),
    'code/game/objects/map_metadata/_map_metadata.dm': (
        ('/obj/map_metadata/New()', '\tmap = src\n\ticon = null\n\treturn\n'),
    ),
    'code/game/objects/map_metadata/nomads/nomads.dm': (
        ('/obj/map_metadata/nomads/New()', '\treturn ..()\n'),
    ),
    'code/datums/configuration.dm': (
        ('/datum/configuration/proc/load(filename, type = "config")', '\treturn FALSE\n'),
    ),
    'code/modules/client/client_procs.dm': (
        ('/client/New(TopicData)', '\tif(!gaia_visibility_admit(src))\n\t\treturn null\n\tprefs = new /datum/preferences()\n\tclients |= src\n\tdirectory[ckey] = src\n\t. = ..()\n\tif(mob)\n\t\tmob.forceMove(locate(24, 22, clients.len == 3 ? 2 : 1))\n\treturn .\n'),
        ('/client/Topic(href, href_list, hsrc)', '\treturn null\n'),
    ),
    'code/modules/webhooks/webhooks.dm': (
        ('/proc/webhook_send(method, data)', '\treturn FALSE\n'),
    ),
    'code/modules/admin/admin_ranks.dm': (
        ('/proc/load_admins(var/force = FALSE)', '\treturn FALSE\n'),
    ),
    'code/modules/client/preferencesSQLite/preferences_saving&loading&del.dm': (
        ('/datum/preferences/proc/save_preferences(var/list/charprefs = list())', '\treturn FALSE\n'),
    ),
}


def adapt(path, data):
    text = data.decode()
    for signature, guard in GUARDS[path]:
        # Allow the existing signature's trailing comment, but require uniqueness.
        matches = [line for line in text.splitlines(keepends=True) if line.startswith(signature) and (not line[len(signature):].strip() or line[len(signature):].lstrip().startswith('//'))]
        if len(matches) != 1:
            raise ValueError('isolation entry drift: ' + signature)
        line = matches[0]
        text = text.replace(line, line + guard, 1)
    return text.encode()
