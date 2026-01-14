#!/usr/bin/env bats

load helpers.bash

teardown() {
    teardown_bolthole
}

@test "initial sync creates destination if missing" {
    create_file "source/file.txt" "content"

    [ ! -e "$BATS_TEST_TMPDIR/dest" ]

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    expected_output=$(sed -e 's/^        //' <<"        EOF"
        created file.txt
        EOF
    )
    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
    [ -d "$BATS_TEST_TMPDIR/dest" ]
    diff -u "$BATS_TEST_TMPDIR/source/file.txt" "$BATS_TEST_TMPDIR/dest/file.txt"
}

@test "initial sync copies files to destination" {
    create_file "source/one.txt" "one"
    create_file "source/two.txt" "two"

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    expected_output=$(sed -e 's/^        //' <<"        EOF"
        created one.txt
        created two.txt
        EOF
    )
    diff -u <(echo "$expected_output") <(sort "$BATS_TEST_TMPDIR/out.txt")
    diff -u "$BATS_TEST_TMPDIR/source/one.txt" "$BATS_TEST_TMPDIR/dest/one.txt"
    diff -u "$BATS_TEST_TMPDIR/source/two.txt" "$BATS_TEST_TMPDIR/dest/two.txt"
}

@test "initial sync copies subdirectories recursively" {
    create_file "source/root.txt" "root"
    create_file "source/sub/sub.txt" "sub"
    create_file "source/sub/nested/nested.txt" "nested"

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    expected_output=$(sed -e 's/^        //' <<"        EOF"
        created root.txt
        created sub/nested/nested.txt
        created sub/sub.txt
        EOF
    )
    diff -u <(echo "$expected_output") <(sort "$BATS_TEST_TMPDIR/out.txt")
    diff -u "$BATS_TEST_TMPDIR/source/root.txt" "$BATS_TEST_TMPDIR/dest/root.txt"
    diff -u "$BATS_TEST_TMPDIR/source/sub/sub.txt" "$BATS_TEST_TMPDIR/dest/sub/sub.txt"
    diff -u "$BATS_TEST_TMPDIR/source/sub/nested/nested.txt" "$BATS_TEST_TMPDIR/dest/sub/nested/nested.txt"
}

@test "initial sync deletes extra files in destination" {
    create_file "source/keep.txt" "keep"
    create_file "dest/extra.txt" "extra"

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    expected_output=$(sed -e 's/^        //' <<"        EOF"
        created keep.txt
        deleted extra.txt
        EOF
    )
    diff -u <(echo "$expected_output") <(sort "$BATS_TEST_TMPDIR/out.txt")
    [ -f "$BATS_TEST_TMPDIR/dest/keep.txt" ]
    [ ! -e "$BATS_TEST_TMPDIR/dest/extra.txt" ]
}

@test "initial sync overwrites read-only files in destination" {
    create_file "source/readonly.txt" "new content"
    create_file "dest/readonly.txt" "old content" 444

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    expected_output=$(sed -e 's/^        //' <<"        EOF"
        modified readonly.txt
        EOF
    )
    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
    diff -u "$BATS_TEST_TMPDIR/source/readonly.txt" "$BATS_TEST_TMPDIR/dest/readonly.txt"
}

@test "initial sync skips identical files" {
    create_file "source/same.txt" "identical"
    create_file "source/different.txt" "new"
    create_file "dest/same.txt" "identical"
    create_file "dest/different.txt" "old"

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    expected_output=$(sed -e 's/^        //' <<"        EOF"
        modified different.txt
        EOF
    )
    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
}

@test "initial sync deletes extra subdirectory tree in destination" {
    create_file "source/keep.txt" "keep"
    create_file "dest/extra/nested/deep.txt" "extra"

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    expected_output=$(sed -e 's/^        //' <<"        EOF"
        created keep.txt
        deleted extra/nested/deep.txt
        EOF
    )
    diff -u <(echo "$expected_output") <(sort "$BATS_TEST_TMPDIR/out.txt")
    [ -f "$BATS_TEST_TMPDIR/dest/keep.txt" ]
    [ ! -e "$BATS_TEST_TMPDIR/dest/extra" ]
}
