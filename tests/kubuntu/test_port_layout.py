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
    "docs",
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
        self.assertEqual(manifest["runtimeManifest"], "~/.local/share/omarchy-kubuntu-ai/install-manifest.tsv")
        self.assertEqual(len(manifest["files"]), 72)
        self.assertEqual(len(manifest["links"]), 42)
        self.assertEqual(
            manifest["configs"],
            [{"path": "~/.config/kglobalshortcutsrc", "section": "[services][omarchy-agent.desktop]", "ownedKeys": ["_launch"]}],
        )
        self.assertEqual(
            {entry["name"] for entry in manifest["sourceCheckouts"]},
            {"omarchy", "omarchy-hermes-harness"},
        )
        self.assertEqual(
            {entry["id"] for entry in manifest["packages"]},
            {"com.asmoday.omarchy.hermes-harness", "com.asmoday.omarchy.agents"},
        )

        file_sources = {entry["source"] for entry in manifest["files"]}
        expected_sources = set()
        for root in ("ai-core", "bin", "libexec", "plasma", "skills", "systemd", "voxtype"):
            for path in (KUBUNTU / root).rglob("*"):
                if path.is_file() and path.name != ".gitkeep" and ".pyc" not in path.name and "__pycache__" not in path.parts:
                    expected_sources.add("kubuntu/" + path.relative_to(KUBUNTU).as_posix())
        expected_sources.add("kubuntu/install/kubuntu-global-shortcut.desktop")
        expected_sources.add("kubuntu/install/kubuntu-global-shortcut-service.desktop")
        self.assertTrue(expected_sources <= file_sources)
        self.assertFalse(any(source.endswith(".pyc") or "__pycache__" in source for source in file_sources))
        self.assertTrue(all((REPO / entry["source"]).is_file() for entry in manifest["files"] if entry["source"].startswith("kubuntu/")))

        expected_links = {
            "~/.local/bin/" + path.name
            for root in (KUBUNTU / "bin", KUBUNTU / "libexec")
            for path in root.iterdir()
            if path.is_file() and path.name != ".gitkeep" and path.name != "kubuntu-global-shortcut"
        }
        self.assertEqual({entry["path"] for entry in manifest["links"]}, expected_links)
        self.assertTrue(all(entry["target"].startswith("~/.local/share/omarchy-kubuntu-ai/") for entry in manifest["links"]))

        for directory in REQUIRED_DIRS:
            self.assertTrue((KUBUNTU / directory).is_dir(), directory)

        allowed_files = {"README.md", "port-manifest.json"}
        allowed_roots = {"ai-core", "bin", "docs", "install", "libexec", "plasma", "skills", "systemd", "tests", "voxtype"}
        for path in KUBUNTU.rglob("*"):
            if path.is_file() and path.name != ".gitkeep":
                relative = path.relative_to(KUBUNTU)
                if relative.as_posix() not in allowed_files:
                    self.assertIn(relative.parts[0], allowed_roots)


if __name__ == "__main__":
    unittest.main()
