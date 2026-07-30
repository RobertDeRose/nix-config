#!/usr/bin/env python3
"""Maison private overlay state and clone helper."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tomllib
from pathlib import Path
from typing import NoReturn


class OverlayError(RuntimeError):
    """Raised when overlay discovery or preparation fails."""


def die(message: str) -> NoReturn:
    raise OverlayError(message)


def xdg_state_home() -> Path:
    return Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))


def xdg_data_home() -> Path:
    return Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))


def default_state_file() -> Path:
    return xdg_state_home() / "maison/overlay.toml"


def default_clone_dir() -> Path:
    return xdg_data_home() / "maison/overlay"


def load_state(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    with path.open("rb") as handle:
        data = tomllib.load(handle)
    source = data.get("source")
    clone_path = data.get("path")
    result: dict[str, str] = {}
    if source is not None:
        if not isinstance(source, str) or not source:
            die(f"{path}: source must be a non-empty string")
        result["source"] = source
    if clone_path is not None:
        if not isinstance(clone_path, str) or not clone_path:
            die(f"{path}: path must be a non-empty string")
        result["path"] = clone_path
    return result


def write_state(path: Path, source: str, clone_dir: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(f'source = "{source}"\npath = "{clone_dir}"\n')
    path.chmod(0o600)


def overlay_source(explicit: str | None, state_file: Path) -> str | None:
    if explicit:
        return explicit
    env_source = os.environ.get("MAISON_OVERLAY_SOURCE")
    if env_source:
        return env_source
    return load_state(state_file).get("source")


def overlay_required(args: argparse.Namespace) -> bool:
    return bool(args.required or os.environ.get("MAISON_REQUIRE_OVERLAY") == "true")


def prompt_source() -> str:
    print("Maison private overlay source is required.", file=sys.stderr)
    try:
        return input("Overlay Git URL or path: ").strip()
    except EOFError:
        return ""


def resolve_source(args: argparse.Namespace) -> str:
    source = overlay_source(args.overlay, args.state_file)
    if source:
        return source
    if overlay_required(args) and sys.stdin.isatty():
        source = prompt_source()
        if source:
            return source
    if overlay_required(args):
        die("overlay source is required; pass --overlay, set MAISON_OVERLAY_SOURCE, or configure overlay.toml")
    return ""


def is_git_repository(path: Path) -> bool:
    return (path / ".git").is_dir()


def clone_or_update(source: str, destination: Path) -> None:
    if destination.exists():
        if not is_git_repository(destination):
            die(f"overlay destination exists but is not a Git repository: {destination}")
        subprocess.run(["git", "-C", str(destination), "pull", "--ff-only"], check=True)
        return
    destination.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["git", "clone", source, str(destination)], check=True)


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--overlay", help="Overlay Git URL or path")
    result.add_argument("--state-file", type=Path, default=default_state_file())
    result.add_argument("--clone-dir", type=Path, default=default_clone_dir())
    result.add_argument("--required", action="store_true")
    commands = result.add_subparsers(dest="command", required=True)
    commands.add_parser("resolve")
    commands.add_parser("prepare")
    return result


def main() -> int:
    args = parser().parse_args()
    try:
        source = resolve_source(args)
        if args.command == "resolve":
            if source:
                print(source)
            return 0
        if args.command == "prepare":
            if not source:
                return 0
            clone_or_update(source, args.clone_dir)
            write_state(args.state_file, source, args.clone_dir)
            print(args.clone_dir)
            return 0
    except (OSError, subprocess.CalledProcessError, tomllib.TOMLDecodeError, OverlayError) as exc:
        print(f"error: maison overlay: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
