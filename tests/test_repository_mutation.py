from __future__ import annotations

import importlib.util
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / ".mise/lib/repository_mutation.py"


def load_helper():
    spec = importlib.util.spec_from_file_location("repository_mutation", HELPER)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class RepositoryMutationLockTest(unittest.TestCase):
    def helper(self, state_root: Path, *args: str) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env["MAISON_REPOSITORY_MUTATION_STATE_DIR"] = str(state_root)
        return subprocess.run(
            [sys.executable, str(HELPER), *args],
            capture_output=True,
            text=True,
            env=env,
        )

    def test_state_directory_is_untracked_owner_only_and_keyed_by_repo(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            repo = temp / "repo"
            repo.mkdir()
            state_root = temp / "state"
            helper = load_helper()

            state = helper.repository_state(repo, state_root=state_root)

            self.assertTrue(state.directory.is_dir())
            self.assertEqual(state.directory.stat().st_mode & 0o777, 0o700)
            self.assertTrue(str(state.directory).startswith(str(state_root)))
            self.assertIn(helper.repository_key(repo), state.directory.name)
            self.assertFalse(str(state.directory).startswith(str(repo)))

    def test_run_fails_fast_when_repository_lock_is_busy(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            repo = temp / "repo"
            repo.mkdir()
            state_root = temp / "state"
            holder = subprocess.Popen(
                [
                    sys.executable,
                    str(HELPER),
                    "run",
                    "--repo",
                    str(repo),
                    "--",
                    sys.executable,
                    "-c",
                    "import time; time.sleep(5)",
                ],
                env={**os.environ, "MAISON_REPOSITORY_MUTATION_STATE_DIR": str(state_root)},
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            try:
                deadline = time.monotonic() + 5
                lock_file = None
                while time.monotonic() < deadline:
                    matches = list(state_root.glob("*/repository.lock"))
                    if matches:
                        lock_file = matches[0]
                        break
                    time.sleep(0.05)
                self.assertIsNotNone(lock_file)

                blocked = self.helper(state_root, "run", "--repo", str(repo), "--", sys.executable, "-c", "")

                self.assertNotEqual(blocked.returncode, 0)
                self.assertIn("repository mutation lock is busy", blocked.stderr)
                self.assertIn(str(repo.resolve()), blocked.stderr)
            finally:
                holder.terminate()
                holder.wait(timeout=10)

    def test_recovery_restores_original_for_incomplete_journal_states(self) -> None:
        helper = load_helper()
        states = ["created", "validated", "committing", "replacing"]
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            state_root = temp / "state"
            for state in states:
                with self.subTest(state=state):
                    repo = temp / state / "repo"
                    repo.mkdir(parents=True)
                    config = repo / "config.toml"
                    candidate = temp / state / "candidate.toml"
                    config.write_text("original\n")
                    candidate.write_text("candidate\n")
                    journal = helper.begin_journal(
                        repo,
                        operation="test",
                        files=[config],
                        state_root=state_root,
                    )
                    helper.record_candidate(journal, config, candidate)
                    helper.mark_journal_state(journal, state)
                    config.write_text("partial\n")

                    recovered = self.helper(state_root, "recover", "--repo", str(repo))

                    self.assertEqual(recovered.returncode, 0, recovered.stderr)
                    self.assertEqual(config.read_text(), "original\n")
                    self.assertFalse(journal.path.exists())

    def test_recovery_failure_preserves_journal_and_diagnostics(self) -> None:
        helper = load_helper()
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            repo = temp / "repo"
            repo.mkdir()
            state_root = temp / "state"
            config = repo / "config.toml"
            candidate = temp / "candidate.toml"
            config.write_text("original\n")
            candidate.write_text("candidate\n")
            journal = helper.begin_journal(repo, operation="test", files=[config], state_root=state_root)
            helper.record_candidate(journal, config, candidate)
            helper.mark_journal_state(journal, "replacing")
            config.unlink()
            config.mkdir()

            recovered = self.helper(state_root, "recover", "--repo", str(repo))

            self.assertNotEqual(recovered.returncode, 0)
            self.assertIn("rollback failed", recovered.stderr)
            self.assertTrue(journal.path.exists())
            self.assertTrue(config.is_dir())


class RepositoryMutationTaskSurfaceTest(unittest.TestCase):
    mutating_tasks = [
        ".mise/tasks/tool/add",
        ".mise/tasks/tool/remove",
        ".mise/tasks/package/add",
        ".mise/tasks/package/remove",
        ".mise/tasks/app/add",
        ".mise/tasks/app/remove",
        ".mise/tasks/host/add",
        ".mise/tasks/update",
    ]
    read_only_tasks = [
        ".mise/tasks/host/list",
        ".mise/tasks/host/validate",
        ".mise/tasks/package/search",
        ".mise/tasks/user/status",
        ".mise/tasks/plan",
    ]

    def test_repository_mutators_enter_shared_lock_before_reads(self) -> None:
        for task in self.mutating_tasks:
            with self.subTest(task=task):
                text = (ROOT / task).read_text()
                self.assertIn("transaction_require_lock", text)
                self.assertLess(text.index("transaction_require_lock"), text.index("transaction_directory"))

    def test_read_only_tasks_do_not_take_repository_mutation_lock(self) -> None:
        for task in self.read_only_tasks:
            with self.subTest(task=task):
                self.assertNotIn("transaction_require_lock", (ROOT / task).read_text())


if __name__ == "__main__":
    unittest.main()
