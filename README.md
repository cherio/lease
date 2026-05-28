## DESCRIPTION
A FIFO semaphore utility that manages resource ownership by processes.

It implements the ability to obtain a lease/ownership on a virtual resource. It will wait for the resource to become available in FIFO order. The maintains a syncronized (flock) queue to keep the order of incoming lease requests.

A resource is identified by an arbitrary identifier of your choice. Resource owner/lessee is a process identified by its PID.

## EXAMPLES
**Example.** Allow up to 3 processes work on the same resource:

```
lease -r database1 -p $$ -c 3 -w 600 || exit 1
<work with your database here>
lease -r database1 -p $$ --release
```
The script will continue only if there are less than 3 processes that leased a resource with name `database1`. This command will wait for up to 10 minutes if the resource is already leased by three or more processes.

A lease is considered to be released when the owner identified by its process ID terminates. Releasing a lease explicitly (with --release) instantly notifies other processes waiting for the same resource, who otherwise would have to periodically poll resource availability to check whether the resource owner identified by its PID (-p $$) is terminated.

**Example.** Use parent PID as the lessee
```
lease -r database1 -p $PPID -w 10 -i 1 -k 1200 || exit 1
```
Allows only one resource owner. It makes the parent process a lessee. This waits for only 10 sec, checking if the resource becomes available every 1 sec. It sends TERM signal to the existing lessee holding the resource for longer than 20 min.

The resource becomes available when the parent process terminates or this lease explicitly released (--release).

## AUTHORS
Yuri Cherio

## COPYRIGHT
Copyright (C) 2026 The Utility Project Contributors\
Licensed under the MIT License (SPDX-License-Identifier: MIT)
