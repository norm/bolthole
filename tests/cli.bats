#!/usr/bin/env bats

@test "version" {
    run bolthole --version
    [[ "$output" =~ ^bolthole\ version\ v[0-9]+\.[0-9]+[^$'\n']*$ ]]
    [ $status -eq 0 ]
}

@test "help" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        usage: bolthole [-h] [--version] [--watchdog-debug] source

        positional arguments:
          source

        options:
          -h, --help        show this help message and exit
          --version         show program's version number and exit
          --watchdog-debug
	EOF
    )

    run bolthole --help
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 0 ]
}

@test "rejects missing source" {
    expected_output=$(sed -e 's/^        //' <<-EOF
		usage: bolthole [-h] [--version] [--watchdog-debug] source
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
