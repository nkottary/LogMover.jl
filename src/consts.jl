let
    conf = ConfParse(ASCIIString(joinpath(Pkg.dir("LogMover"), "config.ini")))
    parse_conf!(conf)

    global const INTERVAL = parse(Int, retrieve(conf, "local", "interval"))
    global const DBNAME = ASCIIString(retrieve(conf, "local", "dbname"))

    global const AWSID = ASCIIString(retrieve(conf, "s3", "id"))
    global const AWSKEY = ASCIIString(retrieve(conf, "s3", "key"))
    global const AWSBKT = ASCIIString(retrieve(conf, "s3", "bkt"))

    delete!(conf._data, "s3")
    delete!(conf._data, "local")
    global LOGS = []
    for (k, v) in conf._data
        push!(LOGS, LogDir(ASCIIString(v["src"][1]), ASCIIString(v["dest"][1])))
    end
end
