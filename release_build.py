#!/usr/bin/env python3
"""
release_build.py
-----------------
Utility script that:
1. Extracts the version from pubspec.yaml.
2. Builds Flutter release artifacts (AAB, APK, Windows, Web).
3. Zips Windows and Web builds.
4. Creates/Updates a GitHub release with the version number as title & tag and uploads all artifacts.

Requirements:
    - Python 3.8+
    - requests (pip install requests)

Environment variables (or CLI flags):
    GITHUB_TOKEN        Personal access token with `repo` scope.
    GITHUB_REPOSITORY   Your repo in the form `owner/repo`.

Typical usage:
    python release_build.py --repo owner/repo --token $GITHUB_TOKEN

If --repo / --token are omitted, the script falls back to the corresponding
environment variables. The script must be executed from the project root (where
pubspec.yaml is located).
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import List

import requests

PROJECT_ROOT = Path(__file__).resolve().parent
PUBSPEC_PATH = PROJECT_ROOT / "pubspec.yaml"

# ---------------------------------------------------------------------------
# Util helpers
# ---------------------------------------------------------------------------

def run(cmd: List[str], **kwargs):
    """Run a shell command and exit on failure."""
    print("$", " ".join(cmd))
    
    # Use shell=True on Windows to access the full PATH
    if os.name == 'nt':  # Windows
        kwargs.setdefault('shell', True)
    
    try:
        subprocess.check_call(cmd, **kwargs)
    except FileNotFoundError:
        print(f"ERROR: Command '{cmd[0]}' not found. Please ensure it's installed and in your PATH.")
        if cmd[0] == "flutter":
            print("Flutter installation guide: https://docs.flutter.dev/get-started/install")
            print("Make sure to restart your command prompt after installing Flutter.")
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        print(f"Command failed with exit code {e.returncode}")
        sys.exit(e.returncode)

def extract_version() -> str:
    """Parse the version from pubspec.yaml (first `version:` line)."""
    pattern = re.compile(r"^version:\s*(.*)$")
    with PUBSPEC_PATH.open(encoding="utf-8") as fp:
        for line in fp:
            m = pattern.match(line.strip())
            if m:
                return m.group(1)
    raise RuntimeError("Unable to find version in pubspec.yaml")

def zip_dir(src: Path, dest_zip: Path):
    """Zip the contents of *src* directory into *dest_zip*."""
    print(f"Zipping {src} -> {dest_zip}")
    if dest_zip.exists():
        dest_zip.unlink()
    shutil.make_archive(dest_zip.with_suffix(""), "zip", src)

def check_flutter_installation():
    """Verify Flutter is installed and accessible."""
    # First try with shell=True to use the full system PATH
    try:
        result = subprocess.run(["flutter", "--version"], 
                              capture_output=True, text=True, shell=True, timeout=30)
        if result.returncode == 0:
            version_line = result.stdout.split('\n')[0] if result.stdout else "version unknown"
            print(f"Flutter found: {version_line}")
            return True
        else:
            print(f"Flutter command failed with return code {result.returncode}")
            if result.stderr:
                print(f"Error output: {result.stderr}")
    except subprocess.TimeoutExpired:
        print("Flutter command timed out")
    except FileNotFoundError:
        print("Flutter command not found in PATH")
    except Exception as e:
        print(f"Error checking Flutter: {e}")
    
    # Try to find flutter.bat or flutter.exe in common locations
    flutter_paths = [
        "flutter",
        "flutter.bat", 
        "flutter.exe",
        r"C:\flutter\bin\flutter.bat",
        r"C:\flutter\bin\flutter.exe",
        r"C:\tools\flutter\bin\flutter.bat",
        r"C:\tools\flutter\bin\flutter.exe",
    ]
    
    for flutter_path in flutter_paths:
        try:
            result = subprocess.run([flutter_path, "--version"], 
                                  capture_output=True, text=True, timeout=30)
            if result.returncode == 0:
                version_line = result.stdout.split('\n')[0] if result.stdout else "version unknown"
                print(f"Flutter found at {flutter_path}: {version_line}")
                return True
        except (FileNotFoundError, subprocess.TimeoutExpired, Exception):
            continue
    
    print("ERROR: Flutter is not accessible from this Python environment.")
    print("Current PATH:", os.environ.get('PATH', 'Not found'))
    print("Please ensure Flutter is properly installed and accessible.")
    print("Try running this script from a command prompt where 'flutter --version' works.")
    return False

# ---------------------------------------------------------------------------
# Config helpers
# ---------------------------------------------------------------------------

def load_config_file(path: Path) -> dict:
    """Load configuration from JSON or simple KEY=VALUE file."""
    if not path or not path.exists():
        return {}
    if path.suffix.lower() == ".json":
        with path.open(encoding="utf-8") as f:
            return json.load(f)
    # Fallback to simple key=value per line (ignore comments and blanks)
    data: dict[str, str] = {}
    with path.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                k, v = line.split("=", 1)
                data[k.strip()] = v.strip()
    return data

# ---------------------------------------------------------------------------
# GitHub helpers
# ---------------------------------------------------------------------------

github_api = "https://api.github.com"


def create_or_get_release(token: str, repo: str, tag: str, name: str):
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github+json",
    }

    # Check if release already exists
    r = requests.get(f"{github_api}/repos/{repo}/releases/tags/{tag}", headers=headers)
    if r.status_code == 200:
        release = r.json()
        print(f"Found existing release id={release['id']} for tag {tag}")
        return release
    elif r.status_code != 404:
        print("Error fetching existing release:", r.text)
        r.raise_for_status()

    payload = {
        "tag_name": tag,
        "name": name,
        "body": f"Release {name}",
        "draft": False,
        "prerelease": False,
    }

    print(f"Creating release {tag} in {repo}…")
    r = requests.post(f"{github_api}/repos/{repo}/releases", json=payload, headers=headers)
    r.raise_for_status()
    return r.json()


def upload_asset(token: str, upload_url_template: str, file_path: Path):
    headers = {
        "Authorization": f"token {token}",
        "Content-Type": "application/octet-stream",
    }

    upload_url = upload_url_template.split("{", 1)[0]  # remove templating var
    params = {"name": file_path.name}
    print(f"Uploading {file_path}…")
    with file_path.open("rb") as fp:
        resp = requests.post(upload_url, params=params, data=fp, headers=headers)
    if resp.status_code not in (200, 201):
        print("Failed to upload asset:", resp.text)
        resp.raise_for_status()


# ---------------------------------------------------------------------------
# Build process
# ---------------------------------------------------------------------------

def run_flutter_builds():
    print("Running Flutter builds…")
    if not check_flutter_installation():
        sys.exit(1)
    
    run(["flutter", "pub", "get"])
    run(["flutter", "build", "appbundle", "--release"])
    run(["flutter", "build", "apk", "--release"])    
    #run(["flutter", "build", "windows", "--release"])
    run(["flutter", "build", "web", "--release"])


def gather_artifacts(version: str) -> List[Path]:
    apk = PROJECT_ROOT / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
    aab = PROJECT_ROOT / "build" / "app" / "outputs" / "bundle" / "release" / "app-release.aab"

    web_dir = PROJECT_ROOT / "build" / "web"

    web_zip = PROJECT_ROOT / f"web-release-{version}.zip"

    
    if not web_dir.exists():
        raise FileNotFoundError(f"Web build directory not found: {web_dir}")

    zip_dir(web_dir, web_zip)

    for p in (apk, aab, web_zip):
        if not p.exists():
            raise FileNotFoundError(f"Missing artifact: {p}")

    return [apk, aab, web_zip]


# ---------------------------------------------------------------------------
# Main entry
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Build Flutter release & GitHub upload")
    parser.add_argument("--repo", default=os.getenv("GITHUB_REPOSITORY"), help="GitHub repository in owner/repo format")
    parser.add_argument("--token", default=os.getenv("GITHUB_TOKEN"), help="GitHub Personal Access Token with repo scope")
    parser.add_argument("--config", default=None, help="Path to config file (json or key=value).")
    args = parser.parse_args()

    # Resolve configuration precedence: CLI > env vars > config file
    config_path = Path(args.config) if args.config else (PROJECT_ROOT / "release_config.json")
    config = load_config_file(config_path) if config_path.exists() else {}

    repo = args.repo or os.getenv("GITHUB_REPOSITORY") or config.get("repo") or config.get("repository") or config.get("GITHUB_REPOSITORY")
    token = args.token or os.getenv("GITHUB_TOKEN") or config.get("token") or config.get("github_token") or config.get("GITHUB_TOKEN")

    # Propagate back to args so the remainder of the script can keep using them
    args.repo = repo
    args.token = token

    if not repo or not token:
        print("ERROR: GitHub repo and token must be supplied via CLI flags, environment variables, or config file.")
        sys.exit(1)

    version = extract_version()
    tag = f"v{version}"
    print(f"Version detected: {version}")

    # 1. Run builds
    run_flutter_builds()

    # 2. Zip and gather artifacts
    artifacts = gather_artifacts(version)

    # 3. Create or fetch GitHub release
    release = create_or_get_release(args.token, args.repo, tag=tag, name=version)

    # 4. Upload assets (skip duplicates)
    existing_names = {asset["name"] for asset in release.get("assets", [])}
    upload_url_template = release["upload_url"]

    for artifact in artifacts:
        if artifact.name in existing_names:
            print(f"Asset {artifact.name} already exists in release – skipping")
            continue
        upload_asset(args.token, upload_url_template, artifact)

    print("Release completed successfully!")


if __name__ == "__main__":
    main()
