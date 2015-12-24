# Generate files with timestamp at random intervals

using Logging
using Base.Dates
using Faker

g_genfile = true

Logging.configure(level=INFO, 
                  filename=joinpath(Pkg.dir("LogMover"), "test", 
                                    "genfiles.log"),
                  override_info=true)

"""
Create files of the form test.<timestamp>.log in the directory
 `destdir` after every random interval where the random interval is
 between `min_gap` and `max_gap` seconds.
"""
function genfiles(destdir, min_gap, max_gap)
    while g_genfile
        tstamp = Dates.format(unix2datetime(time()), "yyyy-mm-dd-HH-MM-SS")
        path = joinpath(destdir, "test.$tstamp.log")
        open(path, "w") do f
            write(f, randstring(20000 + (abs(rand(Int)) % 20000) ))
        end
        info("Created $path")
        twait = min_gap + (abs(rand(Int)) % (max_gap - min_gap))
        sleep(twait)
    end
    info("Stopped.")
end

function start_genfiles(logtype)
    dmn = @task genfiles(ASCIIString(joinpath(Pkg.dir("LogMover"), "test", "src", logtype)), 30, 120) # half a minute to 2 minutes.
    schedule(dmn)
    info("Started")
    global g_genfile = true
    nothing
end

function stop_genfiles()
    global g_genfile = false
    info("Stopping...")
    nothing
end
