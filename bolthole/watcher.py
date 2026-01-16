import filecmp
import os
import shutil
import signal
import stat
import threading
from datetime import datetime
from pathlib import Path
from types import FrameType

from watchdog.events import FileSystemEvent, FileSystemEventHandler
from watchdog.observers import Observer

from bolthole.debounce import Event, collapse_events


def format_timestamp(timeless: bool) -> str:
    if timeless:
        return ""
    return datetime.now().strftime("%H:%M:%S ")


def report_event(event: Event, timeless: bool):
    ts = format_timestamp(timeless)
    if event.type == "renamed":
        print(f'{ts}   "{event.path}" renamed "{event.new_path}"', flush=True)
    elif event.type == "modified":
        print(f'{ts}   "{event.path}" updated', flush=True)
    else:
        print(f'{ts}   "{event.path}" {event.type}', flush=True)


def report_action(event: Event, timeless: bool):
    ts = format_timestamp(timeless)
    if event.type == "renamed":
        print(f'{ts}++ "{event.path}" -> "{event.new_path}"', flush=True)
    elif event.type == "deleted":
        print(f'{ts}-- "{event.path}"', flush=True)
    else:
        print(f'{ts}++ "{event.path}"', flush=True)


def list_files(
    directory: Path,
) -> set[str]:
    files = set()
    for path in directory.rglob("*"):
        if path.is_file():
            rel = str(path.relative_to(directory))
            if not rel.startswith(".git/") and rel != ".git":
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
    timeless: bool = False,
):
    if verbose:
        report_event(event, timeless)
    report_action(event, timeless)

    if dry_run:
        if event.type in ("created", "modified"):
            print(f'#  copy "{event.path}"', flush=True)
        elif event.type == "deleted":
            print(f'#  delete "{event.path}"', flush=True)
        elif event.type == "renamed":
            print(f'#  rename "{event.path}" to "{event.new_path}"', flush=True)
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
    dry_run: bool = False,
    timeless: bool = False,
):
    if not dry_run:
        dest.mkdir(parents=True, exist_ok=True)

    source_files = list_files(source)
    dest_files = list_files(dest) if dest.exists() else set()

    events = []
    for rel_path in sorted(source_files):
        if rel_path not in dest_files:
            events.append(Event("created", rel_path))
        elif not filecmp.cmp(source / rel_path, dest / rel_path, shallow=False):
            events.append(Event("modified", rel_path))

    for rel_path in sorted(dest_files - source_files):
        events.append(Event("deleted", rel_path))

    for event in events:
        apply_event(
            event, source, dest,
            dry_run=dry_run, verbose=False, timeless=timeless,
        )


class DebouncingEventHandler(FileSystemEventHandler):
    def __init__(
        self,
        base_path: Path,
        dest_path: Path | None = None,
        debounce_delay: float = 0.33,
        dry_run: bool = False,
        verbose: bool = False,
        timeless: bool = False,
        watchdog_debug: bool = False,
    ):
        super().__init__()
        self.base_path = base_path.resolve()
        self.dest_path = dest_path.resolve() if dest_path else None
        self.debounce_delay = debounce_delay
        self.dry_run = dry_run
        self.verbose = verbose
        self.timeless = timeless
        self.watchdog_debug = watchdog_debug
        self.pending_events: list[Event] = []
        self.lock = threading.Lock()
        self.timer: threading.Timer | None = None
        self.known_files = list_files(self.base_path)

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
            print(
                f"watchdog: {event.type} {event.path} {event.new_path}",
                flush=True,
            )
        else:
            print(f"watchdog: {event.type} {event.path}", flush=True)

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
                    timeless=self.timeless,
                )
            elif self.verbose:
                report_event(event, self.timeless)

    def on_created(
        self,
        event: FileSystemEvent,
    ):
        if event.is_directory:
            return
        path = self.relative_path(event.src_path)
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
        self.queue_event(Event("modified", path))

    def on_deleted(
        self,
        event: FileSystemEvent,
    ):
        if event.is_directory:
            return
        path = self.relative_path(event.src_path)
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
        self.known_files.discard(src_path)
        self.known_files.add(dst_path)
        self.queue_event(Event("renamed", src_path, dst_path))


def watch(
    source: Path,
    dest: Path | None = None,
    dry_run: bool = False,
    verbose: bool = False,
    timeless: bool = False,
    watchdog_debug: bool = False,
):
    if dest:
        initial_sync(source, dest, dry_run=dry_run, timeless=timeless)

    handler = DebouncingEventHandler(
        source,
        dest_path=dest,
        dry_run=dry_run,
        verbose=verbose,
        timeless=timeless,
        watchdog_debug=watchdog_debug,
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
