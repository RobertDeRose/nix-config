#!/usr/bin/env python3
"""Static repository checks that do not require a Nix installation."""

from __future__ import annotations

import json
import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SUPPORTED_SYSTEMS = {
    "aarch64-darwin",
    "x86_64-darwin",
    "aarch64-linux",
    "x86_64-linux",
}


def fail(message: str) -> None:
    raise AssertionError(message)


def load_toml(relative: str) -> dict:
    with (ROOT / relative).open("rb") as handle:
        return tomllib.load(handle)


def check_toml() -> None:
    mise = load_toml("mise.toml")
    inventory = load_toml("inventory.toml")
    packages = load_toml("packages.toml")
    fixture = load_toml("tests/fixtures/inventory-all-systems.toml")

    if mise.get("task_config", {}).get("includes") != [".mise/tasks"]:
        fail("mise.toml must discover only .mise/tasks")
    if "tasks" in mise:
        fail("mise.toml must not contain inline task definitions")
    if inventory.get("schema") != 1 or packages.get("schema") != 1:
        fail("live TOML inventories must use schema 1")

    fixture_systems = {host["system"] for host in fixture.get("hosts", {}).values()}
    if fixture_systems != SUPPORTED_SYSTEMS:
        fail(f"all-system fixture mismatch: {sorted(fixture_systems)}")


def check_flake_lock() -> None:
    lock = json.loads((ROOT / "flake.lock").read_text())
    nodes = lock["nodes"]
    if "root" not in nodes:
        fail("flake.lock has no root node")
    root_inputs = nodes["root"].get("inputs", {})
    if "easy-hosts" in root_inputs or "easy-hosts" in nodes:
        fail("easy-hosts remains in flake.lock")
    for node_name, node in nodes.items():
        for input_name, reference in node.get("inputs", {}).items():
            if isinstance(reference, str) and reference not in nodes:
                fail(f"flake.lock node {node_name}.{input_name} references missing node {reference}")


def check_nix_paths() -> None:
    path_pattern = re.compile(r'(?<![A-Za-z0-9_"$])((?:\.\.?/)+(?:[A-Za-z0-9._+-]+/?)+)')
    for nix_file in sorted(ROOT.rglob("*.nix")):
        if ".git" in nix_file.parts:
            continue
        for line_number, line in enumerate(nix_file.read_text().splitlines(), 1):
            code = line.split("#", 1)[0]
            for match in path_pattern.finditer(code):
                literal = match.group(1)
                target = (nix_file.parent / literal).resolve()
                if not target.exists():
                    fail(f"{nix_file.relative_to(ROOT)}:{line_number}: missing Nix path {literal}")


def check_outputs_and_legacy_paths() -> None:
    outputs = (ROOT / "nix/outputs.nix").read_text()
    for output in ("darwinConfigurations", "systemConfigs", "homeConfigurations"):
        if output not in outputs:
            fail(f"nix/outputs.nix does not expose {output}")
    for package in ("herdr", "opencode", "openspec", "pi", "worktrunk"):
        if f"{package} =" not in outputs:
            fail(f"nix/outputs.nix does not expose package {package}")
    if "formatter = pkgs.nixfmt-tree;" not in outputs:
        fail("nix/outputs.nix must use the nixfmt-tree formatter wrapper")
    if "systemManagerNoCheckOverlay" not in outputs:
        fail("nix/outputs.nix must apply the targeted system-manager no-check overlay")
    linux_host = (ROOT / "nix/lib/mk-linux-host.nix").read_text()
    if "overlays = [ systemManagerNoCheckOverlay ];" not in linux_host:
        fail("Linux host construction must disable only system-manager package checks")
    for legacy in ("systems", "templates", "home", "modules"):
        if (ROOT / legacy).exists():
            fail(f"legacy top-level path remains: {legacy}/")
    flake = (ROOT / "flake.nix").read_text()
    if "readDir" in flake or "easy-hosts" in flake:
        fail("flake.nix still contains filesystem host discovery")
    required_cache_settings = (
        '"https://nix-community.cachix.org"',
        '"https://cache.numtide.com"',
    )
    if any(setting not in flake for setting in required_cache_settings):
        fail("flake.nix does not advertise the non-default public binary caches as literal values")
    if "fallback = true;" in flake:
        fail("flake.nix must not require trust for the fallback execution preference")
    if '"https://cache.nixos.org"' in flake:
        fail("flake.nix must not duplicate the standard cache as an extra substituter")
    if "publicCache" in flake:
        fail("flake.nix nixConfig must not import cache values as thunks")


def check_mdbook_links() -> None:
    summary = ROOT / "docs/src/SUMMARY.md"
    link_pattern = re.compile(r"\[[^]]+\]\(([^)#]+)(?:#[^)]+)?\)")
    for line_number, line in enumerate(summary.read_text().splitlines(), 1):
        for raw_link in link_pattern.findall(line):
            if "://" in raw_link:
                continue
            target = (summary.parent / raw_link).resolve()
            if not target.exists():
                fail(f"docs/src/SUMMARY.md:{line_number}: missing page {raw_link}")


def main() -> int:
    checks = (
        check_toml,
        check_flake_lock,
        check_nix_paths,
        check_outputs_and_legacy_paths,
        check_mdbook_links,
    )
    try:
        for check in checks:
            check()
    except (AssertionError, OSError, ValueError, json.JSONDecodeError, tomllib.TOMLDecodeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    print("repository structure checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
