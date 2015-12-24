"""
Convert datetime to directory path.  The format of the path is:

yyyy/mm/dd/hh/mm
"""
function time2path(dt::DateTime)
    mint = minute(dt)
    suffix = (mint >= 0 && mint < 30) ? "00" : "30"
    return Dates.format(dt, S3PATH_DT_FORMAT) * suffix
end

@test time2path(DateTime("2015-12-14T12:20:30")) == "2015/12/14/12/00"
@test time2path(DateTime("2015-12-14T12:40:30")) == "2015/12/14/12/30"
@test time2path(DateTime("2015-02-14T12:40:30")) == "2015/02/14/12/30"

sql2datetime(sql) = DateTime(sql, SQLITE_DT_FORMAT)
datetime2sql(dt) = Dates.format(dt, SQLITE_DT_FORMAT)

@test sql2datetime("2015-12-22 03:50:03") == DateTime("2015-12-22T03:50:03")
@test datetime2sql(DateTime("2015-12-22T03:50:03.123")) == "2015-12-22 03:50:03"

"""
Get a `DateTime` representing `time()` but without the milli seconds.
"""
unixtimestamp() = DateTime(Dates.format(unix2datetime(time()), JULIA_DT_FORMAT))

"""
Parse the date time from the file name
"""
function parse_time(fname)
    tstring = split(fname, ".")[end - 1]
    dt = DateTime(tstring, FILE_DT_FORMAT)
end

@test parse_time("test.2015-12-22-08-16-25.log") == DateTime("2015-12-22T08:16:25")

"""
Move the log files in the array of `LogDir` instances `logs`.
"""
function logmove(ctx)
    info("[Upload]: Started.")
    tpath = time2path(ctx.new_upload_time)
    for log in LOGS
        dest = joinpath(log.dest, tpath)
        numfiles = upload(ctx, log.src, dest, log.awsbkt, log.subbkt)
        numfiles == 0 && info("[Upload]: [$(log.dest)] No new files to upload this time.")
    end
    info("[Upload]: Done.")
end

"""
Get a list of tuples of *.log files and times parsed from their file names
 in `srcdir` directory where time is greater than `last_upload_time`.
"""
function get_new_files(srcdir, last_upload_time)
    files = filter(x -> ismatch(r".+\.log$", x), readdir(srcdir))
    newfiles = Any[]
    for file in files
        t = parse_time(file)
        t > last_upload_time && push!(newfiles, (file, t))
    end
    return newfiles
end

@test get_new_files(joinpath(Pkg.dir("LogMover"), "test", "test_get_new_files"),
                    DateTime("2015-12-22T08:16:00")) ==
                        [("test.2015-12-22-08-16-06.log", DateTime("2015-12-22T08:16:06")),
                         ("test.2015-12-22-08-17-06.log", DateTime("2015-12-22T08:17:06")),
                         ("test.2015-12-22-08-18-06.log", DateTime("2015-12-22T08:18:06"))]

"""
Get file tuples from files that are currently open in other programs.
"""
function openfds(srcdir, files)
    prog = joinpath(Pkg.dir("LogMover"), "src", "lmlsof.sh")
    lsof = readall(`$prog $srcdir`)
    return filter(x -> contains(lsof, x[1]), files)
end

"""
Checkpoint files to be uploaded in next round.
"""
function docheckpoint_fds(files, bucket)
    for (file, dtime) in files
        sqltime = datetime2sql(dtime)
        SQLite.execute!(DB, "insert into waiting (filename, parsed_time, bucket) values ('$file', '$sqltime', '$bucket');")
        info("File $file is busy, checkpointing for next log move.")
    end
end

"""
Get the previously checkpointed files from the DB.
"""
function getcheckpoint_fds(bucket)
    res = SQLite.query(DB, "select * from waiting where bucket = '$bucket';")
    len = length(res.data[1])
    arr = Array(Any, len)
    for i = 1:len
        arr[i] = (res.data[1][i].value, sql2datetime(res.data[2][i].value))
    end
    return arr
end

clearcheckpoint_fds(bucket) = SQLite.execute!(DB, "delete from waiting where bucket = '$bucket';")

"""
Remove the non existing files.
"""
filter_nonexisting(srcdir, files) = filter(x -> isfile(joinpath(srcdir, x[1])), files)

"""
Get files valid for this upload and checkpoint files that are not valid.
"""
function get_valid_files(srcdir, last_upload_time, bucket)
    oldfiles = filter_nonexisting(srcdir, getcheckpoint_fds(bucket))
    clearcheckpoint_fds(bucket)
    newfiles = get_new_files(srcdir, last_upload_time)
    files = vcat(newfiles, oldfiles)
    invalids = openfds(srcdir, files)
    docheckpoint_fds(invalids, bucket)
    return setdiff(files, invalids)
end

"""
Upload files given by local directory `srcdir` to S3
 destination given by `destdir`.

Throws `UploadException` on failure.
"""
function upload(ctx, srcdir, destdir, awsbkt, subbkt)
    files_to_upload = get_valid_files(srcdir, ctx.last_upload_time, subbkt)
    for (file, ltime) in files_to_upload
        localsrc = joinpath(srcdir, file)
        s3dest = joinpath(destdir, file * ".gz")
        localsrcgz = localsrc * ".gz"
        run(pipeline(`gzip`, stdin=localsrc, stdout=localsrcgz))
        open(localsrcgz, "r") do f
            resp = S3.put_object(ctx.awsenv, awsbkt, s3dest, f)
            resp.http_code != 200 && throw(UploadException(localsrc,
                                                           s3dest, resp))
        end
        rm(localsrcgz)
        info("[Upload]: $localsrc -> $s3dest")
        dbentry(ctx, localsrc, s3dest, ltime, awsbkt, subbkt)
    end
    return length(files_to_upload)
end

"""
Make an SQLite entry for a log upload.
"""
function dbentry(ctx, src, dest, ltime, awsbkt, subbkt)
    st = stat(src)
    logtime = datetime2sql(ltime)
    SQLite.execute!(ctx.db, "insert into logs (src, dest, size, logtime, awsbkt, subbkt) values ('$src', '$dest', $(st.size), '$logtime', '$awsbkt', '$subbkt');")
    info("[Database]: Made entry for $src")
end

"""
Checkpoint time of last run.
"""
function docheckpoint(ctx)
    sql = datetime2sql(ctx.new_upload_time)
    SQLite.execute!(ctx.db, "update checkpoint set last_run = '$sql'")
    ctx.last_upload_time = ctx.new_upload_time
end

"""
Return the time of last run.  If errored then return `DateTime()`.
"""
function getcheckpoint(ctx)
    try
        res = SQLite.query(ctx.db, "select last_run from checkpoint;")
        ctx.last_upload_time = sql2datetime(res.data[1][1].value)
    catch
        ctx.last_upload_time = DateTime()
    end
    ctx.new_upload_time = unixtimestamp()
end

"""
Sleep for a multiple of an interval. For example if interval is
 5 minutes sleep for 5, 10, 15 etc.
"""
function sleep_for_interval_multiple()
    currmin = minute(unixtimestamp())
    #= If minutes is not a multiple of `INTERVAL` minutes wait
       for a multiple of `INTERVAL` minutes before starting. 
    =#
    # May not be necessary any more.
    if rem(currmin, INTERVAL) != 0
        minwait = INTERVAL * (div(currmin, INTERVAL) + 1) - currmin
        sleep(minwait * 60)
    end
end
