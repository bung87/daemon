# daemon
# Copyright zhoupeng
# daemonizer for Unix, Linux and OS X
# import private/oop
import os
import posix
import strutils


type Daemon = object {.inheritable.}
    pidfile:string
    stdin:string #=devnull
    stdout:string #=devnull
    stderr:string #=devnull,
    home_dir:string #='.', 
    umask:Mode #=0o22, 
    verbose:int #=1,
    daemon_alive:bool


method log(self:Daemon, args:varargs[string, `$`]) =
    if self.verbose >= 1:
        echo join(args)

include "system/ansi_c"

method daemonize(self:Daemon) =
    var pid:Pid 
    try:
        pid = fork()
    except OSError :
        stderr.write("fork #1 failed: $# ($#)\n" % [$errno, getCurrentExceptionMsg()])
        exitnow(1)
    if pid > 0 :
        # Exit first parent
        exitnow(0)
    # Decouple from parent environment
    discard chdir(self.home_dir)
    discard setsid()
    discard umask(self.umask)

    # Do second fork
    try:
        pid = fork()
    except OSError as e:
        stderr.write(
            "fork #2 failed: $# ($#)\n" % [$errno, getCurrentExceptionMsg()])
        exitnow(1)
    if pid > 0:
        # Exit from second parent
        exitnow(0)
    # if platform != "darwin":  # This block breaks on OS X
        # Redirect standard file descriptors
    stdout.flushFile()
    stderr.flushFile()
    let si = open(self.stdin, fmRead)
    let so = open(self.stdout, fmAppend)
    var se:File
    if self.stderr.len > 0:
        try:
            se = open(self.stderr, fmAppend, 0)
        except ValueError:
            # Python 3 can't have unbuffered text I/O
            se = open(self.stderr, fmAppend, 1)
    else:
        se = so
    discard dup2( c_fileno(si), c_fileno(stdin))
    discard dup2( c_fileno(so), c_fileno(stdout))
    discard dup2( c_fileno(se), c_fileno(stderr))

    onSignal(SIGTERM,SIGINT):
        # self.daemon_alive = false
        exitnow(0)

    self.log("Started")

    # Write pidfile
    # atexit.register(
    #     self.delpid)  # Make sure pid file is removed if we quit
    # pid = str(getpid())
    # open(self.pidfile, "w+").write("%s\n" % pid)

method delpid(self:Daemon) =
    var pid:int = -1
    try:
        pid = parseInt(readFile(self.pidfile).strip())
    except OSError as e:
        if errno == ENOENT:
            discard
        else:
            raise
    if pid == getpid():
        removeFile(self.pidfile)

method run (self:Daemon) = discard
    
method start(self:Daemon) =
   
    self.log("Starting...")
    var mpid:int = -1
    # Check for a pidfile to see if the daemon already runs
    try:
        mpid = parseInt(readFile(self.pidfile).strip())
    except IOError:
        discard
    # except SystemExit:
    #     discard

    if mpid != -1:
        let message = r"pidfile $# already exists. Is it already running?\n"
        stderr.write(message % [self.pidfile])
        exitnow(1)

    # Start the daemon
    self.daemonize()
    self.run()

method stop(self:Daemon) =
    discard """
    Stop the daemon
    """
    var mpid:int = -1
    if self.verbose >= 1:
        self.log("Stopping...")

    # Get the pid from the pidfile
    try:
        mpid = parseInt(readFile(self.pidfile).strip())
    except IOError:
        discard
    if mpid != -1:
        let message = "pidfile %s does not exist. Not running?\n"
        stderr.write(message % self.pidfile)

        # Just to be sure. A ValueError might occur if the PID file is
        # empty but does actually exist
        if existsFile(self.pidfile) :
            removeFile(self.pidfile)

        return  # Not an error in a restart

    # Try killing the daemon process
    try:
        var i = 0
        while true:
            discard kill(getPid(), SIGTERM)
            sleep(6)
            i = i + 1
            if i div 10 == 0:
                discard kill(getPid(), SIGHUP)
    except OSError as err:
        if errno == ESRCH:
            if existsFile(self.pidfile) :
                removeFile(self.pidfile)
        else:
            echo repr(err)
            exitnow(1)

    self.log("Stopped")

method restart(self:Daemon) =
    discard """
    Restart the daemon
    """
    self.stop()
    self.start()

method get_pid(self:Daemon):int =
    var pid = -1
    try:
        pid = parseInt(readFile(self.pidfile).strip())
    except IOError:
        discard
    # except SystemExit:
    #     pid = nil
    return pid

method is_running(self:Daemon):bool =
    let pid = self.get_pid()

    if pid == -1:
        self.log("Process is stopped")
        return false
    elif existsFile("/proc/$#" % $pid) :
        self.log("Process (pid $#) is running..." % $pid)
        return true
    else:
        self.log("Process (pid $#) is killed" % $pid)
        return false

