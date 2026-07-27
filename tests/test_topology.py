from __future__ import annotations

import json
import os
import re
import stat
import subprocess
import tempfile
import tomllib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text()


class DataFilesTest(unittest.TestCase):
    def test_toml_files_parse(self) -> None:
        paths = sorted(ROOT.glob("*.toml")) + sorted((ROOT / "config/mise").glob("*.toml"))
        self.assertTrue(paths)
        for path in paths:
            with self.subTest(path=path.relative_to(ROOT)):
                with path.open("rb") as handle:
                    tomllib.load(handle)

    def test_json_files_parse(self) -> None:
        for path in sorted((ROOT / "dotfiles").rglob("*.json")):
            with self.subTest(path=path.relative_to(ROOT)):
                json.loads(path.read_text())

    def test_flake_lock_has_only_live_top_level_inputs(self) -> None:
        lock = json.loads(read("flake.lock"))
        root_inputs = set(lock["nodes"]["root"]["inputs"])
        self.assertEqual(
            root_inputs,
            {
                "darwin",
                "flake-parts",
                "nix-hex-box",
                "nix-homebrew",
                "nixpkgs",
                "system-manager",
            },
        )
        serialized = json.dumps(lock)
        self.assertNotIn("home-manager", serialized)
        self.assertNotIn('"deploy-rs"', serialized)


class OwnershipBoundaryTest(unittest.TestCase):
    def test_home_manager_is_removed_from_nix_graph(self) -> None:
        files = [ROOT / "flake.nix", *sorted((ROOT / "nix").rglob("*.nix"))]
        stale = []
        for path in files:
            text = path.read_text()
            if re.search(r"home-manager|homeConfigurations|homeConfig", text):
                stale.append(str(path.relative_to(ROOT)))
        self.assertEqual(stale, [])
        self.assertFalse((ROOT / "nix/modules/home").exists())
        self.assertFalse((ROOT / "packages.toml").exists())

    def test_system_outputs_are_explicit(self) -> None:
        outputs = read("nix/outputs.nix")
        for output in ("darwinConfigurations", "systemConfigs", "deploy"):
            self.assertRegex(outputs, rf"\b{re.escape(output)}\b")
        self.assertNotIn("homeConfigurations", outputs)

    def test_privileged_macos_state_remains_in_nix(self) -> None:
        darwin = read("nix/modules/darwin/system.nix")
        for token in (
            "security.pam.services.sudo_local",
            "touchIdAuth = true",
            "watchIdAuth = true",
            "reattach = true",
            "defaults.loginwindow.GuestEnabled = false",
            "remapCapsLockToEscape = true",
        ):
            self.assertIn(token, darwin)

    def test_user_defaults_do_not_claim_privileged_domains(self) -> None:
        with (ROOT / "config/mise/config.macos.toml").open("rb") as handle:
            data = tomllib.load(handle)
        defaults = data["bootstrap"]["macos"]["defaults"]
        banned = {
            "com.apple.loginwindow",
            "/Library/Preferences/com.apple.loginwindow",
            "/Library/Preferences/com.apple.alf",
            "com.apple.security",
        }
        self.assertTrue(banned.isdisjoint(defaults))
        self.assertIn("com.apple.dock", defaults)
        self.assertIn("com.apple.finder", defaults)

    def test_system_integrations_remain_nix_owned(self) -> None:
        fonts = read("nix/modules/darwin/fonts.nix")
        homebrew = read("nix/modules/darwin/homebrew-system.nix")
        mac_packages = read("config/mise/config.macos-arm64.toml")

        self.assertIn("fonts.packages", fonts)
        self.assertIn("nix-homebrew", homebrew)
        self.assertIn("fuse-t", homebrew)
        self.assertNotIn("brew-cask:font-", mac_packages)
        self.assertNotIn("fuse-t", mac_packages)

    def test_nix_system_package_closure_is_administrative(self) -> None:
        darwin = read("nix/modules/darwin/system.nix")
        for package in ("pkgs.nh", "pkgs.deploy-rs", "pkgs.nixd"):
            self.assertIn(package, darwin)
        for interactive in ("pkgs.helix", "pkgs.starship", "pkgs.git", "pkgs.ripgrep"):
            self.assertNotIn(interactive, darwin)

        linux = read("nix/modules/linux/system.nix")
        for package in ("pkgs.curl", "pkgs.gitMinimal", "pkgs.gnutar", "pkgs.nh"):
            self.assertIn(package, linux)
        for interactive in ("pkgs.helix", "pkgs.starship", "pkgs.ripgrep"):
            self.assertNotIn(interactive, linux)

    def test_global_mise_config_and_platform_files_are_deployed(self) -> None:
        root_config = read("mise.toml")
        for name in (
            "config.toml",
            "config.macos.toml",
            "config.macos-arm64.toml",
            "config.macos-x64.toml",
            "config.linux.toml",
        ):
            self.assertIn(f"~/.config/mise/{name}", root_config)
        self.assertNotIn('"~/.config/mise/mise.lock"', root_config)

        plan = read(".mise/tasks/user/plan")
        apply = read(".mise/tasks/user/apply")
        self.assertIn('user-link-mise-lock.sh" --dry-run', plan)
        self.assertIn('user-link-mise-lock.sh"', apply)

    def test_platform_package_policy(self) -> None:
        with (ROOT / "config/mise/config.macos-arm64.toml").open("rb") as handle:
            mac = tomllib.load(handle)
        with (ROOT / "config/mise/config.linux.toml").open("rb") as handle:
            linux = tomllib.load(handle)
        global_config = tomllib.loads(read("config/mise/config.toml"))
        mac_packages = mac["bootstrap"]["packages"]
        linux_packages = linux["bootstrap"]["packages"]
        self.assertEqual(
            global_config["plugins"]["nix"],
            "https://github.com/jbadeau/mise-nix.git",
        )
        self.assertEqual(
            global_config["tools"]["nix:deadnix"],
            "nixos/nixpkgs#deadnix",
        )
        self.assertEqual(
            global_config["tools"]["nix:devenv"],
            "nixos/nixpkgs#devenv",
        )
        self.assertEqual(global_config["tools"]["mas"], "latest")
        for package in ("brew:direnv", "brew:helix", "brew:git", "brew:starship", "brew:yazi"):
            self.assertIn(package, mac_packages)
            self.assertIn(package, linux_packages)
        self.assertNotIn("brew:nix-direnv", mac_packages)
        self.assertNotIn("brew:nix-direnv", linux_packages)
        for packages, managers in (
            (mac_packages, {"brew", "brew-cask", "mas"}),
            (linux_packages, {"brew"}),
        ):
            self.assertNotIn("brew:deadnix", packages)
            self.assertNotIn("brew:devenv", packages)
            self.assertFalse(any(package.startswith("nix:") for package in packages))
            self.assertTrue(
                all(package.partition(":")[0] in managers for package in packages),
            )
        self.assertNotIn("brew:mas", mac_packages)
        for package in ("brew-cask:ghostty", "brew-cask:zed", "mas:1352778147"):
            self.assertIn(package, mac_packages)
        self.assertNotIn("brew-cask:ghostty", linux_packages)


class DeploymentContractTest(unittest.TestCase):
    def test_deploy_rs_activates_exact_system_manager_profile(self) -> None:
        deployment = read("nix/lib/deployments.nix")
        self.assertIn('/nix/var/nix/profiles/system-manager-profiles/system-manager', deployment)
        self.assertIn("deployRs.mkActivation", deployment)
        self.assertIn("base = systemConfigs.${name}", deployment)
        self.assertIn('"$PROFILE/bin/activate"', deployment)
        self.assertIn("magicRollback", deployment)
        self.assertIn("autoRollback", deployment)

    def test_deploy_rs_uses_one_nixpkgs_package_revision(self) -> None:
        flake = read("flake.nix")
        outputs = read("nix/outputs.nix")
        adapter = read("nix/lib/deploy-rs.nix")

        self.assertNotIn("github:serokell/deploy-rs", flake)
        self.assertNotIn("inputs.deploy-rs", outputs)
        self.assertIn("deployPackage = pkgs.deploy-rs", adapter)
        self.assertIn("${deployPackage}/bin/activate", adapter)
        self.assertIn("pkgs.symlinkJoin", adapter)
        self.assertIn("${deploySource}/interface.json", adapter)

    def test_nix_check_is_warning_free_and_output_aware(self) -> None:
        script = read(".mise/tasks/check/nix")
        self.assertNotIn("flake check", script)
        self.assertIn("--no-update-lock-file", script)
        self.assertIn("Nix emitted warnings", script)
        for output in (
            ".#packages",
            ".#apps",
            ".#formatter",
            ".#checks",
            ".#darwinConfigurations",
            ".#systemConfigs",
            ".#deploy",
        ):
            self.assertIn(output, script)

    def test_rollbacks_do_not_double_advance_darwin_profile(self) -> None:
        script = read(".mise/tasks/system/rollback")
        darwin_block = script.split("Darwin)", 1)[1].split("Linux)", 1)[0]
        self.assertIn("darwin-rebuild switch --rollback", darwin_block)
        # The recovery nix-env fallback occurs only after both darwin-rebuild paths.
        self.assertLess(darwin_block.index("darwin-rebuild switch --rollback"), darwin_block.index("nix-env --rollback"))
        self.assertEqual(darwin_block.count("nix-env --rollback"), 1)

    def test_deploy_is_two_explicit_transactions(self) -> None:
        script = read(".mise/tasks/deploy")
        self.assertIn("mise run system:deploy", script)
        self.assertIn("mise run user:apply", script)
        self.assertLess(script.index("mise run system:deploy"), script.index("mise run user:apply"))


class MigrationBehaviorTest(unittest.TestCase):
    def test_nh_accepts_repository_flake_config_without_losing_existing_config(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            fake_nh = temp / "nh"
            capture = temp / "nix-config"
            fake_nh.write_text('#!/bin/sh\nprintf "%s" "$NIX_CONFIG" >"$NH_ENV_CAPTURE"\n')
            fake_nh.chmod(0o755)

            env = os.environ.copy()
            env["PATH"] = f"{temp}{os.pathsep}{env['PATH']}"
            env["NH_ENV_CAPTURE"] = str(capture)
            env["NIX_CONFIG"] = "access-tokens = github.com=redacted"
            subprocess.run(
                ["bash", "-c", "source .mise/lib/nix.sh; run_nh darwin build ."],
                cwd=ROOT,
                env=env,
                check=True,
            )

            config = capture.read_text()
            self.assertIn("access-tokens = github.com=redacted", config)
            self.assertIn("accept-flake-config = true", config)

    def test_forced_dotfile_handoff_backs_up_exact_conflicts(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            home = temp / "home"
            fake_bin = temp / "bin"
            fake_bin.mkdir()
            home.mkdir()

            miserc = home / ".miserc.toml"
            settings = home / ".config/zed/settings.json"
            keymap = home / ".config/zed/keymap.json"
            keymap_source = home / "keymap-source.json"
            settings.parent.mkdir(parents=True)
            miserc.write_text('auto_env = true\n')
            settings.write_text('{"theme":"Ayu"}\n')
            keymap_source.write_text('[{"key":"ctrl-p"}]\n')
            keymap.symlink_to(keymap_source)

            fake_mise = fake_bin / "mise"
            fake_mise.write_text(
                "#!/bin/sh\n"
                "cat >&2 <<'EOF'\n"
                "mise ERROR files: refusing to overwrite existing files (use --force-dotfiles):\n"
                "  ~/.miserc.toml\n"
                "  ~/.config/zed/settings.json\n"
                "  ~/.config/zed/keymap.json\n"
                "EOF\n"
                "exit 1\n"
            )
            fake_mise.chmod(0o755)

            env = os.environ.copy()
            env["HOME"] = str(home)
            env["PATH"] = f"{fake_bin}{os.pathsep}{env['PATH']}"
            subprocess.run(
                [str(ROOT / "scripts/user-prepare.sh"), "--force-dotfiles"],
                cwd=ROOT,
                env=env,
                check=True,
                capture_output=True,
                text=True,
            )

            self.assertFalse(miserc.exists())
            self.assertFalse(settings.exists())
            self.assertFalse(keymap.exists())

            backups = list((home / ".local/state/maison/backups/dotfiles").iterdir())
            self.assertEqual(len(backups), 1)
            backup = backups[0]
            self.assertEqual((backup / ".miserc.toml").read_text(), 'auto_env = true\n')
            self.assertEqual((backup / ".config/zed/settings.json").read_text(), '{"theme":"Ayu"}\n')
            keymap_backup = backup / ".config/zed/keymap.json"
            self.assertFalse(keymap_backup.is_symlink())
            self.assertEqual(keymap_backup.read_text(), '[{"key":"ctrl-p"}]\n')

    def test_mise_lockfile_link_is_plannable_and_applied_directly(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            home = temp / "home"
            home.mkdir()
            env = os.environ.copy()
            env["HOME"] = str(home)
            script = ROOT / "scripts/user-link-mise-lock.sh"

            preview = subprocess.run(
                [str(script), "--dry-run"],
                cwd=ROOT,
                env=env,
                check=True,
                capture_output=True,
                text=True,
            )
            target = home / ".config/mise/mise.lock"
            self.assertIn(str(ROOT / "config/mise/mise.lock"), preview.stdout)
            self.assertIn(str(target), preview.stdout)
            self.assertFalse(target.exists())

            subprocess.run([str(script)], cwd=ROOT, env=env, check=True)
            self.assertTrue(target.is_symlink())
            self.assertEqual(target.resolve(), ROOT / "config/mise/mise.lock")

    def test_user_preview_is_forced_but_apply_requires_explicit_opt_in(self) -> None:
        plan = read(".mise/tasks/user/plan")
        apply = read(".mise/tasks/user/apply")
        aggregate = read(".mise/tasks/plan")

        self.assertIn("--dry-run --force-dotfiles", plan)
        self.assertIn('prepare_args+=(--force-dotfiles)', apply)
        self.assertIn('user-prepare.sh" "${prepare_args[@]}"', apply)
        self.assertLess(aggregate.index("mise run user:plan"), aggregate.index("mise run system:plan"))


class RepositoryContractTest(unittest.TestCase):
    def test_task_and_script_entrypoints_are_executable(self) -> None:
        paths = [ROOT / "bootstrap.sh", ROOT / "bin/maison"]
        paths.extend(sorted((ROOT / ".mise/tasks").rglob("*")))
        paths.extend(sorted((ROOT / "scripts").glob("*.sh")))
        for path in paths:
            if not path.is_file():
                continue
            with self.subTest(path=path.relative_to(ROOT)):
                self.assertTrue(path.read_text().startswith("#!"))
                self.assertTrue(path.stat().st_mode & stat.S_IXUSR)

    def test_maison_exposes_layered_commands(self) -> None:
        cli = read("bin/maison")
        for command in ('cmd "check"', 'cmd "system"', 'cmd "user"', 'cmd "deploy"'):
            self.assertIn(command, cli)

    def test_build_matrix_has_no_home_manager_target(self) -> None:
        build = read(".github/scripts/build-platform-targets.sh")
        self.assertNotIn("homeConfigurations", build)
        self.assertIn("systemConfigs", build)
        self.assertIn("darwinConfigurations", build)


if __name__ == "__main__":
    unittest.main()
