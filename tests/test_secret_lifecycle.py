from __future__ import annotations

import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest

import bcrypt
import yaml

PROJECT_ROOT = Path(__file__).resolve().parents[1]
TOOL = PROJECT_ROOT / "scripts/manage-secrets.py"
INVENTORY = PROJECT_ROOT / "inventory.py"


def run_tool(arguments: list[str], payload: dict, expected_returncode: int = 0) -> dict:
    result = subprocess.run(
        [str(TOOL), *arguments],
        input=json.dumps(payload),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != expected_returncode:
        raise AssertionError((result.stdout, result.stderr))
    return json.loads(result.stdout or result.stderr)


class SecretLifecycleTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        inventory = json.loads(
            subprocess.run(
                [str(INVENTORY), "--list"],
                text=True,
                stdout=subprocess.PIPE,
                check=True,
            ).stdout
        )
        cls.hostvars = inventory["_meta"]["hostvars"]
        shared = yaml.safe_load(
            (PROJECT_ROOT / "group_vars/server_pis/shared-secrets.yml").read_text(
                encoding="utf-8"
            )
        )["serverpi_shared_secret_config"]
        cls.configs = [shared] + [
            cls.hostvars[hostname]["serverpi_secret_config"]
            for hostname in sorted(cls.hostvars)
        ]

    def test_generation_application_and_verification(self) -> None:
        with tempfile.TemporaryDirectory(prefix="serverpi-secrets-test.") as directory:
            base = Path(directory)
            state_path = base / "state/generated-secrets.json"
            generated = run_tool(
                ["generate", "--state-file", str(state_path)],
                {"configs": self.configs},
            )
            self.assertTrue(generated["changed"])
            first_state = state_path.read_text(encoding="utf-8")
            repeated = run_tool(
                ["generate", "--state-file", str(state_path)],
                {"configs": self.configs},
            )
            self.assertFalse(repeated["changed"])
            self.assertEqual(first_state, state_path.read_text(encoding="utf-8"))

            state = json.loads(first_state)
            values = state["values"]
            self.assertTrue(
                bcrypt.checkpw(
                    values["loki_basic_auth_password"].encode(),
                    values["loki_basic_auth_hash"].encode(),
                )
            )

            for hostname, variables in self.hostvars.items():
                root = base / hostname
                root.mkdir()
                payload = {
                    "state": state,
                    "config": variables["serverpi_secret_config"],
                }
                self.assertTrue(
                    run_tool(["apply", "--root", str(root)], payload)["changed"]
                )
                self.assertFalse(
                    run_tool(["apply", "--root", str(root)], payload)["changed"]
                )
                env_paths = list(
                    variables["serverpi_secret_config"].get("env_files", {})
                )
                raw_paths = list(
                    variables["serverpi_secret_config"].get("raw_files", {})
                )
                secret_paths = env_paths + raw_paths
                for relative_path in secret_paths:
                    self.assertEqual(
                        0o600,
                        stat.S_IMODE((root / relative_path).stat().st_mode),
                    )

                # Host file permissions are applied and verified by Ansible.
                for relative_path in env_paths:
                    os.chmod(root / relative_path, 0o640)
                for relative_path in raw_paths:
                    os.chmod(root / relative_path, 0o644)
                self.assertFalse(
                    run_tool(["apply", "--root", str(root)], payload)["changed"]
                )
                verification = run_tool(
                    ["verify", "--root", str(root)],
                    payload,
                    expected_returncode=1,
                )
                self.assertFalse(verification["ok"])

    def test_undefined_generator_is_rejected(self) -> None:
        broken = {
            "schema_version": 1,
            "generated_secrets": {},
            "env_files": {
                "service/secrets.env": [
                    {"key": "PASSWORD", "source": "misspelled_generator"}
                ]
            },
            "raw_files": {},
        }
        with tempfile.TemporaryDirectory(prefix="serverpi-schema-test.") as directory:
            result = run_tool(
                [
                    "generate",
                    "--state-file",
                    str(Path(directory) / "state.json"),
                ],
                {"configs": [broken]},
                expected_returncode=1,
            )
            self.assertIn("undefined generator", result["error"])

    def test_unsafe_secure_directory_is_rejected(self) -> None:
        broken = {
            "schema_version": 1,
            "generated_secrets": {},
            "env_files": {},
            "raw_files": {},
            "secure_directories": ["../outside"],
        }
        with tempfile.TemporaryDirectory(prefix="serverpi-schema-test.") as directory:
            result = run_tool(
                [
                    "generate",
                    "--state-file",
                    str(Path(directory) / "state.json"),
                ],
                {"configs": [broken]},
                expected_returncode=1,
            )
            self.assertIn("invalid secure directory", result["error"])

    def test_forced_rotation_replaces_managed_values_only(self) -> None:
        config = {
            "schema_version": 1,
            "generated_secrets": {
                "generated_password": {
                    "type": "random_alphanumeric",
                    "length": 32,
                },
                "generated_hash": {
                    "type": "bcrypt",
                    "source": "generated_password",
                    "rounds": 4,
                },
            },
            "env_files": {
                "service/secrets.env": [
                    {"key": "PASSWORD", "source": "generated_password"},
                    {"key": "PASSWORD_HASH", "source": "generated_hash"},
                    {"key": "MANUAL_VALUE", "source": "manual"},
                    {"key": "FIXED_VALUE", "source": "fixed", "value": "fixed"},
                ]
            },
            "raw_files": {
                "service/raw-secret": {"source": "generated_password"},
                "service/manual-secret": {"source": "manual"},
            },
        }
        with tempfile.TemporaryDirectory(prefix="serverpi-rotation-test.") as directory:
            base = Path(directory)
            state_path = base / "state/generated-secrets.json"
            root = base / "root"
            root.mkdir()

            run_tool(
                ["generate", "--state-file", str(state_path)],
                {"configs": [config]},
            )
            previous_state_text = state_path.read_text(encoding="utf-8")
            previous_state = json.loads(previous_state_text)
            previous_payload = {"state": previous_state, "config": config}
            run_tool(["apply", "--root", str(root)], previous_payload)

            env_path = root / "service/secrets.env"
            env_content = env_path.read_text(encoding="utf-8")
            env_content = env_content.replace(
                "MANUAL_VALUE=", "MANUAL_VALUE=operator-supplied"
            ).replace("FIXED_VALUE=fixed", "FIXED_VALUE=incorrect")
            env_path.write_text(env_content, encoding="utf-8")
            manual_raw_path = root / "service/manual-secret"
            manual_raw_path.write_text("operator-supplied", encoding="utf-8")

            rotated = run_tool(
                ["generate", "--state-file", str(state_path), "--force"],
                {"configs": [config]},
            )
            backup_path = state_path.with_name("generated-secrets.backup.json")
            self.assertEqual(str(backup_path), rotated["backup_file"])
            self.assertEqual(
                previous_state_text, backup_path.read_text(encoding="utf-8")
            )

            rotated_state = json.loads(state_path.read_text(encoding="utf-8"))
            previous_values = previous_state["values"]
            rotated_values = rotated_state["values"]
            self.assertNotEqual(
                previous_values["generated_password"],
                rotated_values["generated_password"],
            )
            self.assertNotEqual(
                previous_values["generated_hash"], rotated_values["generated_hash"]
            )
            self.assertTrue(
                bcrypt.checkpw(
                    rotated_values["generated_password"].encode(),
                    rotated_values["generated_hash"].encode(),
                )
            )

            rotated_payload = {"state": rotated_state, "config": config}
            self.assertTrue(
                run_tool(
                    ["apply", "--root", str(root), "--force"], rotated_payload
                )["changed"]
            )
            updated_env = env_path.read_text(encoding="utf-8")
            self.assertIn(
                f"PASSWORD={rotated_values['generated_password']}", updated_env
            )
            self.assertIn(
                f"PASSWORD_HASH={rotated_values['generated_hash']}", updated_env
            )
            self.assertIn("MANUAL_VALUE=operator-supplied", updated_env)
            self.assertIn("FIXED_VALUE=fixed", updated_env)
            self.assertEqual(
                rotated_values["generated_password"],
                (root / "service/raw-secret").read_text(encoding="utf-8"),
            )
            self.assertEqual(
                "operator-supplied", manual_raw_path.read_text(encoding="utf-8")
            )
            self.assertTrue(
                run_tool(
                    ["verify", "--root", str(root)],
                    rotated_payload,
                )["ok"]
            )
            self.assertFalse(
                run_tool(
                    ["apply", "--root", str(root), "--force"], rotated_payload
                )["changed"]
            )

    def test_existing_generated_value_is_preserved_and_rejected(self) -> None:
        with tempfile.TemporaryDirectory(prefix="serverpi-preserve-test.") as directory:
            base = Path(directory)
            state_path = base / "state.json"
            run_tool(
                ["generate", "--state-file", str(state_path)],
                {"configs": self.configs},
            )
            state = json.loads(state_path.read_text(encoding="utf-8"))
            variables = next(
                variables
                for variables in self.hostvars.values()
                if any(
                    field.get("key") == "LOKI_BASIC_AUTH_PASSWORD"
                    for fields in variables["serverpi_secret_config"][
                        "env_files"
                    ].values()
                    for field in fields
                )
            )
            payload = {"state": state, "config": variables["serverpi_secret_config"]}
            root = base / "root"
            root.mkdir()
            run_tool(["apply", "--root", str(root)], payload)
            path = root / "caddy/secrets.env"
            original = state["values"]["loki_basic_auth_password"]
            content = path.read_text(encoding="utf-8").replace(
                f"LOKI_BASIC_AUTH_PASSWORD={original}",
                "LOKI_BASIC_AUTH_PASSWORD=existing-different-value",
            )
            path.write_text(content, encoding="utf-8")
            os.chmod(path, 0o600)
            self.assertFalse(
                run_tool(["apply", "--root", str(root)], payload)["changed"]
            )
            result = run_tool(
                ["verify", "--root", str(root)], payload, expected_returncode=1
            )
            self.assertTrue(
                any("LOKI_BASIC_AUTH_PASSWORD" in issue for issue in result["issues"])
            )


if __name__ == "__main__":
    unittest.main()
