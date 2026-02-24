#!/usr/bin/env python3
"""
Auto-update Spheres app on this Mac.

Checks for code changes, rebuilds, and stages the new app.
Then spawns a detached helper script that quits the old app,
swaps the binary, and relaunches — avoiding crash dialogs.

Usage:
    python3 auto_update.py              # Run once (check + build if needed)
    python3 auto_update.py --daemon     # Run every 2 hours in background
    python3 auto_update.py --interval 1 # Custom interval in hours
    python3 auto_update.py --force      # Force rebuild even if no changes
"""

import subprocess
import sys
import os
import shutil
import time
import argparse
from datetime import datetime
from pathlib import Path


# === Configuration ===
PROJECT_DIR = Path("/Users/naomiivie/Downloads/App/Spheres Mac - Version 1.0 Dec 2025")
PROJECT_FILE = PROJECT_DIR / "Spheres Multiplatform.xcodeproj"
SCHEME = "Spheres Multiplatform"
APP_NAME = "Spheres Multiplatform.app"
INSTALL_DIR = Path("/Applications")
INSTALLED_APP = INSTALL_DIR / APP_NAME
STAGED_APP = PROJECT_DIR / ".staged_app" / APP_NAME
BUILD_DIR = PROJECT_DIR / "build"
LOG_FILE = PROJECT_DIR / "auto_update.log"
LAST_BUILD_HASH_FILE = PROJECT_DIR / ".last_build_hash"
SWAP_SCRIPT = PROJECT_DIR / ".swap_and_relaunch.sh"


def log(msg):
    """Log with timestamp to both stdout and log file."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{timestamp}] {msg}"
    print(line)
    with open(LOG_FILE, "a") as f:
        f.write(line + "\n")


def run(cmd, timeout=600):
    """Run a command and return (success, stdout, stderr)."""
    result = subprocess.run(
        cmd, shell=True, cwd=str(PROJECT_DIR),
        capture_output=True, text=True, timeout=timeout
    )
    return result.returncode == 0, result.stdout, result.stderr


def get_code_hash():
    """Get a hash of all Swift source files to detect changes."""
    success, stdout, _ = run(
        "find . -name '*.swift' -o -name '*.entitlements' -o -name '*.pbxproj' "
        "| sort | xargs shasum | shasum"
    )
    return stdout.strip() if success else None


def get_last_build_hash():
    if LAST_BUILD_HASH_FILE.exists():
        return LAST_BUILD_HASH_FILE.read_text().strip()
    return None


def save_build_hash(hash_val):
    LAST_BUILD_HASH_FILE.write_text(hash_val)


def has_changes():
    current = get_code_hash()
    last = get_last_build_hash()
    if current is None:
        return True
    return current != last


def pull_latest():
    success, stdout, stderr = run("git pull origin main --ff-only 2>&1")
    if success:
        if "Already up to date" in stdout:
            log("Git: Already up to date.")
        else:
            log("Git: Pulled latest changes.")
        return True
    else:
        log(f"Git: Pull failed (may have local changes): {stderr.strip()}")
        return True


def build_app():
    log("Building Spheres...")
    build_cmd = (
        f'xcodebuild -project "{PROJECT_FILE}" '
        f'-scheme "{SCHEME}" '
        f'-configuration Release '
        f'-derivedDataPath "{BUILD_DIR}" '
        f'build '
        f'2>&1'
    )
    success, stdout, stderr = run(build_cmd, timeout=300)
    if success and "BUILD SUCCEEDED" in stdout:
        log("Build succeeded.")
        return True
    else:
        errors = [l for l in stdout.split("\n") if "error:" in l.lower()]
        log(f"Build failed. Errors: {'; '.join(errors[:5]) if errors else 'See log'}")
        return False


def find_built_app():
    build_products = BUILD_DIR / "Build" / "Products" / "Release"
    app_path = build_products / APP_NAME
    if app_path.exists():
        return app_path
    return None


def stage_app(built_app_path):
    """Copy built app to a staging area using ditto (preserves code signature)."""
    staging_dir = PROJECT_DIR / ".staged_app"
    if staging_dir.exists():
        shutil.rmtree(str(staging_dir))
    staging_dir.mkdir()
    result = subprocess.run(
        ["ditto", str(built_app_path), str(STAGED_APP)],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        log(f"Staging failed: {result.stderr}")
        return False
    log("Staged new build.")
    return True


def swap_and_relaunch():
    """Write and run a detached shell script that does the quit/swap/relaunch.
    This script runs independently of the Spheres process, so it can
    safely quit the app, replace the binary, and relaunch without crashes."""

    script = f"""#!/bin/bash
# Wait a moment for the python process to exit
sleep 1

# Gracefully quit Spheres via AppleScript
osascript -e 'tell application "Spheres Multiplatform" to quit' 2>/dev/null

# Wait for it to fully exit (up to 10 seconds)
for i in $(seq 1 20); do
    if ! pgrep -f "Spheres Multiplatform" > /dev/null 2>&1; then
        break
    fi
    sleep 0.5
done

# Extra safety pause
sleep 1

# Swap: remove old, copy staged into place (ditto preserves code signature)
rm -rf "{INSTALLED_APP}"
ditto "{STAGED_APP}" "{INSTALLED_APP}"

# Remove quarantine flag so macOS doesn't block it
xattr -dr com.apple.quarantine "{INSTALLED_APP}" 2>/dev/null

# Clean up staging
rm -rf "{PROJECT_DIR / '.staged_app'}"

# Relaunch
open "{INSTALLED_APP}"

# Clean up this script
rm -f "{SWAP_SCRIPT}"
"""

    SWAP_SCRIPT.write_text(script)
    SWAP_SCRIPT.chmod(0o755)

    # Launch detached — completely independent of this process
    subprocess.Popen(
        ["/bin/bash", str(SWAP_SCRIPT)],
        start_new_session=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    log("Swap script launched. App will quit, update, and relaunch.")


def update(force=False):
    log("=" * 50)
    log("Starting update check...")

    pull_latest()

    if not force and not has_changes():
        log("No code changes detected. Skipping build.")
        return False

    current_hash = get_code_hash()

    if not build_app():
        log("Update aborted due to build failure.")
        return False

    built_app = find_built_app()
    if not built_app:
        log("Could not find built app. Check build output.")
        return False

    # Stage the new build (don't touch /Applications yet)
    if not stage_app(built_app):
        log("Staging failed.")
        return False

    if current_hash:
        save_build_hash(current_hash)

    # Launch detached swap script
    swap_and_relaunch()

    log("Update complete!")
    return True


def daemon_mode(interval_hours):
    log(f"Starting daemon mode (checking every {interval_hours}h)")
    log("Press Ctrl+C to stop.\n")
    while True:
        try:
            update()
            log(f"Next check in {interval_hours} hour(s)...\n")
            time.sleep(interval_hours * 3600)
        except KeyboardInterrupt:
            log("Daemon stopped.")
            break


def main():
    parser = argparse.ArgumentParser(description="Auto-update Spheres app")
    parser.add_argument("--daemon", action="store_true", help="Run in loop mode")
    parser.add_argument("--interval", type=float, default=2, help="Hours between checks (default: 2)")
    parser.add_argument("--force", action="store_true", help="Force rebuild even if no changes")
    args = parser.parse_args()

    if args.daemon:
        daemon_mode(args.interval)
    else:
        update(force=args.force)


if __name__ == "__main__":
    main()
