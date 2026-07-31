from __future__ import annotations

import argparse
import os
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

Mode = Literal["plan", "apply"]


@dataclass(frozen=True)
class Command:
    name: str
    argv: tuple[str, ...]
    cwd: Path
    env: dict[str, str]
    dry_run: bool
    semantic_action: str
    semantic_arguments: tuple[str, ...] = ()
    documented_substitution: bool = False
    quiet: bool = False


@dataclass(frozen=True)
class CommandPlan:
    mode: Mode
    force_dotfiles: bool
    convergence_commands: tuple[Command, ...]
    apply_only_commands: tuple[Command, ...] = ()

    def command(self, name: str) -> Command:
        for command in (*self.convergence_commands, *self.apply_only_commands):
            if command.name == name:
                return command
        raise KeyError(name)


def aggregate_user_arguments(*, force_dotfiles: bool) -> tuple[str, ...]:
    return ("--force-dotfiles",) if force_dotfiles else ()


def _configuration_path(root: Path, home: Path) -> Path:
    configured = home / ".config/mise/config.toml"
    return configured if configured.is_file() else root / "config/mise/config.toml"


def build_command_plan(
    *,
    mode: Mode,
    force_dotfiles: bool,
    root: Path,
    home: Path,
) -> CommandPlan:
    root = root.resolve()
    home = home.resolve()
    dry_run = mode == "plan"
    force_arguments = aggregate_user_arguments(force_dotfiles=force_dotfiles)
    execution_argument = "--dry-run" if dry_run else "--yes"
    prepare_arguments = (execution_argument, *force_arguments) if dry_run else force_arguments
    mise_environment = {
        "MISE_AUTO_ENV": "true",
        "MISE_GLOBAL_CONFIG_FILE": str(_configuration_path(root, home)),
    }
    commands = (
        Command(
            name="prepare",
            argv=(str(root / "scripts/user-prepare.sh"), *prepare_arguments),
            cwd=root,
            env={},
            dry_run=dry_run,
            semantic_action="prepare-dotfiles",
            semantic_arguments=force_arguments,
        ),
        Command(
            name="dotfiles",
            argv=("mise", "bootstrap", "--only", "dotfiles", execution_argument, *force_arguments),
            cwd=root,
            env={},
            dry_run=dry_run,
            semantic_action="converge-dotfiles",
            semantic_arguments=force_arguments,
        ),
        Command(
            name="lockfiles",
            argv=(
                str(root / "scripts/user-link-mise-lock.sh"),
                *(("--dry-run",) if dry_run else ()),
            ),
            cwd=root,
            env={},
            dry_run=dry_run,
            semantic_action="link-mise-lockfiles",
        ),
        Command(
            name="packages",
            argv=(
                ("mise", "bootstrap", "packages", "apply", "--dry-run")
                if dry_run
                else (str(root / "scripts/user-apply-packages.sh"),)
            ),
            cwd=home,
            env=mise_environment,
            dry_run=dry_run,
            semantic_action="converge-packages",
            documented_substitution=True,
        ),
        Command(
            name="mise",
            argv=(
                "mise",
                "bootstrap",
                "--skip",
                "task",
                "--skip",
                "packages",
                "--skip",
                "dotfiles",
                execution_argument,
                *force_arguments,
            ),
            cwd=home,
            env=mise_environment,
            dry_run=dry_run,
            semantic_action="converge-mise-user-state",
            semantic_arguments=force_arguments,
        ),
    )
    apply_only = ()
    if mode == "apply":
        apply_only = (
            Command(
                name="trust",
                argv=("mise", "trust", str(root / "mise.toml")),
                cwd=root,
                env={},
                dry_run=False,
                semantic_action="trust-repository-config",
                documented_substitution=True,
                quiet=True,
            ),
            Command(
                name="finalize",
                argv=(str(root / "scripts/user-finalize.sh"),),
                cwd=root,
                env={},
                dry_run=False,
                semantic_action="finalize-user-convergence",
                documented_substitution=True,
            ),
        )
    return CommandPlan(mode, force_dotfiles, commands, apply_only)


def run_command_plan(plan: CommandPlan) -> None:
    commands = (
        (*plan.apply_only_commands[:1], *plan.convergence_commands, *plan.apply_only_commands[1:])
        if plan.mode == "apply"
        else plan.convergence_commands
    )
    for command in commands:
        environment = os.environ.copy()
        environment.update(command.env)
        kwargs: dict[str, object] = {
            "cwd": command.cwd,
            "env": environment,
            "check": True,
        }
        if command.quiet:
            kwargs["stdout"] = subprocess.DEVNULL
        subprocess.run(command.argv, **kwargs)


def main() -> None:
    parser = argparse.ArgumentParser(description="Run Maison user convergence")
    parser.add_argument("mode", choices=("plan", "apply"))
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--force-dotfiles", action="store_true")
    arguments = parser.parse_args()
    plan = build_command_plan(
        mode=arguments.mode,
        force_dotfiles=arguments.force_dotfiles,
        root=arguments.root,
        home=Path.home(),
    )
    run_command_plan(plan)


if __name__ == "__main__":
    main()
