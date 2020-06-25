# daemonim

This package that will daemonize your program so it can continue running in the background. It works on Unix, Linux and OS X, creates a PID file and has standard commands (start, stop, restart) .

Based on [python-daemon](https://github.com/serverdensity/python-daemon)

see also [PEP 3143](https://www.python.org/dev/peps/pep-3143/)

## Usage

```nim

import daemonim
import os

const
  devnull = "/dev/null"

var d = initDaemon("/tmp/daemonim.pid", open(devnull, fmRead),
  open(devnull, fmAppend), open(devnull, fmAppend))
daemonize(d):
  echo d.pidfile
  while true:
    echo d.is_running()
    sleep(2000)
```

or

```nim

import os
import strformat

import daemonim

const
  defaultAppName = "daemonim"
  defaultPidPath = "/tmp/daemonim.pid"
  STD_ERR_LOG = &"{defaultAppName}-stderr.log"
  STD_OUT_LOG = &"{defaultAppName}-stdout.log"
  STD_IN_LOG = &"{defaultAppName}-stdin.log"

var d2 = initDaemon(defaultPidPath, STD_IN_LOG, STD_OUT_LOG, STD_ERR_LOG)
# or var d2 = initDaemon(defaultPidPath)
daemonize(d2):
  echo d2.pidfile
  while true:
    echo d2.is_running()
    sleep(2000)
```

## Actions

- `start()` - starts the daemon (creates PID and daemonizes).
- `stop()` - stops the daemon (stops the child process and removes the PID).
- `restart()` - does `stop()` then `start()`.
