// Watchlist, shared by every region of a shard group through the shared player
// records (shared_player_records.dm). When a watched player logs in on any
// region, staff on every region see it in admin chat with the reason.
// Removing a player revokes their watch record.

// The active watch records about key, oldest first.
/proc/watchlist_for(key)
	. = list()
	for (var/list/record in shared_records.records_for(key))
		if (record["kind"] == "watch" && !record["revoked"])
			. += list(record)

/proc/watchlist_add(key, reason, mob/user)
	key = ckey(key)
	if (!key || !reason || length(watchlist_for(key)))
		return null
	var/list/record = shared_records.add(key, "watch", list("text" = reason), user ? user.ckey : "",
		(user && user.client && user.client.holder) ? user.client.holder.rank : "")
	if (record)
		message_admins("[key_name_admin(user)] added [key] to the watchlist: [reason]", key_name_admin(user))
		log_admin("[key_name(user)] added [key] to the watchlist: [reason]")
	return record

/proc/watchlist_remove(key, mob/user)
	key = ckey(key)
	. = 0
	for (var/list/record in watchlist_for(key))
		if (shared_records.revoke(record, user ? user.ckey : "", (user && user.client && user.client.holder) ? user.client.holder.rank : ""))
			.++
	if (.)
		message_admins("[key_name_admin(user)] removed [key] from the watchlist.", key_name_admin(user))
		log_admin("[key_name(user)] removed [key] from the watchlist.")

// Called when a client logs in: tells staff here and on the other regions.
/proc/watchlist_login(client/C)
	if (!C || !shared_records.watched(C.ckey))
		return FALSE
	var/list/watches = watchlist_for(C.ckey)
	var/list/reasons = list()
	for (var/list/record in watches)
		var/list/body = record["body"]
		if (islist(body) && istext(body["text"]))
			reasons += body["text"] // stored sanitized
	var/msg = "[C.ckey] has connected and is on the watchlist[reasons.len ? ": [jointext(reasons, "; ")]" : "."]"
	log_admin("WATCHLIST: [msg]")
	admin_say_show("Watchlist", msg)
	region_asay_outbound("Watchlist", "", msg)
	return TRUE

/client/proc/watchlist_show()
	set category = "Admin"
	set name = "Watchlist"
	if (!holder)
		return
	var/dat = "<html>[common_browser_style]<head><title>Watchlist</title></head><body><b>Watchlist (every region)</b><br><br>"
	var/count = 0
	for (var/key in shared_records.ckeys_with(list("watch")))
		var/list/watches = watchlist_for(key)
		if (!watches.len)
			continue
		count++
		var/list/record = watches[1]
		var/list/body = record["body"]
		dat += "<b>[key]</b>: [islist(body) ? body["text"] : ""] <i>by [record["author"]] on [shared_records.time_text(record["at"])]</i> "
		dat += "<A href='?src=\ref[holder];notes=show;ckey=[key]'>Notes</A> | <A href='?src=\ref[holder];watchlist_remove=[key]'>Remove</A><br>"
	if (!count)
		dat += "Nobody is on the watchlist.<br>"
	dat += "</body></html>"
	usr << browse(dat, "window=watchlist;size=520x480")

// One line for the Player Panel: what every region knows about ckey.
/proc/player_records_summary_html(ckey, datum/admins/holder)
	ckey = ckey(ckey)
	if (!length(ckey))
		return ""
	var/list/sum = shared_records.summary(ckey)
	var/bans = length(shared_records.active_bans(ckey, "any"))
	var/watch = sum["watch"] ? ", <font color=#aa0000><b>on the watchlist</b></font>" : ""
	return "<b>Every region:</b> [sum["notes"]] notes, [sum["warnings"]] warnings, [bans] active bans, [sum["hours"]] hours played[watch] (<A href='?src=\ref[holder];notes=show;ckey=[ckey]'>details</A>)"
