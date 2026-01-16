bats_require_minimum_version 1.7.0

load helpers.bash

setup() {
    create_file "source/existing.txt" "existing"
    create_file "source/to_delete.txt" "to_delete"
    create_file "source/to_rename.txt" "to_rename"
    create_file "dest/existing.txt" "existing"
    create_file "dest/to_delete.txt" "to_delete"
    create_file "dest/to_rename.txt" "to_rename"
    init_dest_repo
    git -C "$BATS_TEST_TMPDIR/dest" add -A
    git -C "$BATS_TEST_TMPDIR/dest" commit -m "initial" --no-verify --no-gpg-sign --quiet

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

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
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

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
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

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
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

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
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

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
    diff -u "$BATS_TEST_TMPDIR/source/subdir/file.txt" "$BATS_TEST_TMPDIR/dest/subdir/file.txt"
    check_commit_message "$BATS_TEST_TMPDIR/dest" "Add subdir/file.txt"
}
