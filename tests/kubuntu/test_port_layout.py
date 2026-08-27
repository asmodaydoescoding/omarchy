"""Offline checks for the initial Kubuntu port layout."""

from __future__ import annotations

import json
from pathlib import Path
import unittest


REPO = Path(__file__).resolve().parents[2]
KUBUNTU = REPO / "kubuntu"
REQUIRED_DIRS = (
    "libexec",
    "bin",
    "plasma",
    "skills",
    "tests",
    "install",
)


class KubuntuPortLayoutTest(unittest.TestCase):
    def test_port_skeleton_and_manifest(self) -> None:
        readme = KUBUNTU / "README.md"
        manifest_path = KUBUNTU / "port-manifest.json"
        self.assertTrue(readme.is_file())
        self.assertTrue(manifest_path.is_file())
        self.assertIn("Kubuntu", readme.read_text(encoding="utf-8"))

        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        self.assertEqual(manifest["schemaVersion"], 1)
        self.assertEqual(manifest["environmentVariable"], "OMARCHY_KUBUNTU_AI_ROOT")
        self.assertEqual(manifest["installPrefix"], "~/.local/share/omarchy-kubuntu-ai")
        self.assertEqual(manifest["files"], [])
        self.assertEqual(manifest["links"], [])
        self.assertEqual(
            {entry["name"] for entry in manifest["sourceCheckouts"]},
            {"omarchy", "omarchy-hermes-harness"},
        )

        for directory in REQUIRED_DIRS:
            self.assertTrue((KUBUNTU / directory).is_dir(), directory)

        allowed_files = {"README.md", "port-manifest.json"}
        allowed_roots = {"ai-core", "bin", "install", "libexec", "plasma", "skills", "systemd", "tests", "voxtype"}
        for path in KUBUNTU.rglob("*"):
            if path.is_file() and path.name != ".gitkeep":
                relative = path.relative_to(KUBUNTU)
                if relative.as_posix() not in allowed_files:
                    self.assertIn(relative.parts[0], allowed_roots)


if __name__ == "__main__":
    unittest.main()
