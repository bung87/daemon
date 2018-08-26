import daemonim
import os
import strutils
import posix

const 
    defaultAppName = "daemonim"
    DEVNULL = "/dev/null"
    VARRUN = "/var/run"
    STD_ERR_LOG = "$#-stderr.log" % defaultAppName
    STD_OUT_LOG = "$#-stdout.log" % defaultAppName
    STD_IN_LOG = "$#-stdin.log" % defaultAppName
    DEFAULT_PID_FILE =  "$#.pid" % defaultAppName
    TMP = "/tmp"
    defaultPidPath = when defined(macosx): TMP / DEFAULT_PID_FILE
    else: VARRUN / DEFAULT_PID_FILE


# var d = initDaemon(DEFAULT_PID_FILE,open(DEVNULL,fmRead),open(DEVNULL,fmAppend),open(DEVNULL,fmAppend))
# daemonize(d):
#     echo d.pidfile
#     while true:
#         echo d.is_running()
#         sleep(2000)
var sin,sout,serr:File
# discard stdin.reopen(STD_IN_LOG,fmRead)
# discard stdout.reopen(STD_OUT_LOG,fmAppend)
# discard stderr.reopen(STD_ERR_LOG,fmAppend)
# var d2 = initDaemon(defaultPidPath,stdin,stdout,stderr)
var d2 = initDaemon(defaultPidPath,STD_IN_LOG,STD_OUT_LOG,STD_ERR_LOG)
daemonize(d2):
    echo d2.pidfile
    while true:
        echo d2.is_running()
        sleep(2000)