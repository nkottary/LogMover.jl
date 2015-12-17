g_db = SQLite.DB(DBNAME)
g_awsenv = AWSEnv(id=AWSID, key=AWSKEY)

"""
Convert datetime to directory path.  The format of the path is:

yyyy/mm/dd/hh/mm
"""
datetime2path(dt) = joinpath(map(string, [year(dt), month(dt), day(dt),
                                             hour(dt), minute(dt)])...)

@test datetime2path(DateTime("2015-12-14T12:20:30",
                             "yyyy-mm-ddTHH:MM:SS")) == "2015/12/14/12/20"

"""
Move the log files in the array of `Log` instances `logs`.
"""
function logmove()
    currtime = now()
    info("[Upload]: Started.")
    tpath = datetime2path(currtime)
    for log in LOGS
        fulldest = joinpath(log.dest, tpath)
        upload(log.src, fulldest)
        dbentry(log, fulldest, currtime)
    end
    info("[Upload]: Done.")
end

"""
Local testing version of logmove.
"""
function _logmove(logs)
    currtime = now()
    info("[Upload]: Started.")
    tpath = datetime2path(currtime)
    for log in logs
        fulldest = joinpath(log.dest, tpath)
        pathexists(fulldest) || createpath(fulldest)
        _upload(log.src, fulldest)
        dbentry(log, fulldest, currtime)
    end
    info("[Upload]: Done.")
end

"""
Upload file given by local path `src` to S3 destination given
 by `dest`.

Throws `UploadException` on failure.
"""
function upload(src, dest)
    f = open(src, "r")
    resp = S3.put_object(g_awsenv, AWSBKT, dest, f)
    resp != 200 && throw(UploadException(src, dest))
    close(f)
end

"""
Local upload for testing purposes.
"""
function _upload(src, dest)
    cp(src, dest, remove_destination=true)
    info("[Upload]: $src -> $dest")
end

"""
Check whether remote path exists.
"""
function pathexists(path)
    return isdir(splitdir(path)[1])
end

"""
Make the remote path.

Throws `CreatePathException` on failure.
"""
function createpath(path)
    dir = splitdir(path)[1]
    run(`mkdir -p $dir`)
    info("[Upload]: Created path $dir")
end

"""
Make an SQLite entry for a log upload.  `log` is an
 instance of type `Log`, `fulldest` is the remote destination
 of the file and `uploadtime` is the time of upload of the file.

Throws `SQLite.SQLiteException` on failure.
"""
function dbentry(log, fulldest, uploadtime)
    tstamp = replace(string(log.tstamp), "T", " ")
    uptime = replace(string(uploadtime), "T", " ")
    SQLite.execute!(g_db, "insert into logs (src, dest, size, tstamp, tupload) values ('$(log.src)', '$fulldest', $(log.sz), '$tstamp', '$uptime')")
    info("[Database]: Made entry for $(log.src)")
end
