// Fixed local helper only; disabled until the host installs its service.
/client/proc/control_civilizationbot()
    set category = "Server"
    set name = "CivilizationBot Service"
    if (!check_rights(R_SERVER))
        return
    if (!config.bot_service_control || world.system_type != UNIX)
        to_chat(src, "Bot service control is disabled or this host is not Linux.")
        return
    if (!filming_denied_shell())
        to_chat(src, "Host safety settings do not permit bot service control.")
        return
    var/action = input(src, "Choose a bot service operation.", "CivilizationBot") as null|anything in list("status", "start", "restart")
    if (!action || !check_rights(R_SERVER) || !config.bot_service_control)
        return
    if (action == "restart")
        if (alert(src, "Restart CivilizationBot? Active bot operations may be interrupted.", "CivilizationBot", "Restart", "Cancel") != "Restart")
            return
    if (!check_rights(R_SERVER) || !config.bot_service_control)
        return
    log_admin("[key_name(usr)] requested CivilizationBot service [action].")
    var/result
    // Never interpolate action, player text, paths or service names into shell.
    switch(action)
        if ("start")
            result = filming_denied_shell("/usr/bin/sudo -n /usr/local/sbin/civ13-bot-control start")
        if ("restart")
            result = filming_denied_shell("/usr/bin/sudo -n /usr/local/sbin/civ13-bot-control restart")
        if ("status")
            result = filming_denied_shell("/usr/bin/sudo -n /usr/local/sbin/civ13-bot-control status")
    if (isnull(result))
        to_chat(src, "The host could not execute the bot service helper.")
        return
    to_chat(src, "Bot service helper exit code: [result]. 0 = active (status) or request accepted (start/restart); 75 = cooldown; other codes require host investigation.")
