# Web server.

"""
Get the data from SQLite DB for the query `qry` which is a JSON encoded in string
 from the `Request` object.
"""
function getdata(qry)
    js = JSON.parse(qry)
    mintime = js["mintime"]
    maxtime = js["maxtime"]
    return JSON.json(SQLite.query(DB, "select * from logs where tupload > '$mintime' AND tupload < '$maxtime';"))
end

@app test = (
  Mux.defaults,
  page("/", req -> getdata(bytestring(req[:data]))),
  Mux.notfound())

"""
Start web server.
"""
startserver() = serve(test)

export startserver
