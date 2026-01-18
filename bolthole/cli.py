import argparse
import sys
from importlib.metadata import version
from pathlib import Path

from bolthole.git import GitRepo, configure_output
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
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="show file updates as well as actions taken",
    )
    parser.add_argument(
        "--timeless",
        action="store_true",
        help="omit timestamps from output",
    )
    parser.add_argument(
        "--ignore",
        action="append",
        default=[],
        metavar="PATTERN",
        help="ignore files matching pattern (repeatable)",
    )
    parser.add_argument(
        "--show-git",
        action="store_true",
        help="display git commands and their output",
    )
    parser.add_argument(
        "--once",
        action="store_true",
        help="commit and exit without watching for changes",
    )
    parser.add_argument("source")
    parser.add_argument("dest", nargs="?")
    args = parser.parse_args()

    configure_output(args.timeless)

    source = Path(args.source).resolve()
    if not source.exists():
        print(
            f"error: source directory does not exist: {args.source}",
            file=sys.stderr,
        )
        sys.exit(2)

    dest = None
    if not args.dest:
        if not GitRepo.is_repo(source):
            print("error: source must be a git repository in single-directory mode",
                  file=sys.stderr)
            sys.exit(2)
    else:
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

        if GitRepo.is_repo(dest):
            pass
        elif dest.exists() and any(dest.iterdir()):
            print("error: destination exists but is not a git repository",
                  file=sys.stderr)
            sys.exit(2)
        elif not args.dry_run:
            dest.mkdir(parents=True, exist_ok=True)
            repo = GitRepo(dest)
            repo.init()

    watch(
        source,
        dest=dest,
        dry_run=args.dry_run,
        verbose=args.verbose,
        watchdog_debug=args.watchdog_debug,
        ignore_patterns=args.ignore,
        show_git=args.show_git,
        source_label=args.source,
        dest_label=args.dest,
        once=args.once,
    )
