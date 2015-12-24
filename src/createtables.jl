using SQLite

DB = SQLite.DB("julia_logmover_data")

SQLite.execute!(DB, "create table logs
(
    id integer primary key AUTOINCREMENT,
    src varchar(100),
    dest varchar(100),
    size integer,
    logtime DateTime,
    awsbkt varchar(100),
    subbkt varchar(100)
);")

SQLite.execute!(DB, "create table checkpoint
(
    last_run DateTime
);")

SQLite.execute!(DB, "create table waiting
(
    filename varchar(100),
    parsed_time DateTime,
    bucket varchar(100)
);")
