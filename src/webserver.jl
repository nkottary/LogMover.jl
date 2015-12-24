# Web server.

# TODO: Implement summaries.

DB = SQLite.DB(DBNAME)

"""
Get the data from SQLite DB for the query `qry` which is a JSON encoded in string
 from the `Request` object.
"""
function getdata(qry)
    js = JSON.parse(qry)
    mintime = js["mintime"]
    maxtime = js["maxtime"]
    return JSON.json(SQLite.query(DB, "select * from logs where logtime > '$mintime' AND logtime < '$maxtime';"))
end

"""
Get the total number of files and the total number of bytes uploaded.
"""
function getsummary(qry)
    js = JSON.parse(qry)
    mintime = js["mintime"]
    maxtime = js["maxtime"]
    res = SQLite.query(DB, "select count(id), sum(size) from logs where logtime > '$mintime' AND logtime < '$maxtime';")
    numfiles = isnull(res.data[1][1]) ? 0 : res.data[1][1].value
    sz = isnull(res.data[2][1]) ? 0 : res.data[2][1].value
    return "{\"type\": \"summary\", \"numfiles\": $numfiles, \"size\": $sz}"
end

@app test = (
  Mux.defaults,
  page("/", req -> getdata(bytestring(req[:data]))),
  page("/summary", req -> getsummary(bytestring(req[:data]))),
  Mux.notfound())

"""
Start web server.
"""
function startserver()
    serve(test)
    info("Web server started.")
end

export startserver
