#!/usr/bin/env python3
"""Small deterministic editor for Maison's mise TOML tables.

The writer only replaces the selected top-level table and leaves comments and
all other sections untouched.  It intentionally supports the simple scalar and
string-list values used by Maison's [tools] and [bootstrap.packages] tables.
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
        else:
            for path in args.files:
                load_toml(path)
    except ConfigError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
