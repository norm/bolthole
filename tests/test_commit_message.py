from textwrap import dedent

from bolthole.debounce import Event
from bolthole.git import GitRepo


class TestEmpty:
    def test_empty_returns_empty_string(self):
        assert GitRepo.generate_commit_message([]) == ""


class TestAdd:
    def test_one_add(self):
        assert GitRepo.generate_commit_message([
            Event("created", "café.txt"),
        ]) == "Add café.txt"

    def test_two_adds(self):
        assert GitRepo.generate_commit_message([
            Event("created", "one.txt"),
            Event("created", "two.txt"),
        ]) == "Add one.txt and two.txt"

    def test_three_adds(self):
        assert GitRepo.generate_commit_message([
            Event("created", "one.txt"),
            Event("created", "three.txt"),
            Event("created", "two.txt"),
        ]) == "Add one.txt, three.txt, and two.txt"

    def test_long_filename(self):
        assert GitRepo.generate_commit_message([
            Event("created", "project/alpha/components/widgets/buttons/file.txt"),
        ]) == dedent("""
            Add 1 file

            - Add project/alpha/components/widgets/buttons/file.txt
        """).strip()

    def test_two_long_filenames(self):
        assert GitRepo.generate_commit_message([
            Event("created", "project/alpha/components/widgets/button.txt"),
            Event("created", "project/alpha/components/widgets/input.txt"),
        ]) == dedent("""
            Add 2 files

            - Add project/alpha/components/widgets/button.txt
            - Add project/alpha/components/widgets/input.txt
        """).strip()

    def test_short_and_long_filename(self):
        assert GitRepo.generate_commit_message([
            Event("created", "file.txt"),
            Event("created", "project/alpha/components/widgets/button.txt"),
        ]) == dedent("""
            Add 2 files

            - Add file.txt
            - Add project/alpha/components/widgets/button.txt
        """).strip()


class TestUpdate:
    def test_one_update(self):
        assert GitRepo.generate_commit_message([
            Event("modified", "file.txt"),
        ]) == "Update file.txt"

    def test_two_updates(self):
        assert GitRepo.generate_commit_message([
            Event("modified", "my file.txt"),
            Event("modified", "your file.txt"),
        ]) == "Update my file.txt and your file.txt"

    def test_three_updates(self):
        assert GitRepo.generate_commit_message([
            Event("modified", "one.txt"),
            Event("modified", "three.txt"),
            Event("modified", "two.txt"),
        ]) == "Update one.txt, three.txt, and two.txt"


class TestRemove:
    def test_one_remove(self):
        assert GitRepo.generate_commit_message([
            Event("deleted", "file.txt"),
        ]) == "Remove file.txt"

    def test_two_removes(self):
        assert GitRepo.generate_commit_message([
            Event("deleted", "one.txt"),
            Event("deleted", "two.txt"),
        ]) == "Remove one.txt and two.txt"

    def test_three_removes(self):
        assert GitRepo.generate_commit_message([
            Event("deleted", "one.txt"),
            Event("deleted", "three.txt"),
            Event("deleted", "two.txt"),
        ]) == "Remove one.txt, three.txt, and two.txt"


class TestRename:
    def test_one_rename(self):
        assert GitRepo.generate_commit_message([
            Event("renamed", "naïve.txt", "naïveté.txt"),
        ]) == "Rename naïve.txt to naïveté.txt"

    def test_two_renames(self):
        assert GitRepo.generate_commit_message([
            Event("renamed", "old1.txt", "new1.txt"),
            Event("renamed", "old2.txt", "new2.txt"),
        ]) == dedent("""
            Rename 2 files

            - Rename old1.txt to new1.txt
            - Rename old2.txt to new2.txt
        """).strip()

    def test_three_renames(self):
        assert GitRepo.generate_commit_message([
            Event("renamed", "old1.txt", "new1.txt"),
            Event("renamed", "old2.txt", "new2.txt"),
            Event("renamed", "old3.txt", "new3.txt"),
        ]) == dedent("""
            Rename 3 files

            - Rename old1.txt to new1.txt
            - Rename old2.txt to new2.txt
            - Rename old3.txt to new3.txt
        """).strip()

    def test_long_rename(self):
        assert GitRepo.generate_commit_message([
            Event("renamed", "project/old/path/file.txt", "project/new/path/file.txt"),
        ]) == dedent("""
            Rename 1 file

            - Rename project/old/path/file.txt to project/new/path/file.txt
        """).strip()


class TestCombinations:
    def test_one_of_each(self):
        assert GitRepo.generate_commit_message([
            Event("renamed", "old.txt", "new.txt"),
            Event("created", "added.txt"),
            Event("deleted", "removed.txt"),
            Event("modified", "updated.txt"),
        ]) == dedent("""
            Change 4 files

            - Add added.txt
            - Rename old.txt to new.txt
            - Remove removed.txt
            - Update updated.txt
        """).strip()

    def test_two_of_each(self):
        assert GitRepo.generate_commit_message([
            Event("renamed", "charlie.txt", "tango.txt"),
            Event("renamed", "golf.txt", "whiskey.txt"),
            Event("created", "alpha.txt"),
            Event("created", "echo.txt"),
            Event("deleted", "bravo.txt"),
            Event("deleted", "foxtrot.txt"),
            Event("modified", "delta.txt"),
            Event("modified", "hotel.txt"),
        ]) == dedent("""
            Change 8 files

            - Add alpha.txt
            - Remove bravo.txt
            - Rename charlie.txt to tango.txt
            - Update delta.txt
            - Add echo.txt
            - Remove foxtrot.txt
            - Rename golf.txt to whiskey.txt
            - Update hotel.txt
        """).strip()

    def test_add_and_update_short(self):
        assert GitRepo.generate_commit_message([
            Event("created", "added.txt"),
            Event("modified", "updated.txt"),
        ]) == "Add added.txt, update updated.txt"

    def test_rename_and_remove_short(self):
        assert GitRepo.generate_commit_message([
            Event("renamed", "old.txt", "new.txt"),
            Event("deleted", "gone.txt"),
        ]) == "Remove gone.txt, rename old.txt to new.txt"

    def test_long_filenames_mixed(self):
        assert GitRepo.generate_commit_message([
            Event("created", "project/source/components/button.tsx"),
            Event("modified", "project/source/components/input.tsx"),
        ]) == dedent("""
            Change 2 files

            - Add project/source/components/button.tsx
            - Update project/source/components/input.tsx
        """).strip()
