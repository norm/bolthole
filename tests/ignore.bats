bats_require_minimum_version 1.7.0

load helpers.bash

setup() {
    mkdir -p "$BATS_TEST_TMPDIR/source"
}

teardown() {
    teardown_bolthole
}

@test "sync ignores files" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "keep.txt"
	EOF
    )

    create_file "source/keep.txt" "keep"
    create_file "source/ignore.log" "ignored"
    create_file "source/ignore.tmp" "ignored"

    start_bolthole --ignore "*.log" --ignore "*.tmp" "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") <(bolthole_log)
    [ -f "$BATS_TEST_TMPDIR/dest/keep.txt" ]
    [ ! -e "$BATS_TEST_TMPDIR/dest/ignore.log" ]
    [ ! -e "$BATS_TEST_TMPDIR/dest/ignore.tmp" ]
}

@test "sync ignores directories" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "keep.txt"
	EOF
    )

    create_file "source/keep.txt" "keep"
    create_file "source/.hidden/secret.txt" "secret"

    start_bolthole --ignore ".hidden" "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") <(bolthole_log)
    [ -f "$BATS_TEST_TMPDIR/dest/keep.txt" ]
    [ ! -e "$BATS_TEST_TMPDIR/dest/.hidden" ]
}

@test "sync preserves ignored files in dest" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "keep.txt"
	EOF
    )

    create_file "source/keep.txt" "keep"
    init_dest_repo
    create_file "dest/existing.log" "existing"

    start_bolthole --ignore "*.log" "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") <(bolthole_log)
    [ -f "$BATS_TEST_TMPDIR/dest/keep.txt" ]
    [ -f "$BATS_TEST_TMPDIR/dest/existing.log" ]
}

@test "new ignored file not copied" {
    expected_output=""

    create_file "source/existing.txt" "existing.txt"
    init_dest_repo existing.txt

    start_bolthole --ignore "*.log" "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    echo "ignored" > "$BATS_TEST_TMPDIR/source/new.log"
    wait_for_debounce

    diff -u <(echo -n "$expected_output") <(bolthole_log)
    [ ! -e "$BATS_TEST_TMPDIR/dest/new.log" ]
}

@test "modified ignored file not copied" {
    expected_output=""

    create_file "source/existing.txt" "existing.txt"
    create_file "source/ignored.log" "original"
    init_dest_repo existing.txt

    start_bolthole --ignore "*.log" "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    echo "modified" > "$BATS_TEST_TMPDIR/source/ignored.log"
    wait_for_debounce

    diff -u <(echo -n "$expected_output") <(bolthole_log)
    [ ! -e "$BATS_TEST_TMPDIR/dest/ignored.log" ]
}

@test "rename to ignored deletes from dest" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        -- "visible.txt"
	EOF
    )

    create_file "source/existing.txt" "existing.txt"
    create_file "source/visible.txt" "visible.txt"
    init_dest_repo existing.txt visible.txt

    start_bolthole --ignore "*.log" "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    mv "$BATS_TEST_TMPDIR/source/visible.txt" "$BATS_TEST_TMPDIR/source/visible.log"
    wait_for_debounce

    diff -u <(echo "$expected_output") <(bolthole_log)
    [ ! -e "$BATS_TEST_TMPDIR/dest/visible.txt" ]
    [ ! -e "$BATS_TEST_TMPDIR/dest/visible.log" ]
}

@test "rename from ignored creates in dest" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "visible.txt"
	EOF
    )

    create_file "source/existing.txt" "existing.txt"
    create_file "source/hidden.log" "hidden"
    init_dest_repo existing.txt

    start_bolthole --ignore "*.log" "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    mv "$BATS_TEST_TMPDIR/source/hidden.log" "$BATS_TEST_TMPDIR/source/visible.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") <(bolthole_log)
    [ -f "$BATS_TEST_TMPDIR/dest/visible.txt" ]
}

@test "deleted ignored file not mirrored" {
    expected_output=""

    create_file "source/existing.txt" "existing.txt"
    create_file "source/ignored.log" "ignored"
    init_dest_repo existing.txt

    start_bolthole --ignore "*.log" "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    rm "$BATS_TEST_TMPDIR/source/ignored.log"
    wait_for_debounce

    diff -u <(echo -n "$expected_output") <(bolthole_log)
}

@test ".git ignored by default" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "file.txt"
	EOF
    )

    create_file "source/file.txt" "content"
    git -C "$BATS_TEST_TMPDIR/source" init --quiet
    create_file "source/.git/custom" "custom"

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") <(bolthole_log)
    [ -f "$BATS_TEST_TMPDIR/dest/file.txt" ]
    [ ! -e "$BATS_TEST_TMPDIR/dest/.git/custom" ]
}

@test "ignores files in subdirectories" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "subdir/keep.txt"
	EOF
    )

    create_file "source/subdir/keep.txt" "keep"
    create_file "source/subdir/ignore.log" "ignored"

    start_bolthole --ignore "*.log" "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") <(bolthole_log)
    [ -f "$BATS_TEST_TMPDIR/dest/subdir/keep.txt" ]
    [ ! -e "$BATS_TEST_TMPDIR/dest/subdir/ignore.log" ]
}

@test "ignores directories in subdirectories" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "subdir/keep.txt"
	EOF
    )

    create_file "source/subdir/keep.txt" "keep"
    create_file "source/subdir/.hidden/secret.txt" "secret"

    start_bolthole --ignore ".hidden" "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") <(bolthole_log)
    [ -f "$BATS_TEST_TMPDIR/dest/subdir/keep.txt" ]
    [ ! -e "$BATS_TEST_TMPDIR/dest/subdir/.hidden" ]
}

@test "move into ignored directory deletes from dest" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        -- "visible.txt"
	EOF
    )

    create_file "source/existing.txt" "existing.txt"
    create_file "source/visible.txt" "visible.txt"
    create_file "source/.hidden/.gitkeep" ""
    init_dest_repo existing.txt visible.txt

    start_bolthole --ignore ".hidden" "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    mv "$BATS_TEST_TMPDIR/source/visible.txt" "$BATS_TEST_TMPDIR/source/.hidden/visible.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") <(bolthole_log)
    [ ! -e "$BATS_TEST_TMPDIR/dest/visible.txt" ]
    [ ! -e "$BATS_TEST_TMPDIR/dest/.hidden" ]
}

@test "move out of ignored directory creates in dest" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "visible.txt"
	EOF
    )

    create_file "source/existing.txt" "existing.txt"
    create_file "source/.hidden/hidden.txt" "hidden"
    init_dest_repo existing.txt

    start_bolthole --ignore ".hidden" "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    mv "$BATS_TEST_TMPDIR/source/.hidden/hidden.txt" "$BATS_TEST_TMPDIR/source/visible.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") <(bolthole_log)
    [ -f "$BATS_TEST_TMPDIR/dest/visible.txt" ]
}

@test "ignores files with special characters" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "keep file.txt"
	EOF
    )

    create_file "source/keep file.txt" "keep"
    create_file "source/ignore file.log" "ignored"

    start_bolthole --ignore "*.log" "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") <(bolthole_log)
    [ -f "$BATS_TEST_TMPDIR/dest/keep file.txt" ]
    [ ! -e "$BATS_TEST_TMPDIR/dest/ignore file.log" ]
}

@test "ignores exact filename" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "keep.txt"
	EOF
    )

    create_file "source/keep.txt" "keep"
    create_file "source/secret.txt" "secret"

    start_bolthole --ignore "secret.txt" "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") <(bolthole_log)
    [ -f "$BATS_TEST_TMPDIR/dest/keep.txt" ]
    [ ! -e "$BATS_TEST_TMPDIR/dest/secret.txt" ]
}

@test "directory with file-like extension ignored" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "keep.txt"
	EOF
    )

    create_file "source/keep.txt" "keep"
    create_file "source/logs.tmp/file.txt" "inside"

    start_bolthole --ignore "*.tmp" "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") <(bolthole_log)
    [ -f "$BATS_TEST_TMPDIR/dest/keep.txt" ]
    [ ! -e "$BATS_TEST_TMPDIR/dest/logs.tmp" ]
}

@test "new ignored directory not copied" {
    expected_output=""

    create_file "source/existing.txt" "existing.txt"
    init_dest_repo existing.txt

    start_bolthole --ignore ".hidden" "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    mkdir -p "$BATS_TEST_TMPDIR/source/.hidden"
    echo "secret" > "$BATS_TEST_TMPDIR/source/.hidden/secret.txt"
    wait_for_debounce

    diff -u <(echo -n "$expected_output") <(bolthole_log)
    [ ! -e "$BATS_TEST_TMPDIR/dest/.hidden" ]
}

@test "ignores path pattern" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "keep.txt"
        ++ "other/file.log"
	EOF
    )

    create_file "source/keep.txt" "keep"
    create_file "source/logs/file.log" "ignored"
    create_file "source/other/file.log" "kept"

    start_bolthole --ignore "logs/*.log" "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") <(sort <(bolthole_log))
    [ -f "$BATS_TEST_TMPDIR/dest/keep.txt" ]
    [ -f "$BATS_TEST_TMPDIR/dest/other/file.log" ]
    [ ! -e "$BATS_TEST_TMPDIR/dest/logs" ]
}

@test "source new ignored file not committed" {
    create_file "source/existing.txt" "existing.txt"
    init_source_repo

    start_bolthole --ignore "*.log" "$BATS_TEST_TMPDIR/source"

    create_file "source/new.log" "ignored"
    wait_for_debounce

    actual=$(git -C "$BATS_TEST_TMPDIR/source" log -1 --format=%s)
    [ "$actual" = "initial" ]
}

@test "source modified ignored file not committed" {
    create_file "source/existing.txt" "existing.txt"
    create_file "source/ignored.log" "original"
    init_source_repo

    start_bolthole --ignore "*.log" "$BATS_TEST_TMPDIR/source"

    echo "modified" > "$BATS_TEST_TMPDIR/source/ignored.log"
    wait_for_debounce

    actual=$(git -C "$BATS_TEST_TMPDIR/source" log -1 --format=%s)
    [ "$actual" = "initial" ]
}

@test "source deleted ignored file not committed" {
    create_file "source/existing.txt" "existing.txt"
    create_file "source/ignored.log" "ignored"
    init_source_repo

    start_bolthole --ignore "*.log" "$BATS_TEST_TMPDIR/source"

    rm "$BATS_TEST_TMPDIR/source/ignored.log"
    wait_for_debounce

    actual=$(git -C "$BATS_TEST_TMPDIR/source" log -1 --format=%s)
    [ "$actual" = "initial" ]
}

@test "source rename to ignored commits removal" {
    create_file "source/existing.txt" "existing.txt"
    create_file "source/visible.txt" "visible.txt"
    init_source_repo

    start_bolthole --ignore "*.log" "$BATS_TEST_TMPDIR/source"

    mv "$BATS_TEST_TMPDIR/source/visible.txt" "$BATS_TEST_TMPDIR/source/visible.log"
    wait_for_debounce

    check_commit_message "$BATS_TEST_TMPDIR/source" "Remove visible.txt"
}

@test "source rename from ignored commits addition" {
    create_file "source/existing.txt" "existing.txt"
    create_file "source/hidden.log" "hidden"
    init_source_repo

    start_bolthole --ignore "*.log" "$BATS_TEST_TMPDIR/source"

    mv "$BATS_TEST_TMPDIR/source/hidden.log" "$BATS_TEST_TMPDIR/source/visible.txt"
    wait_for_debounce

    check_commit_message "$BATS_TEST_TMPDIR/source" "Add visible.txt"
}

@test "source move into ignored directory commits removal" {
    create_file "source/existing.txt" "existing.txt"
    create_file "source/visible.txt" "visible.txt"
    create_file "source/.hidden/.gitkeep" ""
    init_source_repo

    start_bolthole --ignore ".hidden" "$BATS_TEST_TMPDIR/source"

    mv "$BATS_TEST_TMPDIR/source/visible.txt" "$BATS_TEST_TMPDIR/source/.hidden/visible.txt"
    wait_for_debounce

    check_commit_message "$BATS_TEST_TMPDIR/source" "Remove visible.txt"
}

@test "source move out of ignored directory commits addition" {
    create_file "source/existing.txt" "existing.txt"
    create_file "source/.hidden/hidden.txt" "hidden"
    init_source_repo

    start_bolthole --ignore ".hidden" "$BATS_TEST_TMPDIR/source"

    mv "$BATS_TEST_TMPDIR/source/.hidden/hidden.txt" "$BATS_TEST_TMPDIR/source/visible.txt"
    wait_for_debounce

    check_commit_message "$BATS_TEST_TMPDIR/source" "Add visible.txt"
}

@test "concurrent ignored and non-ignored modifications only copies non-ignored" {
    expected_output=$(sed -e 's/^        //' <<-EOF
           "tracked.txt" updated
        ++ "tracked.txt"
	EOF
    )

    create_file "source/tracked.txt" "tracked.txt"
    create_file "source/ignored.log" "original"
    init_dest_repo tracked.txt

    start_bolthole -v --ignore "*.log" "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    echo "modified" > "$BATS_TEST_TMPDIR/source/tracked.txt"
    echo "modified" > "$BATS_TEST_TMPDIR/source/ignored.log"
    wait_for_debounce

    diff -u <(echo "$expected_output") <(bolthole_log)
    [ "$(cat "$BATS_TEST_TMPDIR/dest/tracked.txt")" = "modified" ]
    [ ! -e "$BATS_TEST_TMPDIR/dest/ignored.log" ]
    run git -C "$BATS_TEST_TMPDIR/dest" show --name-only --format=""
    [ "$output" = "tracked.txt" ]
}

@test "source concurrent ignored and non-ignored modifications only commits non-ignored" {
    expected_output=$(sed -e 's/^        //' <<-EOF
           "tracked.txt" updated
	EOF
    )

    create_file "source/tracked.txt" "original"
    create_file "source/ignored.log" "original"
    init_source_repo

    start_bolthole -v --ignore "*.log" "$BATS_TEST_TMPDIR/source"

    echo "modified" > "$BATS_TEST_TMPDIR/source/tracked.txt"
    echo "modified" > "$BATS_TEST_TMPDIR/source/ignored.log"
    wait_for_debounce

    diff -u <(echo "$expected_output") <(bolthole_log)
    check_commit_message "$BATS_TEST_TMPDIR/source" "Update tracked.txt"
    run git -C "$BATS_TEST_TMPDIR/source" show --name-only --format=""
    [ "$output" = "tracked.txt" ]
}
