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
    parser.add_argument("--watchdog-debug", action="store_true")
    parser.add_argument("source")
    args = parser.parse_args()

    source = Path(args.source)
    if not source.exists():
        print(
            f"bolthole: error: source directory does not exist: {args.source}",
            file=sys.stderr,
        )
        sys.exit(2)

    watch(source, watchdog_debug=args.watchdog_debug)
