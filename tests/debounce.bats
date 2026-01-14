#!/usr/bin/env bats

load helpers.bash

setup() {
    mkdir -p "$BATS_TEST_TMPDIR/watch"
    start_bolthole "$BATS_TEST_TMPDIR/watch"
}

teardown() {
    teardown_bolthole
}

@test "debounce create+delete to no report" {
    expected_output=""

    touch "$BATS_TEST_TMPDIR/watch/temp.txt"
    sleep 0.05
    rm "$BATS_TEST_TMPDIR/watch/temp.txt"
    wait_for_debounce

    output=$(cat "$BATS_TEST_TMPDIR/out.txt")
    diff -u <(echo -n "$expected_output") <(echo -n "$output")
    [ $? -eq 0 ]
}

@test "debounce create+modify to create" {
    expected_output=$(sed -e 's/^        //' <<"        EOF"
        created file.txt
        EOF
    )

    touch "$BATS_TEST_TMPDIR/watch/file.txt"
    sleep 0.05
    echo "content" > "$BATS_TEST_TMPDIR/watch/file.txt"
    wait_for_debounce

    output=$(cat "$BATS_TEST_TMPDIR/out.txt")
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $? -eq 0 ]
}

@test "--watchdog-debug shows raw events" {
    kill $pid 2>/dev/null || true
    wait $pid 2>/dev/null || true

    bolthole --watchdog-debug "$BATS_TEST_TMPDIR/watch" >"$BATS_TEST_TMPDIR/out.txt" 2>&1 &
    pid=$!
    sleep 0.1

    touch "$BATS_TEST_TMPDIR/watch/debug.txt"
    sleep 0.05
    rm "$BATS_TEST_TMPDIR/watch/debug.txt"
    wait_for_debounce

    output=$(cat "$BATS_TEST_TMPDIR/out.txt")

    # different OSes generate other events, so look for the
    # guaranteed ones, rather than comparing a full log
    echo "$output" | grep -q "watchdog: created debug.txt"
    echo "$output" | grep -q "watchdog: deleted debug.txt"
}
