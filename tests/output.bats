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

@test "output includes timestamp" {
    start_bolthole "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    echo "modified" > "$BATS_TEST_TMPDIR/source/file.txt"
    wait_for_debounce

    output=$(cat "$BATS_TEST_TMPDIR/out.txt")
    [[ "$output" =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}\ \+\+\ \"file\.txt\"$ ]]
}

@test "new file" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "new.txt"
	EOF
    )

    start_bolthole --timeless "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    create_file "source/new.txt" "new"
    wait_for_debounce

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
}

@test "new file and event" {
    expected_output=$(sed -e 's/^        //' <<-EOF
           "new.txt" created
        ++ "new.txt"
	EOF
    )

    start_bolthole --timeless -v "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    create_file "source/new.txt" "new"
    wait_for_debounce

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
}

@test "new file dry run" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "new.txt"
        #  copy "new.txt"
	EOF
    )

    start_bolthole --timeless -n "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    create_file "source/new.txt" "new"
    wait_for_debounce

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
}

@test "modified file" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "file.txt"
	EOF
    )

    start_bolthole --timeless "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    echo "modified" > "$BATS_TEST_TMPDIR/source/file.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
}

@test "modified file and event" {
    expected_output=$(sed -e 's/^        //' <<-EOF
           "file.txt" updated
        ++ "file.txt"
	EOF
    )

    start_bolthole --timeless -v "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    echo "modified" > "$BATS_TEST_TMPDIR/source/file.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
}

@test "modified file dry run" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "file.txt"
        #  copy "file.txt"
	EOF
    )

    start_bolthole --timeless -n "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    echo "modified" > "$BATS_TEST_TMPDIR/source/file.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
}

@test "deleted file" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        -- "file.txt"
	EOF
    )

    start_bolthole --timeless "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    rm "$BATS_TEST_TMPDIR/source/file.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
}

@test "deleted file and event" {
    expected_output=$(sed -e 's/^        //' <<-EOF
           "file.txt" deleted
        -- "file.txt"
	EOF
    )

    start_bolthole --timeless -v "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    rm "$BATS_TEST_TMPDIR/source/file.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
}

@test "deleted file dry run" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        -- "file.txt"
        #  delete "file.txt"
	EOF
    )

    start_bolthole --timeless -n "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    rm "$BATS_TEST_TMPDIR/source/file.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
}

@test "renamed file" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "file.txt" -> "new.txt"
	EOF
    )

    start_bolthole --timeless "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    mv "$BATS_TEST_TMPDIR/source/file.txt" "$BATS_TEST_TMPDIR/source/new.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
}

@test "renamed file and event" {
    expected_output=$(sed -e 's/^        //' <<-EOF
           "file.txt" renamed "new.txt"
        ++ "file.txt" -> "new.txt"
	EOF
    )

    start_bolthole --timeless -v "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    mv "$BATS_TEST_TMPDIR/source/file.txt" "$BATS_TEST_TMPDIR/source/new.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
}

@test "renamed file dry run" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "file.txt" -> "new.txt"
        #  rename "file.txt" to "new.txt"
	EOF
    )

    start_bolthole --timeless -n "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    mv "$BATS_TEST_TMPDIR/source/file.txt" "$BATS_TEST_TMPDIR/source/new.txt"
    wait_for_debounce

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
}

@test "initial sync verbose" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "new.txt"
	EOF
    )

    create_file "source/new.txt" "new"

    start_bolthole --timeless -v "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
}

@test "initial sync" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "new.txt"
	EOF
    )

    create_file "source/new.txt" "new"

    start_bolthole --timeless "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
}

@test "initial sync dry run" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "new.txt"
        #  copy "new.txt"
	EOF
    )

    create_file "source/new.txt" "new"

    start_bolthole --timeless -n "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
    [ ! -e "$BATS_TEST_TMPDIR/dest/new.txt" ]
}

@test "initial sync delete dry run" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        -- "extra.txt"
        #  delete "extra.txt"
	EOF
    )

    create_file "dest/extra.txt" "extra"

    start_bolthole --timeless -n "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
    [ -f "$BATS_TEST_TMPDIR/dest/extra.txt" ]
}

@test "single-directory mode silent" {
    start_bolthole --timeless "$BATS_TEST_TMPDIR/source"

    create_file "source/new.txt" "new"
    wait_for_debounce

    [ ! -s "$BATS_TEST_TMPDIR/out.txt" ]
}

@test "single-directory mode verbose" {
    expected_output=$(sed -e 's/^        //' <<-EOF
           "new.txt" created
	EOF
    )

    start_bolthole --timeless -v "$BATS_TEST_TMPDIR/source"

    create_file "source/new.txt" "new"
    wait_for_debounce

    diff -u <(echo "$expected_output") "$BATS_TEST_TMPDIR/out.txt"
}
