import filecmp
import fnmatch
import os
import shutil
import signal
import stat
import threading
import time
from pathlib import Path
from types import FrameType

from watchdog.events import FileSystemEvent, FileSystemEventHandler
from watchdog.observers import Observer

from bolthole.debounce import Event, collapse_events
from bolthole.git import GitRepo, output


def should_ignore(rel_path: str, patterns: list[str]) -> bool:
    parts = Path(rel_path).parts
    for pattern in patterns:
        if fnmatch.fnmatch(rel_path, pattern):
            return True
        for part in parts:
            if fnmatch.fnmatch(part, pattern):
                return True
    return False


def report_event(event: Event):
    if event.type == "renamed":
        output(f'   "{event.path}" renamed "{event.new_path}"')
    elif event.type == "modified":
        output(f'   "{event.path}" updated')
    else:
        output(f'   "{event.path}" {event.type}')


def report_action(event: Event):
    if event.type == "renamed":
        output(f'++ "{event.path}" -> "{event.new_path}"')
    elif event.type == "deleted":
        output(f'-- "{event.path}"')
    else:
        output(f'++ "{event.path}"')


def list_files(
    directory: Path,
    ignore_patterns: list[str],
) -> set[str]:
    files = set()
    for path in directory.rglob("*"):
        if path.is_file():
            rel = str(path.relative_to(directory))
            if not should_ignore(rel, ignore_patterns):
                files.add(rel)
    return files


def remove_empty_parents(
    path: Path,
    root: Path,
):
    parent = path.parent
    while parent != root:
        if not any(parent.iterdir()):
            parent.rmdir()
            parent = parent.parent
        else:
            break


def apply_event(
    event: Event,
    source: Path,
    dest: Path,
    dry_run: bool = False,
    verbose: bool = False,
):
    if verbose:
        report_event(event)
    report_action(event)

    if dry_run:
        if event.type in ("created", "modified"):
            output(f'#  copy "{event.path}"')
        elif event.type == "deleted":
            output(f'#  delete "{event.path}"')
        elif event.type == "renamed":
            output(f'#  rename "{event.path}" to "{event.new_path}"')
        return

    if event.type in ("created", "modified"):
        src = source / event.path
        dst = dest / event.path
        dst.parent.mkdir(parents=True, exist_ok=True)
        if dst.exists() and not os.access(dst, os.W_OK):
            os.chmod(dst, stat.S_IWUSR | stat.S_IRUSR)
        shutil.copy2(src, dst)
    elif event.type == "deleted":
        dst = dest / event.path
        dst.unlink(missing_ok=True)
        remove_empty_parents(dst, dest)
    elif event.type == "renamed":
        old_dst = dest / event.path
        new_dst = dest / event.new_path
        old_dst.unlink(missing_ok=True)
        remove_empty_parents(old_dst, dest)
        new_dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source / event.new_path, new_dst)


def initial_sync(
    source: Path,
    dest: Path,
    ignore_patterns: list[str],
    dry_run: bool = False,
    show_git: bool = False,
    author: str | None = None,
    message: str | None = None,
    remotes: list[str] = [],
):
    if not dry_run:
        dest.mkdir(parents=True, exist_ok=True)

    source_files = list_files(source, ignore_patterns)
    if dest.exists():
        dest_files = list_files(dest, ignore_patterns)
    else:
        dest_files = set()

    events = []
    for rel_path in sorted(source_files):
        if rel_path not in dest_files:
            events.append(Event("created", rel_path))
        elif not filecmp.cmp(source / rel_path, dest / rel_path, shallow=False):
            events.append(Event("modified", rel_path))

    for rel_path in sorted(dest_files - source_files):
        events.append(Event("deleted", rel_path))

    for event in events:
        apply_event(event, source, dest, dry_run=dry_run, verbose=False)

    repo = GitRepo(
        dest,
        dry_run=dry_run,
        show_git=show_git,
        author=author,
        message=message,
    )
    committed = False
    if dry_run:
        if events:
            repo.commit_changes(events)
            committed = True
    else:
        uncommitted = repo.get_uncommitted()
        if uncommitted:
            repo.commit_changes(uncommitted)
            committed = True

    if remotes and committed:
        repo.push(remotes)


class DebouncingEventHandler(FileSystemEventHandler):
    def __init__(
        self,
        base_path: Path,
        ignore_patterns: list[str],
        dest_path: Path | None = None,
        debounce_delay: float = 0.1,
        dry_run: bool = False,
        verbose: bool = False,
        watchdog_debug: bool = False,
        show_git: bool = False,
        author: str | None = None,
        message: str | None = None,
        remotes: list[str] = [],
        grace: float = 0,
        bundle: float = 0,
    ):
        super().__init__()
        self.base_path = base_path
        self.dest_path = dest_path
        self.debounce_delay = debounce_delay
        self.dry_run = dry_run
        self.verbose = verbose
        self.watchdog_debug = watchdog_debug
        self.show_git = show_git
        self.author = author
        self.message = message
        self.remotes = remotes
        self.ignore_patterns = ignore_patterns
        self.grace = grace
        self.bundle = bundle
        self.pending_events: list[Event] = []
        self.lock = threading.Lock()
        self.timer: threading.Timer | None = None
        self.known_files = list_files(self.base_path, self.ignore_patterns)
        self.grace_events: dict[str, Event] = {}
        self.grace_timers: dict[str, threading.Timer] = {}
        self.grace_timestamps: dict[str, float] = {}
        self.commit_lock = threading.Lock()

    def relative_path(
        self,
        path: str,
    ) -> str:
        return str(Path(path).relative_to(self.base_path))

    def log_debug(
        self,
        event: Event,
    ):
        if not self.watchdog_debug:
            return
        if event.type == "renamed":
            output(f"watchdog: {event.type} {event.path} {event.new_path}")
        else:
            output(f"watchdog: {event.type} {event.path}")

    def queue_event(
        self,
        event: Event,
    ):
        self.log_debug(event)
        with self.lock:
            self.pending_events.append(event)
            if self.timer:
                self.timer.cancel()
            self.timer = threading.Timer(self.debounce_delay, self.flush_events)
            self.timer.start()

    def flush_events(
        self,
    ):
        with self.lock:
            if not self.pending_events:
                return
            events = self.pending_events[:]
            self.pending_events = []

        collapsed = collapse_events(events)
        for event in collapsed:
            if self.dest_path:
                apply_event(
                    event, self.base_path, self.dest_path,
                    dry_run=self.dry_run,
                    verbose=self.verbose,
                )
            elif self.verbose:
                report_event(event)

        if not collapsed:
            return

        if self.grace > 0:
            self.schedule_grace_commits(collapsed)
        else:
            if self.dest_path:
                repo_path = self.dest_path
            else:
                repo_path = self.base_path
            repo = GitRepo(
                repo_path,
                dry_run=self.dry_run,
                show_git=self.show_git,
                author=self.author,
                message=self.message,
            )
            repo.commit_changes(collapsed)
            if self.remotes:
                repo.push(self.remotes)

    def schedule_grace_commits(
        self,
        events: list[Event],
    ):
        now = time.time()
        with self.lock:
            for event in events:
                if event.type == "renamed":
                    path = event.new_path
                    old_path = event.path
                else:
                    path = event.path
                    old_path = None

                if old_path and old_path in self.grace_timers:
                    self.grace_timers[old_path].cancel()
                    del self.grace_timers[old_path]
                    old_event = self.grace_events.pop(old_path, None)
                    del self.grace_timestamps[old_path]
                    if old_event and old_event.type == "created":
                        # create + rename = create with new name
                        event = Event("created", path)

                if path in self.grace_timers:
                    self.grace_timers[path].cancel()
                    del self.grace_timers[path]
                    old_event = self.grace_events.get(path)
                    if old_event:
                        if old_event.type == "created" and event.type == "deleted":
                            # create + delete = nothing
                            del self.grace_events[path]
                            del self.grace_timestamps[path]
                            continue
                        elif old_event.type == "created":
                            # create + anything else = still created
                            event = Event("created", path)
                        elif old_event.type == "deleted" and event.type == "created":
                            # delete + create = modified
                            event = Event("modified", path)

                self.grace_events[path] = event
                self.grace_timestamps[path] = now
                timer = threading.Timer(
                    self.grace,
                    self.commit_after_grace,
                    args=[path],
                )
                self.grace_timers[path] = timer
                timer.start()

    def commit_after_grace(
        self,
        path: str,
    ):
        if self.bundle > 0:
            self.commit_bundled_files()
            return

        with self.lock:
            if path not in self.grace_events:
                return
            event = self.grace_events.pop(path)
            del self.grace_timers[path]
            del self.grace_timestamps[path]

        with self.commit_lock:
            if self.dest_path:
                repo_path = self.dest_path
            else:
                repo_path = self.base_path
            repo = GitRepo(
                repo_path,
                dry_run=self.dry_run,
                show_git=self.show_git,
                author=self.author,
                message=self.message,
            )
            repo.commit_changes([event])
            if self.remotes:
                repo.push(self.remotes)

    def commit_bundled_files(self):
        now = time.time()
        with self.lock:
            events_to_commit = []
            paths_to_remove = []
            for path, timestamp in self.grace_timestamps.items():
                age = now - timestamp
                if age >= self.bundle:
                    events_to_commit.append(self.grace_events[path])
                    paths_to_remove.append(path)

            for path in paths_to_remove:
                del self.grace_events[path]
                del self.grace_timestamps[path]
                if path in self.grace_timers:
                    del self.grace_timers[path]

        if not events_to_commit:
            return

        with self.commit_lock:
            if self.dest_path:
                repo_path = self.dest_path
            else:
                repo_path = self.base_path
            repo = GitRepo(
                repo_path,
                dry_run=self.dry_run,
                show_git=self.show_git,
                author=self.author,
                message=self.message,
            )
            repo.commit_changes(events_to_commit)
            if self.remotes:
                repo.push(self.remotes)

    def on_created(
        self,
        event: FileSystemEvent,
    ):
        if event.is_directory:
            return
        path = self.relative_path(event.src_path)
        if should_ignore(path, self.ignore_patterns):
            return
        if path in self.known_files:
            self.queue_event(Event("modified", path))
        else:
            self.known_files.add(path)
            self.queue_event(Event("created", path))

    def on_modified(
        self,
        event: FileSystemEvent,
    ):
        if event.is_directory:
            return
        path = self.relative_path(event.src_path)
        if should_ignore(path, self.ignore_patterns):
            return
        self.queue_event(Event("modified", path))

    def on_deleted(
        self,
        event: FileSystemEvent,
    ):
        if event.is_directory:
            return
        path = self.relative_path(event.src_path)
        if should_ignore(path, self.ignore_patterns):
            return
        self.known_files.discard(path)
        self.queue_event(Event("deleted", path))

    def on_moved(
        self,
        event: FileSystemEvent,
    ):
        if event.is_directory:
            return
        src_path = self.relative_path(event.src_path)
        dst_path = self.relative_path(event.dest_path)
        src_ignored = should_ignore(src_path, self.ignore_patterns)
        dst_ignored = should_ignore(dst_path, self.ignore_patterns)

        if src_ignored and dst_ignored:
            return
        elif src_ignored:
            self.known_files.add(dst_path)
            self.queue_event(Event("created", dst_path))
        elif dst_ignored:
            self.known_files.discard(src_path)
            self.queue_event(Event("deleted", src_path))
        else:
            self.known_files.discard(src_path)
            self.known_files.add(dst_path)
            self.queue_event(Event("renamed", src_path, dst_path))


def watch(
    source: Path,
    dest: Path | None = None,
    dry_run: bool = False,
    verbose: bool = False,
    watchdog_debug: bool = False,
    ignore_patterns: list[str] = [],
    show_git: bool = False,
    source_label: str | None = None,
    dest_label: str | None = None,
    once: bool = False,
    author: str | None = None,
    message: str | None = None,
    remotes: list[str] = [],
    grace: float = 0,
    bundle: float = 0,
):
    ignore_patterns = [".git", ".gitignore"] + ignore_patterns

    if dest:
        initial_sync(
            source, dest,
            dry_run=dry_run,
            ignore_patterns=ignore_patterns,
            show_git=show_git,
            author=author,
            message=message,
            remotes=remotes,
        )
    else:
        repo = GitRepo(
            source,
            dry_run=dry_run,
            show_git=show_git,
            author=author,
            message=message,
        )
        events = repo.get_uncommitted()
        if events:
            repo.commit_changes(events)
            if remotes:
                repo.push(remotes)

    if once:
        return

    handler = DebouncingEventHandler(
        source,
        dest_path=dest,
        dry_run=dry_run,
        verbose=verbose,
        watchdog_debug=watchdog_debug,
        ignore_patterns=ignore_patterns,
        show_git=show_git,
        author=author,
        message=message,
        remotes=remotes,
        grace=grace,
        bundle=bundle,
    )
    observer = Observer()
    observer.schedule(handler, str(source), recursive=True)

    def sigterm_handler(
        signum: int,
        frame: FrameType | None,
    ):
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, sigterm_handler)

    observer.start()

    if dest_label:
        output(f"   Copying {source_label} to {dest_label}...")
    else:
        output(f"   Watching {source_label}...")

    try:
        while True:
            observer.join(timeout=1)
            if not observer.is_alive():
                break
    except KeyboardInterrupt:
        pass
    finally:
        observer.stop()
        observer.join()
        handler.flush_events()
