// Admin memos, shown to staff at login on every region (shared_memos.dm).
/client/proc/admin_memo_write()
	set category = "Admin"
	set name = "Write Admin Memo"
	memo_write("admin_memo", src)

/client/proc/admin_memo_show()
	set category = "Admin"
	set name = "Show Admin Memos"
	memo_show("admin_memo", src)

/client/proc/admin_memo_delete()
	set category = "Admin"
	set name = "Delete Admin Memo"
	memo_delete("admin_memo", src)
