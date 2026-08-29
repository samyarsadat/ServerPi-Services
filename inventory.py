#!/usr/bin/env python3
"""Build Ansible inventory from provisioning profiles on local host branches."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys
from typing import Any

import yaml

PROFILE_PATH = "provisioning/host.yml"
SECRETS_PATH = "provisioning/secrets.yml"
PROFILE_VERSION = 1
SECRET_SCHEMA_VERSION = 1
EMPTY_SECRET_CONFIG = {
    "schema_version": SECRET_SCHEMA_VERSION,
    "generated_secrets": {},
    "env_files": {},
    "raw_files": {},
    "secure_directories": [],
}


class InventoryError(RuntimeError):
    """An inventory error safe to display to the operator."""


def git(
    repo: Path, *arguments: str, check: bool = True
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(repo), *arguments],
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def read_branch_yaml(repo: Path, branch: str, path: str) -> dict[str, Any] | None:
    result = git(repo, "show", f"{branch}:{path}", check=False)
    if result.returncode != 0:
        return None
    try:
        document = yaml.safe_load(result.stdout)
    except yaml.YAMLError as error:
        raise InventoryError(f"Invalid YAML in {branch}:{path}") from error
    if not isinstance(document, dict):
        raise InventoryError(f"{branch}:{path} must contain a YAML mapping")
    return document


def discover_hosts(repo: Path) -> dict[str, dict[str, Any]]:
    result = git(repo, "for-each-ref", "--format=%(refname:short)", "refs/heads")
    hosts: dict[str, dict[str, Any]] = {}

    for branch in sorted(result.stdout.splitlines()):
        profile = read_branch_yaml(repo, branch, PROFILE_PATH)
        if profile is None:
            continue

        hostname = profile.get("inventory_hostname")
        # A feature branch inherited from a host branch is not another host.
        if hostname != branch:
            print(
                f"inventory warning: ignoring {branch}:{PROFILE_PATH}; "
                f"inventory_hostname is {hostname!r}",
                file=sys.stderr,
            )
            continue
        if profile.get("profile_version") != PROFILE_VERSION:
            raise InventoryError(
                f"{branch}:{PROFILE_PATH} has an unsupported profile_version"
            )
        ansible_host = profile.get("ansible_host")
        if not isinstance(ansible_host, str) or not ansible_host:
            raise InventoryError(f"{branch}:{PROFILE_PATH} is missing ansible_host")

        secrets = read_branch_yaml(repo, branch, SECRETS_PATH)
        if secrets is None:
            secrets = EMPTY_SECRET_CONFIG.copy()
        if secrets.get("schema_version") != SECRET_SCHEMA_VERSION:
            raise InventoryError(
                f"{branch}:{SECRETS_PATH} has an unsupported schema_version"
            )

        variables = {
            key: value
            for key, value in profile.items()
            if key not in {"inventory_hostname", "profile_version"}
        }
        variables["serverpi_secret_config"] = secrets
        hosts[hostname] = variables

    if not hosts:
        raise InventoryError(
            f"No local host branch contains a matching {PROFILE_PATH} profile"
        )
    return hosts


def build_inventory(hosts: dict[str, dict[str, Any]]) -> dict[str, Any]:
    return {
        "server_pis": {"hosts": sorted(hosts)},
        "_meta": {"hostvars": hosts},
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--host")
    arguments = parser.parse_args()

    repo = Path(__file__).resolve().parent
    try:
        hosts = discover_hosts(repo)
    except (OSError, subprocess.SubprocessError, InventoryError) as error:
        print(f"inventory error: {error}", file=sys.stderr)
        return 1

    if arguments.host:
        output: dict[str, Any] = hosts.get(arguments.host, {})
    else:
        output = build_inventory(hosts)
    print(json.dumps(output, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
