# Monitor Functional SSH (mfs)

Attempts to start a SSH session (concurrently) to each of our segfault.net instances and reports on telegram any failures to connect or login.

Admins must provide `TG_KEY` and `TG_CHATID` env variables to start the tool.
```bash
$ export TG_KEY="key"
$ export TG_CHATID="12345678"
```

The servers list must be supplied via CLI flags, e.g.:
```bash
$ ./mfs \
    -s de.segfault.net:secret \
    -s us.segfault.net:secret \
    -s it.segfault.net:secret
```

By default it checks all servers every 1 minute, you can tweak the timer e.g. `-timer 5m`
