#!/bin/bash

# Delete s3 files
s3cmd del -r s3://jdlogmover/moblog
s3cmd del -r s3://jdlogmover/weblog

# Delete SQLite entries
echo -e "delete from logs;\n delete from waiting; \n" | sqlite3 /home/nishanth/.julia/v0.4/LogMover/julia_logmover_data

# Delete local log
rm logmover.log ; touch logmover.log
rm test/genfiles.log ; touch test/genfiles.log

rm /home/nishanth/.julia/v0.4/LogMover/test/src/moblog/*
rm /home/nishanth/.julia/v0.4/LogMover/test/src/weblog/*
