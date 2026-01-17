bats_require_minimum_version 1.7.0

load helpers.bash

setup() {
    create_file "source/existing.txt" "existing"
    create_file "source/to_delete.txt" "to_delete"
    create_file "source/to_rename.txt" "to_rename"
    init_dest_repo
    add_file_to_repo "dest/existing.txt" "existing"
    add_file_to_repo "dest/to_delete.txt" "to_delete"
    add_file_to_repo "dest/to_rename.txt" "to_rename"

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"
}

teardown() {
    teardown_bolthole
}

@test "new file copied to destination" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "new.txt"
	EOF
    )

    [ ! -e "$BATS_TEST_TMPDIR/dest/new.txt" ]

    echo "hello" > "$BATS_TEST_TMPDIR/source/new.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") <(bolthole_log)
    diff -u "$BATS_TEST_TMPDIR/source/new.txt" "$BATS_TEST_TMPDIR/dest/new.txt"
    check_commit_message "$BATS_TEST_TMPDIR/dest" "Add new.txt"
}

@test "modified file copied to destination" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "existing.txt"
	EOF
    )

    echo "modified" > "$BATS_TEST_TMPDIR/source/existing.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") <(bolthole_log)
    diff -u "$BATS_TEST_TMPDIR/source/existing.txt" "$BATS_TEST_TMPDIR/dest/existing.txt"
    check_commit_message "$BATS_TEST_TMPDIR/dest" "Update existing.txt"
}

@test "deleted file removed from destination" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        -- "to_delete.txt"
	EOF
    )

    rm "$BATS_TEST_TMPDIR/source/to_delete.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") <(bolthole_log)
    [ ! -e "$BATS_TEST_TMPDIR/dest/to_delete.txt" ]
    check_commit_message "$BATS_TEST_TMPDIR/dest" "Remove to_delete.txt"
}

@test "renamed file handled" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "to_rename.txt" -> "renamed.txt"
	EOF
    )

    mv "$BATS_TEST_TMPDIR/source/to_rename.txt" "$BATS_TEST_TMPDIR/source/renamed.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") <(bolthole_log)
    [ ! -e "$BATS_TEST_TMPDIR/dest/to_rename.txt" ]
    diff -u "$BATS_TEST_TMPDIR/source/renamed.txt" "$BATS_TEST_TMPDIR/dest/renamed.txt"
    check_commit_message "$BATS_TEST_TMPDIR/dest" "Rename to_rename.txt to renamed.txt"
}

@test "new subdirectory and contents copied" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "subdir/file.txt"
	EOF
    )

    [ ! -e "$BATS_TEST_TMPDIR/dest/subdir" ]

    create_file "source/subdir/file.txt" "nested"
    wait_for_debounce

    diff -u <(echo "$expected_output") <(bolthole_log)
    diff -u "$BATS_TEST_TMPDIR/source/subdir/file.txt" "$BATS_TEST_TMPDIR/dest/subdir/file.txt"
    check_commit_message "$BATS_TEST_TMPDIR/dest" "Add subdir/file.txt"
}

@test "multiple files committed together" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "one.txt"
        ++ "two.txt"
	EOF
    )

    echo "one" > "$BATS_TEST_TMPDIR/source/one.txt"
    echo "two" > "$BATS_TEST_TMPDIR/source/two.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") <(bolthole_log)
    check_commit_message "$BATS_TEST_TMPDIR/dest" "Add one.txt and two.txt"
}
