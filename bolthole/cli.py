import argparse
from importlib.metadata import version


def main():
    parser = argparse.ArgumentParser(prog="bolthole")
    parser.add_argument(
        "--version",
        action="version",
        version=f"%(prog)s version v{version('bolthole')}",
    )
    parser.parse_args()
