import shlex
import subprocess
from datetime import datetime
from pathlib import Path

from bolthole.debounce import Event


_timeless = False


def configure_output(timeless: bool):
    global _timeless
    _timeless = timeless


def output(message: str):
    if _timeless:
        print(message, flush=True)
    else:
        ts = datetime.now().strftime("%H:%M:%S ")
        print(f"{ts}{message}", flush=True)


class GitRepo:
    SUBJECT_LINE_LIMIT = 50

    def __init__(
        self,
        path,
        dry_run=False,
        show_git=False,
        author=None,
        message=None,
    ):
        self.path = Path(path)
        self.dry_run = dry_run
        self.show_git = show_git
        self.author = author
        self.message = message

    EXCLUDE_FLAGS = {
        "--no-verify",
        "--no-gpg-sign",
        "--quiet",
    }
    EXCLUDE_OPTIONS = {
        "-m",
        "-C",
    }
    EXCLUDE_COMMANDS = {
        "diff",
        "status",
    }
    DRY_RUN_ALLOWED = {
        "diff",
        "status",
    }

    def run_git(self, *args, **kwargs):
        if args:
            command = args[0]
        else:
            command = None
        display_parts = ["git"]
        skip_next = False
        for arg in args:
            if skip_next:
                skip_next = False
                continue
            if arg in self.EXCLUDE_FLAGS:
                continue
            if arg in self.EXCLUDE_OPTIONS:
                skip_next = True
                continue
            display_parts.append(arg)

        formatted = " ".join(shlex.quote(arg) for arg in display_parts)

        if self.dry_run and command not in self.DRY_RUN_ALLOWED:
            output(f"#  {formatted}")
            return subprocess.CompletedProcess(args=[], returncode=0)

        show_this = self.show_git and command not in self.EXCLUDE_COMMANDS
        if show_this:
            output(f"%  {formatted}")

        result = subprocess.run(["git", "-C", str(self.path), *args], **kwargs)

        return result

    @staticmethod
    def is_repo(path):
        result = subprocess.run(
            ["git", "-C", str(path), "rev-parse", "--git-dir"],
            capture_output=True,
        )
        return result.returncode == 0

    def has_remote(self, name):
        result = subprocess.run(
            ["git", "-C", str(self.path), "remote", "get-url", name],
            capture_output=True,
        )
        return result.returncode == 0

    def push(self, remotes):
        for remote in remotes:
            result = self.run_git("push", remote, "HEAD", capture_output=True)
            if result.returncode != 0:
                output(f"!! push to {remote} failed")

    def init(self):
        self.run_git("init", "--quiet", check=True)

    def add_all(self):
        self.run_git("add", "-A", check=True)

    def get_uncommitted(self):
        result = self.run_git(
            "status", "--porcelain", "-z",
            capture_output=True, text=True, check=True,
        )
        events = []
        for entry in result.stdout.split("\0"):
            if not entry:
                continue
            status = entry[:2]
            path = entry[3:]
            if status == "??":
                events.append(Event("created", path))
            elif "D" in status:
                events.append(Event("deleted", path))
            elif "M" in status or "A" in status:
                events.append(Event("modified", path))
        return events

    def get_staged(self):
        result = self.run_git(
            "diff", "--cached", "--name-status",
            capture_output=True, text=True, check=True,
        )
        events = []
        for line in result.stdout.splitlines():
            parts = line.split("\t")
            status = parts[0]
            path = parts[1]
            if status == "A":
                events.append(Event("created", path))
            elif status == "D":
                events.append(Event("deleted", path))
            elif status == "M":
                events.append(Event("modified", path))
            elif status.startswith("R"):
                new_path = parts[2]
                events.append(Event("renamed", path, new_path))
        return events

    def commit_changes(self, events):
        if not events:
            return
        paths = []
        for event in events:
            paths.append(event.path)
            if event.new_path:
                paths.append(event.new_path)
        self.run_git("add", "--", *paths)
        if self.dry_run:
            if self.message:
                message = self.message
            else:
                message = self.generate_commit_message(events)
        else:
            staged = self.get_staged()
            if not staged:
                return
            if self.message:
                message = self.message
            else:
                message = self.generate_commit_message(staged)
        commit_args = [
            "commit",
            "-m", message,
            "--no-verify",
            "--no-gpg-sign",
            "--quiet",
        ]
        if self.author:
            commit_args.extend(["--author", self.author])
        self.run_git(*commit_args, check=True)

    @staticmethod
    def generate_commit_message(events):
        if not events:
            return ""

        verb_map = {
            "created": "Add",
            "modified": "Update",
            "deleted": "Remove",
            "renamed": "Rename",
        }

        items = []
        for event in events:
            verb = verb_map[event.type]
            if event.type == "renamed":
                line = f"{verb} {event.path} to {event.new_path}"
            else:
                line = f"{verb} {event.path}"
            items.append((event.path, line))

        items.sort(key=lambda x: x[0])
        count = len(events)

        types = set(e.type for e in events)
        if len(types) == 1:
            # only one operation, can simplify subject line
            event_type = next(iter(types))
            verb = verb_map[event_type]

            if event_type == "renamed":
                if count == 1:
                    candidate = items[0][1]
                    if len(candidate) < GitRepo.SUBJECT_LINE_LIMIT:
                        return candidate
            else:
                # oxford comma join filenames
                filenames = [item[0] for item in items]
                if len(filenames) == 1:
                    candidate = f"{verb} {filenames[0]}"
                elif len(filenames) == 2:
                    candidate = f"{verb} {filenames[0]} and {filenames[1]}"
                else:
                    joined = ', '.join(filenames[:-1])
                    candidate = f"{verb} {joined}, and {filenames[-1]}"

                if len(candidate) < GitRepo.SUBJECT_LINE_LIMIT:
                    return candidate

            if count == 1:
                subject = f"{verb} 1 file"
            else:
                subject = f"{verb} {count} files"
        else:
            # multiple operations, try comma-separated
            short_parts = [items[0][1]]
            for item in items[1:]:
                short_parts.append(item[1][0].lower() + item[1][1:])
            candidate = ", ".join(short_parts)
            if len(candidate) < GitRepo.SUBJECT_LINE_LIMIT:
                return candidate

            subject = f"Change {count} files"

        # couldn't fit in the subject line, itemise
        body_lines = [
            f"- {item[1]}"
                for item in items
        ]
        return f"{subject}\n\n" + "\n".join(body_lines)
