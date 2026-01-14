#!/usr/bin/env bats


function wait_for_debounce {
    # debounce period is 0.3s, wait a little longer
    sleep 0.5
}

setup() {
    mkdir -p "$BATS_TEST_TMPDIR/watch"
    bolthole "$BATS_TEST_TMPDIR/watch" >"$BATS_TEST_TMPDIR/out.txt" 2>&1 &
    pid=$!
    sleep 0.1
}

teardown() {
    kill $pid 2>/dev/null || true
    wait $pid 2>/dev/null || true
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
    expected_output=$(sed -e 's/^        //' <<"        EOF"
        watchdog: created debug.txt
        watchdog: deleted debug.txt
        EOF
    )

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
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $? -eq 0 ]
}
