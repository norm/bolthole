bats_require_minimum_version 1.7.0

load helpers.bash

setup() {
    mkdir -p "$BATS_TEST_TMPDIR/source"
}

teardown() {
    teardown_bolthole
}

@test "creates mirror" {
    expected_output=""

    [ ! -e "$BATS_TEST_TMPDIR/dest" ]

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"
    teardown_bolthole

    diff -u <(echo -n "$expected_output") <(bolthole_log)
    [ -d "$BATS_TEST_TMPDIR/dest" ]
    [ -d "$BATS_TEST_TMPDIR/dest/.git" ]
}

@test "creates repo in empty mirror" {
    expected_output=""

    mkdir -p "$BATS_TEST_TMPDIR/dest"

    [ ! -e "$BATS_TEST_TMPDIR/dest/.git" ]

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"
    teardown_bolthole

    diff -u <(echo -n "$expected_output") <(bolthole_log)
    [ -d "$BATS_TEST_TMPDIR/dest/.git" ]
}

@test "dry run skips repo creation" {
    expected_output=""

    [ ! -e "$BATS_TEST_TMPDIR/dest" ]

    start_bolthole -n "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"
    teardown_bolthole

    diff -u <(echo -n "$expected_output") <(bolthole_log)
    [ ! -e "$BATS_TEST_TMPDIR/dest" ]
}

@test "existing destination errors" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        error: destination exists but is not a git repository
	EOF
    )

    create_file "dest/existing.txt" "content"

    run bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 2 ]
}

@test "existing destination checks for dotfiles" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        error: destination exists but is not a git repository
	EOF
    )

    create_file "dest/.hidden" "content"

    run bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 2 ]
}

@test "existing repository" {
    expected_output=""

    mkdir -p "$BATS_TEST_TMPDIR/dest"
    git -C "$BATS_TEST_TMPDIR/dest" init --quiet
    echo "marker" > "$BATS_TEST_TMPDIR/dest/.git/info/exclude"

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"
    teardown_bolthole

    diff -u <(echo -n "$expected_output") <(bolthole_log)
    diff -u <(echo "marker") "$BATS_TEST_TMPDIR/dest/.git/info/exclude"
}

@test "copies files to destination" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "file.txt"
	EOF
    )

    create_file "source/file.txt" "content"
    [ ! -e "$BATS_TEST_TMPDIR/dest" ]

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") <(bolthole_log)
    [ -d "$BATS_TEST_TMPDIR/dest" ]
    diff -u "$BATS_TEST_TMPDIR/source/file.txt" "$BATS_TEST_TMPDIR/dest/file.txt"
    check_commit_message "$BATS_TEST_TMPDIR/dest" "Add file.txt"
}

@test "copies multiple files to destination" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "one.txt"
        ++ "two.txt"
	EOF
    )

    create_file "source/one.txt" "one"
    create_file "source/two.txt" "two"

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") <(bolthole_log | sort)
    diff -u "$BATS_TEST_TMPDIR/source/one.txt" "$BATS_TEST_TMPDIR/dest/one.txt"
    diff -u "$BATS_TEST_TMPDIR/source/two.txt" "$BATS_TEST_TMPDIR/dest/two.txt"
    check_commit_message "$BATS_TEST_TMPDIR/dest" "Add one.txt and two.txt"
}

@test "copies subdirectories recursively" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "root.txt"
        ++ "sub/nested/nested.txt"
        ++ "sub/sub.txt"
	EOF
    )

    create_file "source/root.txt" "root"
    create_file "source/sub/sub.txt" "sub"
    create_file "source/sub/nested/nested.txt" "nested"

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") <(bolthole_log | sort)
    diff -u "$BATS_TEST_TMPDIR/source/root.txt" "$BATS_TEST_TMPDIR/dest/root.txt"
    diff -u "$BATS_TEST_TMPDIR/source/sub/sub.txt" "$BATS_TEST_TMPDIR/dest/sub/sub.txt"
    diff -u "$BATS_TEST_TMPDIR/source/sub/nested/nested.txt" "$BATS_TEST_TMPDIR/dest/sub/nested/nested.txt"
    check_commit_message "$BATS_TEST_TMPDIR/dest" "Add 3 files"
}

@test "deletes extra files in destination" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "keep.txt"
        -- "extra.txt"
	EOF
    )

    create_file "source/keep.txt" "keep"
    init_dest_repo extra.txt

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") <(bolthole_log | sort)
    [ -f "$BATS_TEST_TMPDIR/dest/keep.txt" ]
    [ ! -e "$BATS_TEST_TMPDIR/dest/extra.txt" ]
    check_commit_message "$BATS_TEST_TMPDIR/dest" "Remove extra.txt, add keep.txt"
}

@test "overwrites read-only files in destination" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "readonly.txt"
	EOF
    )

    create_file "source/readonly.txt" "new content"
    init_dest_repo
    add_file_to_repo "dest/readonly.txt" "old content"
    chmod 444 "$BATS_TEST_TMPDIR/dest/readonly.txt"

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") <(bolthole_log)
    diff -u "$BATS_TEST_TMPDIR/source/readonly.txt" "$BATS_TEST_TMPDIR/dest/readonly.txt"
    check_commit_message "$BATS_TEST_TMPDIR/dest" "Update readonly.txt"
}

@test "skips identical files" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "different.txt"
	EOF
    )

    create_file "source/same.txt" "identical"
    create_file "source/different.txt" "new"
    init_dest_repo
    add_file_to_repo "dest/same.txt" "identical"
    add_file_to_repo "dest/different.txt" "old"

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") <(bolthole_log)
    check_commit_message "$BATS_TEST_TMPDIR/dest" "Update different.txt"
}

@test "deletes extra subdirectory tree in destination" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "keep.txt"
        -- "extra/nested/deep.txt"
	EOF
    )

    create_file "source/keep.txt" "keep"
    init_dest_repo
    add_file_to_repo "dest/extra/nested/deep.txt" "extra"

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") <(bolthole_log | sort)
    [ -f "$BATS_TEST_TMPDIR/dest/keep.txt" ]
    [ ! -e "$BATS_TEST_TMPDIR/dest/extra" ]
    check_commit_message "$BATS_TEST_TMPDIR/dest" "Remove extra/nested/deep.txt, add keep.txt"
}

@test "excludes source .git directory" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "file.txt"
	EOF
    )

    create_file "source/file.txt" "content"
    git -C "$BATS_TEST_TMPDIR/source" init --quiet
    echo "source-marker" > "$BATS_TEST_TMPDIR/source/.git/source-marker"

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") <(bolthole_log)
    [ -f "$BATS_TEST_TMPDIR/dest/file.txt" ]
    [ ! -e "$BATS_TEST_TMPDIR/dest/.git/source-marker" ]
    check_commit_message "$BATS_TEST_TMPDIR/dest" "Add file.txt"
}

@test "commits pre-existing uncommitted file in dest" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "new.txt"
	EOF
    )

    create_file "source/existing.txt" "content"
    create_file "source/new.txt" "new"
    init_dest_repo
    create_file "dest/existing.txt" "content"

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"
    teardown_bolthole

    diff -u <(echo "$expected_output") <(bolthole_log)
    check_commit_message "$BATS_TEST_TMPDIR/dest" "Add existing.txt and new.txt"
}
