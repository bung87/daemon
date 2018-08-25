# daemon

This package that will daemonize your program so it can continue running in the background. It works on Unix, Linux and OS X, creates a PID file and has standard commands (start, stop, restart) .

Based on [python-daemon](https://github.com/serverdensity/python-daemon)

see also [PEP 3143](https://www.python.org/dev/peps/pep-3143/)

## Usage

Define a class which inherits from `Daemon` and has a `run()` method (which is what will be called once the daemonization is completed.

```nim
    import daemon
    import os

    var d = initDaemon()
    daemonize(d):
        echo d.pidfile
        while true:
            echo d.is_running()
            sleep(2000)
```

## Actions

- `start()` - starts the daemon (creates PID and daemonizes).
- `stop()` - stops the daemon (stops the child process and removes the PID).
- `restart()` - does `stop()` then `start()`.
