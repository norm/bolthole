# bolthole

Automatically backup changes to a directory to git.

## Usage

```bash
bolthole
    [--ignore GLOB [--ignore ...]]          # autoignored: .git, .gitignore
    [--author AUTHOR] [--message TEXT]      # override your git config
    [--grace SECONDS] [--bundle SECONDS]    # allow for rapid edits to finish
    [--remote NAME [--remote ...]]          # push changes upstream
    [--verbose] [--show-git] [--timeless]
        [--watchdog-debug]                  # control verbosity
    [--dry-run]                             # test it first
    [--once]                                # no ongoing monitoring
    source_dir                              # what to monitor
    [dest_dir]                              # optionally copy to repo
```


## Autocommit a directory

```bash
bolthole .
```

Assumes the directory is already git controlled, and will refuse to start if
not. It will commit any outstanding changes. If `--once` was used, it will
then stop, otherwise it will watch for changes until killed, committing them.


## Autocommit to a different directory

```bash
bolthole project/ pristine-copy/
```

If `pristine-copy` doesn't exist, it will copy it and create a git repository
there, or it will check that if directory is already git controlled and will
refuse to start if not. It will commit any outstanding changes. If `--once`
was used, it will then stop, otherwise it will watch for changes until killed,
committing them.


## Grace and bundling

The `--grace SECONDS` option will wait until the amount of time specified
has passed before committing the file, and will restart the timer after
each change. This way, if a file is being edited repeatedly in a short
span of time, the result would be only one commit, not many.

The `--bundle SECONDS` option allows for multiple file changes to be
bundled together in one commit rather than one commit per file, as long as
they all happened at roughly the same time. The bundle time is how
recently a file needs to have been changed in order to be excluded from the
bundle.

For example, with a grace period of five minutes, and a bundle window of
one minute:

- at `t = 0m00s` — `foo.txt` is edited, and a timer for it is set for 300 seconds
- at `t = 0m30s` — `bar.txt` is edited, and a timer for it is set
  for 300s (we now have `foo.txt` at 270s, `bar.txt` at 300s)
- at `t = 4m30s` — `baz.txt` is edited, and a timer for it is set for 300s
  (we now have `foo.txt` at 30s, `bar.txt` at 60s, `baz.txt` at 300s)
- at `t = 5m00s` — the `foo.txt` timer goes off (we now have `foo.txt` at 0s,
  `bar.txt` at 30s, `baz.txt` at 270s); the changes to `foo.txt` and `bar.txt`
  were both made earlier than the bundle window, and one commit is made with
  both changes
- at `t = 9m30s` — `baz.txt` is committed


## Installation

Bolthole is installed from pypi:

```bash
pip install bolthole
```
