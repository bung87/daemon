# daemon
# Copyright zhoupeng
# daemonizer for Unix, Linux and OS X
# import private/oop
import os
import posix
import strutils

const 
    DEVNULL = "/dev/null"
    VARRUN = "/var/run"
    STD_ERR_LOG = "daemon-nim-stderr.log"
    STD_OUT_LOG = "daemon-nim-stdout.log"
    STD_IN_LOG = "daemon-nim-stdin.log"
    pid_file =  "daemon-nim.pid"

type Daemon* = ref object of RootObj
    # DaemonRef* = ref of Daemon
    pidfile:string
    stdin:File #=devnull
    stdout:File #=devnull
    stderr:File #=devnull,
    home_dir:string #='.', 
    umask:Mode #=0o22, 
    verbose:int #=1,
    daemon_alive:bool
# ,stdin,stdout,stderr:string = DEVNULL,home_dir:string,umask:Mode = 0o22,verbose:int = 1
method initDaemon*(self:Daemon,pidfile:string = VARRUN / pid_file, stdin:File = stdin,stdout:File=stdout,stderr:File=stderr,home_dir:string="",umask:Mode = 0o22,verbose:int = 1) =
    # stdin,stdout,stderr:string = DEVNULL,\
    # stdout:string = DEVNULL,\
    # stderr:string = DEVNULL,\
    # home_dir:string,\
    # umask:Mode = 0o22,\
    # verbose:int = 1): Daemon =

    # result = Daemon()

    self.pidfile = pidfile
    self.stdin = stdin
    self.stdout = stdout
    self.stderr = stderr
    if home_dir.len > 0:
        self.home_dir = home_dir
        try:
            setCurrentDir(home_dir)
        except OSError:
            discard
    else:
        self.home_dir = getCurrentDir()
    self.umask = umask
    self.verbose = verbose

method log(self:Daemon, args:varargs[string, `$`]) =
    if self.verbose >= 1:
        echo join(args)

# include "system/ansi_c"

# proc atexit*(handler:proc()) {.importc:"atexit", header: "<stdlib.h>".}


method daemonize(self:Daemon) =
    var pid:Pid 
    try:
        pid = fork()
    except  :
        stderr.write("fork #1 failed: $# ($#)\n" % [$errno, getCurrentExceptionMsg()])
        exitnow(1)
    if pid > 0 :
        # Exit first parent
        exitnow(0)
    # Decouple from parent environment
    try:
        discard chdir(self.home_dir)
    except:
        discard
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
    self.stdout.flushFile()
    self.stderr.flushFile()
    discard reopen(self.stdin,STD_IN_LOG, fmRead)
    discard reopen(self.stdout,STD_OUT_LOG, fmAppend)
    discard reopen(self.stderr, STD_ERR_LOG,fmAppend)
    # var se:File
    
    # if self.stderr:
    # try:
    #     discard reopen(self.stderr, STD_ERR_LOG,fmAppend, 0)
    # except ValueError:
    #     # Python 3 can't have unbuffered text I/O
    #     discard reopen(self.stderr, STD_ERR_LOG,fmAppend, 1)
    # except:
    #     se = so
    # discard dup2( c_fileno(self.stdin), c_fileno(stdin))
    # discard dup2( c_fileno(self.stdout), c_fileno(stdout))
    # discard dup2( c_fileno(self.stderr), c_fileno(stderr))

    onSignal(SIGTERM,SIGINT):
        # self.daemon_alive = false
        echo "on signal"
        exitnow(0)

    self.log("Started")
    
    # Write pidfile
    # closureScope:
    #     myClosure = proc() = self.delpid
    template delpid(self:Daemon) :proc() =
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
    
    # atexit( self.delpid )  # Make sure pid file is removed if we quit
    # # addQuitProc
    # pid = getpid()
    # try:
    #     open(self.pidfile, fmWrite).write("$#\n" % $pid)
    # except:
    #     self.pidfile = "/tmp" / pid_file
    #     open(self.pidfile, fmWrite).write("$#\n" % $pid)


method run (self:Daemon) = discard
    
method start*(self:Daemon){.base.} =
   
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
        self.stderr.write(message % [self.pidfile])
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
    if mpid == -1:
        let message = "pidfile %s does not exist. Not running?\n"
        self.stderr.write(message % self.pidfile)

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
    except ValueError:
        discard
    # except SystemExit:
    #     pid = nil
    return pid

method is_running*(self:Daemon):bool =
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

when isMainModule:
    type MineDaemon = ref object of Daemon
    method run(self:MineDaemon) =
        while true:
            echo 3
            sleep(1)
    var d = newDaemon()
    d.start()
