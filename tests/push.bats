bats_require_minimum_version 1.7.0

load helpers.bash

setup() {
    mkdir -p "$BATS_TEST_TMPDIR/source"
}

teardown() {
    teardown_bolthole
}

@test "creating mirror prompts for remote" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        remote 'origin' needs to be added
	EOF
    )

    create_file "source/file.txt" "content"

    run timeout 5 bolthole --once --timeless -r origin "$BATS_TEST_TMPDIR/source" "$BATS_TEST_TMPDIR/dest"
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 2 ]
    [ ! -f "$BATS_TEST_TMPDIR/dest/file.txt" ]
}

@test "remote not configured" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        remote 'backup' needs to be added
	EOF
    )

    create_file "source/file.txt" "content"
    init_source_repo
    create_bare_remote "origin"
    add_remote "source" "origin"

    run timeout 5 bolthole --once --timeless -r origin -r backup "$BATS_TEST_TMPDIR/source"
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 2 ]
}

@test "push after commit" {
    create_file "source/file.txt" "content"
    init_source_repo
    create_bare_remote "origin"
    create_bare_remote "backup"
    add_remote "source" "origin"
    add_remote "source" "backup"

    create_file "source/new.txt" "new content"

    run timeout 5 bolthole --once --timeless -r origin -r backup "$BATS_TEST_TMPDIR/source"
    [ -z "$output" ]
    [ $status -eq 0 ]

    local origin_head backup_head source_head
    origin_head=$(get_remote_head "origin")
    backup_head=$(get_remote_head "backup")
    source_head=$(git -C "$BATS_TEST_TMPDIR/source" rev-parse HEAD)
    [ "$origin_head" = "$source_head" ]
    [ "$backup_head" = "$source_head" ]
}

@test "push failure continues" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        !! push to origin failed
	EOF
    )

    create_file "source/file.txt" "content"
    init_source_repo
    create_bare_remote "origin"
    add_remote "source" "origin"
    git -C "$BATS_TEST_TMPDIR/source" push --quiet -u origin main

    advance_remote "origin"
    create_file "source/new.txt" "new content"

    run timeout 5 bolthole --once --timeless -r origin "$BATS_TEST_TMPDIR/source"
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 0 ]
    check_commit_message "$BATS_TEST_TMPDIR/source" "Add new.txt"
}

@test "push after commit in watch mode" {
    create_file "source/file.txt" "content"
    init_source_repo
    create_bare_remote "origin"
    add_remote "source" "origin"

    start_bolthole -r origin "$BATS_TEST_TMPDIR/source"

    create_file "source/new.txt" "new content"
    wait_for_debounce

    local origin_head source_head
    origin_head=$(get_remote_head "origin")
    source_head=$(git -C "$BATS_TEST_TMPDIR/source" rev-parse HEAD)
    [ "$origin_head" = "$source_head" ]
    check_commit_message "$BATS_TEST_TMPDIR/source" "Add new.txt"
}

@test "dry run shows push commands" {
    expected_output=$(sed -e 's/^        //' <<-EOF
        #  git add -- new.txt
        #  git commit
        #  git push origin HEAD
        #  git push backup HEAD
	EOF
    )

    create_file "source/file.txt" "content"
    init_source_repo
    create_bare_remote "origin"
    create_bare_remote "backup"
    add_remote "source" "origin"
    add_remote "source" "backup"

    create_file "source/new.txt" "new content"

    run timeout 5 bolthole --once --dry-run --timeless -r origin -r backup "$BATS_TEST_TMPDIR/source"
    diff -u <(echo "$expected_output") <(echo "$output")
    [ $status -eq 0 ]
}
