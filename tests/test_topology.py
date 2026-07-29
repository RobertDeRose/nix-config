from __future__ import annotations

import json
import os
import re
import shutil
import stat
import subprocess
import tarfile
import tempfile
import textwrap
import tomllib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text()


def executable(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    path.chmod(0o755)


def copy_files(destination: Path, *names: str) -> None:
    for name in names:
        source = ROOT / name
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)


def git_init(path: Path) -> None:
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=path, check=True)
    subprocess.run(["git", "config", "user.name", "Maison Tests"], cwd=path, check=True)
    subprocess.run(["git", "config", "user.email", "tests@example.invalid"], cwd=path, check=True)


def git_commit_all(path: Path, message: str = "fixture") -> str:
    subprocess.run(["git", "add", "-A"], cwd=path, check=True)
    subprocess.run(["git", "commit", "-q", "-m", message], cwd=path, check=True)
    return subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=path, text=True).strip()


class DataFilesTest(unittest.TestCase):
    def test_toml_files_and_lockfiles_parse(self) -> None:
        paths = sorted(ROOT.glob("*.toml")) + sorted((ROOT / "config/mise").glob("*.toml"))
        paths += [path for path in (ROOT / "mise.lock", ROOT / "mise.dev.lock") if path.exists()]
        paths += sorted((ROOT / "config/mise").glob("*.lock"))
        self.assertTrue(paths)
        for path in paths:
            with self.subTest(path=path.relative_to(ROOT)):
                with path.open("rb") as handle:
                    tomllib.load(handle)

    def test_lockfiles_exactly_cover_their_tool_configs(self) -> None:
        pairs = (
            ("config/mise/config.toml", "config/mise/mise.lock"),
            ("config/mise/config.macos.toml", "config/mise/config.macos.lock"),
            ("mise.dev.toml", "mise.dev.lock"),
        )
        for config_name, lock_name in pairs:
            with self.subTest(config=config_name, lock=lock_name):
                config = tomllib.loads(read(config_name)).get("tools", {})
                lock = tomllib.loads(read(lock_name)).get("tools", {})
                self.assertEqual(set(lock), set(config))

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

    def test_nix_formatter_uses_the_contributor_lock(self) -> None:
        lock = tomllib.loads(read("mise.dev.lock"))
        entries = lock["tools"]["aqua:Mic92/nixfmt-rs"]
        self.assertEqual(len(entries), 1)
        entry = entries[0]
        version = entry["version"]
        platform_keys = {
            "aarch64-darwin": "platforms.macos-arm64",
            "aarch64-linux": "platforms.linux-arm64",
            "x86_64-linux": "platforms.linux-x64",
        }
        for system, platform_key in platform_keys.items():
            with self.subTest(system=system):
                artifact = entry[platform_key]
                self.assertIn(f"/{version}/", artifact["url"])
                self.assertRegex(artifact["checksum"], r"^sha256:[0-9a-f]{64}$")

        package = read("nix/lib/nixfmt-rs.nix")
        outputs = read("nix/outputs.nix")
        self.assertIn("builtins.readFile ../../mise.dev.lock", package)
        for system, platform_key in platform_keys.items():
            self.assertIn(f'{system} = "{platform_key}";', package)
        self.assertIn("pkgs.nixfmt-tree.override { inherit nixfmtPackage; }", outputs)
        self.assertIn("nixfmt = nixfmtPackage;", outputs)
        self.assertNotIn("formatter = pkgs.nixfmt-tree;", outputs)


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
            "config.linux.toml",
        ):
            self.assertIn(f"~/.config/mise/{name}", root_config)
        self.assertNotIn("config.macos-x64.toml", root_config)
        self.assertNotIn('"~/.config/mise/mise.lock"', root_config)

        plan = read(".mise/tasks/user/plan")
        apply = read(".mise/tasks/user/apply")
        self.assertIn('user-link-mise-lock.sh" --dry-run', plan)
        self.assertIn('user-link-mise-lock.sh"', apply)
        lock_script = read("scripts/user-link-mise-lock.sh")
        self.assertIn("mise.lock", lock_script)
        self.assertIn("config.macos.lock", lock_script)

    def test_platform_package_policy_and_single_ownership(self) -> None:
        common = tomllib.loads(read("config/mise/config.toml"))
        mac = tomllib.loads(read("config/mise/config.macos.toml"))
        mac_arm = tomllib.loads(read("config/mise/config.macos-arm64.toml"))
        linux = tomllib.loads(read("config/mise/config.linux.toml"))

        common_packages = common["bootstrap"]["packages"]
        mac_packages = mac_arm["bootstrap"]["packages"]
        self.assertNotIn("bootstrap", linux)
        for package in ("brew:direnv", "brew:helix", "brew:git", "brew:starship", "brew:yazi"):
            self.assertIn(package, common_packages)
        for package in ("brew-cask:ghostty", "brew-cask:zed", "mas:1352778147"):
            self.assertIn(package, mac_packages)
        self.assertFalse(set(common_packages) & set(mac_packages))

        tools = common["tools"]
        self.assertNotIn("bat", tools)
        self.assertIn("brew:bat", common_packages)

        active_tool_tables = {
            "common": tools,
            "mac": mac["tools"],
            "dev": tomllib.loads(read("mise.dev.toml"))["tools"],
        }
        for left_name, left in active_tool_tables.items():
            for right_name, right in active_tool_tables.items():
                if left_name >= right_name:
                    continue
                self.assertFalse(
                    set(left) & set(right),
                    f"duplicate tool ownership between {left_name} and {right_name}",
                )
        brew_formulae = {
            package.removeprefix("brew:")
            for package in common_packages
            if package.startswith("brew:")
        }
        self.assertFalse(set(tools) & brew_formulae)

        for ai_tool in (
            "codex",
            "npm:@earendil-works/pi-coding-agent",
            "npm:@fission-ai/openspec",
            "opencode",
        ):
            self.assertIn(ai_tool, mac["tools"])
            self.assertNotIn(ai_tool, tools)

    def test_intel_darwin_is_removed_from_supported_surface(self) -> None:
        candidates = [
            ROOT / "README.md",
            ROOT / "mise.toml",
            ROOT / "config/mise/config.toml",
            ROOT / ".mise/lib/platform.sh",
            ROOT / ".github/scripts/build-platform-targets.sh",
            ROOT / "nix/lib/validation.nix",
            ROOT / "nix/outputs.nix",
        ]
        candidates += list((ROOT / "docs").rglob("*.md"))
        candidates += [path for path in (ROOT / "mise.lock", ROOT / "mise.dev.lock") if path.exists()]
        candidates += list((ROOT / "config/mise").glob("*.lock"))
        for path in candidates:
            with self.subTest(path=path.relative_to(ROOT)):
                text = path.read_text()
                self.assertNotIn("x86_64-darwin", text)
                self.assertNotIn("macos-x64", text)
        self.assertFalse((ROOT / "config/mise/config.macos-x64.toml").exists())

    def test_repository_tools_are_isolated_from_machine_convergence(self) -> None:
        base = tomllib.loads(read("mise.toml"))
        dev = tomllib.loads(read("mise.dev.toml"))
        self.assertNotIn("tools", base)
        self.assertEqual(tomllib.loads(read("config/mise/config.toml"))["tools"]["usage"], "latest")
        for tool in ("actionlint", "hk", "shellcheck", "shfmt", "tombi"):
            self.assertIn(tool, dev["tools"])
        self.assertNotIn("jq", dev["tools"])
        user_apply = read(".mise/tasks/user/apply")
        self.assertNotIn("mise install", user_apply)
        self.assertIn("mise -E dev install", read(".mise/tasks/check/_default"))

    def test_nix_direnv_uses_pinned_direnvrc(self) -> None:
        root_config = read("mise.toml")
        direnvrc = read("dotfiles/direnv/direnvrc")
        self.assertIn("~/.config/direnv/direnvrc", root_config)
        self.assertIn("nix_direnv_version 3.1.1", direnvrc)
        self.assertIn("nix-community/nix-direnv/3.1.1/direnvrc", direnvrc)
        self.assertIn("sha256-p+fzQdrms/hDa7g+soShAybJNo4bN4SIAeSfqNKgD5I=", direnvrc)


class InventoryBehaviorTest(unittest.TestCase):
    def run_inventory(self, path: Path, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(ROOT / ".mise/lib/inventory.py"), "--file", str(path), *args],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )

    def test_repository_inventory_validates_with_typed_reader(self) -> None:
        result = self.run_inventory(ROOT / "inventory.toml", "--repo-root", str(ROOT), "validate")
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = self.run_inventory(ROOT / "inventory.toml", "host-rows", "--system", "aarch64-linux")
        self.assertEqual(rows.returncode, 0, rows.stderr)
        self.assertIn("dev-som\trderose\tRobert DeRose", rows.stdout)

    def test_shell_inventory_falls_back_to_flake_app_without_tomllib(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            fake_bin = temp / "bin"
            fake_bin.mkdir()
            log = temp / "nix-log"
            executable(fake_bin / "python3", "#!/bin/sh\nexit 1\n")
            executable(
                fake_bin / "nix",
                "#!/bin/sh\n"
                'printf "%s\n" "$*" >"$NIX_LOG"\n'
                'while [ "$#" -gt 0 ]; do [ "$1" = -- ] && { shift; break; }; shift; done\n'
                'exec "$REAL_PYTHON" "$INVENTORY_SCRIPT" "$@"\n',
            )
            env = os.environ.copy()
            env.update(
                {
                    "PATH": f"{fake_bin}{os.pathsep}{env['PATH']}",
                    "NIX_LOG": str(log),
                    "REAL_PYTHON": os.fspath(Path(os.sys.executable)),
                    "INVENTORY_SCRIPT": str(ROOT / ".mise/lib/inventory.py"),
                }
            )
            result = subprocess.run(
                [
                    "bash",
                    "-c",
                    'source "$1/.mise/lib/inventory.sh"; inventory_hosts "$1"',
                    "_",
                    str(ROOT),
                ],
                cwd=ROOT,
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("USMBDEROSER", result.stdout)
            self.assertIn("#maison-inventory -- --file", log.read_text())

    def test_inventory_rejects_intel_and_unsafe_deploy_paths(self) -> None:
        original = read("inventory.toml")
        cases = {
            "intel": original.replace('system = "aarch64-darwin"', 'system = "x86_64-darwin"', 1),
            "home": original.replace('repo_path = "/home/rderose/.maison"', 'repo_path = "/home/rderose"'),
            "escape": original.replace('repo_path = "/home/rderose/.maison"', 'repo_path = "/home/rderose/../root"'),
            "root": original.replace('repo_path = "/home/rderose/.maison"', 'repo_path = "/"'),
            "unsafe-character": original.replace(
                'repo_path = "/home/rderose/.maison"',
                'repo_path = "/home/rderose/Maison Config"',
            ),
            "trailing-host-dot": original.replace(
                'hostname = "dev-som.checkpoint-device.com"',
                'hostname = "dev-som.checkpoint-device.com."',
            ),
            "wrong-user": original.replace(
                'user_ssh_user = "rderose"',
                'user_ssh_user = "somebody-else"',
            ),
        }
        with tempfile.TemporaryDirectory() as directory:
            for label, content in cases.items():
                with self.subTest(case=label):
                    path = Path(directory) / f"{label}.toml"
                    path.write_text(content)
                    result = self.run_inventory(path, "validate")
                    self.assertNotEqual(result.returncode, 0)


class DeploymentContractTest(unittest.TestCase):
    def deployment_environment(self, temp: Path, home: Path) -> tuple[str, dict[str, str]]:
        """Provide a deterministic portable Linux deployment user."""

        user = "maison-test"
        real_mv = shutil.which("mv")
        real_tar = shutil.which("tar")
        if real_mv is None or real_tar is None:
            self.skipTest("mv and tar are required for deployment contract tests")
        fake_bin = temp / "deployment-bin"
        executable(
            fake_bin / "id",
            textwrap.dedent(
                f"""\
                #!/bin/sh
                case "${{1:-}}" in
                  -u) printf '%s\\n' 501 ;;
                  -un) printf '%s\\n' {user} ;;
                  {user}) exit 0 ;;
                  *) exit 1 ;;
                esac
                """
            ),
        )
        executable(
            fake_bin / "mv",
            textwrap.dedent(
                """\
                #!/bin/sh
                case "${1:-}" in
                  --version | -T) exit 64 ;;
                esac
                exec "$MAISON_TEST_REAL_MV" "$@"
                """
            ),
        )
        executable(
            fake_bin / "tar",
            textwrap.dedent(
                """\
                #!/bin/sh
                [ "${1:-}" != --no-same-owner ] || exit 64
                exec "$MAISON_TEST_REAL_TAR" "$@"
                """
            ),
        )
        env = os.environ.copy()
        env.update(
            {
                "PATH": f"{fake_bin}{os.pathsep}{env['PATH']}",
                "MAISON_MANAGED_HOME": str(home),
                "MAISON_TEST_REAL_MV": real_mv,
                "MAISON_TEST_REAL_TAR": real_tar,
            }
        )
        return user, env

    def test_deploy_rs_activates_exact_system_manager_profile(self) -> None:
        deployment = read("nix/lib/deployments.nix")
        adapter = read("nix/lib/deploy-rs.nix")
        self.assertIn('/nix/var/nix/profiles/system-manager-profiles/system-manager', deployment)
        self.assertIn("deployRs.mkActivation", deployment)
        self.assertIn("base = systemConfigs.${name}", deployment)
        self.assertIn('"$PROFILE/bin/activate"', deployment)
        self.assertIn("boot = activateSystem", deployment)
        self.assertIn("DRY_ACTIVATE=1", adapter)
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

    def test_upstream_system_manager_tests_remain_enabled(self) -> None:
        self.assertFalse((ROOT / "nix/lib/system-manager-no-check-overlay.nix").exists())
        combined = "\n".join(path.read_text() for path in (ROOT / "nix").rglob("*.nix"))
        self.assertNotIn("doCheck = false", combined)
        self.assertIn("Keep upstream Rust checks enabled", read("nix/lib/mk-linux-host.nix"))

    def test_nix_checks_are_realized_in_ci(self) -> None:
        check = read(".mise/tasks/check/nix")
        matrix = read(".github/scripts/build-platform-targets.sh")
        self.assertIn("run_nix_checked build", check)
        self.assertIn('.#checks.', check)
        self.assertIn('attribute_names ".#checks.', matrix)
        self.assertIn('build_target ".#checks.', matrix)

    def test_rollbacks_do_not_double_advance_darwin_profile(self) -> None:
        script = read(".mise/tasks/system/rollback")
        darwin_block = script.split("Darwin)", 1)[1].split("Linux)", 1)[0]
        self.assertIn("darwin-rebuild switch --rollback", darwin_block)
        self.assertLess(
            darwin_block.index("darwin-rebuild switch --rollback"),
            darwin_block.index("nix-env --rollback"),
        )
        self.assertEqual(darwin_block.count("nix-env --rollback"), 1)

    def test_deploy_is_two_explicit_transactions(self) -> None:
        script = read(".mise/tasks/deploy")
        self.assertIn("scripts/create-deploy-archive.sh", script)
        self.assertIn("scripts/deploy-repository.sh", script)
        self.assertIn("scripts/finalize-deploy-repository.sh", script)
        self.assertIn("mktemp /tmp/maison-deploy.XXXXXX.tar.gz", script)
        self.assertNotIn("maison-deploy-${host}-$$", script)
        self.assertIn("mise run system:deploy", script)
        self.assertIn("mise run user:apply", script)
        self.assertLess(script.index("mise run system:deploy"), script.index("mise run user:apply"))

    def test_deploy_archive_contains_committed_content_only(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            repo = temp / "repo"
            repo.mkdir()
            (repo / "mise.toml").write_text("[settings]\n")
            (repo / "flake.nix").write_text("{}\n")
            (repo / "tracked.txt").write_text("tracked\n")
            (repo / ".gitignore").write_text("ignored-secret\n")
            git_init(repo)
            revision = git_commit_all(repo)
            (repo / "ignored-secret").write_text("must not deploy\n")

            archive = temp / "deploy.tar.gz"
            subprocess.run(
                [str(ROOT / "scripts/create-deploy-archive.sh"), str(repo), str(archive)],
                check=True,
            )
            with tarfile.open(archive, "r:gz") as bundle:
                names = {name.removeprefix("./") for name in bundle.getnames()}
                self.assertIn("tracked.txt", names)
                self.assertIn(".maison-revision", names)
                self.assertNotIn(".git", names)
                self.assertNotIn("ignored-secret", names)
                revision_file = bundle.extractfile("./.maison-revision") or bundle.extractfile(".maison-revision")
                assert revision_file is not None
                self.assertEqual(revision_file.read().decode().strip(), revision)

            (repo / "untracked-secret").write_text("must fail\n")
            refused = subprocess.run(
                [str(ROOT / "scripts/create-deploy-archive.sh"), str(repo), str(temp / "refused.tar.gz")],
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(refused.returncode, 0)
            self.assertIn("clean working tree", refused.stderr)

    def test_repository_stage_rolls_back_and_commits(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            physical_root = temp / "private"
            physical_root.mkdir()
            alias_root = temp / "var"
            alias_root.symlink_to(physical_root, target_is_directory=True)
            home = alias_root / "home"
            home.mkdir()
            self.assertNotEqual(home, home.resolve())
            user, env = self.deployment_environment(temp, home)
            repo = home / ".maison"
            repo.mkdir()
            (repo / "old-marker").write_text("old\n")

            def make_archive(path: Path, revision: str) -> None:
                source = temp / f"source-{revision}"
                source.mkdir()
                (source / "mise.toml").write_text("[settings]\n")
                (source / "flake.nix").write_text("{}\n")
                (source / ".maison-revision").write_text(f"{revision}\n")
                with tarfile.open(path, "w:gz") as bundle:
                    for child in source.iterdir():
                        bundle.add(child, arcname=child.name)

            archive = temp / "one.tar.gz"
            revision_one = "1" * 40
            make_archive(archive, revision_one)
            subprocess.run(
                [str(ROOT / "scripts/deploy-repository.sh"), str(repo), user, str(archive)],
                env=env,
                check=True,
            )
            self.assertEqual((repo / ".maison-revision").read_text().strip(), revision_one)
            self.assertTrue((Path(f"{repo}.previous") / "old-marker").exists())
            subprocess.run(
                [str(ROOT / "scripts/finalize-deploy-repository.sh"), str(repo), user, "rollback"],
                env=env,
                check=True,
            )
            self.assertTrue((repo / "old-marker").exists())
            self.assertFalse(Path(f"{repo}.deploy-state").exists())

            archive = temp / "two.tar.gz"
            revision_two = "2" * 40
            make_archive(archive, revision_two)
            subprocess.run(
                [str(ROOT / "scripts/deploy-repository.sh"), str(repo), user, str(archive)],
                env=env,
                check=True,
            )
            subprocess.run(
                [str(ROOT / "scripts/finalize-deploy-repository.sh"), str(repo), user, "commit"],
                env=env,
                check=True,
            )
            self.assertEqual((repo / ".maison-revision").read_text().strip(), revision_two)
            self.assertFalse(Path(f"{repo}.previous").exists())
            self.assertFalse(Path(f"{repo}.deploy-state").exists())

            unsafe = subprocess.run(
                [str(ROOT / "scripts/deploy-repository.sh"), str(temp / "outside"), user, str(temp / "missing")],
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(unsafe.returncode, 0)
            self.assertIn("must be below", unsafe.stderr)

            dot_segment = subprocess.run(
                [str(ROOT / "scripts/deploy-repository.sh"), str(home / "nested/.."), user, str(archive)],
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(dot_segment.returncode, 0)
            self.assertIn("dot segments", dot_segment.stderr)

            archive_link = temp / "archive-link.tar.gz"
            archive_link.symlink_to(archive)
            symlink_archive = subprocess.run(
                [str(ROOT / "scripts/deploy-repository.sh"), str(home / "other"), user, str(archive_link)],
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(symlink_archive.returncode, 0)
            self.assertIn("regular non-symlink", symlink_archive.stderr)


    def test_finalize_never_deletes_active_repo_when_previous_is_missing(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            home = temp / "home"
            home.mkdir()
            user, env = self.deployment_environment(temp, home)

            repo = home / ".maison"
            repo.mkdir()
            (repo / "old-marker").write_text("old\n")
            source = temp / "source"
            source.mkdir()
            (source / "mise.toml").write_text("[settings]\n")
            (source / "flake.nix").write_text("{}\n")
            revision = "3" * 40
            (source / ".maison-revision").write_text(f"{revision}\n")
            archive = temp / "deploy.tar.gz"
            with tarfile.open(archive, "w:gz") as bundle:
                for child in source.iterdir():
                    bundle.add(child, arcname=child.name)

            subprocess.run(
                [str(ROOT / "scripts/deploy-repository.sh"), str(repo), user, str(archive)],
                env=env,
                check=True,
            )
            shutil.rmtree(Path(f"{repo}.previous"))
            failed = subprocess.run(
                [str(ROOT / "scripts/finalize-deploy-repository.sh"), str(repo), user, "rollback"],
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(failed.returncode, 0)
            self.assertIn("previous repository is missing or unsafe", failed.stderr)
            self.assertEqual((repo / ".maison-revision").read_text().strip(), revision)
            self.assertTrue(Path(f"{repo}.deploy-state").exists())



class TransactionBehaviorTest(unittest.TestCase):
    def make_config_repo(self, temp: Path) -> Path:
        repo = temp / "repo"
        (repo / "config/mise").mkdir(parents=True)
        copy_files(
            repo,
            ".mise/lib/config_edit.py",
            ".mise/lib/transaction.sh",
            "scripts/user-apply-packages.sh",
        )
        return repo

    def test_host_add_restores_inventory_when_override_commit_fails(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            repo = temp / "repo"
            repo.mkdir()
            copy_files(
                repo,
                ".mise/tasks/host/add",
                ".mise/lib/common.sh",
                ".mise/lib/platform.sh",
                ".mise/lib/inventory.sh",
                ".mise/lib/inventory.py",
                ".mise/lib/transaction.sh",
                "inventory.toml",
            )
            original = (repo / "inventory.toml").read_text()
            (repo / "hosts").write_text("blocks directory creation\n")
            env = os.environ.copy()
            env.update(
                {
                    "MISE_PROJECT_ROOT": str(repo),
                    "usage_hostname": "rollback-host",
                    "usage_system": "aarch64-linux",
                    "usage_user": "rderose",
                    "usage_profiles": "base,linux",
                    "usage_overrides": "true",
                }
            )
            result = subprocess.run(
                [str(repo / ".mise/tasks/host/add")],
                env=env,
                cwd=repo,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual((repo / "inventory.toml").read_text(), original)
            self.assertFalse((repo / "hosts/rollback-host").exists())

    def test_package_and_app_add_do_not_record_failed_installs(self) -> None:
        cases = [
            (".mise/tasks/package/add", "config.toml", {"usage_package": "brew:new-package"}),
            (".mise/tasks/app/add", "config.macos-arm64.toml", {"usage_cask": "new-app"}),
        ]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for index, (task_name, config_name, extra_env) in enumerate(cases):
                with self.subTest(task=task_name):
                    temp = root / str(index)
                    repo = self.make_config_repo(temp)
                    copy_files(repo, task_name)
                    config = repo / "config/mise" / config_name
                    config.write_text('[bootstrap.packages]\n"brew:existing" = "latest"\n')
                    original = config.read_text()
                    fake_bin = temp / "bin"
                    fake_bin.mkdir(parents=True)
                    executable(fake_bin / "mise", "#!/bin/sh\necho unrelated failure >&2\nexit 23\n")
                    env = os.environ.copy()
                    env.update(extra_env)
                    env["MISE_PROJECT_ROOT"] = str(repo)
                    env["PATH"] = f"{fake_bin}{os.pathsep}{env['PATH']}"
                    result = subprocess.run(
                        [str(repo / task_name)],
                        env=env,
                        cwd=repo,
                        capture_output=True,
                        text=True,
                    )
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(config.read_text(), original)

    def test_remove_mutators_leave_config_unchanged_when_target_is_absent(self) -> None:
        cases = [
            (".mise/tasks/package/remove", "config.toml", {"usage_package": "brew:missing"}),
            (".mise/tasks/app/remove", "config.macos-arm64.toml", {"usage_cask": "missing"}),
            (".mise/tasks/tool/remove", "config.toml", {"usage_tool": "missing"}),
        ]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for index, (task_name, config_name, extra_env) in enumerate(cases):
                with self.subTest(task=task_name):
                    temp = root / str(index)
                    repo = self.make_config_repo(temp)
                    copy_files(repo, task_name)
                    config = repo / "config/mise" / config_name
                    if "tool/remove" in task_name:
                        config.write_text('[tools]\nnode = "24"\n')
                    else:
                        config.write_text('[bootstrap.packages]\n"brew:existing" = "latest"\n')
                    original = config.read_text()
                    env = os.environ.copy()
                    env.update(extra_env)
                    env["MISE_PROJECT_ROOT"] = str(repo)
                    result = subprocess.run(
                        [str(repo / task_name)],
                        env=env,
                        cwd=repo,
                        capture_output=True,
                        text=True,
                    )
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(config.read_text(), original)

    def test_tool_remove_cannot_remove_maison_runtime_by_version(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            root = self.make_config_repo(temp)
            copy_files(root, ".mise/tasks/tool/remove")
            config = root / "config/mise/config.toml"
            lock = root / "config/mise/mise.lock"
            config.write_text('[tools]\nusage = "latest"\n')
            lock.write_text('[[tools.usage]]\nversion = "1.0.0"\n')
            before_config = config.read_bytes()
            before_lock = lock.read_bytes()
            env = os.environ.copy()
            env.update({"MISE_PROJECT_ROOT": str(root), "usage_tool": "usage@latest"})
            result = subprocess.run([str(root / ".mise/tasks/tool/remove")], env=env)
            self.assertEqual(result.returncode, 2)
            self.assertEqual(config.read_bytes(), before_config)
            self.assertEqual(lock.read_bytes(), before_lock)

    def test_tool_remove_updates_config_and_lock_together(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            repo = self.make_config_repo(temp)
            copy_files(repo, ".mise/tasks/tool/remove")
            config = repo / "config/mise/config.toml"
            lock = repo / "config/mise/mise.lock"
            config.write_text('[tools]\nnode = "24"\nusage = "latest"\n')
            lock.write_text(
                '[[tools.node]]\nversion = "24.1.0"\nbackend = "core:node"\n\n'
                '[[tools.usage]]\nversion = "2.1.0"\nbackend = "aqua:jdx/usage"\n'
            )
            env = os.environ.copy()
            env.update({"MISE_PROJECT_ROOT": str(repo), "usage_tool": "node"})
            subprocess.run(
                [str(repo / ".mise/tasks/tool/remove")],
                cwd=repo,
                env=env,
                check=True,
            )
            with config.open("rb") as handle:
                tools = tomllib.load(handle)["tools"]
            with lock.open("rb") as handle:
                locked = tomllib.load(handle)["tools"]
            self.assertNotIn("node", tools)
            self.assertNotIn("node", locked)
            self.assertIn("usage", tools)
            self.assertIn("usage", locked)

            env["usage_tool"] = "usage"
            refused = subprocess.run(
                [str(repo / ".mise/tasks/tool/remove")],
                cwd=repo,
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertEqual(refused.returncode, 2)
            self.assertIn("command runtime", refused.stderr)

    def test_tool_remove_relocks_remaining_versions_transactionally(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            repo = self.make_config_repo(temp)
            copy_files(repo, ".mise/tasks/tool/remove")
            config = repo / "config/mise/config.toml"
            lock = repo / "config/mise/mise.lock"
            original_config = '[settings]\nlockfile = true\n\n[tools]\nnode = ["24", "lts"]\nusage = "latest"\n'
            original_lock = (
                '[[tools.node]]\nversion = "24.18.0"\nbackend = "core:node"\n\n'
                '[[tools.node]]\nversion = "22.20.0"\nbackend = "core:node"\n\n'
                '[[tools.usage]]\nversion = "2.1.0"\nbackend = "aqua:jdx/usage"\n'
            )
            config.write_text(original_config)
            lock.write_text(original_lock)
            fake_bin = temp / "bin"
            fake_bin.mkdir()
            log = temp / "mise-log"
            executable(
                fake_bin / "mise",
                textwrap.dedent(
                    """\
                    #!/bin/sh
                    printf '%s\\n' "$*" >"$MISE_LOG"
                    [ "$1" = lock ] && [ "$2" = --global ] && [ "$3" = node ] || exit 12
                    grep -Fq 'node = "lts"' "$MISE_GLOBAL_CONFIG_FILE" || exit 13
                    cat >"$(dirname "$MISE_GLOBAL_CONFIG_FILE")/mise.lock" <<'EOF'
                    [[tools.node]]
                    version = "22.20.0"
                    backend = "core:node"

                    [[tools.usage]]
                    version = "2.1.0"
                    backend = "aqua:jdx/usage"
                    EOF
                    """
                ),
            )
            env = os.environ.copy()
            env.update(
                {
                    "MISE_PROJECT_ROOT": str(repo),
                    "PATH": f"{fake_bin}{os.pathsep}{env['PATH']}",
                    "MISE_LOG": str(log),
                    "usage_tool": "node@24",
                }
            )
            subprocess.run(
                [str(repo / ".mise/tasks/tool/remove")],
                cwd=repo,
                env=env,
                check=True,
            )
            self.assertEqual(tomllib.loads(config.read_text())["tools"]["node"], "lts")
            self.assertEqual(
                [entry["version"] for entry in tomllib.loads(lock.read_text())["tools"]["node"]],
                ["22.20.0"],
            )
            self.assertEqual(log.read_text().strip(), "lock --global node")

            config.write_text(original_config)
            lock.write_text(original_lock)
            executable(fake_bin / "mise", "#!/bin/sh\nexit 31\n")
            failed = subprocess.run(
                [str(repo / ".mise/tasks/tool/remove")],
                cwd=repo,
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertEqual(failed.returncode, 31)
            self.assertEqual(config.read_text(), original_config)
            self.assertEqual(lock.read_text(), original_lock)

    def test_tool_add_rolls_back_config_and_lock_on_resolution_warning(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            repo = self.make_config_repo(temp)
            copy_files(repo, ".mise/tasks/tool/add")
            config = repo / "config/mise/config.toml"
            lock = repo / "config/mise/mise.lock"
            original_config = '[tools]\nnode = "24"\n'
            original_lock = "lock-before\n"
            config.write_text(original_config)
            lock.write_text(original_lock)
            fake_bin = temp / "bin"
            fake_bin.mkdir()
            executable(
                fake_bin / "mise",
                "#!/bin/sh\n"
                'printf "# lock-after\\n" >"$(dirname "$MISE_GLOBAL_CONFIG_FILE")/mise.lock"\n'
                "echo 'mise WARN Failed to resolve tool version list for broken'\n"
                "exit 0\n",
            )
            env = os.environ.copy()
            env.update(
                {
                    "MISE_PROJECT_ROOT": str(repo),
                    "PATH": f"{fake_bin}{os.pathsep}{env['PATH']}",
                    "usage_tool": "aqua:gastownhall/beads",
                    "usage_version": "latest",
                }
            )
            result = subprocess.run(
                [str(repo / ".mise/tasks/tool/add")], cwd=repo, env=env, capture_output=True, text=True
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(config.read_text(), original_config)
            self.assertEqual(lock.read_text(), original_lock)
            self.assertIn("repository config and lock were not changed", result.stderr)

    def test_tool_add_restores_lock_when_config_commit_fails(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            repo = self.make_config_repo(temp)
            copy_files(repo, ".mise/tasks/tool/add")
            config = repo / "config/mise/config.toml"
            lock = repo / "config/mise/mise.lock"
            original_config = '[tools]\nnode = "24"\n'
            original_lock = "lock-before\n"
            config.write_text(original_config)
            lock.write_text(original_lock)
            fake_bin = temp / "bin"
            fake_bin.mkdir()
            executable(
                fake_bin / "mise",
                "#!/bin/sh\n"
                'printf "# lock-after\n" >"$(dirname "$MISE_GLOBAL_CONFIG_FILE")/mise.lock"\n'
                "echo installed\n",
            )
            executable(
                fake_bin / "mv",
                "#!/bin/sh\n"
                'last=""; for arg in "$@"; do last="$arg"; done\n'
                'if [ "$last" = "$FAIL_DEST" ] && [ ! -e "$FAIL_MARKER" ]; then\n'
                '  : >"$FAIL_MARKER"; exit 71\n'
                "fi\n"
                'exec /bin/mv "$@"\n',
            )
            env = os.environ.copy()
            env.update(
                {
                    "MISE_PROJECT_ROOT": str(repo),
                    "PATH": f"{fake_bin}{os.pathsep}{env['PATH']}",
                    "usage_tool": "aqua:gastownhall/beads",
                    "usage_version": "1.1.0",
                    "FAIL_DEST": str(config),
                    "FAIL_MARKER": str(temp / "failed-once"),
                }
            )
            result = subprocess.run(
                [str(repo / ".mise/tasks/tool/add")],
                cwd=repo,
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(config.read_text(), original_config)
            self.assertEqual(lock.read_text(), original_lock)

    def test_tool_add_commits_config_and_candidate_lock_after_success(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            repo = self.make_config_repo(temp)
            copy_files(repo, ".mise/tasks/tool/add")
            config = repo / "config/mise/config.toml"
            lock = repo / "config/mise/mise.lock"
            config.write_text('[tools]\nnode = "24"\n')
            lock.write_text("lock-before\n")
            fake_bin = temp / "bin"
            fake_bin.mkdir()
            executable(
                fake_bin / "mise",
                "#!/bin/sh\n"
                'printf "# lock-after\\n" >"$(dirname "$MISE_GLOBAL_CONFIG_FILE")/mise.lock"\n'
                "echo installed\n",
            )
            env = os.environ.copy()
            env.update(
                {
                    "MISE_PROJECT_ROOT": str(repo),
                    "PATH": f"{fake_bin}{os.pathsep}{env['PATH']}",
                    "usage_tool": "aqua:gastownhall/beads",
                    "usage_version": "1.1.0",
                }
            )
            subprocess.run([str(repo / ".mise/tasks/tool/add")], cwd=repo, env=env, check=True)
            with config.open("rb") as handle:
                tools = tomllib.load(handle)["tools"]
            self.assertEqual(tools["aqua:gastownhall/beads"], "1.1.0")
            self.assertEqual(lock.read_text(), "# lock-after\n")


class MigrationBehaviorTest(unittest.TestCase):
    def test_apply_is_system_first_and_stops_before_user_on_system_failure(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            fake_bin = temp / "bin"
            fake_bin.mkdir()
            log = temp / "calls"
            executable(
                fake_bin / "mise",
                "#!/bin/sh\n"
                'printf "%s\\n" "$*" >>"$TEST_LOG"\n'
                'case "$*" in *system:apply*) [ "${FAIL_SYSTEM:-false}" != true ] || exit 42;; esac\n',
            )
            env = os.environ.copy()
            env["PATH"] = f"{fake_bin}{os.pathsep}{env['PATH']}"
            env["TEST_LOG"] = str(log)
            subprocess.run([str(ROOT / ".mise/tasks/apply")], env=env, cwd=ROOT, check=True)
            calls = log.read_text().splitlines()
            self.assertIn("system:apply", calls[0])
            self.assertIn("user:apply", calls[1])

            log.write_text("")
            env["FAIL_SYSTEM"] = "true"
            failed = subprocess.run([str(ROOT / ".mise/tasks/apply")], env=env, cwd=ROOT)
            self.assertEqual(failed.returncode, 42)
            calls = log.read_text().splitlines()
            self.assertEqual(len(calls), 1)
            self.assertIn("system:apply", calls[0])

    def test_docker_completion_handoff_is_exact_and_retried_once(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            prefix = temp / "prefix"
            docker = temp / "Docker.app"
            target = prefix / "share/fish/vendor_completions.d/docker-compose.fish"
            source = docker / "Contents/Resources/etc/docker-compose.fish-completion"
            source.parent.mkdir(parents=True)
            source.write_text("completion\n")
            target.parent.mkdir(parents=True)
            target.symlink_to(source)
            fake_bin = temp / "bin"
            fake_bin.mkdir()
            counter = temp / "counter"
            executable(
                fake_bin / "mise",
                textwrap.dedent(
                    """\
                    #!/bin/sh
                    count=0
                    [ ! -f "$COUNTER" ] || count=$(cat "$COUNTER")
                    count=$((count + 1))
                    printf '%s\\n' "$count" >"$COUNTER"
                    if [ "$count" -eq 1 ]; then
                      message="mise ERROR completion target '$TEST_TARGET' already points to"
                      message="$message '$TEST_SOURCE' and is not owned by cask 'docker-desktop'"
                      printf '%s\\n' "$message" >&2
                      exit 1
                    fi
                    [ ! -e "$TEST_TARGET" ]
                    """
                ),
            )
            env = os.environ.copy()
            env.update(
                {
                    "PATH": f"{fake_bin}{os.pathsep}{env['PATH']}",
                    "COUNTER": str(counter),
                    "TEST_TARGET": str(target),
                    "TEST_SOURCE": str(source),
                    "MAISON_HOMEBREW_PREFIX": str(prefix),
                    "MAISON_DOCKER_APP": str(docker),
                }
            )
            result = subprocess.run(
                [str(ROOT / "scripts/user-apply-packages.sh")], env=env, capture_output=True, text=True
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(counter.read_text().strip(), "2")
            self.assertFalse(target.exists())
            self.assertIn("retrying package convergence", result.stderr)

    def test_docker_handoff_restores_link_when_retry_fails(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            prefix = temp / "prefix"
            docker = temp / "Docker.app"
            target = prefix / "share/fish/vendor_completions.d/docker-compose.fish"
            source = docker / "Contents/Resources/etc/docker-compose.fish-completion"
            source.parent.mkdir(parents=True)
            source.write_text("completion\n")
            target.parent.mkdir(parents=True)
            relative_source = os.path.relpath(source, target.parent)
            target.symlink_to(relative_source)
            fake_bin = temp / "bin"
            fake_bin.mkdir()
            counter = temp / "counter"
            executable(
                fake_bin / "mise",
                textwrap.dedent(
                    """\
                    #!/bin/sh
                    count=0
                    [ ! -f "$COUNTER" ] || count=$(cat "$COUNTER")
                    count=$((count + 1))
                    printf '%s\\n' "$count" >"$COUNTER"
                    if [ "$count" -eq 1 ]; then
                      message="mise ERROR completion target '$TEST_TARGET' already points to"
                      message="$message '$TEST_SOURCE' and is not owned by cask 'docker-desktop'"
                      printf '%s\\n' "$message" >&2
                      exit 1
                    fi
                    exit 27
                    """
                ),
            )
            env = os.environ.copy()
            env.update(
                {
                    "PATH": f"{fake_bin}{os.pathsep}{env['PATH']}",
                    "COUNTER": str(counter),
                    "TEST_TARGET": str(target),
                    "TEST_SOURCE": str(source),
                    "MAISON_HOMEBREW_PREFIX": str(prefix),
                    "MAISON_DOCKER_APP": str(docker),
                }
            )
            result = subprocess.run(
                [str(ROOT / "scripts/user-apply-packages.sh")], env=env, capture_output=True, text=True
            )
            self.assertEqual(result.returncode, 27)
            self.assertTrue(target.is_symlink())
            self.assertEqual(os.readlink(target), relative_source)
            self.assertEqual(target.resolve(), source.resolve())

    def test_docker_handoff_never_removes_an_unrelated_symlink(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            prefix = temp / "prefix"
            docker = temp / "Docker.app"
            target = prefix / "share/fish/vendor_completions.d/docker-compose.fish"
            unrelated = temp / "unrelated"
            unrelated.write_text("keep\n")
            target.parent.mkdir(parents=True)
            target.symlink_to(unrelated)
            fake_bin = temp / "bin"
            fake_bin.mkdir()
            executable(
                fake_bin / "mise",
                textwrap.dedent(
                    """\
                    #!/bin/sh
                    message="mise ERROR completion target '$TEST_TARGET' already points elsewhere"
                    message="$message and is not owned by cask 'docker-desktop'"
                    printf '%s\\n' "$message" >&2
                    exit 9
                    """
                ),
            )
            env = os.environ.copy()
            env.update(
                {
                    "PATH": f"{fake_bin}{os.pathsep}{env['PATH']}",
                    "TEST_TARGET": str(target),
                    "MAISON_HOMEBREW_PREFIX": str(prefix),
                    "MAISON_DOCKER_APP": str(docker),
                }
            )
            result = subprocess.run([str(ROOT / "scripts/user-apply-packages.sh")], env=env)
            self.assertEqual(result.returncode, 9)
            self.assertTrue(target.is_symlink())
            self.assertEqual(target.resolve(), unrelated.resolve())

    def test_forced_dotfile_handoff_backs_up_exact_conflicts(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
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
            executable(
                fake_bin / "mise",
                "#!/bin/sh\n"
                "cat >&2 <<'EOF'\n"
                "mise ERROR files: refusing to overwrite existing files (use --force-dotfiles):\n"
                "  ~/.miserc.toml\n"
                "  ~/.config/zed/settings.json\n"
                "  ~/.config/zed/keymap.json\n"
                "EOF\n"
                "exit 1\n",
            )
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

    def test_mise_lockfile_links_are_plannable_and_applied_directly(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory) / "home"
            home.mkdir()
            env = os.environ.copy()
            env["HOME"] = str(home)
            script = ROOT / "scripts/user-link-mise-lock.sh"
            preview = subprocess.run(
                [str(script), "--dry-run"], cwd=ROOT, env=env, check=True, capture_output=True, text=True
            )
            for name in ("mise.lock", "config.macos.lock"):
                source = ROOT / "config/mise" / name
                target = home / ".config/mise" / name
                self.assertIn(str(source), preview.stdout)
                self.assertIn(str(target), preview.stdout)
                self.assertFalse(target.exists())
            subprocess.run([str(script)], cwd=ROOT, env=env, check=True)
            for name in ("mise.lock", "config.macos.lock"):
                target = home / ".config/mise" / name
                self.assertTrue(target.is_symlink())
                self.assertEqual(target.resolve(), ROOT / "config/mise" / name)

    def test_bootstrap_help_pipe_and_clone_handoff(self) -> None:
        direct = subprocess.run([str(ROOT / "bootstrap.sh"), "--help"], capture_output=True, text=True, check=True)
        piped = subprocess.run(
            ["bash", "-c", 'cat "$1" | bash -s -- --help', "_", str(ROOT / "bootstrap.sh")],
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertEqual(direct.stdout, piped.stdout)
        self.assertNotIn("run_root()", piped.stdout)

        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            source = temp / "source"
            source.mkdir()
            copy_files(
                source,
                "mise.toml",
                "flake.nix",
                "bin/maison",
                ".mise/lib/common.sh",
                ".mise/lib/platform.sh",
                ".mise/lib/bootstrap.sh",
            )
            git_init(source)
            git_commit_all(source)
            home = temp / "home"
            home.mkdir()
            fake_bin = temp / "bin"
            fake_bin.mkdir()
            log = temp / "mise-log"
            executable(fake_bin / "nix", "#!/bin/sh\n[ \"$1\" = --version ] && echo 'nix 2.0'\n")
            executable(fake_bin / "mise", "#!/bin/sh\nprintf '%s\\n' \"$*\" >>\"$MISE_LOG\"\n")
            env = os.environ.copy()
            env.update(
                {
                    "HOME": str(home),
                    "MAISON_HOME": str(home / ".maison"),
                    "PATH": f"{fake_bin}{os.pathsep}{env['PATH']}",
                    "MISE_LOG": str(log),
                }
            )
            result = subprocess.run(
                [str(ROOT / "bootstrap.sh"), "--repo", str(source), "--ref", "main", "--host", "fixture-host"],
                cwd=temp,
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((home / ".maison/.git").is_dir())
            self.assertTrue((home / ".local/bin/maison").is_symlink())
            calls = log.read_text()
            self.assertIn("trust", calls)
            self.assertIn("run --skip-tools bootstrap -- --host fixture-host", calls)

    def test_maison_version_uses_deployment_revision_without_git(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            install = Path(directory) / "install"
            (install / "bin").mkdir(parents=True)
            copy_files(install, "bin/maison", "mise.toml", "flake.nix")
            (install / ".maison-revision").write_text("0123456789abcdef0123456789abcdef\n")
            fake_bin = Path(directory) / "fake-bin"
            fake_bin.mkdir()
            executable(fake_bin / "mise", "#!/bin/sh\nexit 0\n")
            env = os.environ.copy()
            env["MAISON_HOME"] = str(install)
            env["PATH"] = f"{fake_bin}{os.pathsep}{env['PATH']}"
            result = subprocess.run(
                ["bash", str(install / "bin/maison"), "--version"], env=env, capture_output=True, text=True, check=True
            )
            self.assertEqual(result.stdout.strip(), "maison 0123456789ab")

    def test_update_uses_single_nix_process_and_atomic_lockfile(self) -> None:
        script = read(".mise/tasks/update")
        flake = read("flake.nix")
        self.assertNotIn("flake prefetch", script)
        self.assertNotIn("MAISON_NIX_PREFETCH_JOBS", script)
        self.assertEqual(script.count("flake update"), 1)
        self.assertIn('MAISON_NIX_UPDATE_ATTEMPTS:-1', script)
        self.assertIn('MAISON_NIX_UPDATE_STALLED_TIMEOUT:-60', script)
        self.assertIn('--output-lock-file "$candidate_lock"', script)
        self.assertIn('mv "$candidate_lock" flake.lock', script)
        self.assertIn("--option download-attempts 1", script)
        self.assertIn('git+https://github.com/NixOS/nixpkgs?ref=nixpkgs-unstable&shallow=1', flake)


class RepositoryContractTest(unittest.TestCase):
    def test_task_and_script_entrypoints_are_executable(self) -> None:
        paths = [ROOT / "bootstrap.sh", ROOT / "bin/maison", ROOT / ".mise/lib/inventory.py"]
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
        self.assertIn('export MISE_PROJECT_ROOT="$maison_home"', cli)

    def test_inventory_flake_app_is_built_on_every_supported_system(self) -> None:
        outputs = read("nix/outputs.nix")
        build = read(".github/scripts/build-platform-targets.sh")
        self.assertIn('name = "maison-inventory"', outputs)
        self.assertIn("runtimeInputs = [ pkgs.python3 ]", outputs)
        self.assertIn("maison-inventory = inventoryPackage", outputs)
        self.assertIn(r'build_target ".#packages.\"$SYSTEM\".\"$package\""', build)

    def test_build_matrix_has_no_home_manager_or_intel_target(self) -> None:
        build = read(".github/scripts/build-platform-targets.sh")
        self.assertNotIn("homeConfigurations", build)
        self.assertNotIn("x86_64-darwin", build)
        self.assertIn("systemConfigs", build)
        self.assertIn("darwinConfigurations", build)

    def test_all_task_root_discovery_supports_gitless_deployments(self) -> None:
        for path in sorted((ROOT / ".mise/tasks").rglob("*")):
            if not path.is_file():
                continue
            text = path.read_text()
            if "rev-parse --show-toplevel" not in text:
                continue
            with self.subTest(path=path.relative_to(ROOT)):
                self.assertIn("MISE_PROJECT_ROOT", text)


if __name__ == "__main__":
    unittest.main()
