import hashlib
import json
import stat
import subprocess
import unittest
from pathlib import Path


OMARCHY_CHECKOUT = Path("/home/xenofon/Work/omarchy-kubuntu-ai/upstream/omarchy")
HARNESS_CHECKOUT = Path("/home/xenofon/Work/omarchy-kubuntu-ai/upstream/omarchy-hermes-harness")
CONTRACT_DIR = OMARCHY_CHECKOUT / "source-contract"

OMARCHY_COMMIT = "946704f30950576731d91a732b743f7c7fa8b188"
HARNESS_COMMIT = "2d7268800ee36eb36ba837c9755ebb3536f73d62"

OMARCHY_FEATURES = {
    "agent_launch": [
        "bin/omarchy",
        "bin/omarchy-agent",
        "bin/omarchy-agent-prompt",
        "bin/omarchy-default-agent",
        "bin/omarchy-mise-install",
        "bin/omarchy-launch-tui",
        "bin/omarchy-launch-floating-terminal-with-presentation",
        "install/user/mise.sh",
        "install/user/mise-work.sh",
        "install/user/first-run/setup-agent.hook",
        "default/omarchy/omarchy-menu.jsonc",
        "default/bash/aliases",
        "default/hypr/qconsole.lua",
        "test/shell.d/default-agent-test.sh",
        "test/shell.d/agent-invitation-test.sh",
    ],
    "agent_usage": [
        "bin/omarchy-agent-usage-claude",
        "bin/omarchy-agent-usage-codex",
        "bin/omarchy-agent-usage-fireworks",
        "bin/omarchy-agent-usage-update",
        "shell/plugins/agents/Agent.qml",
        "shell/plugins/agents/Main.qml",
        "shell/plugins/agents/Panel.qml",
        "shell/plugins/agents/README.md",
        "shell/plugins/agents/manifest.json",
        "shell/plugins/agents/assets/claude.svg",
        "shell/plugins/agents/assets/codex.svg",
        "shell/plugins/agents/assets/codex-light.svg",
        "shell/plugins/agents/assets/fireworks.svg",
        "test/shell.d/agent-usage-claude-limits-test.sh",
        "test/shell.d/agent-usage-claude-scanner-test.sh",
        "test/shell.d/agent-usage-codex-scanner-test.sh",
        "test/shell.d/agent-usage-fireworks-scanner-test.sh",
        "test/shell.d/agent-usage-update-test.sh",
        "test/shell.d/agents-panel-test.sh",
        "test/shell.d/agents-default-migration-test.sh",
        "test/shell.d/agents-rename-migration-test.sh",
    ],
    "crash_diagnosis": [
        "bin/omarchy-agent-crash",
        "bin/omarchy-crash-watch",
        "bin/omarchy-crash-mute",
        "bin/omarchy-toggle-crash-capture",
        "bin/omarchy-notification-send",
        "bin/omarchy-notification-wait",
        "bin/omarchy-toggle",
        "bin/omarchy-toggle-enabled",
        "default/systemd/user/omarchy-crash-watch.service",
        "default/agents/skills/diagnose-crash/SKILL.md",
        "default/agents/skills/diagnose-crash/reporting.md",
        "test/shell.d/crash-capture-test.sh",
    ],
    "skills_theme": [
        "default/agents/skills/omarchy/SKILL.md",
        "default/agents/skills/omarchy/capture.md",
        "default/agents/skills/omarchy/contributing.md",
        "default/agents/skills/omarchy/hooks.md",
        "default/agents/skills/omarchy/hyprland.md",
        "default/agents/skills/omarchy/plugins.md",
        "default/agents/skills/omarchy/theming.md",
        "bin/omarchy-theme-set",
        "bin/omarchy-theme-refresh",
        "bin/omarchy-theme-set-claude",
        "bin/omarchy-theme-set-pi",
        "default/themed/claude.json.tpl",
        "default/themed/pi.json.tpl",
        "config/opencode/opencode.json",
        "test/shell.d/theme-staging-test.sh",
        "test/shell.d/vscode-theme-test.sh",
    ],
    "ai_install_menu": [
        "bin/omarchy-install-ai-chatgpt",
        "bin/omarchy-remove-ai-chatgpt",
        "bin/omarchy-remove-ai-grok-bot",
        "bin/omarchy-remove-ai-lm-studio",
        "bin/omarchy-remove-ai-ollama",
        "bin/omarchy-remove-ai-t3-code",
        "default/omarchy/omarchy-menu.jsonc",
        "test/shell.d/remove-ai-test.sh",
    ],
    "voxtype": [
        "bin/omarchy-voxtype-config",
        "bin/omarchy-voxtype-install",
        "bin/omarchy-voxtype-model",
        "bin/omarchy-voxtype-remove",
        "bin/omarchy-voxtype-status",
        "bin/omarchy-capture-text",
        "default/hypr/bindings/voxtype.lua",
        "default/voxtype/config.toml",
        "install/user/first-run/install-voxtype.hook",
        "shell/plugins/bar/indicators/Dictation.qml",
        "shell/plugins/bar/widgets/Indicators.qml",
        "shell/plugins/bar/widgets/Indicators.manifest.json",
        "manual/11-text-extraction-dictation.md",
        "test/shell.d/voxtype-invitation-test.sh",
    ],
}

HARNESS_FILES = {
    "BarWidget.qml": "b24658983026589d99b3ca56f42a78a3b8e82b0e755b5d8a07a32e9783bda2ba",
    "LICENSE": "9795cb7c4916590cfef3526651ade55b9aec54ea93f110f545cdfac820bda105",
    "Panel.qml": "33725f38ae0390d51eae51257b78ccf724faec1ac9c3d2a5e9ba87247d0c9824",
    "README.md": "bb4dcbdd051dcc6a32f7e691e217251aa1ba65c76b51dd2a85d69dc793211c5e",
    "docs/architecture.md": "970947858b2e6261db0e9d0afc05cea1ba6bc28a1ab7d9fa6e0e0e04f78d61af",
    "docs/security.md": "ad10da887c93e5d7e076a95dd0f2470201ef4dcff9c7575580112a8fbc48b8a0",
    "docs/telemetry.md": "92122dbcaa85637eff1d3abd45fe37e841b8c85d6707a7f443049d6bb42f5e1e",
    "docs/troubleshooting.md": "56f727256690be12d7c7d7a92ab18c81fad4d66b11a89565370ddd517c860f58",
    "manifest.json": "c7a5a8a4ea5912a5df0f86bd80b12909b7a139472428735eb5b4f44e2cd8c87d",
    "scripts/hermes-safe-io": "6c9c7bdd0208d14d9755264d897c44cc27bf47380d5e752802bea55222bde6c9",
    "scripts/hermes-status": "801e153f0987adf67e3f8c812b91e65616d92d5e838ba535bb62d51b35be8f91",
    "skill/SKILL.md": "3449524c425db2f38cdd9ec722f1db96b860e0b00ca47433a34c38f41850e380",
}

REQUIRED_ENTRY_KEYS = {"path", "exists", "sha256", "bytes", "executable"}
REQUIRED_CONTRACT_KEYS = {"repository", "source_ref", "source_commit", "checkout", "paths", "feature_groups"}


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def git_ref(checkout, ref):
    return subprocess.check_output(
        ["git", "-C", str(checkout), "rev-parse", ref], text=True
    ).strip()


class SourceContractTest(unittest.TestCase):
    def load_contract(self, filename):
        with (CONTRACT_DIR / filename).open(encoding="utf-8") as stream:
            return json.load(stream)

    def assert_shape(self, contract, expected_repository, expected_ref, expected_commit):
        self.assertIsInstance(contract, dict)
        self.assertTrue(REQUIRED_CONTRACT_KEYS <= contract.keys())
        self.assertEqual(contract["repository"], expected_repository)
        self.assertEqual(contract["source_ref"], expected_ref)
        self.assertEqual(contract["source_commit"], expected_commit)
        self.assertIsInstance(contract["checkout"], str)
        self.assertIsInstance(contract["paths"], list)
        self.assertIsInstance(contract["feature_groups"], dict)
        for entry in contract["paths"]:
            self.assertIsInstance(entry, dict)
            self.assertTrue(REQUIRED_ENTRY_KEYS <= entry.keys())
            self.assertIsInstance(entry["path"], str)
            self.assertIs(entry["exists"], True)
            self.assertIsInstance(entry["sha256"], str)
            self.assertRegex(entry["sha256"], r"^[0-9a-f]{64}$")
            self.assertIsInstance(entry["bytes"], int)
            self.assertGreaterEqual(entry["bytes"], 0)
            self.assertIsInstance(entry["executable"], bool)
        grouped_paths = []
        for name, group in contract["feature_groups"].items():
            self.assertIsInstance(name, str)
            self.assertIsInstance(group, dict)
            self.assertIsInstance(group.get("description"), str)
            self.assertTrue(group["description"])
            self.assertIsInstance(group.get("paths"), list)
            grouped_paths.extend(group["paths"])
        self.assertEqual(
            {entry["path"] for entry in contract["paths"]}, set(grouped_paths)
        )

    def assert_files(self, contract, checkout, expected_paths):
        entries = {entry["path"]: entry for entry in contract["paths"]}
        self.assertEqual(set(entries), set(expected_paths))
        for relative in expected_paths:
            path = checkout / relative
            self.assertTrue(path.is_file(), relative)
            entry = entries[relative]
            self.assertEqual(entry["sha256"], sha256(path), relative)
            self.assertEqual(entry["bytes"], path.stat().st_size, relative)
            self.assertEqual(
                entry["executable"],
                bool(path.stat().st_mode & (stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)),
                relative,
            )

    def test_omarchy_contract(self):
        contract = self.load_contract("omarchy-source.json")
        self.assert_shape(contract, "omarchy", "quattro", OMARCHY_COMMIT)
        self.assertEqual(git_ref(OMARCHY_CHECKOUT, "quattro"), OMARCHY_COMMIT)
        self.assert_files(contract, OMARCHY_CHECKOUT, [
            path for paths in OMARCHY_FEATURES.values() for path in paths
        ])

    def test_harness_contract(self):
        contract = self.load_contract("hermes-harness-source.json")
        self.assert_shape(contract, "omarchy-hermes-harness", "main", HARNESS_COMMIT)
        self.assertEqual(git_ref(HARNESS_CHECKOUT, "main"), HARNESS_COMMIT)
        self.assert_files(contract, HARNESS_CHECKOUT, list(HARNESS_FILES))
        entries = {entry["path"]: entry for entry in contract["paths"]}
        for relative, expected_hash in HARNESS_FILES.items():
            self.assertEqual(entries[relative]["sha256"], expected_hash, relative)

    def test_feature_matrix(self):
        matrix = (CONTRACT_DIR / "ai-feature-matrix.md").read_text(encoding="utf-8")
        for feature in (*OMARCHY_FEATURES, "harness"):
            self.assertIn(f"## {feature}", matrix)
        for phrase in (
            "lazy mise wrappers",
            "Claude, Codex, Fireworks collectors",
            "systemd-coredump journal watch",
            "Omarchy and diagnose-crash skills",
            "ChatGPT Desktop, Dictation, Grok Bot, LM Studio, Ollama, T3 Code",
            "offline Whisper dictation",
            "Hermes Harness status/launch plugin",
        ):
            self.assertIn(phrase, matrix)


if __name__ == "__main__":
    unittest.main()
