bats_require_minimum_version 1.7.0

load helpers.bash

setup() {
    mkdir -p "$BATS_TEST_TMPDIR/source"
}

teardown() {
    teardown_bolthole
}

@test "grace period delays commits with independent timers" {
    create_file "source/existing.txt" "existing"

    start_bolthole --grace 0.8 "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    # create file A
    create_file "source/a.txt" "first"
    wait_for_debounce

    # synced but not committed
    [ -f "$BATS_TEST_TMPDIR/dest/a.txt" ]
    run git -C "$BATS_TEST_TMPDIR/dest" log --format=%s
    diff -u <(echo "Add existing.txt") <(echo "$output")

    # wait partway through grace
    sleep 0.4

    # modify A (resets timer) and create B (starts timer)
    echo "modified" > "$BATS_TEST_TMPDIR/source/a.txt"
    create_file "source/b.txt" "second"
    wait_for_debounce

    # both synced, neither committed
    [ -f "$BATS_TEST_TMPDIR/dest/b.txt" ]
    run git -C "$BATS_TEST_TMPDIR/dest" log --format=%s
    diff -u <(echo "Add existing.txt") <(echo "$output")

    # wait past A's original timer - proves reset worked
    sleep 0.5

    # still not committed (A's timer was reset)
    run git -C "$BATS_TEST_TMPDIR/dest" log --format=%s
    diff -u <(echo "Add existing.txt") <(echo "$output")

    # wait for both timers to expire
    sleep 0.5

    # both committed separately
    expected=$(sed -e 's/^        //' <<-EOF
        Add a.txt
        Add b.txt
        Add existing.txt
	EOF
    )
    run git -C "$BATS_TEST_TMPDIR/dest" log --format=%s
    diff -u <(echo "$expected" | sort) <(echo "$output" | sort)
}

@test "create then delete within grace results in no commit" {
    create_file "source/existing.txt" "existing"

    start_bolthole --grace 0.5 "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    create_file "source/ephemeral.txt" "temporary"
    wait_for_debounce

    # file synced
    [ -f "$BATS_TEST_TMPDIR/dest/ephemeral.txt" ]

    rm "$BATS_TEST_TMPDIR/source/ephemeral.txt"
    wait_for_debounce

    # file removed
    [ ! -f "$BATS_TEST_TMPDIR/dest/ephemeral.txt" ]

    # wait for grace period to expire
    sleep 0.6

    # no new commits (only initial)
    run git -C "$BATS_TEST_TMPDIR/dest" log --format=%s
    diff -u <(echo "Add existing.txt") <(echo "$output")
}

@test "create then rename within grace results in one commit" {
    create_file "source/existing.txt" "existing"

    start_bolthole --grace 0.5 "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    create_file "source/original.txt" "content"
    wait_for_debounce

    # file synced
    [ -f "$BATS_TEST_TMPDIR/dest/original.txt" ]

    mv "$BATS_TEST_TMPDIR/source/original.txt" "$BATS_TEST_TMPDIR/source/renamed.txt"
    wait_for_debounce

    # rename synced
    [ ! -f "$BATS_TEST_TMPDIR/dest/original.txt" ]
    [ -f "$BATS_TEST_TMPDIR/dest/renamed.txt" ]

    # wait for grace period to expire
    sleep 0.6

    # one commit for the new name (not two commits)
    expected=$(sed -e 's/^        //' <<-EOF
        Add renamed.txt
        Add existing.txt
	EOF
    )
    run git -C "$BATS_TEST_TMPDIR/dest" log --format=%s
    diff -u <(echo "$expected") <(echo "$output")
}
