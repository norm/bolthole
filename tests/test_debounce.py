from bolthole.debounce import collapse_events, Event


def test_single_created():
    assert collapse_events([
        Event("created", "a.txt"),
    ]) == [
        Event("created", "a.txt"),
    ]


def test_single_modified():
    assert collapse_events([
        Event("modified", "a.txt"),
    ]) == [
        Event("modified", "a.txt"),
    ]


def test_single_deleted():
    assert collapse_events([
        Event("deleted", "a.txt"),
    ]) == [
        Event("deleted", "a.txt"),
    ]


def test_single_renamed():
    assert collapse_events([
        Event("renamed", "a.txt", "b.txt"),
    ]) == [
        Event("renamed", "a.txt", "b.txt"),
    ]


def test_created_then_deleted():
    assert collapse_events([
        Event("created", "a.txt"),
        Event("deleted", "a.txt"),
    ]) == []


def test_created_then_modified():
    assert collapse_events([
        Event("created", "a.txt"),
        Event("modified", "a.txt"),
    ]) == [
        Event("created", "a.txt"),
    ]


def test_deleted_then_created():
    assert collapse_events([
        Event("deleted", "a.txt"),
        Event("created", "a.txt"),
    ]) == [
        Event("modified", "a.txt"),
    ]


def test_modified_then_deleted():
    assert collapse_events([
        Event("modified", "a.txt"),
        Event("deleted", "a.txt"),
    ]) == [
        Event("deleted", "a.txt"),
    ]


def test_modified_then_modified():
    assert collapse_events([
        Event("modified", "a.txt"),
        Event("modified", "a.txt"),
    ]) == [
        Event("modified", "a.txt"),
    ]


def test_created_modified_deleted():
    assert collapse_events([
        Event("created", "a.txt"),
        Event("modified", "a.txt"),
        Event("deleted", "a.txt"),
    ]) == []


def test_deleted_created_deleted():
    assert collapse_events([
        Event("deleted", "a.txt"),
        Event("created", "a.txt"),
        Event("deleted", "a.txt"),
    ]) == [
        Event("deleted", "a.txt"),
    ]


def test_created_modified_renamed():
    assert collapse_events([
        Event("created", "a.txt"),
        Event("modified", "a.txt"),
        Event("renamed", "a.txt", "b.txt"),
    ]) == [
        Event("created", "b.txt"),
    ]


def test_modified_renamed_deleted():
    assert collapse_events([
        Event("modified", "a.txt"),
        Event("renamed", "a.txt", "b.txt"),
        Event("deleted", "b.txt"),
    ]) == [
        Event("deleted", "a.txt"),
    ]


def test_rename_chain_two():
    assert collapse_events([
        Event("renamed", "a.txt", "b.txt"),
        Event("renamed", "b.txt", "c.txt"),
    ]) == [
        Event("renamed", "a.txt", "c.txt"),
    ]


def test_rename_chain_three():
    assert collapse_events([
        Event("renamed", "a.txt", "b.txt"),
        Event("renamed", "b.txt", "c.txt"),
        Event("renamed", "c.txt", "d.txt"),
    ]) == [
        Event("renamed", "a.txt", "d.txt"),
    ]


def test_rename_back_to_original():
    assert collapse_events([
        Event("renamed", "a.txt", "b.txt"),
        Event("renamed", "b.txt", "a.txt"),
    ]) == []


def test_rename_cycle_three():
    assert collapse_events([
        Event("renamed", "a.txt", "b.txt"),
        Event("renamed", "b.txt", "c.txt"),
        Event("renamed", "c.txt", "a.txt"),
    ]) == []


def test_three_way_cycle_simultaneous():
    assert collapse_events([
        Event("renamed", "a.txt", "b.txt"),
        Event("renamed", "b.txt", "c.txt"),
        Event("renamed", "c.txt", "a.txt"),
    ]) == []


def test_created_then_renamed():
    assert collapse_events([
        Event("created", "a.txt"),
        Event("renamed", "a.txt", "b.txt"),
    ]) == [
        Event("created", "b.txt"),
    ]


def test_modified_then_renamed():
    assert collapse_events([
        Event("modified", "a.txt"),
        Event("renamed", "a.txt", "b.txt"),
    ]) == [
        Event("renamed", "a.txt", "b.txt"),
    ]


def test_modified_modified_then_renamed():
    assert collapse_events([
        Event("modified", "a.txt"),
        Event("modified", "a.txt"),
        Event("renamed", "a.txt", "b.txt"),
    ]) == [
        Event("renamed", "a.txt", "b.txt"),
    ]


def test_renamed_then_deleted():
    assert collapse_events([
        Event("renamed", "a.txt", "b.txt"),
        Event("deleted", "b.txt"),
    ]) == [
        Event("deleted", "a.txt"),
    ]


def test_renamed_then_modified():
    assert collapse_events([
        Event("renamed", "a.txt", "b.txt"),
        Event("modified", "b.txt"),
    ]) == [
        Event("renamed", "a.txt", "b.txt"),
    ]


def test_renamed_then_created_at_source():
    assert collapse_events([
        Event("renamed", "a.txt", "b.txt"),
        Event("created", "a.txt"),
    ]) == [
        Event("renamed", "a.txt", "b.txt"),
        Event("created", "a.txt"),
    ]


def test_renamed_then_modified_at_source():
    assert collapse_events([
        Event("renamed", "a.txt", "b.txt"),
        Event("modified", "a.txt"),
    ]) == [
        Event("renamed", "a.txt", "b.txt"),
    ]


def test_renamed_then_deleted_at_source():
    assert collapse_events([
        Event("renamed", "a.txt", "b.txt"),
        Event("deleted", "a.txt"),
    ]) == [
        Event("renamed", "a.txt", "b.txt"),
    ]


def test_two_creates():
    assert collapse_events([
        Event("created", "a.txt"),
        Event("created", "b.txt"),
    ]) == [
        Event("created", "a.txt"),
        Event("created", "b.txt"),
    ]


def test_modified_and_deleted():
    assert collapse_events([
        Event("modified", "a.txt"),
        Event("deleted", "b.txt"),
    ]) == [
        Event("modified", "a.txt"),
        Event("deleted", "b.txt"),
    ]


def test_renamed_and_created():
    assert collapse_events([
        Event("renamed", "a.txt", "b.txt"),
        Event("created", "c.txt"),
    ]) == [
        Event("renamed", "a.txt", "b.txt"),
        Event("created", "c.txt"),
    ]


def test_deleted_then_renamed_to_same():
    assert collapse_events([
        Event("deleted", "b.txt"),
        Event("renamed", "a.txt", "b.txt"),
    ]) == [
        Event("modified", "b.txt"),
    ]


def test_created_then_renamed_to_same():
    assert collapse_events([
        Event("created", "b.txt"),
        Event("renamed", "a.txt", "b.txt"),
    ]) == [
        Event("renamed", "a.txt", "b.txt"),
    ]


def test_modified_then_renamed_to_same():
    assert collapse_events([
        Event("modified", "b.txt"),
        Event("renamed", "a.txt", "b.txt"),
    ]) == [
        Event("deleted", "a.txt"),
        Event("modified", "b.txt"),
    ]


def test_three_way_swap():
    assert collapse_events([
        Event("renamed", "a.txt", "tmp.txt"),
        Event("renamed", "b.txt", "a.txt"),
        Event("renamed", "tmp.txt", "b.txt"),
    ]) == [
        Event("renamed", "a.txt", "b.txt"),
        Event("renamed", "b.txt", "a.txt"),
    ]


def test_atomic_replace_with_tmp_in_name():
    assert collapse_events([
        Event("deleted", "a.txt"),
        Event("renamed", "tmp.txt", "a.txt"),
    ]) == [
        Event("modified", "a.txt"),
    ]


def test_atomic_replace_with_swp_extension():
    assert collapse_events([
        Event("deleted", "a.txt"),
        Event("renamed", "a.txt.swp", "a.txt"),
    ]) == [
        Event("modified", "a.txt"),
    ]


def test_atomic_replace_with_backup_name():
    assert collapse_events([
        Event("deleted", "a.txt"),
        Event("renamed", "backup.txt", "a.txt"),
    ]) == [
        Event("modified", "a.txt"),
    ]


def test_atomic_replace_with_tilde_suffix():
    assert collapse_events([
        Event("deleted", "a.txt"),
        Event("renamed", "a.txt~", "a.txt"),
    ]) == [
        Event("modified", "a.txt"),
    ]


def test_atomic_replace_with_hash_prefix():
    assert collapse_events([
        Event("deleted", "a.txt"),
        Event("renamed", ".#a.txt", "a.txt"),
    ]) == [
        Event("modified", "a.txt"),
    ]


def test_atomic_replace_unrelated_filenames():
    assert collapse_events([
        Event("deleted", "config.json"),
        Event("renamed", "data.json", "config.json"),
    ]) == [
        Event("modified", "config.json"),
    ]
