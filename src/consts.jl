using ConfParser

let
    conf = ConfParse(ASCIIString(joinpath(Pkg.dir("LogMover"), "config.ini")))
    parse_conf!(conf)

    global const INTERVAL = retrieve(conf, "local", "interval")
    global const DBNAME = retrieve(conf, "local", "dbname")

    global const AWSID = retrieve(conf, "s3", "id")
    global const AWSKEY = retrieve(conf, "s3", "key")
    global const AWSBKT = retrieve(conf, "s3", "bkt")

    delete!(conf._data, "s3")
    global LOGS = []
    for (k, v) in conf._data
        push!(LOGS, Log(v["src"][1], v["dest"][1]))
    end
end
