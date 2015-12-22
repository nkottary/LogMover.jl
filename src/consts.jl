let
    conf = ConfParse(ASCIIString(joinpath(Pkg.dir("LogMover"), "config.ini")))
    parse_conf!(conf)

    global const INTERVAL = parse(Int, retrieve(conf, "local", "interval"))
    global const DBNAME = ASCIIString(retrieve(conf, "local", "dbname"))

    global const AWSID = ASCIIString(retrieve(conf, "s3", "id"))
    global const AWSKEY = ASCIIString(retrieve(conf, "s3", "key"))

    delete!(conf._data, "s3")
    delete!(conf._data, "local")
    global LOGS = []
    for (k, v) in conf._data
        parseddest = URI(ASCIIString(v["dest"][1]))
        parseddest.scheme != "s3" && error("Invalid destination scheme $(parseddest.scheme) in destination in section $k in config.ini")
        push!(LOGS, LogDir(ASCIIString(v["src"][1]),
                           ASCIIString(parseddest.path),
                           ASCIIString(parseddest.host)))
    end
end
