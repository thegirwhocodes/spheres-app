#!/usr/bin/env python3
"""
Auto-deploy Spheres app to GitHub.

Usage:
  python3 auto_deploy.py                          # Emergency auto-save (context compaction)
  python3 auto_deploy.py "feat: add Gmail OAuth"  # Deploy with descriptive message
"""

import subprocess
import sys
from datetime import datetime


REPO_DIR = "/Users/naomiivie/Downloads/App/Spheres Mac - Version 1.0 Dec 2025"


def run(cmd, check=True):
    """Run a shell command and return output."""
    result = subprocess.run(
        cmd, shell=True, cwd=REPO_DIR,
        capture_output=True, text=True
    )
    if check and result.returncode != 0:
        print(f"Error: {result.stderr.strip()}", file=sys.stderr)
        return None
    return result.stdout.strip()


def main():
    # Check if there are any changes to commit
    status = run("git status --porcelain")
    if not status:
        print("No changes to deploy.", file=sys.stderr)
        return

    # Stage all tracked + new files (respects .gitignore)
    run("git add -A")

    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    changed_files = run("git diff --cached --name-only")
    file_count = len(changed_files.splitlines()) if changed_files else 0

    # Use provided message or fall back to auto-save
    if len(sys.argv) > 1:
        custom_msg = sys.argv[1]
        message = f"{custom_msg}\n\nDeployed: {timestamp} ({file_count} files)"
    else:
        message = (
            f"Auto-save: {timestamp} ({file_count} files)\n\n"
            f"Session snapshot before context compaction."
        )

    # Commit
    result = subprocess.run(
        ["git", "commit", "-m", message],
        cwd=REPO_DIR, capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"Commit failed: {result.stderr.strip()}", file=sys.stderr)
        return

    # Push to origin
    push_result = run("git push origin main")
    if push_result is not None:
        print(f"Deployed {file_count} files to GitHub at {timestamp}", file=sys.stderr)
    else:
        print("Push failed - will retry next session.", file=sys.stderr)


if __name__ == "__main__":
    main()
