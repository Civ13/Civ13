// The memory a shell owns. One pool per circuit shell, shared by every memory
// component in the circuit and wiped when the circuit leaves the shell, the
// shell is deleted or the circuit is switched off. Nothing is saved.
//
// 512 KiB is the whole address space. Each memory component owns a contiguous
// slice of it; a small memory claims 1 KiB and the large components divide what
// is left, whole KiB at a time. Leftover KiB goes to the first-installed large
// component. Installation order fixes the bases, so a 4 KiB page can straddle
// two small slices and is still one page; the 128-page cap counts pages of the
// pool as a whole, never per component.

/datum/wiremod_memory_pool
	var/obj/item/circuit_shell/owner
	// Page number to a list of 1024 words. A page exists only once written to.
	var/list/pages = list()
	var/dirty = TRUE
	var/signature = ""

/datum/wiremod_memory_pool/New(obj/item/circuit_shell/new_owner)
	owner = new_owner

/datum/wiremod_memory_pool/Destroy()
	wipe()
	owner = null
	return ..()

// Called by a memory component when the set of memory components may have
// changed: it is installed, removed, or the circuit moved into or out of a shell.
/datum/wiremod_memory_pool/proc/invalidate()
	dirty = TRUE

/datum/wiremod_memory_pool/proc/ensure()
	if(dirty)
		dirty = FALSE
		recompute()

/datum/wiremod_memory_pool/proc/wipe()
	pages.Cut()
	signature = ""

// Splits the pool across the installed memory components. A change in the set
// remaps every slice, so the old contents cannot be trusted and are wiped.
/datum/wiremod_memory_pool/proc/recompute()
	var/list/obj/item/circuit_component/memory/members = list()
	var/obj/item/integrated_circuit/circuit = owner?.circuit
	if(circuit)
		for(var/member in circuit.attached_components)
			if(istype(member, /obj/item/circuit_component/memory))
				members += member
	var/new_signature = ""
	for(var/obj/item/circuit_component/memory/member as anything in members)
		new_signature += "[member.circuit_id]:[member.small ? "s" : "l"],"
	if(new_signature != signature)
		signature = new_signature
		pages.Cut()
	var/small_count = 0
	for(var/obj/item/circuit_component/memory/member as anything in members)
		if(member.small)
			small_count++
	var/free = CIRCUIT_MEMORY_TOTAL_BYTES - small_count * CIRCUIT_MEMORY_SMALL_BYTES
	if(free < 0)
		free = 0
	var/large_count = length(members) - small_count
	var/large_bytes = 0
	var/leftover = 0
	if(large_count > 0)
		large_bytes = floor(free / large_count / 1024) * 1024
		leftover = free - large_bytes * large_count
	var/base = 0
	var/first_large = TRUE
	for(var/obj/item/circuit_component/memory/member as anything in members)
		member.slice_base = base
		if(member.small)
			member.slice_bytes = CIRCUIT_MEMORY_SMALL_BYTES
		else
			member.slice_bytes = large_bytes
			if(first_large)
				member.slice_bytes += leftover
				first_large = FALSE
		base += member.slice_bytes

// The word a component holds at a byte offset inside its own slice, or null
// when the offset is outside it or not word-aligned.
/datum/wiremod_memory_pool/proc/read_word(obj/item/circuit_component/memory/member, address)
	ensure()
	if(!member || address < 0 || address % CIRCUIT_MEMORY_WORD_BYTES || address + CIRCUIT_MEMORY_WORD_BYTES > member.slice_bytes)
		return null
	var/offset = member.slice_base + address
	var/page = "[floor(offset / CIRCUIT_MEMORY_PAGE_BYTES) + 1]"
	var/list/entries = pages[page]
	if(!entries)
		return wiremod_u32(0)
	return entries[floor((offset % CIRCUIT_MEMORY_PAGE_BYTES) / CIRCUIT_MEMORY_WORD_BYTES) + 1]

/datum/wiremod_memory_pool/proc/write_word(obj/item/circuit_component/memory/member, address, word)
	ensure()
	if(!member || address < 0 || address % CIRCUIT_MEMORY_WORD_BYTES || address + CIRCUIT_MEMORY_WORD_BYTES > member.slice_bytes)
		return FALSE
	var/offset = member.slice_base + address
	var/page = "[floor(offset / CIRCUIT_MEMORY_PAGE_BYTES) + 1]"
	var/list/entries = pages[page]
	if(!entries)
		if(length(pages) >= CIRCUIT_MEMORY_MAX_PAGES)
			return FALSE
		entries = list()
		for(var/index in 1 to floor(CIRCUIT_MEMORY_PAGE_BYTES / CIRCUIT_MEMORY_WORD_BYTES))
			entries += list(wiremod_u32(0))
		pages[page] = entries
	entries[floor((offset % CIRCUIT_MEMORY_PAGE_BYTES) / CIRCUIT_MEMORY_WORD_BYTES) + 1] = wiremod_u32(word)
	return TRUE
