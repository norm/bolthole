import argparse
import sys
from importlib.metadata import version
from pathlib import Path

from bolthole.watcher import watch


def main():
    parser = argparse.ArgumentParser(prog="bolthole")
    parser.add_argument(
        "--version",
        action="version",
        version=f"%(prog)s version v{version('bolthole')}",
    )
    parser.add_argument(
        "--watchdog-debug",
        action="store_true",
        help="show raw filesystem events",
    )
    parser.add_argument(
        "-n",
        "--dry-run",
        action="store_true",
        help="take no actions, but report what would happen",
    )
    parser.add_argument("source")
    parser.add_argument("dest", nargs="?")
    args = parser.parse_args()

    source = Path(args.source).resolve()
    if not source.exists():
        print(
            f"bolthole: error: source directory does not exist: {args.source}",
            file=sys.stderr,
        )
        sys.exit(2)

    dest = None
    if args.dest:
        dest = Path(args.dest).resolve()
        if source == dest:
            print("error: source and destination cannot be the same",
                  file=sys.stderr)
            sys.exit(2)
        if source.is_relative_to(dest):
            print("error: source cannot be inside destination",
                  file=sys.stderr)
            sys.exit(2)
        if dest.is_relative_to(source):
            print("error: destination cannot be inside source",
                  file=sys.stderr)
            sys.exit(2)

    watch(
        source,
        dest=dest,
        dry_run=args.dry_run,
        watchdog_debug=args.watchdog_debug,
    )
