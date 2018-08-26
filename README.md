# daemonim

This package that will daemonize your program so it can continue running in the background. It works on Unix, Linux and OS X, creates a PID file and has standard commands (start, stop, restart) .

Based on [python-daemon](https://github.com/serverdensity/python-daemon)

see also [PEP 3143](https://www.python.org/dev/peps/pep-3143/)

## Usage

```nim
    import daemonim
    import os
    const
        DEVNULL = "/dev/null"
    var d = initDaemon("/tmp/daemonim.pid",open(DEVNULL,fmRead),open(DEVNULL,fmAppend),open(DEVNULL,fmAppend))
    daemonize(d):
        echo d.pidfile
        while true:
            echo d.is_running()
            sleep(2000)
```

or

```nim
    import daemonim
    import os
    const
        defaultAppName = "daemonim"
        STD_ERR_LOG = "$#-stderr.log" % defaultAppName
        STD_OUT_LOG = "$#-stdout.log" % defaultAppName
        STD_IN_LOG = "$#-stdin.log" % defaultAppName

    var d2 = initDaemon(defaultPidPath,STD_IN_LOG,STD_OUT_LOG,STD_ERR_LOG)
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
