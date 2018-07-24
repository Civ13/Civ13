import sys
import sqlite3
conn = sqlite3.connect('/home/customer/WW13/SQL/database.db')
curs = conn.cursor()
script = sys.argv[1]
curs.execute(script)
conn.commit()
conn.close()