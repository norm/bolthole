bats_require_minimum_version 1.7.0

load helpers.bash

setup() {
    create_file "source/file.txt" "content"
    create_file "dest/file.txt" "content"
    init_dest_repo
}

teardown() {
    teardown_bolthole
}

@test "new file" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "new.txt"
	EOF
    )

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    create_file "source/new.txt" "new"
    wait_for_debounce

    diff -u <(echo "$expected_output") <(bolthole_log)
}

@test "new file and event" {
    expected_output=$(sed -e 's/^        //' <<-EOF
           "new.txt" created
        ++ "new.txt"
	EOF
    )

    start_bolthole -v "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    create_file "source/new.txt" "new"
    wait_for_debounce

    diff -u <(echo "$expected_output") <(bolthole_log)
}

@test "new file dry run" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "new.txt"
        #  copy "new.txt"
        #  git add -- new.txt
        #  git commit
	EOF
    )

    start_bolthole -n "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    create_file "source/new.txt" "new"
    wait_for_debounce

    diff -u <(echo "$expected_output") <(bolthole_log)
}

@test "modified file" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "file.txt"
	EOF
    )

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    echo "modified" > "$BATS_TEST_TMPDIR/source/file.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") <(bolthole_log)
}

@test "modified file and event" {
    expected_output=$(sed -e 's/^        //' <<-EOF
           "file.txt" updated
        ++ "file.txt"
	EOF
    )

    start_bolthole -v "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    echo "modified" > "$BATS_TEST_TMPDIR/source/file.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") <(bolthole_log)
}

@test "modified file dry run" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "file.txt"
        #  copy "file.txt"
        #  git add -- file.txt
        #  git commit
	EOF
    )

    start_bolthole -n "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    echo "modified" > "$BATS_TEST_TMPDIR/source/file.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") <(bolthole_log)
}

@test "deleted file" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        -- "file.txt"
	EOF
    )

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    rm "$BATS_TEST_TMPDIR/source/file.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") <(bolthole_log)
}

@test "deleted file and event" {
    expected_output=$(sed -e 's/^        //' <<-EOF
           "file.txt" deleted
        -- "file.txt"
	EOF
    )

    start_bolthole -v "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    rm "$BATS_TEST_TMPDIR/source/file.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") <(bolthole_log)
}

@test "deleted file dry run" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        -- "file.txt"
        #  delete "file.txt"
        #  git add -- file.txt
        #  git commit
	EOF
    )

    start_bolthole -n "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    rm "$BATS_TEST_TMPDIR/source/file.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") <(bolthole_log)
}

@test "renamed file" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "file.txt" -> "new.txt"
	EOF
    )

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    mv "$BATS_TEST_TMPDIR/source/file.txt" "$BATS_TEST_TMPDIR/source/new.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") <(bolthole_log)
}

@test "renamed file and event" {
    expected_output=$(sed -e 's/^        //' <<-EOF
           "file.txt" renamed "new.txt"
        ++ "file.txt" -> "new.txt"
	EOF
    )

    start_bolthole -v "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    mv "$BATS_TEST_TMPDIR/source/file.txt" "$BATS_TEST_TMPDIR/source/new.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") <(bolthole_log)
}

@test "renamed file dry run" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "file.txt" -> "new.txt"
        #  rename "file.txt" to "new.txt"
        #  git add -- file.txt new.txt
        #  git commit
	EOF
    )

    start_bolthole -n "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    mv "$BATS_TEST_TMPDIR/source/file.txt" "$BATS_TEST_TMPDIR/source/new.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") <(bolthole_log)
}

@test "initial sync verbose" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "new.txt"
	EOF
    )

    create_file "source/new.txt" "new"

    start_bolthole -v "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") <(bolthole_log)
}

@test "initial sync" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "new.txt"
	EOF
    )

    create_file "source/new.txt" "new"

    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") <(bolthole_log)
}

@test "initial sync dry run" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "new.txt"
        #  copy "new.txt"
        #  git add -- new.txt
        #  git commit
	EOF
    )

    create_file "source/new.txt" "new"

    start_bolthole -n "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") <(bolthole_log)
    [ ! -e "$BATS_TEST_TMPDIR/dest/new.txt" ]
}

@test "initial sync delete dry run" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        -- "extra.txt"
        #  delete "extra.txt"
        #  git add -- extra.txt
        #  git commit
	EOF
    )

    create_file "dest/extra.txt" "extra"

    start_bolthole -n "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") <(bolthole_log)
    [ -f "$BATS_TEST_TMPDIR/dest/extra.txt" ]
}

@test "single-directory mode silent" {
    init_source_repo

    start_bolthole "$BATS_TEST_TMPDIR/source"

    create_file "source/new.txt" "new"
    wait_for_debounce

    [ -z "$(bolthole_log)" ]
}

@test "single-directory mode verbose" {
    expected_output=$(sed -e 's/^        //' <<-EOF
           "new.txt" created
	EOF
    )

    init_source_repo

    start_bolthole -v "$BATS_TEST_TMPDIR/source"

    create_file "source/new.txt" "new"
    wait_for_debounce

    diff -u <(echo "$expected_output") <(bolthole_log)
}

@test "dry run shows git commands" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "new.txt"
        #  copy "new.txt"
        #  git add -- new.txt
        #  git commit
	EOF
    )

    start_bolthole -n "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    create_file "source/new.txt" "new"
    wait_for_debounce

    diff -u <(echo "$expected_output") <(bolthole_log)
    ! git -C "$BATS_TEST_TMPDIR/dest" log -1 2>/dev/null
}

@test "display selective git commands" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        %  git add -- new.txt
        %  git commit
	EOF
    )

    init_source_repo

    create_file "source/new.txt" "new"

    start_bolthole --show-git "$BATS_TEST_TMPDIR/source"
    sleep 0.2

    diff -u <(echo "$expected_output") <(bolthole_log)
}

@test "dry-run output includes timestamp" {
    create_file "source/rename-me.txt" "rename"
    create_file "source/delete-me.txt" "delete"

    bolthole -n -v --watchdog-debug "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest" >"$BATS_TEST_TMPDIR/out.txt" 2>&1 &
    pid=$!
    wait_for_bolthole_ready

    create_file "source/new.txt" "new"
    echo "modified" > "$BATS_TEST_TMPDIR/source/file.txt"
    mv "$BATS_TEST_TMPDIR/source/rename-me.txt" "$BATS_TEST_TMPDIR/source/renamed.txt"
    rm "$BATS_TEST_TMPDIR/source/delete-me.txt"
    wait_for_debounce
    kill $pid 2>/dev/null; wait $pid 2>/dev/null || true

    cat "$BATS_TEST_TMPDIR/out.txt"
    [ -s "$BATS_TEST_TMPDIR/out.txt" ]
    [ -z "$(grep -vE '^[0-9]{2}:[0-9]{2}:[0-9]{2} ' "$BATS_TEST_TMPDIR/out.txt")" ]
}

@test "show-git output includes timestamp" {
    create_file "source/rename-me.txt" "rename"
    create_file "source/delete-me.txt" "delete"
    init_source_repo

    bolthole -v --watchdog-debug --show-git "$BATS_TEST_TMPDIR/source" >"$BATS_TEST_TMPDIR/out.txt" 2>&1 &
    pid=$!
    wait_for_bolthole_ready

    create_file "source/new.txt" "new"
    echo "modified" > "$BATS_TEST_TMPDIR/source/file.txt"
    mv "$BATS_TEST_TMPDIR/source/rename-me.txt" "$BATS_TEST_TMPDIR/source/renamed.txt"
    rm "$BATS_TEST_TMPDIR/source/delete-me.txt"
    wait_for_debounce
    kill $pid 2>/dev/null; wait $pid 2>/dev/null || true

    cat "$BATS_TEST_TMPDIR/out.txt"
    [ -s "$BATS_TEST_TMPDIR/out.txt" ]
    [ -z "$(grep -vE '^[0-9]{2}:[0-9]{2}:[0-9]{2} ' "$BATS_TEST_TMPDIR/out.txt")" ]
}
