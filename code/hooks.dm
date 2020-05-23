/**
 * @file hooks.dm
 * Implements hooks, a simple way to run code on pre-defined events.
 */

/** @page hooks Code hooks
 * @section hooks Hooks
 * A hook is defined under /hook in the type tree.
 *
 * To add some code to be called by the hook, define a proc under the type, as so:
 * @code
	hook/foo/proc/bar()
		if (TRUE)
			return TRUE //Sucessful
		else
			return FALSE //Error, or runtime.
 * @endcode
 * All hooks must return nonzero on success, as runtimes will force return null.
 */

/**
 * Calls a hook, executing every piece of code that's attached to it.
 * @param hook	Identifier of the hook to call.
 * @returns		TRUE if all hooked code runs successfully, FALSE otherwise.
 */

 /**
 * Startup hook.
 * Called in world.dm when the server starts.
 */
/hook/startup

/**
 * Roundstart hook.
 * Called in gameticker.dm when a round starts.
 */
/hook/roundstart

/**
 * Roundend hook.
 * Called in gameticker.dm when a round ends.
 */
/hook/roundend

/**
 * Death hook.
 * Called in death.dm when someone dies.
 * Parameters: var/mob/living/human, var/gibbed
 */
/hook/death

/proc/callHook(hook, list/args=null)
	var/hook_path = text2path("/hook/[hook]")
	if (!hook_path)
		error("Invalid hook '/hook/[hook]' called.")
		return FALSE

	var/caller = new hook_path
	var/status = TRUE
	for (var/P in typesof("[hook_path]/proc"))
		if (!call(caller, P)(arglist(args)))
			error("Hook '[P]' failed or runtimed.")
			status = FALSE

	return status
