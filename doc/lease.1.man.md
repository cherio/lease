% lease(1) Version 1.0 | User Commands
% Yuri Cherio
% May 27, 2026

# NAME

**lease** - FIFO semaphore utility that manages resource ownership by processes.

# SYNOPSIS

**lease** [*options*].\..

**lease** [*options*].\.. -\- command [*arguments...*].\..

# DESCRIPTION

FIFO semaphore utility that manages resource ownership by processes.

Obtains a lease/ownership for the specified resource. When the resource lease
is requested for a specific PID, it succeeds if the resource is available,
otherwise, it will add the requesting process to a FIFO queue and block until
the resource becomes available when the other processes that acquired the
resource earlier release it or finish executing.

A process can borrow a resource either for itself or for another process by
supplying `-p PID`.

This utility can also launch a user-supplied command upon successful
acquisition of this resource lease. In this case, option `-p` is not needed and
`-r` is optional and will be calculated, if not specified, by hashing the user
command, thus using the user command as a resource identifier.

A resource can be explicitly released with the `--release` option. Otherwise
the resource will be released when the owner process ends.

# OPTIONS

**-r {resource} | -\-resource={resource}**
: Resource identifier. Lease/ownership is created/acquired on this resource.

**-p {PID} | -\-pid={PID}**
: Process ID that is to become an owner of the resource (to acquire a lease on it).

**-d {directory} | -\-dir={directory}**
: A directory where the semaphore/resource/queue files are stored. Defaults to
XDG_RUNTIME_DIR/zemaphore if present, falling back to
XDG_DATA_HOME/.local/share/zemaphore when systemd is not present.

**-c {number} | -\-concurrency={number}**
: Maximum number of processes allowed to own/lease the resource at the same time
and run concurrently.

` `
: Concurrency is enforced within the same concurrency/exclusivity group. Minimum
of 1 is enforced. Default is 1.

**-x {group} | -\-exclusivity={group}**
: Exclusivity group code/identifier.
` `
: Only processes within one group can be executed concurrently.
Concurrency defines the maximum number of processes that can run in parallel within the same group.
` `
: If a resource lease is acquired by Group A then a request from Group B will block until
all processes in Group A scheduled before have completed and released this resource.
` `
: Optional, defaults to `X`

**-w {wait sec} | -\-wait={wait sec}**
: Wait this long (seconds) before giving up on locking/acquiring the resource.

` `

: When wait time exceeds this parameter, the semaphore exits with non-zero code.
The script keeps waiting if there are too many other processes requesting this resource.

` `

: Requestors are placed in the queue to wait and get their leases as they become
available in FIFO order.

` `

: Defaults to infinite wait.

**-i {interval sec} | -\-interval={interval sec}**
: While waiting for the resource to be released, the script wakes up
periodically to check whether the resource was released or the previous owner
ceased to exist. This is a polling/wake-up interval. Fractional numbers are
allowed.

` `

: Optional. The default is automatically derived from the wait time.

**-k {second} | -\-kill={second}**
: If another process that owns this resource is "stuck", becomes a zombie, or
simply has been around for this many seconds, then TERM it. By default no
killing is performed. Fractional numbers are allowed.

` `

: This parameter also supports extended format **seconds[=SIGNAL][;seconds[=SIGNAL][;...]]**.
For example, parameter **"-k 300:310:400=INT:410:500=HUP:600=KILL"** will send
`TERM` after 300 and 310 seconds, send `INT` at 400 and 410 seconds, send `HUP`
at 500 seconds, send `KILL` at 600 seconds.

**-e {second} | -\-expire={second}**
: Resource will be considered automatically unlocked when the lease time exceeds this number of seconds.
The lease gets invalidated and the resource/lease record is purged afterward.

**-R | -\-release**
: Makes an attempt to release a previously obtained/leased resource for the resource/PID combination.

: Semaphore is more efficient when it is released explicitly. Doing so sends instant notification signals to other semaphores waiting for this resource to become available.

: Otherwise it relies on periodic polling and may wait for as long as specified with `-i`
before checking whether the resource became available.

**-\-sweep**
: Purge empty queues/resources.

: With `-v`, also lists the existing queues and statistics.

**-v | -\-verbose**
: Be verbose, think out loud. Can be specified multiple times to increase verbosity level.

**-h | -\-help**
: Print this help.

# EXAMPLES

## Example. Acquire resource lease with concurrency limit
` `
```
lease -r 'XYZ' -p $PPID -c 2 -i 30 -k 240 -w 600
```

Asks for a lock on resource `XYZ` for the caller shell parent process,
allowing one more resource owner (have 2 owners) to have the lock at the same time.

While waiting for the lease to become available, re-checks every 30 seconds.

Attempts to TERM other processes that held the lock for over 240 seconds.

Gives up after 10 minutes of waiting.

## Example. Escalating signal sequence
` `
```
lease -r 'XYZ' -p "$(ps -p $$ -o ppid:1=)" -c 2 -i 30 -k 240:250:260=HUP:270=INT -w 600
```
Same as the example above, except that if another lease does not become available,
it attempts sending signals to the lease owner:

- `TERM` at 240 and 250 seconds
- `HUP` at 260 seconds
- `INT` at 270 seconds

## Example. Expiring stale leases
` `
```
lease -r 'XYZ' -p "$$" -i 30 -e 240 -w 600 || exit 1
```

Attempts to lock resource `XYZ` for the calling shell.

Checks availability every 30 seconds while waiting.

If the lock is not available after 10 minutes (600 seconds), exits the calling shell script.

While waiting, invalidates existing leases older than 240 seconds.

Keep in mind that invalidating a lease does not necessarily make the resource immediately eligible
to be locked, because there may be other semaphores already waiting in the FIFO queue.
