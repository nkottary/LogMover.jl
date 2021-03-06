"""
Convert datetime to directory path.  The format of the path is:

yyyy/mm/dd/hh/mm
"""
time2path(dt::DateTime) = joinpath(map(string, [year(dt), month(dt), day(dt),
                                             hour(dt), minute(dt)])...)
@test time2path(DateTime("2015-12-14T12:20:30")) == "2015/12/14/12/20"
time2path(ut) = time2path(unix2datetime(ut))

"""
Move the log files in the array of `LogDir` instances `logs`.
"""
function logmove(ctx)
    info("[Upload]: Started.")
    tpath = time2path(ctx.new_upload_time)
    for log in LOGS
        dest = joinpath(log.dest, tpath)
        numfiles = upload(ctx, log.src, dest, log.awsbkt)
        numfiles == 0 && info("[Upload]: [$(log.dest)] No new files to upload this time.")
    end
    info("[Upload]: Done.")
end

"""
Get a list of *.log files in `srcdir` directory that were created
 after `last_upload_time`.
"""
function get_new_files(srcdir, last_upload_time)
    files = filter(x -> ismatch(r".+\.log$", x), readdir(srcdir))
    newfiles = Any[]
    for file in files
        st = stat(joinpath(srcdir, file))
        t = max(st.ctime, st.mtime)
        t > last_upload_time && push!(newfiles, file)
    end
    return newfiles
end

@test get_new_files(joinpath(Pkg.dir("LogMover"), "test", "test_get_new_files"), datetime2unix(DateTime("2015-12-22T04:04:00"))) == ["abc.12345.log", "file2.log", "file4.log", "file5.log", "file6.log"]

"""
Upload files given by local directory `srcdir` to S3
 destination given by `destdir`.

Throws `UploadException` on failure.
"""
function upload(ctx, srcdir, destdir, awsbkt)
    files_to_upload = get_new_files(srcdir, ctx.last_upload_time)
    for file in files_to_upload
        localsrc = joinpath(srcdir, file)
        s3dest = joinpath(destdir, file * ".gz")
        localsrcgz = localsrc * ".gz"
        run(pipeline(`gzip`, stdin=localsrc, stdout=localsrcgz))
        open(localsrcgz, "r") do f
            resp = S3.put_object(ctx.awsenv, awsbkt, s3dest, f)
            resp.http_code != 200 && throw(UploadException(localsrc, s3dest, resp))
        end
        rm(localsrcgz)
        info("[Upload]: $localsrc -> $s3dest")
        dbentry(ctx, localsrc, s3dest)
    end
    return length(files_to_upload)
end

get_sql_datetime(ut) = replace(string(unix2datetime(ut)), "T", " ")
@test get_sql_datetime(1.450756203548761e9) == "2015-12-22 03:50:03.549"

"""
Make an SQLite entry for a log upload.  `db` is the SQLite
 database connection, `src` is the path
 of the source file, `dest` is the remote destination
 of the file and `uploadtime` is the time of upload of the file.

Throws `SQLite.SQLiteException` on failure.
"""
function dbentry(ctx, src, dest)
    st = stat(src)
    tstamp = get_sql_datetime(st.mtime)
    uptime = get_sql_datetime(ctx.new_upload_time)
    SQLite.execute!(ctx.db, "insert into logs (src, dest, size, tstamp, tupload) values ('$src', '$dest', $(st.size), '$tstamp', '$uptime')")
    info("[Database]: Made entry for $src")
end
