# Daemon task and controllers.

# All variables of the form g_* are globals.

g_plug = false           # Signifies whether daemon is done (false) or running (true).
g_switch = false         # Signifies whether daemon is paused (false)
                         # or unpaused (true).
g_cond = nothing         # For wait() and notify()

Logging.configure(level=INFO, filename=joinpath(Pkg.dir("LogMover"), "logmover.log"))

"""
A daemon that uploades log files every `INTERVAL`
 minutes to S3.
"""
function daemon()
    ctx = LogMoverCtx(SQLite.DB(DBNAME), AWSEnv(id=AWSID, key=AWSKEY))

    currtime = unix2datetime(time())
    currmin = minute(currtime)

    #= If minutes is not a multiple of `INTERVAL` minutes wait
       for a multiple of `INTERVAL` minutes before starting. 
    =#
    if rem(currmin, INTERVAL) != 0
        minwait = INTERVAL * (div(currmin, INTERVAL) + 1) - currmin
        sleep(minwait * 60)
    end

    global g_plug, g_switch, g_cond
    while g_plug
        while g_switch && g_plug
            msgflag = true
            tic()
            ctx.new_upload_time = time()
            logmove(ctx)
            ctx.last_upload_time = ctx.new_upload_time
            twait = (INTERVAL * 60) - toq()
            if twait > 0
                sleep(twait)
            else
                warn("[Daemon]: Moving files took longer than the wait time, consider using a higher interval.")
            end
        end
        if g_plug
            info("[Daemon]: Paused.")
            wait(g_cond)
        end
    end
    info("[Daemon]: Stopped.")
end

"""
Start the daemon as a `Task`.
"""
function startd()
    global g_plug, g_switch, g_cond
    g_plug == true && throw(DaemonException("Daemon already running. Please stop current daemon by calling `stop()`"))

    g_plug = true
    g_switch = true
    g_cond = Condition()

    info("[Daemon]: Starting...")
    dmn = @task daemon()
    schedule(dmn)
    info("[Daemon]: Started with interval $INTERVAL minutes.")
    return dmn
end

"""
Permanently stop the daemon. The daemon task will be in `done` state
 after this call.
"""
function stop()
    global g_plug
    g_plug == false && throw(DaemonException("Cannot stop Daemon, there is no Daemon running."))
    info("[Daemon]: Stopping...")
    g_plug = false
end

"""
Start or unpause the daemon.
"""
function unpause()
    global g_plug, g_switch, g_cond
    g_plug == false && throw(DaemonException("Cannot unpause Daemon, there is no Daemon running."))
    g_switch == true && throw(DaemonException("Cannot unpause Daemon, Daemon is not paused."))
    info("[Daemon]: Unpaused.")
    g_switch = true
    notify(g_cond)
end

"""
Pause the daemon.
"""
function pause()
    global g_plug, g_switch
    g_plug == false && throw(DaemonException("Cannot pause Daemon, there is no Daemon running."))
    g_switch == false && throw(DaemonException("Cannot pause Daemon, Daemon is already paused."))
    info("[Daemon]: Pausing...")
    g_switch = false
end

export startd, stop, pause, unpause
