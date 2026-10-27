/mob/var/lastattacker = null
/mob/var/lastattacked = null
/mob/var/list/attack_log = list()

#define ATTACK_HISTORY_RECENT_LIMIT 1024
#define ATTACK_HISTORY_ARCHIVE_BATCH 64
#define ATTACK_HISTORY_ARCHIVE_RETRY 600

// Scalars only: failed storage must not create another owner of mob histories.
var/attack_history_archive_retry_at = 0
var/attack_history_archive_warning_at = 0

/proc/archive_attack_history(mob/subject, list/entries)
	if (!global.attack_log)
		return FALSE
	// The ordinary attack logger is optional. History retirement must archive
	// even when config.log_attack is disabled. JSON preserves the exact rows.
	var/payload = json_encode(list("category" = "ARCHIVED_MOB_ATTACK_HISTORY", "time" = time_stamp(), "game_id" = game_id, "subject_ref" = "\ref[subject]", "subject_name" = subject.name, "subject_key" = subject.ckey, "entries" = entries))
	return text2file("\n[payload]", global.attack_log)

/mob/proc/append_attack_log(entry)
	if (!islist(attack_log))
		attack_log = list()
	attack_log += entry
	if (attack_log.len <= ATTACK_HISTORY_RECENT_LIMIT || world.time < attack_history_archive_retry_at)
		return

	// One bounded batch per append also drains loaded legacy backlogs gradually.
	// Never replace the list: ghosts can share it with their original body.
	var/archive_count = min(ATTACK_HISTORY_ARCHIVE_BATCH, attack_log.len - 1)
	var/list/entries = attack_log.Copy(1, archive_count + 1)
	var/archived = FALSE
	try
		archived = archive_attack_history(src, entries)
	catch
		archived = FALSE
	if (!archived)
		attack_history_archive_retry_at = world.time + ATTACK_HISTORY_ARCHIVE_RETRY
		if (world.time >= attack_history_archive_warning_at)
			attack_history_archive_warning_at = world.time + ATTACK_HISTORY_ARCHIVE_RETRY
			world.log << "Attack history archive unavailable; older entries retained in memory. Further attempts and warnings are limited to once per minute."
		return
	attack_log.Cut(1, archive_count + 1)

proc/log_and_message_admins(var/message as text, var/mob/user = usr, var/turf/location)
	var/turf/T = location ? location : (user ? get_turf(user) : null)
	if (T)
		message = message + " (<a HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[T.x];Y=[T.y];Z=[T.z]'>JMP</a>)"

	log_admin(user ? "[key_name(user)] [message]" : "EVENT [message]")
	message_admins(user ? "[key_name_admin(user)] [message]" : "EVENT [message]", user ? key_name_admin(user) : "")

proc/admin_attack_log(var/mob/attacker, var/mob/victim, var/attacker_message, var/victim_message, var/admin_message)
	if (victim)
		victim.append_attack_log(text("\[[time_stamp()]\] <font color='orange'>[key_name(attacker)] - [victim_message]</font>"))
	if (attacker)
		attacker.append_attack_log(text("\[[time_stamp()]\] <font color='red'>[key_name(victim)] - [attacker_message]</font>"))

	msg_admin_attack("[key_name(attacker)] [admin_message] [key_name(victim)] (INTENT: [attacker? uppertext(attacker.a_intent) : "N/A"]) (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[attacker.x];Y=[attacker.y];Z=[attacker.z]'>JMP</a>)", key_name(attacker), key_name(victim))

proc/admin_inject_log(mob/attacker, mob/victim, obj/item/weapon, reagents, amount_transferred, violent=0)
	if (violent)
		violent = "violently "
	else
		violent = ""
	admin_attack_log(attacker,
					 victim,
					 "used \the [weapon] to [violent]inject - [reagents] - [amount_transferred]u transferred",
					 "was [violent]injected with \the [weapon] - [reagents] - [amount_transferred]u transferred",
					 "used \the [weapon] to [violent]inject [reagents] ([amount_transferred]u transferred) into")
