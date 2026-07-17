# oblocate / nblocate

Sometimes I want to know which OpenBSD release has what version of a given package.

Sometimes I want to know packages that match a given name.

So I created 'oblocate' to locate files in release directories of snapshots and past releases.
**nblocate** does the same for **NetBSD** mirrors.

## Layout (after merge)

| Path | Role |
|------|------|
| `oblocate` / `nblocate` | Thin wrappers (`OSMIRROR_PROFILE=openbsd\|netbsd`) |
| `osmirror-driver` | Shared `-B` / search / assemble |
| `profiles/*.ksh` | OS-specific remotes, filters, walk |
| `osmirror-lib` | Shared munge/cache helpers |
| `locatelib/` | git submodule → `scm0.fdh.bz:/scm/locatelib.git` (PIDFILE, cksys, …) |
| `regress/run.sh` | Offline tests for helpers (`./regress/run.sh`) |

```
./regress/run.sh          # must pass before commit
oblocate -B               # rebuild OpenBSD index
nblocate -B               # rebuild NetBSD index
oblocate 'some-pkg'       # search
```


'locate' essentially takes a set of lines to stdin and makes it possible to search rapidly.

So I borrowed the concept, formatted the files on remote mirrors, and stuffed it into a separate db to search.

Example of updating the local db:

```
t0|todd@tlaptop/q6 ~|1691$ oblocate -B
Testing rsync://mirror.leaseweb.com/openbsd/
caching rmt dir 7.8
caching rmt dir ftplist
caching rmt dir timestamp
caching rmt dir Changelogs
caching rmt dir OpenSSH/portable
caching rmt dir patches
caching rmt dir snapshots
t0|todd@tlaptop/q6 ~|1692$
```

Notes for use:

1)  in the source, a list of rsync mirrors is included to see which one is available, first one that responds is used.  This will potentially need maintained in the future, or tweaked to order and/or add and/or remove from the list to have better choices for you.

2) rclone (pkg_add -Ur rclone)  is used for older releases, so you'll need a stanza in $HOME/.config/rclone/rclone.conf similar to the following:

```
[ob-https]
type = http
url = https://ftp.eu.openbsd.org/pub/OpenBSD
```

3) local storage considerations: oblocate utilizes $HOME/.cache/oblocate as a place to drop xz (pkg_add -Ur xz) compressed cached listings.  This way it doesn't re-check release dirs unless they're not present.  If you manage to get a very small size on a future release that hasn't occurred yet, remove it once the release has occurrred.   And up to two releases back there are stable packages released, those won't be picked up unless current and one back release is not removed.  The total space is 19M for the cache directory... The total file of the locate file ($HOME/var/db/allobsd.database) is 75.4M:
```
-rw-r--r--  1 todd  wheel  75.4M Nov 11 11:18 allobsd.database
```
