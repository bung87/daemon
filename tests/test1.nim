import daemon
import os
import posix

type MineDaemon = ref object of Daemon
method run(self:MineDaemon) =
    while true:
        echo self.is_running()
        sleep(1)
var d = newDaemon()
d.start()