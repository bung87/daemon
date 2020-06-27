# daemonim
# Copyright zhoupeng
# daemonizer for Unix, Linux and OS X

import os
import posix
import strutils
import strformat

const
  # defaultAppName = "daemonim"
  DEVNULL = "/dev/null"
  # VARRUN = "/var/run"
  # STD_ERR_LOG = "$#-stderr.log" % defaultAppName
  # STD_OUT_LOG = "$#-stdout.log" % defaultAppName
  # STD_IN_LOG = "$#-stdin.log" % defaultAppName
  # DEFAULT_PID_FILE =  "$#.pid" % defaultAppName
  # TMP = "/tmp"
  # defaultPidPath = when defined(macosx): TMP / DEFAULT_PID_FILE
  # else: VARRUN / DEFAULT_PID_FILE
  invalidPid* = -1

type
  Daemon* = object of RootObj
    pidfile*: string
    stdin: File
    stdout: File
    stderr: File
    home_dir: string
    umask: Mode
    verbose: int
    daemon_alive: bool
    handler*: proc() {.noconv.}

  DaemonRef* = ref Daemon

var glPidPath:string

proc init(pidfile: string ,
  stdin, stdout, stderr: File,
  home_dir: string, umask: Mode, verbose: range[0..3]): Daemon {.noInit.} =

  result = Daemon()
  var
    pidpath = pidfile

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

proc `handler=`*(d: var Daemon, h: proc() {.noconv.}) =
  d.handler = h

proc initDaemon*(pidfile: string,
  stdin = stdin, stdout = stdout, stderr = stderr,
  home_dir = ".", umask: Mode = 0o22, verbose: range[0..3] = 0): Daemon {.noInit.} =
  return init(pidfile, stdin, stdout, stderr, home_dir, umask, verbose)

proc initDaemon*(pidfile: string ,
  stdin, stdout, stderr: string,
  home_dir = ".", umask: Mode = 0o22, verbose: range[0..3] = 0): Daemon {.noInit.} =
  doAssert system.stdin.reopen(stdin, fmRead)
  doAssert system.stdout.reopen(stdout, fmAppend)
  doAssert system.stderr.reopen(stderr, fmAppend)
  return init(pidfile, system.stdin, system.stdout ,system.stderr, home_dir, umask, verbose)

proc log(self: Daemon, args: varargs[string, `$`]) =
  if self.verbose >= 1:
    self.stdout.writeLine join(args)
    self.stdout.flushFile

proc delpid(){.noconv, locks: 0.} =
  var pid = invalidPid
  try:
    pid = parseInt(readFile(glPidPath).strip())
  except IOError:
    # Pid file didn't exist
    discard
  except OSError:
    if errno == ENOENT:
      discard
    else:
      raise
  if pid == getpid():
    removeFile(glPidPath)

template onQuit*(handler: proc() {.noconv, locks: 0.}): typed =
  bind glPidPath  # DEBUG: What for this capture?
  addQuitProc(handler)

proc daemonize(self: Daemon) =
  var pid: Pid
  try:
    pid = fork()
  except:
    stderr.writeLine(&"fork #1 failed: {errno} ({getCurrentExceptionMsg()})")
    quit(1)
  if pid > 0:
    # Exit first parent
    quit(0)
  # Decouple from parent environment
  try:
    discard chdir(self.home_dir)
  except:
    stderr.writeLine("chdir failed: {errno} ({getCurrentExceptionMsg})")
  discard setsid()
  discard umask(self.umask)

  # Do second fork
  try:
    pid = fork()
  except OSError :
    stderr.writeLine(&"fork #2 failed: {errno} ({getCurrentExceptionMsg()})")
    quit(1)
  if pid > 0:
    # Exit from second parent
    quit(0)

  self.stdout.flushFile()
  self.stderr.flushFile()

  # discard posix.dup2(getFileHandle(self.stdin),getFileHandle(stdin))
  # discard posix.dup2(getFileHandle(self.stdout), getFileHandle(stdout))
  # discard posix.dup2(getFileHandle(self.stderr), getFileHandle(stderr))

  onSignal(SIGTERM, SIGINT):
    # self.daemon_alive = false
    quit(0)

  self.log("Started")

  # onQuit():
  #   var pid1:int = -1
  #   try:
  #     pid1 = parseInt(readFile(pidpath).strip())
  #   except OSError as e:
  #     if errno == ENOENT:
  #       discard
  #     else:
  #       raise
  #   if pid1 == getpid():
  #     removeFile(pidpath)
  # Write pidfile
  # onQuit(mypidpath,handler)
  onQuit(delpid)
  # delpid()
  # Make sure pid file is removed if we quit

  let pifile: File = open(self.pidfile, fmWrite)
  defer: close(pifile)
  pifile.writeLine(&"{getpid()}")

template daemonize*(self: Daemon, body: untyped) =
  var handler: proc() {.noconv.} = proc () {.noconv.} = body
  self.handler = handler
  self.start()

proc start*(self: Daemon) =
  self.log("Starting...")
  var mpid = invalidPid
  # Check for a pidfile to see if the daemon already runs
  try:
    mpid = parseInt(readFile(self.pidfile).strip())
  except IOError:
    self.stderr.writeLine(&"pidfile {self.pidfile} {getCurrentExceptionMsg()}")
  except ValueError:
    discard
  # except SystemExit:
  #   discard

  if mpid != invalidPid:
    self.stderr.writeLine(
      &"pidfile {self.pidfile} already exists. Is it already running?")
    quit(1)

  # Start the daemon
  self.daemonize()
  self.handler()

proc stop*(self: Daemon) =
  ##[
  Stop the daemon
  ]##
  var mpid: int = invalidPid
  if self.verbose >= 1:
    self.log("Stopping...")

  # Get the pid from the pidfile
  try:
    mpid = parseInt(readFile(self.pidfile).strip())
  except IOError:
    discard
  if mpid == invalidPid:
    self.stderr.writeLine(&"pidfile {self.pidfile} does not exist. Not running?")

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

proc restart*(self:Daemon) =
    ##[
    Restart the daemon
    ]##
    self.stop()
    self.start()

proc getPid*(self: Daemon): int =
  var pid = invalidPid
  try:
    pid = parseInt(readFile(self.pidfile).strip())
  except IOError:
    discard
  except ValueError:
    discard
  # except SystemExit:
  #   pid = nil
  return pid


when defined(macosx): 
  proc running(pid:int):bool =
    try:
      discard kill(Pid(pid),0)
    except OSError:
      return false
    result = true
else:
  proc running(pid:int):bool =
    result = existsFile("/proc/$#" % $pid)

proc is_running*(self:Daemon):bool =
  let pid = self.getPid()

  if pid == invalidPid:
    self.log("Process is stopped")
    return false
  elif running(pid): # mac has no /proc
    self.log("Process (pid $#) is running..." % $pid)
    return true
  else:
    self.log("Process (pid $#) is killed" % $pid)
    return false
