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
    DEFAULT_PID_FILE =  "daemon-nim.pid"
    TMP = "/tmp"

type 
    Daemon* = object of RootObj
        pidfile:string
        stdin:File
        stdout:File
        stderr:File
        home_dir:string
        umask:Mode
        verbose:int
        daemon_alive:bool
        handler:proc() {.noconv.}

    DaemonRef* = ref Daemon

var glPidPath:string

proc initDaemon*(pidfile:string = VARRUN / DEFAULT_PID_FILE, stdin:File = stdin,stdout:File=stdout,stderr:File=stderr,home_dir:string="",umask:Mode = 0o22,verbose:int = 1):Daemon{.noInit.}= 
    var 
        result = Daemon()
        pidpath = pidfile
        file:File 
    try:
        file = open(pidpath,fmReadWrite)
    except IOError:
        if pidpath != VARRUN / DEFAULT_PID_FILE:
            pidpath =  VARRUN / DEFAULT_PID_FILE
        try:
            file = open(pidpath,fmReadWrite)
        except IOError:
            pidpath =  TMP / DEFAULT_PID_FILE
            file = open(pidpath,fmReadWrite)
    defer: close(file)
    glPidPath = pidpath
    result.pidfile = pidpath
    result.stdin = stdin
    result.stdout = stdout
    result.stderr = stderr
    if home_dir.len > 0:
        result.home_dir = home_dir
        try:
            setCurrentDir(home_dir)
        except OSError:
            discard
    else:
        result.home_dir = getCurrentDir()
    result.umask = umask
    result.verbose = verbose
    result.daemon_alive = true
    return result

# proc newDaemon[T](a:varargs[T]):DaemonRef = 
#     new(result)
#     for s in items(a):
#         result[s] = s

proc log(self:Daemon, args:varargs[string, `$`]) =
    if self.verbose >= 1:
        echo join(args)

# include "system/ansi_c"

# proc atexit*(handler:proc()) {.importc:"atexit", header: "<stdlib.h>".}

# proc run (self:Daemon,handler:proc ()) = discard


proc delpid(){.noconv.} =
    var pid:int = -1
    try:
        pid = parseInt(readFile(glPidPath).strip())
    except OSError as e:
        if errno == ENOENT:
            discard
        else:
            raise
    if pid == getpid():
        removeFile(glPidPath)

template onQuit*(handler:proc(){.noconv, locks: 0.}) :typed =
    bind glPidPath
    # var fn:proc() = proc() = body
    addQuitProc(handler)

proc daemonize(self: Daemon) =
    var pid:Pid 
    try:
        pid = fork()
    except  :
        stderr.write("fork #1 failed: $# ($#)\n" % [$errno, getCurrentExceptionMsg()])
        quit(1)
    if pid > 0 :
        # Exit first parent
        quit(0)
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
        quit(1)
    if pid > 0:
        # Exit from second parent
        quit(0)
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
        quit(0)

    self.log("Started")
    
    # onQuit():
    #     var pid1:int = -1
    #     try:
    #         pid1 = parseInt(readFile(pidpath).strip())
    #     except OSError as e:
    #         if errno == ENOENT:
    #             discard
    #         else:
    #             raise
    #     if pid1 == getpid():
    #         removeFile(pidpath)
    # Write pidfile
    # onQuit(mypidpath,handler)
    onQuit(delpid)
        # delpid()
    # Make sure pid file is removed if we quit

    pid = getpid()
    var pifile:File
    defer:close(pifile)
    pifile = open(self.pidfile, fmWrite)
    pifile.write("$#\n" % $pid)
    

template daemonize*(self:Daemon, body: untyped) =
    var handler:proc() {.noconv.} = proc () {.noconv.} = body
    self.handler = handler
    self.start()

proc start*(self:Daemon) =
   
    self.log("Starting...")
    var mpid:int = -1
    # Check for a pidfile to see if the daemon already runs
    try:
        mpid = parseInt(readFile(self.pidfile).strip())
    except IOError:
        let message = r"pidfile $# $#\n"
        self.stderr.write(message % [self.pidfile, getCurrentExceptionMsg()])
    except ValueError:
        discard
    # except SystemExit:
    #     discard

    if mpid != -1:
        let message = r"pidfile $# already exists. Is it already running?\n"
        self.stderr.write(message % [self.pidfile])
        quit(1)

    # Start the daemon
    self.daemonize()
    self.handler()

proc stop(self:Daemon) =
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
            sleep(6000)
            i = i + 1
            if i div 10 == 0:
                discard kill(getPid(), SIGHUP)
    except OSError as err:
        if errno == ESRCH:
            if existsFile(self.pidfile) :
                removeFile(self.pidfile)
        else:
            echo repr(err)
            quit(1)

    self.log("Stopped")

proc restart(self:Daemon) =
    discard """
    Restart the daemon
    """
    self.stop()
    self.start()

proc get_pid(self:Daemon):int =
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

proc is_running*(self:Daemon):bool =
    let pid = self.get_pid()

    if pid == -1:
        self.log("Process is stopped")
        return false
    elif existsFile("/proc/$#" % $pid): # mac has no /proc
        self.log("Process (pid $#) is running..." % $pid)
        return true
    else:
        self.log("Process (pid $#) is killed" % $pid)
        return false
