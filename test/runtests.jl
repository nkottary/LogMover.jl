using LogMover

const LOGPATH = joinpath(Pkg.dir("LogMover"), "test")
logs = [Log("/var/log/syslog", joinpath(LOGPATH, "syslog")),
        Log("/var/log/auth.log", joinpath(LOGPATH, "auth"))]
interval = 0.1 # 6 seconds
dmn = startdaemon(logs, interval)
