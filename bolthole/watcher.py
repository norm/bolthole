import signal
import threading
from pathlib import Path
from types import FrameType

from watchdog.events import FileSystemEvent, FileSystemEventHandler
from watchdog.observers import Observer

from bolthole.debounce import Event, collapse_events


class DebouncingEventHandler(FileSystemEventHandler):
    def __init__(
        self,
        base_path: Path,
        debounce_delay: float = 0.33,
        watchdog_debug: bool = False,
    ):
        super().__init__()
        self.base_path = base_path.resolve()
        self.debounce_delay = debounce_delay
        self.watchdog_debug = watchdog_debug
        self.pending_events: list[Event] = []
        self.lock = threading.Lock()
        self.timer: threading.Timer | None = None

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
            if event.type == "renamed":
                print(f"renamed {event.path} {event.new_path}", flush=True)
            else:
                print(f"{event.type} {event.path}", flush=True)

    def on_created(
        self,
        event: FileSystemEvent,
    ):
        if event.is_directory:
            return
        path = self.relative_path(event.src_path)
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
        self.queue_event(Event("deleted", path))

    def on_moved(
        self,
        event: FileSystemEvent,
    ):
        if event.is_directory:
            return
        src_path = self.relative_path(event.src_path)
        dst_path = self.relative_path(event.dest_path)
        self.queue_event(Event("renamed", src_path, dst_path))


def watch(
    source: Path,
    watchdog_debug: bool = False,
):
    handler = DebouncingEventHandler(source, watchdog_debug=watchdog_debug)
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
