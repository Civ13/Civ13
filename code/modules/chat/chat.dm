/**
 * Chat module for browser-based chat interface.
 */

/client
	var/datum/chat/chat

/datum/chat
	var/client/client
	var/is_ready = FALSE
	var/list/message_queue = list()

/datum/chat/New(client/C)
	src.client = C

/datum/chat/proc/load()
	if (!client)
		return
	
	// No longer sending individual CSS/JS as they are inlined for reliability
	client << browse('interface/chat/chat.html', "window=output")
	// world.log << "DEBUG: Chat loading for [client.ckey]"

/datum/chat/proc/on_ready()
	is_ready = TRUE
	for (var/message in message_queue)
		send_message(message)
	message_queue.Cut()

/datum/chat/proc/send_message(message)
	if (!client)
		return
	
	if (!is_ready)
		message_queue += message
		return

	// Escape message for JS
	var/escaped_message = json_encode(list("message" = message))
	client << output(escaped_message, "output:receiveMessage")

/**
 * Global chat wrapper to replace the to_chat macro functionality.
 */
/proc/to_chat_wrapper(target, message)
	if (!target || !message)
		return

	if (istype(target, /client))
		var/client/C = target
		if (C.chat)
			C.chat.send_message(message)
		else
			C << message
		return

	if (istype(target, /mob))
		var/mob/M = target
		if (M.client)
			to_chat_wrapper(M.client, message)
		else
			// Fallback for mobs without clients (logs or similar)
			M << message
		return

	if (istype(target, /list))
		for (var/T in target)
			to_chat_wrapper(T, message)
		return

	if (target == world)
		for (var/client/C in clients)
			to_chat_wrapper(C, message)
		return

	// Final fallback
	target << message
