import sqlite3

con = sqlite3.connect(":memory:")

# load dump file if available or init with default data
dumpfilecontents = ""

with con:
    con.executescript(dumpfilecontents)

# Connection object used as context manager only commits or rollbacks
# transactions, so the connection object should be closed manually
con.close()
