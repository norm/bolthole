#!/usr/bin/env bats

@test "version" {
    run bolthole --version
    [[ "$output" =~ ^bolthole\ version\ v[0-9]+\.[0-9]+[^$'\n']*$ ]]
    [ $status -eq 0 ]
}

@test "help" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        usage: bolthole [-h] [--version] [--watchdog-debug] [-n] source [dest]

        positional arguments:
          source
          dest

        options:
          -h, --help        show this help message and exit
          --version         show program's version number and exit
          --watchdog-debug  show raw filesystem events
          -n, --dry-run     take no actions, but report what would happen
	EOF
    )

    run bolthole --help
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 0 ]
}

@test "rejects missing source" {
    expected_output=$(sed -e 's/^        //' <<-EOF
		usage: bolthole [-h] [--version] [--watchdog-debug] [-n] source [dest]
		bolthole: error: the following arguments are required: source
		EOF
    )

    run bolthole
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 2 ]
}

@test "rejects non-existent source directory" {
    expected_output=$(sed -e 's/^        //' <<-EOF
		bolthole: error: source directory does not exist: /nonexistent/path
		EOF
    )

    run bolthole /nonexistent/path
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 2 ]
}

@test "rejects source same as dest" {
    mkdir -p "$BATS_TEST_TMPDIR/dir"

    expected_output=$(sed -e 's/^        //' <<"        EOF"
        error: source and destination cannot be the same
        EOF
    )

    run bolthole "$BATS_TEST_TMPDIR/dir" "$BATS_TEST_TMPDIR/dir"
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 2 ]
}

@test "rejects source inside dest" {
    mkdir -p "$BATS_TEST_TMPDIR/dest/source"

    expected_output=$(sed -e 's/^        //' <<"        EOF"
        error: source cannot be inside destination
        EOF
    )

    run bolthole "$BATS_TEST_TMPDIR/dest/source" "$BATS_TEST_TMPDIR/dest"
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 2 ]
}

@test "rejects dest inside source" {
    mkdir -p "$BATS_TEST_TMPDIR/source/dest"

    expected_output=$(sed -e 's/^        //' <<"        EOF"
        error: destination cannot be inside source
        EOF
    )

    run bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/source/dest"
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 2 ]
}
