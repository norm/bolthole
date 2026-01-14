#!/usr/bin/env bats

load helpers.bash

setup() {
    create_file "source/existing.txt" "existing"
    create_file "source/to_delete.txt" "to_delete"
    create_file "source/to_rename.txt" "to_rename"
    create_file "dest/existing.txt" "existing"
    create_file "dest/to_delete.txt" "to_delete"
    create_file "dest/to_rename.txt" "to_rename"

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"
}

teardown() {
    teardown_bolthole
}

@test "new file copied to destination" {
    [ ! -e "$BATS_TEST_TMPDIR/dest/new.txt" ]

    echo "hello" > "$BATS_TEST_TMPDIR/source/new.txt"
    wait_for_debounce

    expected_output=$(sed -e 's/^        //' <<"        EOF"
        created new.txt
        EOF
    )
    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
    diff -u "$BATS_TEST_TMPDIR/source/new.txt" "$BATS_TEST_TMPDIR/dest/new.txt"
}

@test "modified file copied to destination" {
    echo "modified" > "$BATS_TEST_TMPDIR/source/existing.txt"
    wait_for_debounce

    expected_output=$(sed -e 's/^        //' <<"        EOF"
        modified existing.txt
        EOF
    )
    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
    diff -u "$BATS_TEST_TMPDIR/source/existing.txt" "$BATS_TEST_TMPDIR/dest/existing.txt"
}

@test "deleted file removed from destination" {
    rm "$BATS_TEST_TMPDIR/source/to_delete.txt"
    wait_for_debounce

    expected_output=$(sed -e 's/^        //' <<"        EOF"
        deleted to_delete.txt
        EOF
    )
    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
    [ ! -e "$BATS_TEST_TMPDIR/dest/to_delete.txt" ]
}

@test "renamed file handled" {
    mv "$BATS_TEST_TMPDIR/source/to_rename.txt" "$BATS_TEST_TMPDIR/source/renamed.txt"
    wait_for_debounce

    expected_output=$(sed -e 's/^        //' <<"        EOF"
        renamed to_rename.txt renamed.txt
        EOF
    )
    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
    [ ! -e "$BATS_TEST_TMPDIR/dest/to_rename.txt" ]
    diff -u "$BATS_TEST_TMPDIR/source/renamed.txt" "$BATS_TEST_TMPDIR/dest/renamed.txt"
}

@test "new subdirectory and contents copied" {
    [ ! -e "$BATS_TEST_TMPDIR/dest/subdir" ]

    create_file "source/subdir/file.txt" "nested"
    wait_for_debounce

    expected_output=$(sed -e 's/^        //' <<"        EOF"
        created subdir/file.txt
        EOF
    )
    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
    diff -u "$BATS_TEST_TMPDIR/source/subdir/file.txt" "$BATS_TEST_TMPDIR/dest/subdir/file.txt"
}
