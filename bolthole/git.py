import subprocess
from pathlib import Path

from bolthole.debounce import Event


class GitRepo:
    SUBJECT_LINE_LIMIT = 50

    def __init__(self, path):
        self.path = Path(path)

    def run_git(self, *args, **kwargs):
        return subprocess.run(["git", "-C", str(self.path), *args], **kwargs)

    @staticmethod
    def is_repo(path):
        result = subprocess.run(
            ["git", "-C", str(path), "rev-parse", "--git-dir"],
            capture_output=True,
        )
        return result.returncode == 0

    def init(self):
        self.run_git("init", "--quiet", check=True)

    def add_all(self):
        self.run_git("add", "-A", check=True)

    def has_staged_changes(self):
        result = self.run_git("diff", "--cached", "--quiet", capture_output=True)
        return result.returncode != 0

    def commit(self, message):
        if not self.has_staged_changes():
            return
        self.run_git(
            "commit", "-m", message, "--no-verify", "--no-gpg-sign", "--quiet",
            check=True,
        )

    def get_uncommitted(self):
        result = self.run_git(
            "status", "--porcelain",
            capture_output=True, text=True, check=True,
        )
        events = []
        for line in result.stdout.splitlines():
            if not line:
                continue
            status = line[:2]
            path = line[3:]
            if status == "??":
                events.append(Event("created", path))
            elif "D" in status:
                events.append(Event("deleted", path))
            elif "M" in status or "A" in status:
                events.append(Event("modified", path))
        return events

    def commit_changes(self, events):
        if not events:
            return
        message = self.generate_commit_message(events)
        self.add_all()
        self.commit(message)

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
