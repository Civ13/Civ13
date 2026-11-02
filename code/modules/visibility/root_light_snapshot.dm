// A copied committed light-mask matrix, not a tree color or visibility decision.
/proc/root_light_mask_snapshot(turf/root, allow_pending = FALSE)
	if(!root || lighting_startup_in_progress || !created_lighting_corners_and_overlays)
		return null
	var/atom/movable/lighting_overlay/owner = root.lighting_overlay
	if(!owner || owner.loc != root || (owner.needs_update && !allow_pending))
		return null
	if(!islist(owner.color) || !islist(owner.last_color))
		return null
	var/list/current = owner.color
	var/list/previous = owner.last_color
	if(current.len != 20 || previous.len != 20)
		return null
	var/list/result = list()
	for(var/i = 1, i <= 20, i++)
		if(!isnum(current[i]) || current[i] != previous[i])
			return null
		result += current[i]
	return result

// Sample the actual four-channel mask texture after applying its matrix. That
// matrix must never be assigned directly to the unrelated RGB tree texture.
/proc/root_light_rgb(turf/root, mob/viewer, allow_pending = FALSE)
	if(!CIV13_ROOT_TREE_PRESENTATION || !root || !viewer)
		return null
	if(viewer.see_invisible >= INVISIBILITY_LEVEL_TWO)
		return "#ffffff"
	if(!root.lighting_overlay && root.needs_fullbright_coverage())
		return "#ffffff"
	var/list/sample = root_light_mask_snapshot(root, allow_pending)
	if(!sample)
		return null
	var/atom/movable/lighting_overlay/L = root.lighting_overlay
	var/icon/mask = icon(L.icon, L.icon_state, L.dir, 1)
	if(mask.Width() != 32 || mask.Height() != 32)
		return null
	mask.MapColors(arglist(sample))
	var/rgb = mask.GetPixel(16, 16)
	return istext(rgb) && length(rgb) == 7 ? rgb : null
