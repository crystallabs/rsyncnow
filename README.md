# rsyncnow

This tool is for you if your rsyncing data directories takes days
or weeks to just build the index of files to sync.

## The rsync problem

Rsync's delta algorithm doesn't need any changes - once a file to sync
is identified, the algorithm does its job well (or the whole file is
copied with rsync option `-W`).

But when rsync is told to sync directories, before it begins with
the actual syncing it builds an index of the files that need to be
synced. On large data sets, this index building can take hours, days, or weeks.

In addition to just taking time, it is making it harder to schedule data
migrations at the end/beginning of months when the extra traffic will not
influence the month's 95th percentile and is essentially free.

Also, it is making it harder to fully sync the source and destination if
the source is still being modified or uploaded to, because by the time
rsync completes, the destination is already severely out of date and
requires another sync.

## How does `rsyncnow` help?

The above-described behavior of rsync, in which it first builds an index
and then starts syncing, cannot be changed.

However, rsync has some useful command line options. One of them is a mode
in which rsync will print the files that need syncing to STDOUT in real
time. That is, it will print the filenames to sync immediately as it
finds/identifies them, during index building.

This enables `rsyncnow` to introduce a huge increase in efficiency on large
data sets as follows:

1. It runs a set of `rsync` processes (by default 1 for every source path)
that are finding the files to sync (in dry run mode) and printing them to
STDOUT as a stream in real time.  We call these processes `finders`.

1. As finders keep printing filenames to sync, `rsyncnow` keeps reading
them and (again in real time)  pushing them to a small internal queue.

1. As soon as `rsyncnow` collects the requested amount of filenames to
sync in a batch (or every X seconds if a batch has not been filled up yet),
it runs separate rsync processes (called `syncers`) which then sync specific
lists of files, and so execute immediately since there there are no
indexes to build.

1. Additionally, if the filenames to sync are being found faster than they
are synced, and the bandwidth allows it, one can run `rsyncnow` with more
`syncer` processes to achieve even faster/concurrent syncing of multiple files.

## Usage instructions

You need Ruby installed to run the script. Hopefully this is a trivial requirement.

The script is a single file and can be run directly from a clone of this repository.
It can also be installed as a gem, which is attached to every
[release](https://github.com/docelic/rsyncnow/releases):

```
gem install ./rsyncnow-X.Y.Z.gem
```


```
Usage: rsyncnow [OPTIONS...] SRC... DST -- [FIND OPTIONS...] -- [SYNC OPTIONS...]

OPTIONS:
  -f, --finders N    - Max number of rsync find processes running at the same
                       time. Each one processes one SRC path at a time. If not
                       specified, defaults to the number of SRC paths
  -s, --syncers 1    - Nr. of respawning rsync sync/copy processes, per finder
  -b, --batchsize 5  - Nr. of files to collect in a batch before running syncers
  -q, --queuesize 50 - Max number of paths to queue for sync. If not specified,
                       defaults to batchsize * 10. Finder processes get
                       automatically paused when their queue goes above this
                       limit and are resumed when queue falls below threshold
  -t, --timeout 5.0  - After timeout seconds, run rsync sync/copy process even
                       if a batch isn't full
  -d, --delete       - Delete files from DST which don't exist in SRC (same
                       as rsync option --delete)
  -R, --relative     - Sync SRC paths with their full names, instead of just
                       the last part (same as rsync option --relative)

  -r, --rsync rsync  - Name (and/or path) of rsync binary

  -v, --verbose      - Enable rsyncnow and rsync verbose mode
  -h, --help         - Show help and exit
  -e, --examples     - Show examples and exit

SRC, DST:
  Rsync source and destination as usual (including the "/" magic)

FIND OPTIONS:
  If specified, overrides all default cmdline options for rsync find processes.
  Default value: -ae=ssh
    NOTE: options `--dry-run --no-relative --out-format='%i %n'` are always
    added automatically. To use rsync option -R, use option -R of rsyncnow.

SYNC OPTIONS:
  If specified, overrides all default cmdline options for rsync sync processes.
  Default value: -lptgoD0e=ssh --files-from=-
    NOTE: options `--from0 --files-from=-` are always added automatically.
    NOTE: options -lptgoD are used explicitly instead just specifying -a
    because -a also includes option -r which should not be present. Recursion
    is controlled via FIND OPTIONS (where it is enabled/implied by -a)

EXAMPLES:

# Most basic example:
# (implies finding files to sync with rsync options -ae=ssh,
# and syncing the actual files with rsync options -lptgoD0e=ssh --files-from=-)
rsyncnow -v /source/dir /target/dir

# Finding files with size differences only, without full checksum (--size-only), and
# syncing them by copying, without using rsync's delta algorithm (-W):
rsyncnow -v /source/dir /target/dir -- -ae=ssh --size-only -- -lptgoD0e=ssh --files-from=- -W
```

## Notes on options -b, -q, -t

Option `-b` (`--batchsize`) organizes files to sync in batches to reduce the number of
`rsync` process invocations. (If one specifies `-b 1` then a separate process would be
called every time a file is to be synced.)

Option `-q` defines max internal queue size. Finder processes are automatically paused
if they fill up the queue to this limit (i.e. if they are finding files to sync much
faster than the syncers are able to process them). This option doesn't primarily exist
to save RAM, but to stop finders from finding all the files quickly and finishing
the directory traversal much sooner than syncers will be done with syncing. Namely,
as long as syncers are syncing the files, the whole syncing process isn't over anyway,
so by slowing down finders (by spreading their work over more time), we
increase the chance of any changes in the source directories to be picked up on the
first run or `rsyncnow`.

Finally, re. option `-t`: if batch size is set to a large value, or if the files to
sync are rarely found (e.g. if the source and destination are fairly well synced
already), then it makes sense to just sync whatever paths are found every X seconds,
not to let the process of finding files go on for too long without syncing
anything in the meantime.

## Compatibility with rsync

`SRC` and `DST` arguments are interpreted in the same way as rsync interprets
them, and the files end up in the same places where `rsync -a SRC... DST` would
put them. This includes the meaning of a trailing slash on `SRC` (`dir/` syncs the
contents of the directory, while `dir` syncs the directory itself), syncing of
single files (optionally to a different name), and remote sources or destinations
(`host:path`, `host::module/path` and `rsync://host/module/path`).

Exit status of `rsyncnow` is 0 if all rsync processes were successful. Otherwise
it is the exit status of the first rsync process that failed. Invalid arguments
result in exit status 1. If `rsyncnow` is interrupted or terminated, it also
terminates the rsync processes which it has started.

Known differences:

- Hard links (rsync option `-H`) are preserved only between the files which get
synced in the same batch
- Files are deleted from `DST` only if `rsyncnow` option `--delete` is used (rsync
option `--delete` in `FIND OPTIONS` or `SYNC OPTIONS` has no effect). See below
for the differences in how it works.
- Relative paths are used only if `rsyncnow` option `-R` is used (rsync option `-R`
in `FIND OPTIONS` has no effect)

## Relative paths

With option `-R` (`--relative`), full paths specified as `SRC` are created in `DST`,
like with rsync option `-R`. For example, `rsyncnow -R /data/dir/ /target` syncs to
`/target/data/dir/`, and not to `/target/`. The part of `SRC` to leave out can be
marked with `/./`: `rsyncnow -R /data/./dir/ /target` syncs to `/target/dir/`.

## Deleting files

With option `-d` (`--delete`), files which exist in `DST` but not in `SRC` are deleted
from `DST`, like with rsync option `--delete`.

Finders run with option `--delete` and so they also print the paths to delete. Those
paths are queued separately, and deleted by an additional rsync process (1 per finder)
which is given filter rules that allow only those specific paths to be deleted.

Differences from rsync:

- Files are deleted as they are found (as with `--delete-during`). Other variants
(`--delete-before`, `--delete-after`, `--delete-delay`, `--delete-excluded`) are not
supported.
- If there are multiple `SRC` paths, they must be synced into different directories
in `DST`. This is not the case if `SRC` ends with `/` (`rsyncnow --delete a/ b/ dst`),
and `rsyncnow` refuses to run then. The reason is that each `SRC` has its own finder,
which would delete the files synced from the other `SRC` paths. (With option `-R`
this applies to `SRC` paths which are relative to different directories, like
`a/./dir/` and `b/./dir/sub/`.)
- Limits such as `--max-delete` (in `SYNC OPTIONS`) apply to each batch of paths, and
not to the whole run.

## Testing

```
test/run.sh
```

Tests which need `ssh localhost` to work without a password are skipped if it doesn't.
Run `test/run.sh -h` for more information.

The tests also run in GitHub Actions on every push and pull request.

## Misc notes

By default, 1 rsync finder process is started for each source directory,
concurrently. If you don't want that many finders running at the same time
(for example if all source directories to sync are on the same partition),
limit their number with option `-f`. Each finder then processes one source
path after another; with `-f 1` only one source path is synced at a time.

Rsyncnow doesn't put any restrictions on the rsync options that one can use in
either find or sync phase (options related to comparing/finding files,
what to copy/sync, max bandwidth to use etc.).
See a myriad of options available in the [rsync man page](https://download.samba.org/pub/rsync/rsync.1).

## Feedback

Please report any comments or suggestions!

## License

GNU Affero General Public License v3. See [LICENSE](LICENSE).
