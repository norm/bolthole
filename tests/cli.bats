#!/usr/bin/env bats

@test "version" {
    run bolthole --version
    [[ "$output" =~ ^bolthole\ version\ v[0-9]+\.[0-9]+[^$'\n']*$ ]]
    [ $status -eq 0 ]
}

@test "help" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        usage: bolthole [-h] [--version]

        options:
          -h, --help  show this help message and exit
          --version   show program's version number and exit
	EOF
    )

    run bolthole --help
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 0 ]
}
