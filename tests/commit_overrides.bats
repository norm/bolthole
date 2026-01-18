bats_require_minimum_version 1.7.0

load helpers.bash

setup() {
    mkdir -p "$BATS_TEST_TMPDIR/source"
}

teardown() {
    teardown_bolthole
}

@test "author override in mirror mode" {
    create_file "source/file.txt" "content"
    init_dest_repo

    start_bolthole -a "Custom Author <custom@example.com>" \
        "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    echo "first change" > "$BATS_TEST_TMPDIR/source/file.txt"
    wait_for_debounce

    echo "second change" > "$BATS_TEST_TMPDIR/source/file.txt"
    wait_for_debounce

    local authors
    authors=$(git -C "$BATS_TEST_TMPDIR/dest" log -2 --format="%an <%ae>")
    expected=$(sed -e 's/^        //' <<-EOF
        Custom Author <custom@example.com>
        Custom Author <custom@example.com>
	EOF
    )
    diff -u <(echo "$expected") <(echo "$authors")
}

@test "author override in single-directory mode" {
    create_file "source/file.txt" "content"
    init_source_repo

    start_bolthole -a "Custom Author <custom@example.com>" \
        "$BATS_TEST_TMPDIR/source"

    echo "first change" > "$BATS_TEST_TMPDIR/source/file.txt"
    wait_for_debounce

    echo "second change" > "$BATS_TEST_TMPDIR/source/file.txt"
    wait_for_debounce

    local authors
    authors=$(git -C "$BATS_TEST_TMPDIR/source" log -2 --format="%an <%ae>")
    expected=$(sed -e 's/^        //' <<-EOF
        Custom Author <custom@example.com>
        Custom Author <custom@example.com>
	EOF
    )
    diff -u <(echo "$expected") <(echo "$authors")
}

@test "message override in mirror mode" {
    create_file "source/file.txt" "content"
    init_dest_repo

    start_bolthole -m "Custom commit message" \
        "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    echo "first change" > "$BATS_TEST_TMPDIR/source/file.txt"
    wait_for_debounce

    echo "second change" > "$BATS_TEST_TMPDIR/source/file.txt"
    wait_for_debounce

    local messages
    messages=$(git -C "$BATS_TEST_TMPDIR/dest" log -2 --format=%s)
    expected=$(sed -e 's/^        //' <<-EOF
        Custom commit message
        Custom commit message
	EOF
    )
    diff -u <(echo "$expected") <(echo "$messages")
}

@test "message override in single-directory mode" {
    create_file "source/file.txt" "content"
    init_source_repo

    start_bolthole -m "Custom commit message" \
        "$BATS_TEST_TMPDIR/source"

    echo "first change" > "$BATS_TEST_TMPDIR/source/file.txt"
    wait_for_debounce

    echo "second change" > "$BATS_TEST_TMPDIR/source/file.txt"
    wait_for_debounce

    local messages
    messages=$(git -C "$BATS_TEST_TMPDIR/source" log -2 --format=%s)
    expected=$(sed -e 's/^        //' <<-EOF
        Custom commit message
        Custom commit message
	EOF
    )
    diff -u <(echo "$expected") <(echo "$messages")
}
