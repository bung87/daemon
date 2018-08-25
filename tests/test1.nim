import daemon
import os
import posix

var d = initDaemon()
daemonize(d):
    echo d.pidfile
    while true:
        
        echo d.is_running()
        sleep(2000)