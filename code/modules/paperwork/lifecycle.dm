// Private targeted notifications supplement the existing moved/destroyed events.
// No player route creates authoring sessions, and no global listener is installed.
GLOBAL_DATUM_INIT(paper_authoring_event, /decl/observ/paper_authoring, new)

/decl/observ/paper_authoring
	name = "Paper authoring lifecycle"
	should_save = FALSE

// Snapshot recipients: retirement unregisters itself during this notification.
/decl/observ/paper_authoring/proc/notify(datum/source, reason, datum/paper_document_authoring/exempt = null)
	var/list/listeners = event_sources[source]
	if (!listeners)
		return FALSE
	for (var/datum/paper_document_authoring/session in listeners.Copy())
		if (session != exempt)
			try
				session.lifecycle_signal(source, reason)
			catch (var/exception/e)
				error(e.desc)
	return TRUE

/proc/paper_authoring_notify(datum/source, reason, datum/paper_document_authoring/exempt = null)
	if (!source || !GLOB.paper_authoring_event)
		return FALSE
	return GLOB.paper_authoring_event.notify(source, reason, exempt)

// Physical checks only: movement must not serialize the document on every step.
/datum/paper_document_authoring/proc/lifecycle_physical_current()
	return controller && !controller.gc_destroyed && controller.loc && has_access(controller, TRUE) && writing_pen && !writing_pen.gc_destroyed && controller.get_active_hand() == writing_pen && writing_pen.loc == controller

/datum/paper_document_authoring/proc/watch_lifecycle_source(datum/source)
	if (!source)
		return FALSE
	if (source in lifecycle_sources)
		return TRUE
	if (length(lifecycle_sources) >= 16)
		return FALSE
	lifecycle_sources += source
	if (!GLOB.paper_authoring_event.register(source, src, /datum/paper_document_authoring/proc/lifecycle_signal))
		return FALSE
	if (!GLOB.destroyed_event.register(source, src, /datum/paper_document_authoring/proc/lifecycle_destroyed))
		return FALSE
	if (istype(source, /atom/movable))
		if (!GLOB.moved_event.register(source, src, /datum/paper_document_authoring/proc/lifecycle_moved))
			return FALSE
	if (source == paper)
		if (!GLOB.name_set_event.register(source, src, /datum/paper_document_authoring/proc/lifecycle_named))
			return FALSE
	return TRUE

// Prepare a bounded subscription graph before registering any observer.
// Include movable ancestors so raw relocation of a carrier is visible.
/datum/paper_document_authoring/proc/plan_lifecycle()
	var/list/planned = list()
	var/list/links = list()
	for (var/datum/root in list(paper, writing_pen, controller, context_owner))
		var/datum/node = root
		var/list/seen = list()
		while (node)
			if (node in seen)
				return null
			seen += node
			if (!(node in planned))
				// Reserve one of sixteen sources for an eventual owned UI.
				if (length(planned) >= 15)
					return null
				planned += node
			if (!istype(node, /atom/movable) || !istype(node.loc, /atom/movable))
				break
			if (length(links) >= 64)
				return null
			links += list(list("mover" = node, "parent" = node.loc))
			node = node.loc
	return list("sources" = planned, "links" = links)

/datum/paper_document_authoring/proc/start_lifecycle()
	if (lifecycle_bound || !lifecycle_physical_current() || !GLOB.paper_authoring_event || !GLOB.destroyed_event || !GLOB.moved_event || !GLOB.name_set_event || !GLOB.stat_set_event)
		return FALSE
	var/list/plan = plan_lifecycle()
	if (!plan)
		return FALSE
	lifecycle_bound = TRUE
	lifecycle_sources = list()
	lifecycle_links = plan["links"]
	var/list/planned = plan["sources"]
	for (var/datum/source in planned)
		if (!watch_lifecycle_source(source))
			return FALSE
	if (istype(controller, /mob/living))
		if (!GLOB.stat_set_event.register(controller, src, /datum/paper_document_authoring/proc/lifecycle_status))
			return FALSE
	return TRUE

// Remove only this session's direct subscription here. Parent forwarding
// links are released from captured edges after all direct listeners are gone.
/datum/paper_document_authoring/proc/unwatch_movement(atom/movable/source)
	GLOB.moved_event.unregister(source, src, /datum/paper_document_authoring/proc/lifecycle_moved)

/datum/paper_document_authoring/proc/stop_lifecycle()
	var/datum/nanoui/old_ui = authoring_ui
	authoring_ui = null
	if (lifecycle_bound)
		lifecycle_bound = FALSE
		var/list/sources = lifecycle_sources
		lifecycle_sources = null
		for (var/datum/source in sources)
			GLOB.paper_authoring_event.unregister(source, src, /datum/paper_document_authoring/proc/lifecycle_signal)
			GLOB.destroyed_event.unregister(source, src, /datum/paper_document_authoring/proc/lifecycle_destroyed)
			if (istype(source, /atom/movable))
				unwatch_movement(source)
			GLOB.name_set_event.unregister(source, src, /datum/paper_document_authoring/proc/lifecycle_named)
			if (istype(source, /mob/living))
				GLOB.stat_set_event.unregister(source, src, /datum/paper_document_authoring/proc/lifecycle_status)
		var/list/links = lifecycle_links
		lifecycle_links = null
		for (var/list/link in links)
			var/atom/movable/mover = link["mover"]
			var/atom/movable/parent = link["parent"]
			if (!GLOB.moved_event.has_listeners(mover))
				GLOB.moved_event.unregister(parent, mover, /atom/movable/proc/recursive_move)
		// Normal Entered() may have added forwarding through a new parent.
		// Prune that current chain too, after releasing captured old edges.
		for (var/datum/source in sources)
			var/datum/node = source
			var/list/seen = list()
			while (istype(node, /atom/movable) && !(node in seen) && !GLOB.moved_event.has_listeners(node) && istype(node.loc, /atom/movable))
				seen += node
				var/atom/movable/parent = node.loc
				GLOB.moved_event.unregister(parent, node, /atom/movable/proc/recursive_move)
				node = parent
	return old_ui

/datum/paper_document_authoring/proc/bind_ui(mob/actor, lease, datum/nanoui/ui)
	if (!lease || lease != session_lease || !can_mutate(actor, writing_pen) || !istype(ui, /datum/nanoui/tgui) || ui.gc_destroyed || !isnull(ui.ref) || ui.user != controller || ui.src_object != paper || authoring_ui || GLOB.paper_authoring_event.has_listeners(ui))
		return FALSE
	// Paper editing never owns an unrelated machine interaction.
	ui.use_on_close_logic(FALSE)
	if (!can_mutate(actor, writing_pen) || lease != session_lease)
		retire()
		return FALSE
	authoring_ui = ui
	if (!watch_lifecycle_source(ui))
		retire()
		return FALSE
	return TRUE

/datum/paper_document_authoring/proc/lifecycle_signal(datum/source, reason)
	if (session_closed || !(source in lifecycle_sources))
		return
	if (reason == "relocated")
		if (!lifecycle_physical_current())
			retire()
		return
	if (source == authoring_ui && reason == "close")
		authoring_ui = null
	retire()

/datum/paper_document_authoring/proc/lifecycle_moved(atom/movable/source, atom/old_loc, atom/new_loc)
	if (session_closed || !(source in lifecycle_sources))
		return
	// Changing containment invalidates the cached watch graph. Turf-to-turf
	// walking with a held page/pen remains valid.
	if (old_loc != new_loc && (!isturf(old_loc) || !isturf(new_loc)) && source != paper && source != writing_pen && (source == controller || source != context_owner))
		retire()
		return
	// Direct departures and returns invalidate even when a nested callback has
	// already restored loc. Recursive carried movement has different anchors.
	if (old_loc != new_loc)
		if ((source == paper && (old_loc == context_owner || new_loc == context_owner)) || (source == writing_pen && (old_loc == controller || new_loc == controller)) || (source == context_owner && context_parent && (old_loc == context_parent || new_loc == context_parent)))
			retire()
			return
	if (source == controller && isturf(context_owner) && old_loc != new_loc)
		var/old_distance = old_loc ? get_dist(context_owner, old_loc) : -1
		var/new_distance = new_loc ? get_dist(context_owner, new_loc) : -1
		if (old_distance < 0 || old_distance > 1 || new_distance < 0 || new_distance > 1)
			retire()
			return
	if (!lifecycle_physical_current())
		retire()

/datum/paper_document_authoring/proc/lifecycle_destroyed(datum/source)
	if (!session_closed && source in lifecycle_sources)
		retire()

/datum/paper_document_authoring/proc/lifecycle_status(mob/living/source, old_stat, new_stat)
	if (!session_closed && !lifecycle_physical_current())
		retire()

/datum/paper_document_authoring/proc/lifecycle_named(atom/source, old_name, new_name)
	if (!session_closed && source == paper)
		retire()
