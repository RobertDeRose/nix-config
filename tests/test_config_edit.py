from __future__ import annotations

import importlib.util
import tempfile
import tomllib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("config_edit", ROOT / ".mise/lib/config_edit.py")
assert SPEC and SPEC.loader
CONFIG_EDIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CONFIG_EDIT)


class ConfigEditTest(unittest.TestCase):
    def parse(self, path: Path) -> dict:
        with path.open("rb") as handle:
            return tomllib.load(handle)

    def test_add_and_remove_tool_versions(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.toml"
            path.write_text('[settings]\nexperimental = true\n\n[tools]\nnode = "24"\n')
            CONFIG_EDIT.edit_tool(path, "node", "lts", False)
            self.assertEqual(self.parse(path)["tools"]["node"], ["24", "lts"])
            CONFIG_EDIT.edit_tool(path, "node@24", "latest", True)
            self.assertEqual(self.parse(path)["tools"]["node"], "lts")
            CONFIG_EDIT.edit_tool(path, "node", "latest", True)
            self.assertNotIn("node", self.parse(path).get("tools", {}))

    def test_backend_qualified_tool_is_not_split_without_version(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.toml"
            path.write_text("[tools]\n")
            tool = "npm:@fission-ai/openspec"
            CONFIG_EDIT.edit_tool(path, tool, "latest", False)
            self.assertEqual(self.parse(path)["tools"][tool], "latest")

    def test_remove_lock_entry_preserves_other_versions_and_sections(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "mise.lock"
            path.write_text(
                "# generated\n\n"
                "[[tools.node]]\nversion = \"24.1.0\"\nbackend = \"core:node\"\n\n"
                "[tools.node.\"platforms.linux-x64\"]\nurl = \"one\"\n\n"
                "[[tools.node]]\nversion = \"22.2.0\"\nbackend = \"core:node\"\n\n"
                "[[tools.\"aqua:owner/tool\"]]\nversion = \"1.0\"\n"
                "backend = \"aqua:owner/tool\"\n\n"
                "[metadata]\nvalue = true\n"
            )
            CONFIG_EDIT.remove_locked_tool(path, "node@24.1.0")
            data = self.parse(path)
            self.assertEqual([entry["version"] for entry in data["tools"]["node"]], ["22.2.0"])
            self.assertIn("aqua:owner/tool", data["tools"])
            self.assertTrue(data["metadata"]["value"])

            CONFIG_EDIT.remove_locked_tool(path, "aqua:owner/tool")
            data = self.parse(path)
            self.assertNotIn("aqua:owner/tool", data["tools"])
            self.assertTrue(data["metadata"]["value"])

            config = Path(directory) / "config.toml"
            config.write_text("[tools]\n")
            CONFIG_EDIT.remove_locked_tool(path, "node@22", config)
            data = self.parse(path)
            self.assertNotIn("node", data.get("tools", {}))
            self.assertTrue(data["metadata"]["value"])

    def test_add_and_remove_package(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.toml"
            path.write_text('[bootstrap.packages]\n"brew:git" = "latest"\n')
            CONFIG_EDIT.edit_package(path, "brew:helix", "latest", False)
            self.assertEqual(self.parse(path)["bootstrap"]["packages"]["brew:helix"], "latest")
            CONFIG_EDIT.edit_package(path, "brew:git", "latest", True)
            self.assertNotIn("brew:git", self.parse(path)["bootstrap"]["packages"])


if __name__ == "__main__":
    unittest.main()
