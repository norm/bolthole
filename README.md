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

- [ ] verbose and debugging output
- [ ] sync existing files on startup
- [ ] mirror changes to destination directory
- [ ] dry run mode
- [ ] create new repo if destination does not exist
- [ ] show git commands being executed
- [ ] override commit author
- [ ] override commit message
- [ ] commit changes to git
- [ ] ignore files matching glob patterns
- [ ] respect .gitignore
- [ ] commit and exit without watching
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
