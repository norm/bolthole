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
    bolthole "$@" >"$BATS_TEST_TMPDIR/out.txt" 2>&1 &
    pid=$!
    sleep 0.1
}

function teardown_bolthole {
    kill $pid 2>/dev/null || true
    wait $pid 2>/dev/null || true
}
