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
        !isfile(src) && error("File $src does not exist.")
        st = stat(src)
        mtime = unix2datetime(st.mtime)
        tstamp = DateTime(year(mtime), month(mtime), day(mtime),
                          hour(mtime), minute(mtime), second(mtime))
        new(src, dest, st.size, tstamp)
    end
end

Base.show(io::IO, log::Log) =
    print(io, "Log\n=======================================================\nsrc:\t\t$(log.src)\ndest:\t\t$(log.dest)\nsize:\t\t$(log.sz)\ntimestamp:\t$(log.tstamp)\n")

"""
Exception for failures in upload of log files.
"""
type UploadException <: LogMoverException
    src::AbstractString
    dest::AbstractString
    resp::S3Response
end

"""
Exception for invalid daemon states.
"""
type DaemonException <: LogMoverException
    msg::AbstractString
end

Base.showerror(io::IO, e::UploadException) =
    print(io, "Failed to upload file: $(e.src) -> $(e.dest), S3 response is $(e.resp)")

Base.showerror(io::IO, e::DaemonException) =
    print(io, e.msg)

export LogMoverException, UploadException, CreatePathException,
       DaemonException, Log
