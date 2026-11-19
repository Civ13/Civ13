// Server memos, shown to every player with the MOTD on every region (shared_memos.dm).
/client/proc/player_memo_write()
	set category = "Admin"
	set name = "Write Server Memo"
	memo_write("server_memo", src)

/client/proc/player_memo_show()
	memo_show("server_memo", src)

/client/proc/player_memo_delete()
	set category = "Admin"
	set name = "Delete Server Memo"
	memo_delete("server_memo", src)
