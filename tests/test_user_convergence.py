from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / ".mise/lib/user_convergence.py"


def load_user_convergence():
    spec = importlib.util.spec_from_file_location("user_convergence", MODULE)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class UserConvergencePlanTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.convergence = load_user_convergence()
        cls.root = Path("/repo")
        cls.home = Path("/home/maison")

    def plans(self, *, force_dotfiles: bool):
        plan = self.convergence.build_command_plan(
            mode="plan",
            force_dotfiles=force_dotfiles,
            root=self.root,
            home=self.home,
        )
        apply = self.convergence.build_command_plan(
            mode="apply",
            force_dotfiles=force_dotfiles,
            root=self.root,
            home=self.home,
        )
        return plan, apply

    def test_default_plan_and_apply_keep_dotfile_force_disabled(self) -> None:
        plan, apply = self.plans(force_dotfiles=False)

        self.assertFalse(plan.force_dotfiles)
        self.assertFalse(apply.force_dotfiles)
        for command in (*plan.convergence_commands, *apply.convergence_commands):
            self.assertNotIn("--force-dotfiles", command.argv)

    def test_explicit_force_dotfiles_is_shared_by_plan_and_apply(self) -> None:
        plan, apply = self.plans(force_dotfiles=True)

        self.assertTrue(plan.force_dotfiles)
        self.assertTrue(apply.force_dotfiles)
        for name in ("prepare", "dotfiles", "mise"):
            self.assertIn("--force-dotfiles", plan.command(name).argv)
            self.assertIn("--force-dotfiles", apply.command(name).argv)

    def test_convergence_steps_match_except_documented_execution_substitutions(self) -> None:
        plan, apply = self.plans(force_dotfiles=True)

        self.assertEqual(
            [command.name for command in plan.convergence_commands],
            [command.name for command in apply.convergence_commands],
        )
        self.assertEqual(
            ["prepare", "dotfiles", "lockfiles", "packages", "mise"],
            [command.name for command in plan.convergence_commands],
        )
        self.assertTrue(all(command.dry_run for command in plan.convergence_commands))
        self.assertTrue(all(not command.dry_run for command in apply.convergence_commands))
        self.assertEqual(plan.command("dotfiles").semantic_arguments, apply.command("dotfiles").semantic_arguments)
        self.assertEqual(plan.command("mise").semantic_arguments, apply.command("mise").semantic_arguments)
        self.assertEqual(plan.command("packages").semantic_action, apply.command("packages").semantic_action)
        self.assertNotEqual(plan.command("packages").argv, apply.command("packages").argv)
        self.assertEqual(plan.command("lockfiles").cwd, apply.command("lockfiles").cwd)
        self.assertEqual(plan.command("mise").env, apply.command("mise").env)

    def test_apply_only_steps_are_explicitly_documented(self) -> None:
        plan, apply = self.plans(force_dotfiles=False)

        self.assertEqual([], [command.name for command in plan.apply_only_commands])
        self.assertEqual(["trust", "finalize"], [command.name for command in apply.apply_only_commands])
        self.assertTrue(all(command.documented_substitution for command in apply.apply_only_commands))

    def test_aggregate_force_dotfiles_forwarding_matches_user_commands(self) -> None:
        self.assertEqual((), self.convergence.aggregate_user_arguments(force_dotfiles=False))
        self.assertEqual(
            ("--force-dotfiles",),
            self.convergence.aggregate_user_arguments(force_dotfiles=True),
        )


if __name__ == "__main__":
    unittest.main()
