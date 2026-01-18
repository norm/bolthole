bats_require_minimum_version 1.7.0

load helpers.bash

setup() {
    mkdir -p "$BATS_TEST_TMPDIR/source"
}

@test "commit and exit" {
    create_file "source/existing.txt" "existing"
    init_source_repo

    create_file "source/new.txt" "new content"

    run timeout 5 bolthole --once --timeless "$BATS_TEST_TMPDIR/source"
    [ -z "$output" ]
    [ $status -eq 0 ]
    check_commit_message "$BATS_TEST_TMPDIR/source" "Add new.txt"
}

@test "mirror, commit and exit" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "file.txt"
	EOF
    )

    create_file "source/file.txt" "content"
    init_dest_repo

    run timeout 5 bolthole --once --timeless "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 0 ]
    check_commit_message "$BATS_TEST_TMPDIR/dest" "Add file.txt"
    [ -f "$BATS_TEST_TMPDIR/dest/file.txt" ]
}

@test "dry run of commit and exit" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        #  git add -- new.txt
        #  git commit
	EOF
    )

    create_file "source/existing.txt" "existing"
    init_source_repo

    create_file "source/new.txt" "new content"

    run timeout 5 bolthole --once --dry-run --timeless "$BATS_TEST_TMPDIR/source"
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 0 ]
}

@test "dry run of mirror, commit and exit" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "file.txt"
        #  copy "file.txt"
        #  git add -- file.txt
        #  git commit
	EOF
    )

    create_file "source/file.txt" "content"
    init_dest_repo

    run timeout 5 bolthole --once --dry-run --timeless "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 0 ]
}
