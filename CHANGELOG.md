# Changelog


## [v1.0] - 2026-01-19

Automatically backup a directory to git — watch a directory for changes,
and either commit the changes or mirror the directory to another that is
a git repository, and commit changes there.

There is a grace period to allow multiple edits in a short space of time,
and multiple files changed within the grace period should be packaged as
one commit, not many.
