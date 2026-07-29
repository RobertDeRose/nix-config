#!/usr/bin/env python3
"""Small deterministic editor for Maison's mise TOML tables.

The writer only replaces selected top-level tables or lockfile tool blocks and
leaves comments and unrelated sections untouched. It intentionally supports the
simple scalar and string-list values used by Maison's [tools] and
[bootstrap.packages] tables.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import tomllib
from pathlib import Path
from typing import Any


class ConfigError(RuntimeError):
    pass


TOOL_LOCK_HEADER_RE = re.compile(
    r'^\s*\[\[tools\.(?P<key>"(?:[^"\\]|\\.)*"|[A-Za-z0-9_-]+)\]\]\s*(?:#.*)?$'
)


def load_toml(path: Path) -> dict[str, Any]:
    try:
        with path.open("rb") as handle:
            return tomllib.load(handle)
    except (OSError, tomllib.TOMLDecodeError) as exc:
        raise ConfigError(f"{path}: {exc}") from exc


def table_bounds(lines: list[str], section: str) -> tuple[int, int] | None:
    header = f"[{section}]"
    start = next((i for i, line in enumerate(lines) if line.strip() == header), None)
    if start is None:
        return None
    end = len(lines)
    for index in range(start + 1, len(lines)):
        stripped = lines[index].strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            end = index
            break
    return start, end


def toml_key(value: str) -> str:
    return value if re.fullmatch(r"[A-Za-z0-9_-]+", value) else json.dumps(value)


def format_value(value: Any) -> str:
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, list) and value and all(isinstance(item, str) for item in value):
        return "[" + ", ".join(json.dumps(item) for item in value) + "]"
    raise ConfigError(f"unsupported table value {value!r}; edit the config manually")


def rewrite_table(path: Path, section: str, values: dict[str, Any]) -> None:
    lines = path.read_text().splitlines(keepends=True)
    bounds = table_bounds(lines, section)
    replacement = [f"[{section}]\n"]
    replacement.extend(
        f"{toml_key(key)} = {format_value(values[key])}\n"
        for key in sorted(values, key=lambda item: (item.casefold(), item))
    )
    replacement.append("\n")

    if bounds is None:
        if lines and lines[-1].strip():
            lines.append("\n")
        lines.extend(replacement)
    else:
        start, end = bounds
        lines[start:end] = replacement

    path.write_text("".join(lines))
    load_toml(path)


def split_tool_version(tool: str) -> tuple[str, str | None]:
    # Scoped package names such as npm:@scope/package contain @ as part of the
    # identifier. Treat @ as a version separator only when it appears after the
    # final path separator (or for unqualified names such as node@24).
    separator_index = tool.rfind("@")
    if separator_index <= tool.rfind("/") or separator_index <= tool.find(":"):
        return tool, None
    name = tool[:separator_index]
    version = tool[separator_index + 1 :]
    if name and version:
        return name, version
    return tool, None


def edit_tool(path: Path, tool: str, version: str, remove: bool) -> None:
    data = load_toml(path)
    tools = dict(data.get("tools", {}))
    name, embedded_version = split_tool_version(tool)
    selected = embedded_version or version

    for configured_name, configured in tools.items():
        valid = isinstance(configured, str) or (
            isinstance(configured, list)
            and configured
            and all(isinstance(item, str) for item in configured)
        )
        if not valid:
            raise ConfigError(
                f"{path}: [tools].{configured_name} uses a structured value; "
                "edit it manually to preserve its options"
            )

    if remove:
        if name not in tools:
            raise ConfigError(f"tool {name!r} is not present in {path}")
        if embedded_version is None:
            del tools[name]
        else:
            configured = tools[name]
            versions = [configured] if isinstance(configured, str) else list(configured)
            if embedded_version not in versions:
                raise ConfigError(
                    f"version {embedded_version!r} is not configured for tool {name!r}"
                )
            versions.remove(embedded_version)
            if not versions:
                del tools[name]
            else:
                tools[name] = versions[0] if len(versions) == 1 else versions
    else:
        configured = tools.get(name)
        if configured is None:
            tools[name] = selected
        else:
            versions = [configured] if isinstance(configured, str) else list(configured)
            if selected in versions:
                raise ConfigError(f"version {selected!r} is already configured for {name!r}")
            tools[name] = [*versions, selected]

    rewrite_table(path, "tools", tools)


def edit_package(path: Path, package: str, version: str, remove: bool) -> None:
    if ":" not in package:
        raise ConfigError("package must use manager:package syntax")
    data = load_toml(path)
    packages = dict(data.get("bootstrap", {}).get("packages", {}))
    if not all(isinstance(key, str) and isinstance(value, str) for key, value in packages.items()):
        raise ConfigError(f"{path}: [bootstrap.packages] must map names to version strings")

    if remove:
        if package not in packages:
            raise ConfigError(f"package {package!r} is not present in {path}")
        del packages[package]
    else:
        if package in packages:
            raise ConfigError(f"package {package!r} is already present in {path}")
        packages[package] = version

    rewrite_table(path, "bootstrap.packages", packages)


def decode_toml_key(raw: str) -> str:
    if raw.startswith('"'):
        try:
            return tomllib.loads(f"key = {raw}")["key"]
        except tomllib.TOMLDecodeError as exc:
            raise ConfigError(f"invalid lockfile tool key {raw!r}: {exc}") from exc
    return raw


def lock_block_end(lines: list[str], start: int, raw_key: str) -> int:
    nested_prefixes = (f"[tools.{raw_key}.", f"[[tools.{raw_key}.")
    for index in range(start + 1, len(lines)):
        stripped = lines[index].lstrip()
        if TOOL_LOCK_HEADER_RE.match(lines[index]):
            return index
        if stripped.startswith("[") and not stripped.startswith(nested_prefixes):
            return index
    return len(lines)


def lock_block_version(block: str, name: str) -> str:
    try:
        data = tomllib.loads(block)
    except tomllib.TOMLDecodeError as exc:
        raise ConfigError(f"unable to parse lockfile block for {name!r}: {exc}") from exc
    entries = data.get("tools", {}).get(name)
    if not isinstance(entries, list) or len(entries) != 1:
        raise ConfigError(f"lockfile block for {name!r} has an unexpected shape")
    version = entries[0].get("version")
    if not isinstance(version, str):
        raise ConfigError(f"lockfile block for {name!r} has no string version")
    return version


def has_tool(path: Path, tool: str) -> bool:
    name, _ = split_tool_version(tool)
    return name in load_toml(path).get("tools", {})


def remove_locked_tool(path: Path, tool: str, config: Path | None = None) -> None:
    # Lockfiles use one [[tools.NAME]] block per resolved version. Remove all
    # blocks when the tool disappeared from the candidate config. For a
    # version-specific removal that leaves other selectors configured, remove
    # only an exactly matching resolved version; fuzzy selectors may share a
    # resolved lock entry and are intentionally left for mise to reconcile.
    name, selected_version = split_tool_version(tool)
    if config is not None and name not in load_toml(config).get("tools", {}):
        selected_version = None
    lines = path.read_text().splitlines(keepends=True)
    output: list[str] = []
    index = 0
    while index < len(lines):
        match = TOOL_LOCK_HEADER_RE.match(lines[index])
        if match is None:
            output.append(lines[index])
            index += 1
            continue
        raw_key = match.group("key")
        block_end = lock_block_end(lines, index, raw_key)
        block = "".join(lines[index:block_end])
        block_name = decode_toml_key(raw_key)
        should_remove = block_name == name
        if should_remove and selected_version is not None:
            should_remove = lock_block_version(block, block_name) == selected_version
        if not should_remove:
            output.extend(lines[index:block_end])
        index = block_end

    path.write_text("".join(output))
    load_toml(path)


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser()
    sub = result.add_subparsers(dest="command", required=True)

    tool = sub.add_parser("tool")
    tool.add_argument("--file", required=True, type=Path)
    tool.add_argument("--name", required=True)
    tool.add_argument("--version", default="latest")
    tool.add_argument("--remove", action="store_true")

    package = sub.add_parser("package")
    package.add_argument("--file", required=True, type=Path)
    package.add_argument("--name", required=True)
    package.add_argument("--version", default="latest")
    package.add_argument("--remove", action="store_true")

    contains = sub.add_parser("has-tool")
    contains.add_argument("--file", required=True, type=Path)
    contains.add_argument("--name", required=True)

    lock_remove = sub.add_parser("lock-remove")
    lock_remove.add_argument("--file", required=True, type=Path)
    lock_remove.add_argument("--name", required=True)
    lock_remove.add_argument("--config", type=Path)

    validate = sub.add_parser("validate")
    validate.add_argument("files", nargs="+", type=Path)
    return result


def main() -> int:
    args = parser().parse_args()
    try:
        if args.command == "tool":
            edit_tool(args.file, args.name, args.version, args.remove)
        elif args.command == "package":
            edit_package(args.file, args.name, args.version, args.remove)
        elif args.command == "has-tool":
            return 0 if has_tool(args.file, args.name) else 1
        elif args.command == "lock-remove":
            remove_locked_tool(args.file, args.name, args.config)
        else:
            for path in args.files:
                load_toml(path)
    except ConfigError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
