import daemon
import os

var d = initDaemon()
daemonize(d):
    echo d.pidfile
    while true:
        echo d.is_running()
        sleep(2000)