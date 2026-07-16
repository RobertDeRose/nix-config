#!/usr/bin/env python3
"""Small TOML-preserving editor and validator for Maison inventories."""

from __future__ import annotations

import argparse
import json
import re
import sys
import tomllib
from pathlib import Path
from typing import Any, Iterable


class ConfigError(RuntimeError):
    pass


def load_toml(path: Path) -> dict[str, Any]:
    try:
        with path.open("rb") as handle:
            return tomllib.load(handle)
    except (OSError, tomllib.TOMLDecodeError) as exc:
        raise ConfigError(f"{path.name}: {exc}") from exc


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


def format_array(key: str, values: Iterable[str]) -> list[str]:
    ordered = sorted(set(values), key=lambda value: (value.casefold(), value))
    if not ordered:
        return [f"{key} = []\n"]
    return [f"{key} = [\n", *[f"  {json.dumps(value)},\n" for value in ordered], "]\n"]


def replace_array(path: Path, section: str, key: str, value: str, remove: bool) -> None:
    lines = path.read_text().splitlines(keepends=True)
    bounds = table_bounds(lines, section)
    if bounds is None:
        if remove:
            raise ConfigError(f"{path.name}: section [{section}] does not exist")
        if lines and lines[-1].strip():
            lines.append("\n")
        lines.extend([f"[{section}]\n", *format_array(key, [value])])
        path.write_text("".join(lines))
        return

    start, end = bounds
    assignment = re.compile(rf"^\s*{re.escape(key)}\s*=\s*\[")
    key_start = next((i for i in range(start + 1, end) if assignment.match(lines[i])), None)
    current: list[str] = []
    key_end = key_start
    if key_start is not None:
        depth = 0
        for index in range(key_start, end):
            line = lines[index]
            depth += line.count("[") - line.count("]")
            if depth <= 0:
                key_end = index + 1
                break
        parsed = load_toml(path)
        node: Any = parsed
        for segment in section.split("."):
            node = node[segment]
        current = list(node.get(key, []))

    if remove:
        if value not in current:
            raise ConfigError(f"{value!r} is not present in [{section}].{key}")
        current.remove(value)
    else:
        if value in current:
            raise ConfigError(f"{value!r} is already present in [{section}].{key}")
        current.append(value)

    replacement = format_array(key, current)
    if key_start is None:
        insertion = end
        while insertion > start + 1 and not lines[insertion - 1].strip():
            insertion -= 1
        lines[insertion:insertion] = replacement
    else:
        lines[key_start:key_end] = replacement
    path.write_text("".join(lines))


def toml_key(value: str) -> str:
    return value if re.fullmatch(r"[A-Za-z0-9_-]+", value) else json.dumps(value)


def rewrite_tools(path: Path, tool: str, version: str | None, remove: bool) -> None:
    data = load_toml(path)
    tools = dict(data.get("tools", {}))
    if remove:
        if tool not in tools:
            raise ConfigError(f"tool {tool!r} is not present in mise.toml")
        del tools[tool]
    else:
        tools[tool] = version or "latest"

    for name, configured in tools.items():
        if not isinstance(configured, str):
            raise ConfigError(
                f"mise.toml: [tools].{name} uses a structured value; edit it manually to preserve its options"
            )

    lines = path.read_text().splitlines(keepends=True)
    bounds = table_bounds(lines, "tools")
    if bounds is None:
        raise ConfigError("mise.toml: missing [tools] section")
    start, end = bounds
    replacement = ["[tools]\n"] + [
        f"{toml_key(name)} = {json.dumps(tools[name])}\n"
        for name in sorted(tools, key=lambda value: (value.casefold(), value))
    ]
    if end < len(lines) and lines[end - 1].strip():
        replacement.append("\n")
    lines[start:end] = replacement
    path.write_text("".join(lines))


def canonical_tool(name: str) -> str:
    candidate = name.split(":", 1)[-1]
    return candidate.rstrip("/").rsplit("/", 1)[-1]


def canonical_homebrew(name: str) -> str:
    return name.rstrip("/").rsplit("/", 1)[-1]


def iter_strings(value: Any, context: str) -> Iterable[str]:
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise ConfigError(f"{context} must be an array of strings")
    if len(value) != len(set(value)):
        raise ConfigError(f"{context} contains duplicate entries")
    expected = sorted(value, key=lambda item: (item.casefold(), item))
    if value != expected:
        raise ConfigError(f"{context} must be sorted; expected: {expected}")
    yield from value


def add_owner(owners: dict[str, set[str]], package: str, owner: str) -> None:
    owners.setdefault(package, set()).add(owner)


def validate(root: Path) -> None:
    inventory = load_toml(root / "inventory.toml")
    packages = load_toml(root / "packages.toml")
    mise = load_toml(root / "mise.toml")

    if inventory.get("schema") != 1:
        raise ConfigError("inventory.toml: schema must be 1")
    if packages.get("schema") != 1:
        raise ConfigError("packages.toml: schema must be 1")

    inventory_profiles = {"base", "dev", "mac", "linux"}
    unknown_profiles = set(packages.get("profiles", {})) - inventory_profiles
    if unknown_profiles:
        raise ConfigError(f"packages.toml: unknown profiles: {sorted(unknown_profiles)}")

    known_hosts = set(inventory.get("hosts", {}))
    package_hosts = set(packages.get("hosts", {}))
    missing_hosts = package_hosts - known_hosts
    if missing_hosts:
        raise ConfigError(f"packages.toml: host package entries have no inventory host: {sorted(missing_hosts)}")

    owners: dict[str, set[str]] = {}
    for tool in mise.get("tools", {}):
        add_owner(owners, canonical_tool(tool), "mise")

    for profile, profile_data in packages.get("profiles", {}).items():
        mise_tools = profile_data.get("mise", {}).get("tools", {})
        if not isinstance(mise_tools, dict) or not all(
            isinstance(tool, str) and isinstance(version, str)
            for tool, version in mise_tools.items()
        ):
            raise ConfigError(f"profiles.{profile}.mise.tools must map tool names to version strings")
        for tool in mise_tools:
            add_owner(owners, canonical_tool(tool), "mise")

        for section_name in ("nix", "system"):
            section = profile_data.get(section_name, {})
            for package in iter_strings(section.get("packages", []), f"profiles.{profile}.{section_name}.packages"):
                add_owner(owners, package, "nix")
            for system, entries in section.get("systems", {}).items():
                for package in iter_strings(entries, f"profiles.{profile}.{section_name}.systems.{system}"):
                    add_owner(owners, package, "nix")

        brew = profile_data.get("homebrew", {})
        for key in ("taps", "brews", "casks"):
            for package in iter_strings(brew.get(key, []), f"profiles.{profile}.homebrew.{key}"):
                if key != "taps":
                    add_owner(owners, canonical_homebrew(package), "homebrew")
        for system, entries in brew.get("systems", {}).items():
            for package in iter_strings(entries, f"profiles.{profile}.homebrew.systems.{system}"):
                add_owner(owners, canonical_homebrew(package), "homebrew")

        mas = profile_data.get("mas", {})
        if not isinstance(mas, dict) or not all(isinstance(name, str) and isinstance(app_id, int) for name, app_id in mas.items()):
            raise ConfigError(f"profiles.{profile}.mas must map app names to integer IDs")
        if len(set(mas.values())) != len(mas):
            raise ConfigError(f"profiles.{profile}.mas contains duplicate app IDs")
        for name in mas:
            add_owner(owners, name.casefold(), "mas")

    for host, host_data in packages.get("hosts", {}).items():
        nix_data = host_data.get("nix", {})
        for package in iter_strings(nix_data.get("packages", []), f"hosts.{host}.nix.packages"):
            add_owner(owners, package, "nix")
        brew = host_data.get("homebrew", {})
        for key in ("taps", "brews", "casks"):
            for package in iter_strings(brew.get(key, []), f"hosts.{host}.homebrew.{key}"):
                if key != "taps":
                    add_owner(owners, canonical_homebrew(package), "homebrew")

    module_owned = packages.get("module_owned", {})
    for package in iter_strings(module_owned.get("nix", {}).get("packages", []), "module_owned.nix.packages"):
        add_owner(owners, package, "nix")
    for package in iter_strings(
        module_owned.get("custom_nix", {}).get("packages", []), "module_owned.custom_nix.packages"
    ):
        add_owner(owners, package, "custom_nix")

    exceptions: dict[str, tuple[set[str], str]] = {}
    for entry in packages.get("ownership", {}).get("exceptions", []):
        if not isinstance(entry, dict):
            raise ConfigError("ownership.exceptions entries must be tables")
        package = entry.get("package")
        exception_owners = entry.get("owners")
        reason = entry.get("reason")
        if not isinstance(package, str) or not isinstance(reason, str) or not reason.strip():
            raise ConfigError("ownership exception requires package and a non-empty reason")
        if not isinstance(exception_owners, list) or not all(isinstance(owner, str) for owner in exception_owners):
            raise ConfigError(f"ownership exception for {package!r} requires an owners array")
        exceptions[package] = (set(exception_owners), reason)

    used_exceptions: set[str] = set()
    for package, package_owners in sorted(owners.items()):
        if len(package_owners) <= 1:
            continue
        exception = exceptions.get(package)
        if exception is None or exception[0] != package_owners:
            raise ConfigError(
                f"package {package!r} has multiple owners {sorted(package_owners)} without an exact documented exception"
            )
        used_exceptions.add(package)

    unused = set(exceptions) - used_exceptions
    if unused:
        raise ConfigError(f"unused ownership exceptions: {sorted(unused)}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("validate")

    array = sub.add_parser("array")
    array.add_argument("--file", required=True)
    array.add_argument("--section", required=True)
    array.add_argument("--key", required=True)
    array.add_argument("--value", required=True)
    array.add_argument("--remove", action="store_true")

    tool = sub.add_parser("tool")
    tool.add_argument("name")
    tool.add_argument("--version", default="latest")
    tool.add_argument("--remove", action="store_true")

    args = parser.parse_args()
    root = args.root.resolve()
    try:
        if args.command == "validate":
            validate(root)
        elif args.command == "array":
            replace_array(root / args.file, args.section, args.key, args.value, args.remove)
            load_toml(root / args.file)
        elif args.command == "tool":
            rewrite_tools(root / "mise.toml", args.name, args.version, args.remove)
            load_toml(root / "mise.toml")
        else:
            raise AssertionError(args.command)
    except ConfigError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
