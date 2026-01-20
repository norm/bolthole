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
    expected_output=$(sed -e 's/^        //' <<-EOF
        Add a.txt
        Add b.txt
        Add existing.txt
	EOF
    )
    run git -C "$BATS_TEST_TMPDIR/dest" log --format=%s
    diff -u <(echo "$expected_output" | sort) <(echo "$output" | sort)
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
    # both committed separately
    expected_output=$(sed -e 's/^        //' <<-EOF
        Add existing.txt
	EOF
    )
    run git -C "$BATS_TEST_TMPDIR/dest" log --format=%s
    diff -u <(echo "$expected_output") <(echo "$output")
}

@test "delete then recreate identical within grace results in no commit" {
    create_file "source/existing.txt" "existing"
    create_file "source/stable.txt" "unchanged"

    start_bolthole --grace 0.5 "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    rm "$BATS_TEST_TMPDIR/source/stable.txt"
    wait_for_debounce
    [ ! -f "$BATS_TEST_TMPDIR/dest/stable.txt" ]

    create_file "source/stable.txt" "unchanged"
    wait_for_debounce
    [ -f "$BATS_TEST_TMPDIR/dest/stable.txt" ]

    # wait for grace period to expire
    sleep 0.6

    # no new commits (content unchanged)
    run git -C "$BATS_TEST_TMPDIR/dest" log --format=%s
    diff -u <(echo "Add existing.txt and stable.txt") <(echo "$output")
}

@test "modify then delete within grace results in one delete commit" {
    create_file "source/existing.txt" "existing"
    create_file "source/doomed.txt" "original"

    start_bolthole --grace 0.5 "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    echo "modified" > "$BATS_TEST_TMPDIR/source/doomed.txt"
    wait_for_debounce
    [ "$(cat "$BATS_TEST_TMPDIR/dest/doomed.txt")" = "modified" ]

    rm "$BATS_TEST_TMPDIR/source/doomed.txt"
    wait_for_debounce
    [ ! -f "$BATS_TEST_TMPDIR/dest/doomed.txt" ]

    # wait for grace period to expire
    sleep 0.6

    # one commit for the deletion (not modify then delete)
    expected_output=$(sed -e 's/^        //' <<-EOF
        Remove doomed.txt
        Add doomed.txt and existing.txt
	EOF
    )
    run git -C "$BATS_TEST_TMPDIR/dest" log --format=%s
    diff -u <(echo "$expected_output") <(echo "$output")
}

@test "delete then recreate modified within grace results in one commit" {
    create_file "source/existing.txt" "existing"
    create_file "source/changing.txt" "original"

    start_bolthole --grace 0.5 "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    rm "$BATS_TEST_TMPDIR/source/changing.txt"
    wait_for_debounce
    [ ! -f "$BATS_TEST_TMPDIR/dest/changing.txt" ]

    create_file "source/changing.txt" "modified"
    wait_for_debounce
    [ -f "$BATS_TEST_TMPDIR/dest/changing.txt" ]

    # wait for grace period to expire
    sleep 0.6

    # one commit for the modification
    expected_output=$(sed -e 's/^        //' <<-EOF
        Update changing.txt
        Add changing.txt and existing.txt
	EOF
    )
    run git -C "$BATS_TEST_TMPDIR/dest" log --format=%s
    diff -u <(echo "$expected_output") <(echo "$output")
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
    expected_output=$(sed -e 's/^        //' <<-EOF
        Add renamed.txt
        Add existing.txt
	EOF
    )
    run git -C "$BATS_TEST_TMPDIR/dest" log --format=%s
    diff -u <(echo "$expected_output") <(echo "$output")
}

@test "files older than bundle threshold commit together" {
    create_file "source/existing.txt" "existing"
    start_bolthole --grace 2.0 --bundle 1.0 "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    create_file "source/a.txt" "first"
    wait_for_debounce

    # t=0.7s
    sleep 0.5
    create_file "source/b.txt" "second"
    wait_for_debounce

    [ -f "$BATS_TEST_TMPDIR/dest/a.txt" ]
    [ -f "$BATS_TEST_TMPDIR/dest/b.txt" ]
    run git -C "$BATS_TEST_TMPDIR/dest" log --format=%s
    diff -u <(echo "Add existing.txt") <(echo "$output")

    # t=2.2s, a.txt grace fires, b.txt is more than bundle (1.0s) old
    sleep 1.3
    expected_output=$(sed -e 's/^        //' <<-EOF
        Add a.txt and b.txt
        Add existing.txt
	EOF
    )
    run git -C "$BATS_TEST_TMPDIR/dest" log --format=%s
    diff -u <(echo "$expected_output") <(echo "$output")
}

@test "file younger than bundle threshold waits for own timer" {
    create_file "source/existing.txt" "existing"
    start_bolthole --grace 2.0 --bundle 1.0 "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    create_file "source/a.txt" "first"
    wait_for_debounce

    # t=0.7s
    sleep 0.5
    create_file "source/b.txt" "second"
    wait_for_debounce

    # t=1.7s
    sleep 0.8
    echo "modified" > "$BATS_TEST_TMPDIR/source/b.txt"
    wait_for_debounce

    # T=2.3: a.txt's grace has fired, b.txt not bundled (too young)
    # t=2.3s, a.txt grace fires, b
    sleep 0.4

    expected_output=$(sed -e 's/^        //' <<-EOF
        Add a.txt
        Add existing.txt
	EOF
    )

    run git -C "$BATS_TEST_TMPDIR/dest" log --format=%s
    diff -u <(echo "$expected_output") <(echo "$output")

    # T=3.9: b.txt's grace fires (1.7 + 2.0 = 3.7)
    sleep 1.6
    expected_output=$(sed -e 's/^        //' <<-EOF
        Add b.txt
        Add a.txt
        Add existing.txt
	EOF
    )
    run git -C "$BATS_TEST_TMPDIR/dest" log --format=%s
    diff -u <(echo "$expected_output") <(echo "$output")
}

@test "bundled commits work in single-directory mode" {
    create_file "source/existing.txt" "existing"
    init_source_repo
    start_bolthole --grace 1.0 --bundle 0.8 "$BATS_TEST_TMPDIR/source"

    create_file "source/a.txt" "first"
    create_file "source/b.txt" "second"
    wait_for_debounce

    run git -C "$BATS_TEST_TMPDIR/source" log --format=%s
    diff -u <(echo "initial") <(echo "$output")

    sleep 1
    expected=$(sed -e 's/^        //' <<-EOF
        Add a.txt and b.txt
        initial
	EOF
    )
    run git -C "$BATS_TEST_TMPDIR/source" log --format=%s
    diff -u <(echo "$expected") <(echo "$output")
}

@test "dry-run shows multiple files in bundled commit" {
    create_file "source/existing.txt" "existing"
    create_file "dest/existing.txt" "existing"
    init_dest_repo
    start_bolthole --dry-run --grace 2.0 --bundle 1.0 "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"

    create_file "source/a.txt" "first"
    create_file "source/b.txt" "second"
    wait_for_debounce

    # grace timer has not fired
    sleep 1.5
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "a.txt"
        #  copy "a.txt"
        ++ "b.txt"
        #  copy "b.txt"
	EOF
    )
    diff -u <(echo "$expected_output") <(bolthole_log)

    # grace timer has fired
    sleep 0.6
    expected_output=$(sed -e 's/^        //' <<-EOF
        ++ "a.txt"
        #  copy "a.txt"
        ++ "b.txt"
        #  copy "b.txt"
        #  git add -- a.txt b.txt
        #  git commit
	EOF
    )
    diff -u <(echo "$expected_output") <(bolthole_log)
}
