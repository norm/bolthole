export GIT_AUTHOR_NAME="Test User"
export GIT_AUTHOR_EMAIL="test@example.com"
export GIT_COMMITTER_NAME="Test User"
export GIT_COMMITTER_EMAIL="test@example.com"

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
    # debounce period is 0.1s, wait longer for processing and commit
    sleep 0.2
}

function wait_for_bolthole_ready {
    for i in {1..50}; do
        if grep -qE "(Copying|Watching) " "$BATS_TEST_TMPDIR/out.txt" 2>/dev/null; then
            return 0
        fi
        sleep 0.02
    done
    echo "bolthole did not become ready" >&2
    return 1
}

function start_bolthole {
    bolthole --timeless "$@" >"$BATS_TEST_TMPDIR/out.txt" 2>&1 &
    pid=$!
    wait_for_bolthole_ready
}

function bolthole_log {
    sed -e '/^   Copying /d' -e '/^   Watching /d' "$BATS_TEST_TMPDIR/out.txt"
}

function teardown_bolthole {
    kill $pid 2>/dev/null || true
    wait $pid 2>/dev/null || true
}

function init_dest_repo {
    mkdir -p "$BATS_TEST_TMPDIR/dest"
    git -C "$BATS_TEST_TMPDIR/dest" init --quiet -b main

    if [ $# -gt 0 ]; then
        for file in "$@"; do
            create_file "dest/$file" "$file"
        done
        git -C "$BATS_TEST_TMPDIR/dest" add -A
        git -C "$BATS_TEST_TMPDIR/dest" commit -m "initial" --no-verify --no-gpg-sign --quiet
    fi
}

function init_source_repo {
    git -C "$BATS_TEST_TMPDIR/source" init --quiet -b main
    if [ "$1" = "--gitignore" ]; then
        printf "%s\n" "$2" > "$BATS_TEST_TMPDIR/source/.gitignore"
    fi
    git -C "$BATS_TEST_TMPDIR/source" add -A
    git -C "$BATS_TEST_TMPDIR/source" commit -m "initial" --no-verify --no-gpg-sign --quiet
}

function add_file_to_repo {
    local path="$1"
    local content="$2"
    local repo="${path%%/*}"
    local file="${path#*/}"
    create_file "$path" "$content"
    git -C "$BATS_TEST_TMPDIR/$repo" add -- "$file"
    git -C "$BATS_TEST_TMPDIR/$repo" commit -m "add $file" --no-verify --no-gpg-sign --quiet
}

function check_commit_message {
    local repo="$1"
    local expected="$2"
    local actual
    actual=$(git -C "$repo" log -1 --format=%s)
    diff -u <(echo "$expected") <(echo "$actual")
}

function check_commit_author {
    local repo="$1"
    local expected="$2"
    local actual
    actual=$(git -C "$repo" log -1 --format="%an <%ae>")
    diff -u <(echo "$expected") <(echo "$actual")
}

function create_bare_remote {
    local name="$1"
    git init --bare --quiet -b main "$BATS_TEST_TMPDIR/$name.git"
}

function add_remote {
    local repo="$1"
    local name="$2"
    local url="$BATS_TEST_TMPDIR/$name.git"
    git -C "$BATS_TEST_TMPDIR/$repo" remote add "$name" "$url"
}

function get_remote_head {
    local name="$1"
    git -C "$BATS_TEST_TMPDIR/$name.git" rev-parse HEAD 2>/dev/null
}

function advance_remote {
    local name="$1"
    local tmp="$BATS_TEST_TMPDIR/tmp_clone"
    git clone --quiet "$BATS_TEST_TMPDIR/$name.git" "$tmp"
    echo "conflict" > "$tmp/conflict.txt"
    git -C "$tmp" add conflict.txt
    git -C "$tmp" commit -m "advance" --no-verify --no-gpg-sign --quiet
    git -C "$tmp" push --quiet
    rm -rf "$tmp"
}
