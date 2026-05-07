/proc/check_rights(rights_required, show_msg = 1, var/mob/user = usr)
    // Normalise to a client reference C
    var/client/C = null
    if (istype(user, /client))
        C = user
    else if (user && user.client)
        C = user.client

    if (!C)
        if (show_msg)
            to_chat(user, "<font color='red'>Error: You are not an admin.</font>")
        return FALSE

    if (!rights_required)
        if (C.holder)
            return TRUE
        else if (show_msg)
            to_chat(user, "<font color='red'>Error: You are not an admin.</font>")
        return FALSE

    if (C.holder && (rights_required & C.holder.rights))
        return TRUE
    else if (show_msg)
        to_chat(user, "<font color='red'>Error: You do not have sufficient rights to do that. You require one of the following flags:[rights2text(rights_required)].</font>")
    return FALSE