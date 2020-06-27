import unittest

import daemonim
import os
import strutils
import strformat

#const
#    defaultAppName = "daemonim"
#    DEVNULL = "/dev/null"
#    VARRUN = "/var/run"
#    STD_ERR_LOG = "$#-stderr.log" % defaultAppName
#    STD_OUT_LOG = "$#-stdout.log" % defaultAppName
#    STD_IN_LOG = "$#-stdin.log" % defaultAppName
#    DEFAULT_PID_FILE =  "$#.pid" % defaultAppName
#    TMP = "/tmp"
#    defaultPidPath = when defined(macosx): TMP / DEFAULT_PID_FILE
#    else: VARRUN / DEFAULT_PID_FILE


suite "Object Daemon stuff":
  setup:
    let pidfile: string = currentSourcePath.parentDir / "tests.pid"

    var stdinF: File = open(currentSourcePath.parentDir / "stdin.log", fmWrite)
    stdinF.close
    stdinF = open(currentSourcePath.parentDir() / "stdin.log", fmRead)
    let stdoutF: File = open(currentSourcePath.parentDir / "stdout.log", fmAppend)
    let stderrF: File = open(currentSourcePath.parentDir / "stderr.log", fmAppend)

  teardown:
    removeFile(pidfile)
    stdinF.close
    stdoutF.close
    stderrF.close
    removeFile(currentSourcePath.parentDir / "stdin.log")
    removeFile(currentSourcePath.parentDir / "stdout.log")
    removeFile(currentSourcePath.parentDir / "stderr.log")

  test "Plain object creation with only a pidfile":
    let d: Daemon = initDaemon(pidfile)

    assert d.pidfile == pidfile

  test "Plain object creation with pidfile and output files":
    let d: Daemon = initDaemon(pidfile, stdinF, stdoutF, stderrF)

    assert d.pidfile == pidfile

  test "Getting the PID of a Daemon":
    let d: Daemon = initDaemon(pidfile)

    assert d.getPid == invalidPid

  test "Getting the Status of a Daemon":
    let d: Daemon = initDaemon(pidfile, stdinF, stdoutF, stderrF, verbose=1)

    assert d.is_running == false

    let o: File = open(currentSourcePath.parentDir / "stdout.log")
    defer: o.close
    assert "Process is stopped" == o.readAll.strip()

suite "Starting/stopping a Daemon":
  setup:
    let pidfile: string = currentSourcePath.parentDir / "tests.pid"

    var stdinF: File = open(currentSourcePath.parentDir / "stdin.log", fmWrite)
    stdinF.close
    stdinF = open(currentSourcePath.parentDir() / "stdin.log", fmRead)
    let stdoutF: File = open(currentSourcePath.parentDir / "stdout.log", fmAppend)
    let stderrF: File = open(currentSourcePath.parentDir / "stderr.log", fmAppend)

  teardown:
    removeFile(pidfile)
    stdinF.close
    stdoutF.close
    stderrF.close
    removeFile(currentSourcePath.parentDir / "stdin.log")
    removeFile(currentSourcePath.parentDir / "stdout.log")
    removeFile(currentSourcePath.parentDir / "stderr.log")

  test "Assigning a function handler to execute, full cycle":
    let o: File = open(currentSourcePath.parentDir / "stdout.log")
    defer: o.close

    proc fakeTask() {.noconv.} =
      stdoutF.writeLine("Fake function run")
      stdoutF.flushFile
    var d: Daemon = initDaemon(pidfile, stdinF, stdoutF, stderrF, verbose=1)
    d.handler = fakeTask

    check d.is_running == false
    check @["Process is stopped"] == o.readAll.strip().splitLines
    d.start()
    check @["Starting...", "Started", "Fake function run"] ==
      o.readAll.strip().splitLines
    check d.is_running == true
    check @[&"Process (pid {d.getPid}) is running..."] ==
      o.readAll.strip().splitLines

  test "Restarting a Daemon, full cycle":
    let o: File = open(currentSourcePath.parentDir / "stdout.log")
    defer: o.close

    proc fakeTask() {.noconv.} =
      stdoutF.writeLine("Fake function run")
      stdoutF.flushFile
    var d: Daemon = initDaemon(pidfile, stdinF, stdoutF, stderrF, verbose=1)
    d.handler = fakeTask

    check d.is_running == false
    discard o.readAll.strip().splitLines
    d.restart()
    check d.is_running == true
    check @["Stopping...", "Starting...", "Started", "Fake function run",
      &"Process (pid {d.getPid}) is running..."] == o.readAll.strip().splitLines

  test "Daemonize through the template":
    let o: File = open(currentSourcePath.parentDir / "stdout.log")
    defer: o.close

    var d: Daemon = initDaemon(pidfile, stdinF, stdoutF, stderrF, verbose=1)

    daemonize(d):
      stdoutF.writeLine("Running a fake function")
      stdoutF.flushFile

    check d.is_running == true
    let output = o.readAll.strip().splitLines
    check &"Process (pid {d.getPid}) is running..." in output
    check "Running a fake function" in output
