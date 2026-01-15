bats_require_minimum_version 1.7.0

load helpers.bash

teardown() {
    teardown_bolthole
}

@test "dry-run reports initial sync without copying" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        created file.txt
        #  copy "file.txt"
	EOF
    )

    create_file "source/file.txt" "content"
    [ ! -e "$BATS_TEST_TMPDIR/dest" ]

    start_bolthole --dry-run "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
    [ ! -e "$BATS_TEST_TMPDIR/dest" ]
}

@test "dry-run reports initial sync delete without deleting" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        created keep.txt
        #  copy "keep.txt"
        deleted extra.txt
        #  delete "extra.txt"
	EOF
    )

    create_file "source/keep.txt" "keep"
    create_file "dest/extra.txt" "extra"

    start_bolthole --dry-run "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
    [ -f "$BATS_TEST_TMPDIR/dest/extra.txt" ]
}

@test "dry-run skips file copy on create" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        created new.txt
        #  copy "new.txt"
	EOF
    )

    create_file "source/existing.txt" "existing"
    create_file "dest/existing.txt" "existing"

    start_bolthole --dry-run "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    echo "hello" > "$BATS_TEST_TMPDIR/source/new.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
    [ ! -e "$BATS_TEST_TMPDIR/dest/new.txt" ]
}

@test "dry-run skips file copy on modify" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        modified file.txt
        #  copy "file.txt"
	EOF
    )

    create_file "source/file.txt" "original"
    create_file "dest/file.txt" "original"

    start_bolthole --dry-run "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    echo "modified" > "$BATS_TEST_TMPDIR/source/file.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
    diff -u <(echo "original") "$BATS_TEST_TMPDIR/dest/file.txt"
}

@test "dry-run skips file delete" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        deleted file.txt
        #  delete "file.txt"
	EOF
    )

    create_file "source/file.txt" "content"
    create_file "dest/file.txt" "content"

    start_bolthole --dry-run "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    rm "$BATS_TEST_TMPDIR/source/file.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
    [ -f "$BATS_TEST_TMPDIR/dest/file.txt" ]
}

@test "dry-run skips rename" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        renamed old.txt new.txt
        #  rename "old.txt" to "new.txt"
	EOF
    )

    create_file "source/old.txt" "content"
    create_file "dest/old.txt" "content"

    start_bolthole --dry-run "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    mv "$BATS_TEST_TMPDIR/source/old.txt" "$BATS_TEST_TMPDIR/source/new.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
    [ -f "$BATS_TEST_TMPDIR/dest/old.txt" ]
    [ ! -e "$BATS_TEST_TMPDIR/dest/new.txt" ]
}

@test "dry-run short flag -n works" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        created file.txt
        #  copy "file.txt"
	EOF
    )

    create_file "source/file.txt" "content"

    start_bolthole -n "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
    [ ! -e "$BATS_TEST_TMPDIR/dest" ]
}

@test "dry-run reports subdirectory changes without creating them" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        created sub/nested/file.txt
        #  copy "sub/nested/file.txt"
	EOF
    )

    create_file "source/existing.txt" "existing"
    create_file "dest/existing.txt" "existing"

    start_bolthole --dry-run "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    create_file "source/sub/nested/file.txt" "nested"
    wait_for_debounce

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
    [ ! -e "$BATS_TEST_TMPDIR/dest/sub" ]
}
