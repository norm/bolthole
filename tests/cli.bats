bats_require_minimum_version 1.7.0

@test "version" {
    run bolthole --version
    [[ "$output" =~ ^bolthole\ version\ v[0-9]+\.[0-9]+[^$'\n']*$ ]]
    [ $status -eq 0 ]
}

@test "help" {
    python_minor=$(python -c 'import sys; print(sys.version_info.minor)')
    if [ "$python_minor" -ge 13 ]; then
        expected_output=$(sed -e 's/^        //' <<-EOF
        usage: bolthole [-h] [--version] [--watchdog-debug] [-n] [-v] [--timeless]
                        [--ignore PATTERN] [--show-git] [--once] [-a AUTHOR]
                        [-b SECONDS] [-g SECONDS] [-m MESSAGE] [-r REMOTE]
                        source [dest]

        positional arguments:
          source
          dest

        options:
          -h, --help            show this help message and exit
          --version             show program's version number and exit
          --watchdog-debug      show raw filesystem events
          -n, --dry-run         take no actions, but report what would happen
          -v, --verbose         show file updates as well as actions taken
          --timeless            omit timestamps from output
          --ignore PATTERN      ignore files matching pattern (repeatable)
          --show-git            display git commands and their output
          --once                commit and exit without watching for changes
          -a, --author AUTHOR   override commit author (format: 'Name <email>')
          -b, --bundle SECONDS  bundle files older than threshold into single commit
          -g, --grace SECONDS   delay commits by grace period (default: 0)
          -m, --message MESSAGE
                                override commit message
          -r, --remote REMOTE   push to remote after commit (repeatable)
	EOF
        )
    else
        expected_output=$(sed -e 's/^        //' <<-EOF
        usage: bolthole [-h] [--version] [--watchdog-debug] [-n] [-v] [--timeless]
                        [--ignore PATTERN] [--show-git] [--once] [-a AUTHOR]
                        [-b SECONDS] [-g SECONDS] [-m MESSAGE] [-r REMOTE]
                        source [dest]

        positional arguments:
          source
          dest

        options:
          -h, --help            show this help message and exit
          --version             show program's version number and exit
          --watchdog-debug      show raw filesystem events
          -n, --dry-run         take no actions, but report what would happen
          -v, --verbose         show file updates as well as actions taken
          --timeless            omit timestamps from output
          --ignore PATTERN      ignore files matching pattern (repeatable)
          --show-git            display git commands and their output
          --once                commit and exit without watching for changes
          -a AUTHOR, --author AUTHOR
                                override commit author (format: 'Name <email>')
          -b SECONDS, --bundle SECONDS
                                bundle files older than threshold into single commit
          -g SECONDS, --grace SECONDS
                                delay commits by grace period (default: 0)
          -m MESSAGE, --message MESSAGE
                                override commit message
          -r REMOTE, --remote REMOTE
                                push to remote after commit (repeatable)
	EOF
        )
    fi

    run bolthole --help
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 0 ]
}

@test "rejects missing source" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        usage: bolthole [-h] [--version] [--watchdog-debug] [-n] [-v] [--timeless]
                        [--ignore PATTERN] [--show-git] [--once] [-a AUTHOR]
                        [-b SECONDS] [-g SECONDS] [-m MESSAGE] [-r REMOTE]
                        source [dest]
        bolthole: error: the following arguments are required: source
	EOF
    )

    run bolthole
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 2 ]
}

@test "rejects non-existent source directory" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        error: source directory does not exist: /nonexistent/path
	EOF
    )

    run bolthole /nonexistent/path
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 2 ]
}

@test "rejects source same as dest" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        error: source and destination cannot be the same
	EOF
    )

    mkdir -p "$BATS_TEST_TMPDIR/dir"

    run bolthole "$BATS_TEST_TMPDIR/dir" "$BATS_TEST_TMPDIR/dir"
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 2 ]
}

@test "rejects source inside dest" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        error: source cannot be inside destination
	EOF
    )

    mkdir -p "$BATS_TEST_TMPDIR/dest/source"

    run bolthole "$BATS_TEST_TMPDIR/dest/source" "$BATS_TEST_TMPDIR/dest"
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 2 ]
}

@test "rejects dest inside source" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        error: destination cannot be inside source
	EOF
    )

    mkdir -p "$BATS_TEST_TMPDIR/source/dest"

    run bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/source/dest"
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 2 ]
}

@test "rejects negative grace period" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        error: grace period cannot be negative
	EOF
    )

    mkdir -p "$BATS_TEST_TMPDIR/source"

    run bolthole --grace -1 "$BATS_TEST_TMPDIR/source"
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 2 ]
}

@test "rejects negative bundle threshold" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        error: bundle threshold cannot be negative
	EOF
    )

    mkdir -p "$BATS_TEST_TMPDIR/source"

    run bolthole --grace 2 --bundle -1 "$BATS_TEST_TMPDIR/source"
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 2 ]
}

@test "rejects bundle without grace" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        error: bundle requires grace period
	EOF
    )

    mkdir -p "$BATS_TEST_TMPDIR/source"

    run bolthole --bundle 1 "$BATS_TEST_TMPDIR/source"
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 2 ]
}

@test "rejects bundle equal to grace" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        error: bundle threshold must be less than grace period
	EOF
    )

    mkdir -p "$BATS_TEST_TMPDIR/source"

    run bolthole --grace 1 --bundle 1 "$BATS_TEST_TMPDIR/source"
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 2 ]
}
