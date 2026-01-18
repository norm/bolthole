# bolthole

```bash
(computer)% bolthole source_dir [dest_dir]
```

Automatically backup a directory to git — watch a directory for changes, and
either commit the changes or mirror the directory to another that is a git
repository, and commit changes there.

There is a grace period to allow multiple edits in a short space of time,
and multiple files changed within the grace period should be packaged as
one commit, not many.

## Outstanding

- [ ] override commit author
- [ ] override commit message
- [ ] push commits to remote
- [ ] wait before committing to allow more edits
- [ ] bundle multiple file changes into single commits

## Testing

```bash
# run all tests
(computer)% make test

# run subsets
(computer)% make lint
(computer)% make pytest
(computer)% make bats
```
