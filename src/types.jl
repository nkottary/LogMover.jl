abstract LogMoverException <: Exception

"""
Type for holding the details of the log file.

 `src` -> The local path to the log file.
 `dest` -> The remote destination path.
 `sz` -> The size in bytes of the file.
 `tstamp` -> The create timestamp of the file.
"""
immutable LogDir
    src::AbstractString
    dest::AbstractString

    function LogDir(src, dest)
        !isdir(src) && error("Directory $src does not exist.")
        new(src, dest)
    end
end

Base.show(io::IO, log::LogDir) =
    print(io, "Log Directory\n=======================================================\nsrc:\t\t$(log.src)\ndest:\t\t$(log.dest)\n")

"""
Context for argument passing.
"""
type LogMoverCtx
    db::SQLite.DB
    awsenv::AWSEnv
    last_upload_time::Float64
    new_upload_time::Float64

    function LogMoverCtx(db, awsenv)
        new(db, awsenv, 0, 0)
    end
end

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
       DaemonException, LogDir
