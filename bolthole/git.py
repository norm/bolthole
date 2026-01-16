import subprocess
from pathlib import Path


class GitRepo:
    def __init__(self, path):
        self.path = Path(path)

    @staticmethod
    def is_repo(path):
        result = subprocess.run(
            ["git", "-C", str(path), "rev-parse", "--git-dir"],
            capture_output=True,
        )
        return result.returncode == 0

    def init(self):
        subprocess.run(
            ["git", "-C", str(self.path), "init", "--quiet"],
            check=True,
        )
