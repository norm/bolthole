bats_require_minimum_version 1.7.0

load helpers.bash

setup() {
    mkdir -p "$BATS_TEST_TMPDIR/source"
}

teardown() {
    teardown_bolthole
}

@test "rejects non-git-repo source" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        error: source must be a git repository in single-directory mode
	EOF
    )

    run timeout 2 bolthole "$BATS_TEST_TMPDIR/source"
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 2 ]
}

@test "new file committed" {
    create_file "source/existing.txt" "existing"
    init_source_repo

    start_bolthole "$BATS_TEST_TMPDIR/source"

    create_file "source/new.txt" "new content"
    wait_for_debounce

    check_commit_message "$BATS_TEST_TMPDIR/source" "Add new.txt"
}

@test "modification committed" {
    create_file "source/existing.txt" "original"
    init_source_repo

    start_bolthole "$BATS_TEST_TMPDIR/source"

    echo "modified" > "$BATS_TEST_TMPDIR/source/existing.txt"
    wait_for_debounce

    check_commit_message "$BATS_TEST_TMPDIR/source" "Update existing.txt"
}

@test "deletion committed" {
    create_file "source/to_delete.txt" "delete me"
    init_source_repo

    start_bolthole "$BATS_TEST_TMPDIR/source"

    rm "$BATS_TEST_TMPDIR/source/to_delete.txt"
    wait_for_debounce

    check_commit_message "$BATS_TEST_TMPDIR/source" "Remove to_delete.txt"
}

@test "rename committed" {
    create_file "source/old_name.txt" "content"
    init_source_repo

    start_bolthole "$BATS_TEST_TMPDIR/source"

    mv "$BATS_TEST_TMPDIR/source/old_name.txt" "$BATS_TEST_TMPDIR/source/new_name.txt"
    wait_for_debounce

    check_commit_message "$BATS_TEST_TMPDIR/source" "Rename old_name.txt to new_name.txt"
}

@test "changes committed on startup" {
    create_file "source/to_modify.txt" "original"
    create_file "source/to_delete.txt" "delete me"
    init_source_repo

    create_file "source/new.txt" "new"
    echo "modified" > "$BATS_TEST_TMPDIR/source/to_modify.txt"
    rm "$BATS_TEST_TMPDIR/source/to_delete.txt"

    start_bolthole "$BATS_TEST_TMPDIR/source"
    sleep 0.2

    check_commit_message "$BATS_TEST_TMPDIR/source" "Change 3 files"
}

@test "no changes" {
    create_file "source/existing.txt" "existing"
    init_source_repo

    start_bolthole "$BATS_TEST_TMPDIR/source"
    sleep 0.2

    actual=$(git -C "$BATS_TEST_TMPDIR/source" log -1 --format=%s)
    [ "$actual" = "initial" ]
}

@test "multiple files committed together" {
    create_file "source/existing.txt" "existing"
    init_source_repo

    start_bolthole "$BATS_TEST_TMPDIR/source"

    create_file "source/one.txt" "one"
    create_file "source/two.txt" "two"
    wait_for_debounce

    check_commit_message "$BATS_TEST_TMPDIR/source" "Add one.txt and two.txt"
}
