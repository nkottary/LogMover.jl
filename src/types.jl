abstract LogMoverException <: Exception

"""
Type for holding the details of the log file.

 `src` -> The local path to the log file.
 `dest` -> The remote destination path.
 `sz` -> The size in bytes of the file.
 `tstamp` -> The create timestamp of the file.
"""
immutable Log
    src::AbstractString
    dest::AbstractString
    sz::Int
    tstamp::DateTime

    function Log(src, dest)
        st = stat(src)
        mtime = unix2datetime(st.mtime)
        tstamp = DateTime(year(mtime), month(mtime), day(mtime),
                          hour(mtime), minute(mtime), second(mtime))
        new(src, dest, st.size, tstamp)
    end
end

Base.show(io::IO, log::Log) =
    print(io, "Log\n====\nsrc: $(log.src)\ndest: $(log.dest)\nsize: $(log.sz)\ntimestamp: $(log.tstamp)\n")

"""
Exception for failures in upload of log files.
"""
type UploadException <: LogMoverException
    log::Log
end

"""
Exception for failure to create remote path.
"""
type CreatePathException <: LogMoverException
    path::AbstractString
end

"""
Exception for invalid daemon states.
"""
type DaemonException <: LogMoverException
    msg::AbstractString
end

Base.showerror(io::IO, e::UploadException) =
    print(io, "Failed to upload file: $(e.log)")

Base.showerror(io::IO, e::CreatePathException) =
    print(io, "Failed to create path $(e.path)")

Base.showerror(io::IO, e::DaemonException) =
    print(io, e.msg)

export LogMoverException, UploadException, CreatePathException,
       DaemonException, Log
