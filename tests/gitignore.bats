bats_require_minimum_version 1.7.0

load helpers.bash

setup() {
    mkdir -p "$BATS_TEST_TMPDIR/source"
    mkdir -p "$BATS_TEST_TMPDIR/dest"
    git -C "$BATS_TEST_TMPDIR/dest" init --quiet
    add_file_to_repo "dest/.gitignore" $'*.log\n!important.log\nbuild/'
}

teardown() {
    teardown_bolthole
}

@test "gitignored file copied but not committed" {
    create_file "source/keep.txt" "keep"
    create_file "source/ignored.log" "ignored"

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    [ -f "$BATS_TEST_TMPDIR/dest/keep.txt" ]
    [ -f "$BATS_TEST_TMPDIR/dest/ignored.log" ]
    check_commit_message "$BATS_TEST_TMPDIR/dest" "Add keep.txt"
}

@test "new gitignored file not committed" {
    create_file "source/existing.txt" "existing"
    add_file_to_repo "dest/existing.txt" "existing"

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    create_file "source/new.log" "ignored"
    wait_for_debounce

    [ -f "$BATS_TEST_TMPDIR/dest/new.log" ]
    check_commit_message "$BATS_TEST_TMPDIR/dest" "add existing.txt"
}

@test "modified gitignored file not committed" {
    create_file "source/existing.txt" "existing"
    create_file "source/ignored.log" "original"
    add_file_to_repo "dest/existing.txt" "existing"
    create_file "dest/ignored.log" "original"

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    echo "modified" > "$BATS_TEST_TMPDIR/source/ignored.log"
    wait_for_debounce

    [ "$(cat "$BATS_TEST_TMPDIR/dest/ignored.log")" = "modified" ]
    check_commit_message "$BATS_TEST_TMPDIR/dest" "add existing.txt"
}

@test "concurrent tracked and gitignored changes commits only tracked" {
    create_file "source/tracked.txt" "original"
    create_file "source/ignored.log" "original"
    add_file_to_repo "dest/tracked.txt" "original"
    create_file "dest/ignored.log" "original"

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    echo "modified" > "$BATS_TEST_TMPDIR/source/tracked.txt"
    echo "modified" > "$BATS_TEST_TMPDIR/source/ignored.log"
    wait_for_debounce

    check_commit_message "$BATS_TEST_TMPDIR/dest" "Update tracked.txt"
    run git -C "$BATS_TEST_TMPDIR/dest" show --name-only --format=""
    [ "$output" = "tracked.txt" ]
}

@test "source gitignored file not committed on startup" {
    create_file "source/ignored.log" "ignored"
    git -C "$BATS_TEST_TMPDIR/source" init --quiet
    add_file_to_repo "source/.gitignore" "*.log"
    add_file_to_repo "source/keep.txt" "keep"

    start_bolthole "$BATS_TEST_TMPDIR/source"
    wait_for_debounce

    check_commit_message "$BATS_TEST_TMPDIR/source" "add keep.txt"
}

@test "source modified gitignored file not committed" {
    create_file "source/existing.txt" "existing"
    create_file "source/ignored.log" "original"
    init_source_repo --gitignore "*.log"

    start_bolthole "$BATS_TEST_TMPDIR/source"

    echo "modified" > "$BATS_TEST_TMPDIR/source/ignored.log"
    wait_for_debounce

    check_commit_message "$BATS_TEST_TMPDIR/source" "initial"
}

@test ".gitignore in dest preserved during sync" {
    create_file "source/keep.txt" "keep"

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    [ -f "$BATS_TEST_TMPDIR/dest/keep.txt" ]
    [ -f "$BATS_TEST_TMPDIR/dest/.gitignore" ]
}

@test "source concurrent tracked and gitignored changes commits only tracked" {
    create_file "source/tracked.txt" "original"
    create_file "source/ignored.log" "original"
    init_source_repo --gitignore "*.log"

    start_bolthole "$BATS_TEST_TMPDIR/source"

    echo "modified" > "$BATS_TEST_TMPDIR/source/tracked.txt"
    echo "modified" > "$BATS_TEST_TMPDIR/source/ignored.log"
    wait_for_debounce

    check_commit_message "$BATS_TEST_TMPDIR/source" "Update tracked.txt"
    run git -C "$BATS_TEST_TMPDIR/source" show --name-only --format=""
    [ "$output" = "tracked.txt" ]
}

