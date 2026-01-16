function create_file {
    local path="$BATS_TEST_TMPDIR/$1"
    local content="$2"
    local mode="${3:-}"
    mkdir -p "$(dirname "$path")"
    echo "$content" > "$path"
    if [ -n "$mode" ]; then
        chmod "$mode" "$path"
    fi
}

function wait_for_debounce {
    # debounce period is 0.33s, wait a little longer
    sleep 0.5
}

function start_bolthole {
    bolthole --timeless "$@" >"$BATS_TEST_TMPDIR/out.txt" 2>&1 &
    pid=$!
    sleep 0.1
}

function teardown_bolthole {
    kill $pid 2>/dev/null || true
    wait $pid 2>/dev/null || true
}

function init_dest_repo {
    mkdir -p "$BATS_TEST_TMPDIR/dest"
    git -C "$BATS_TEST_TMPDIR/dest" init --quiet
}

function check_commit_message {
    local repo="$1"
    local expected="$2"
    local actual
    actual=$(git -C "$repo" log -1 --format=%s)
    diff -u <(echo "$expected") <(echo "$actual")
}
