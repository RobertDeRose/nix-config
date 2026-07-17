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
    for package in ("herdr", "opencode", "openspec", "pi"):
        if f"{package} =" not in outputs:
            fail(f"nix/outputs.nix does not expose package {package}")
    if 'lib.hasSuffix "-darwin" system' not in outputs:
        fail("AI package outputs must be restricted to Darwin systems")
    mise = load_toml("mise.toml")
    packages = load_toml("packages.toml")
    if mise.get("tools", {}).get("usage") != "3.5.5":
        fail("mise.toml must pin Usage 3.5.5 for stable Maison parsing and completion")
    shell_module = (ROOT / "nix/modules/home/common/shell.nix").read_text()
    if "source <(maison completion zsh)" not in shell_module:
        fail("Home Manager must load Maison-specific Zsh completion")
    if "completion-init zsh" in shell_module:
        fail("Home Manager must not install Usage's global Zsh fallback completion")
    if "dotfiles/starship/starship.toml" not in shell_module:
        fail("Home Manager must use the shared Maison Starship prompt")
    starship_binding = shell_module.split("starshipConfig", 1)[1].split("in", 1)[0]
    if "starship-linux.toml" in shell_module or "pkgs.stdenv.isLinux" in starship_binding:
        fail("Home Manager must not select a separate Linux Starship prompt")
    if 'xdg.configFile."starship/minimal.toml"' not in shell_module:
        fail("Home Manager must install the minimal Starship recovery prompt")

    starship_text = (ROOT / "dotfiles/starship/starship.toml").read_text()
    starship = load_toml("dotfiles/starship/starship.toml")
    if starship.get("palette") != "catppuccin_macchiato":
        fail("Maison Starship must use the Catppuccin Macchiato palette")
    expected_macchiato = {
        "base": "#24273a",
        "text": "#cad3f5",
        "blue": "#8aadf4",
        "green": "#a6da95",
        "yellow": "#eed49f",
        "red": "#ed8796",
        "mauve": "#c6a0f6",
        "peach": "#f5a97f",
    }
    palette = starship.get("palettes", {}).get("catppuccin_macchiato", {})
    for color, expected in expected_macchiato.items():
        if palette.get(color) != expected:
            fail(f"Maison Starship Macchiato color {color} must be {expected}")
    starship_format = starship.get("format", "")
    if "$fill" in starship_format or starship.get("right_format"):
        fail("Maison Starship prompt must not use width-sensitive fill or right alignment")
    if "\n" not in starship_format:
        fail("Maison Starship prompt must keep the Powerlevel10k-inspired two-line layout")
    if "" not in starship_text or "" not in starship_text:
        fail("Maison Starship prompt must retain Nerd Font Powerline styling")
    if starship.get("character", {}).get("success_symbol") != "[❯](bold green)":
        fail("Maison Starship prompt must use the Nerd Font-compatible input marker")

    linux_system = (ROOT / "nix/modules/linux/system.nix").read_text()
    if linux_system.count("LANG=C.UTF-8") < 2 or linux_system.count("LC_CTYPE=C.UTF-8") < 2:
        fail("Linux system configuration must set C.UTF-8 in both locale files")
    if '"default/locale"' not in linux_system or '"locale.conf"' not in linux_system:
        fail("Linux system configuration must manage both default/locale and locale.conf")
    if 'LANG = "C.UTF-8";' not in shell_module or 'LC_CTYPE = "C.UTF-8";' not in shell_module:
        fail("Home Manager must export the UTF-8 locale for Linux shells")

    minimal_starship_path = ROOT / "dotfiles/starship/starship-minimal.toml"
    minimal_starship_text = minimal_starship_path.read_text()
    if any(ord(character) > 127 for character in minimal_starship_text):
        fail("Minimal Starship recovery prompt must remain ASCII-only")
    minimal_starship = load_toml("dotfiles/starship/starship-minimal.toml")
    minimal_format = minimal_starship.get("format", "")
    if "$fill" in minimal_format or minimal_starship.get("right_format"):
        fail("Minimal Starship recovery prompt must not use fill or right alignment")
    worktrunk = "github:max-sixty/worktrunk"
    if worktrunk in mise.get("tools", {}):
        fail("repository-local mise.toml must not activate Worktrunk globally")
    if packages.get("profiles", {}).get("base", {}).get("mise", {}).get("tools", {}).get(worktrunk) != "latest":
        fail("packages.toml must own the global Worktrunk installation")
    mise_module = (ROOT / "nix/modules/home/common/mise.nix").read_text()
    if 'xdg.configFile."mise/config.toml"' not in mise_module:
        fail("Home Manager must render the global mise config")
    apply_task = (ROOT / ".mise/tasks/apply").read_text()
    if 'MISE_CONFIG_FILE="$global_mise_config" mise install' not in apply_task:
        fail("apply must install tools from the Home Manager-managed global mise config")
    deploy_task = (ROOT / ".mise/tasks/deploy").read_text()
    if "run bootstrap first" not in deploy_task:
        fail("deploy must require an already bootstrapped remote host")
    if 'MISE_CONFIG_FILE="$mise_config"' not in deploy_task or '"$mise_bin" install' not in deploy_task:
        fail("deploy must install remote tools from the Home Manager-managed global mise config")
    if (ROOT / "nix/modules/home/common/zellij.nix").exists():
        fail("removed Zellij Home Manager module still exists")
    if "formatter = pkgs.nixfmt-tree;" not in outputs:
        fail("nix/outputs.nix must use the nixfmt-tree formatter wrapper")
    overlay = ROOT / "nix/lib/system-manager-no-check-overlay.nix"
    if not overlay.is_file():
        fail("targeted system-manager no-check overlay file is missing")
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


def check_workflows() -> None:
    docs_workflow = (ROOT / ".github/workflows/docs.yml").read_text()
    if "- .mise/tasks/docs/build" not in docs_workflow:
        fail("docs workflow must run when the docs build task changes")


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
        check_workflows,
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
