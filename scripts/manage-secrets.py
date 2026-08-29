#!/usr/bin/env python3
"""Generate, apply, and verify secrets described by host branch profiles."""

from __future__ import annotations

import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import secrets
import string
import sys
import tempfile
from typing import Any

STATE_SCHEMA_VERSION = 1
CONFIG_SCHEMA_VERSION = 1
ALPHANUMERIC = string.ascii_letters + string.digits
ENV_LINE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$")
SECRET_NAME = re.compile(r"^[a-z][a-z0-9_]*$")
BCRYPT_HASH = re.compile(r"^\$2[aby]\$\d\d\$[./A-Za-z0-9]{53}$")


class SecretError(RuntimeError):
    """A safe-to-display validation error which never contains a secret."""


def atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        dir=path.parent, prefix=f".{path.name}.", text=True
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary_name, path)
    except BaseException:
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass
        raise


def load_json_stdin() -> dict[str, Any]:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError as error:
        raise SecretError("Input is not valid JSON") from error
    if not isinstance(payload, dict):
        raise SecretError("Input must be a JSON object")
    return payload


def load_state(path: Path) -> tuple[dict[str, Any], str | None]:
    if not path.exists():
        return {"schema_version": STATE_SCHEMA_VERSION, "values": {}}, None
    if path.is_symlink():
        raise SecretError("The generated secret state file must not be a symlink")
    try:
        content = path.read_text(encoding="utf-8")
        state = json.loads(content)
    except (OSError, json.JSONDecodeError) as error:
        raise SecretError(
            "The generated secret state file is unreadable or invalid"
        ) from error
    validate_state(state)
    return state, content


def validate_state(state: Any) -> dict[str, str]:
    if (
        not isinstance(state, dict)
        or state.get("schema_version") != STATE_SCHEMA_VERSION
    ):
        raise SecretError("Generated secret state has an unsupported schema")
    values = state.get("values")
    if not isinstance(values, dict) or not all(
        isinstance(key, str) and isinstance(value, str) for key, value in values.items()
    ):
        raise SecretError("Generated secret state has an invalid values object")
    return values


def validate_config(config: Any) -> dict[str, Any]:
    if (
        not isinstance(config, dict)
        or config.get("schema_version") != CONFIG_SCHEMA_VERSION
    ):
        raise SecretError("Host secret configuration has an unsupported schema")
    for key in ("generated_secrets", "env_files", "raw_files"):
        if not isinstance(config.get(key, {}), dict):
            raise SecretError(f"Host secret configuration has an invalid {key} mapping")
    secure_directories = config.get("secure_directories", [])
    if not isinstance(secure_directories, list):
        raise SecretError("Host secret configuration has invalid secure directories")
    normalized_directories: list[Path] = []
    for relative_path in secure_directories:
        if (
            not isinstance(relative_path, str)
            or not relative_path
            or Path(relative_path).is_absolute()
            or Path(relative_path) == Path(".")
            or ".." in Path(relative_path).parts
        ):
            raise SecretError(
                "Host secret configuration has an invalid secure directory"
            )
        normalized_directories.append(Path(relative_path))
    if len(normalized_directories) != len(set(normalized_directories)):
        raise SecretError("Host secret configuration has duplicate secure directories")
    return config


def collect_generators(configs: Any) -> dict[str, dict[str, Any]]:
    if not isinstance(configs, list) or not configs:
        raise SecretError("At least one host secret configuration is required")
    validated_configs = [validate_config(config) for config in configs]
    generators: dict[str, dict[str, Any]] = {}
    for config in validated_configs:
        for name, specification in config.get("generated_secrets", {}).items():
            if not isinstance(name, str) or not SECRET_NAME.fullmatch(name):
                raise SecretError("A generated secret has an invalid name")
            if not isinstance(specification, dict):
                raise SecretError(f"Generator {name!r} must be a mapping")
            previous = generators.get(name)
            if previous is not None and previous != specification:
                raise SecretError(f"Generator {name!r} has conflicting definitions")
            generators[name] = specification

    for config in validated_configs:
        for relative_path, fields in config.get("env_files", {}).items():
            seen_keys: set[str] = set()
            for field in validated_fields(relative_path, fields):
                key = field["key"]
                if key in seen_keys:
                    raise SecretError(
                        f"Duplicate configured variable {key} in {relative_path}"
                    )
                seen_keys.add(key)
                source = field["source"]
                if source not in {"manual", "fixed"} and source not in generators:
                    raise SecretError(
                        f"Secret field {key} references undefined generator {source!r}"
                    )
                if source == "fixed" and not isinstance(field.get("value"), str):
                    raise SecretError(f"Fixed secret field {key} has an invalid value")
                if "literal_quote" in field and not isinstance(
                    field["literal_quote"], bool
                ):
                    raise SecretError(
                        f"Secret field {key} has an invalid literal_quote value"
                    )
        for relative_path, specification in config.get("raw_files", {}).items():
            if not isinstance(specification, dict):
                raise SecretError(
                    f"Raw secret specification for {relative_path} is invalid"
                )
            source = specification.get("source")
            if source not in {"manual", "fixed"} and source not in generators:
                raise SecretError(
                    f"Raw secret {relative_path} references undefined generator "
                    f"{source!r}"
                )
    return generators


def require_length(name: str, specification: dict[str, Any]) -> int:
    length = specification.get("length")
    if not isinstance(length, int) or isinstance(length, bool) or length < 16:
        raise SecretError(f"Generator {name!r} has an invalid length")
    return length


def generate_state(path: Path, configs: Any, force: bool = False) -> bool:
    path.parent.mkdir(parents=True, exist_ok=True)
    lock_path = path.with_name(f"{path.name}.lock")
    descriptor = os.open(lock_path, os.O_CREAT | os.O_RDWR)
    with os.fdopen(descriptor, "r+", encoding="utf-8") as lock_file:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
        return generate_state_locked(path, configs, force)


def generate_state_locked(path: Path, configs: Any, force: bool) -> bool:
    try:
        import bcrypt
    except ImportError as error:
        raise SecretError(
            "Python package 'bcrypt' is required; install requirements.txt"
        ) from error

    generators = collect_generators(configs)
    state, previous_state = load_state(path)
    values = state["values"]

    for name, specification in generators.items():
        generator_type = specification.get("type")
        if generator_type == "random_alphanumeric":
            length = require_length(name, specification)
            current = values.get(name)
            if force or current is None:
                values[name] = "".join(
                    secrets.choice(ALPHANUMERIC) for _ in range(length)
                )
            elif len(current) != length:
                raise SecretError(f"Generated value {name!r} has an invalid length")
        elif generator_type != "bcrypt":
            raise SecretError(f"Generator {name!r} has an unsupported type")

    for name, specification in generators.items():
        if specification.get("type") != "bcrypt":
            continue
        source = specification.get("source")
        rounds = specification.get("rounds", 14)
        if not isinstance(source, str) or source not in generators:
            raise SecretError(f"Bcrypt generator {name!r} has an invalid source")
        if (
            not isinstance(rounds, int)
            or isinstance(rounds, bool)
            or not 4 <= rounds <= 16
        ):
            raise SecretError(f"Bcrypt generator {name!r} has invalid rounds")
        password = values.get(source)
        if not isinstance(password, str) or not password:
            raise SecretError(f"Bcrypt source {source!r} is unavailable")
        current = values.get(name)
        if force or current is None:
            values[name] = bcrypt.hashpw(
                password.encode("utf-8"), bcrypt.gensalt(rounds=rounds)
            ).decode("ascii")
        elif not BCRYPT_HASH.fullmatch(current):
            raise SecretError(f"Generated bcrypt value {name!r} is invalid")
        elif not bcrypt.checkpw(password.encode("utf-8"), current.encode("ascii")):
            raise SecretError(
                f"Generated bcrypt value {name!r} does not match its source"
            )

    serialized = json.dumps(state, indent=2, sort_keys=True) + "\n"
    changed = previous_state != serialized
    backup_path = None
    if changed:
        if force and previous_state is not None:
            backup_path = path.with_name(f"{path.stem}.backup{path.suffix}")
            atomic_write(backup_path, previous_state)
        atomic_write(path, serialized)

    print(
        json.dumps(
            {
                "changed": changed,
                "state_file": str(path),
                "backup_file": str(backup_path) if backup_path else None,
            }
        )
    )
    return changed


def safe_target(root: Path, relative_path: str) -> Path:
    if not relative_path or Path(relative_path).is_absolute():
        raise SecretError("Secret paths must be non-empty and relative")
    root = root.resolve(strict=True)
    target = root / relative_path
    resolved = target.resolve(strict=False)
    if root != resolved and root not in resolved.parents:
        raise SecretError(f"Secret path escapes the services root: {relative_path}")
    if target.is_symlink():
        raise SecretError(f"Secret path must not be a symlink: {relative_path}")
    return target


def parse_env(content: str, relative_path: str) -> tuple[list[str], dict[str, int]]:
    lines = content.splitlines()
    positions: dict[str, int] = {}
    for index, line in enumerate(lines):
        match = ENV_LINE.match(line)
        if not match:
            continue
        key = match.group(1)
        if key in positions:
            raise SecretError(f"Duplicate variable {key} in {relative_path}")
        positions[key] = index
    return lines, positions


def unquote_env_value(raw_value: str) -> str:
    value = raw_value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        return value[1:-1]
    return value


def desired_value(field: dict[str, Any], values: dict[str, str]) -> str | None:
    source = field.get("source")
    if source == "manual":
        return None
    if source == "fixed":
        value = field.get("value")
        if not isinstance(value, str) or not value:
            raise SecretError("A fixed secret field has an invalid value")
    else:
        value = values.get(source)
        if not isinstance(source, str) or not isinstance(value, str) or not value:
            raise SecretError(f"Generated state is missing {source!r}")
    return f"'{value}'" if field.get("literal_quote") else value


def validated_fields(relative_path: str, fields: Any) -> list[dict[str, Any]]:
    if not isinstance(fields, list):
        raise SecretError(f"Secret fields for {relative_path} must be a list")
    for field in fields:
        if not isinstance(field, dict) or not ENV_LINE.fullmatch(
            f"{field.get('key', '')}="
        ):
            raise SecretError(f"An environment field in {relative_path} is invalid")
        if not isinstance(field.get("source"), str):
            raise SecretError(f"A source in {relative_path} is invalid")
    return fields


def apply_env_file(
    root: Path,
    relative_path: str,
    fields: Any,
    values: dict[str, str],
    force: bool,
) -> bool:
    target = safe_target(root, relative_path)
    existed = target.exists()
    content = target.read_text(encoding="utf-8") if existed else ""
    lines, positions = parse_env(content, relative_path)

    if not existed:
        lines = [
            "# Managed by ServerPi provisioning.",
            "# Fill the empty externally supplied values manually.",
            "",
        ]

    for field in validated_fields(relative_path, fields):
        key = field["key"]
        desired = desired_value(field, values)
        if key in positions:
            match = ENV_LINE.match(lines[positions[key]])
            assert match is not None
            if unquote_env_value(match.group(2)) and not (
                force and field["source"] != "manual"
            ):
                continue
            if desired is not None:
                lines[positions[key]] = f"{key}={desired}"
        else:
            lines.append(f"{key}={desired or ''}")
            positions[key] = len(lines) - 1

    rendered = "\n".join(lines).rstrip("\n") + "\n"
    if content != rendered:
        atomic_write(target, rendered)
        return True
    return False


def apply_raw_file(
    root: Path,
    relative_path: str,
    specification: Any,
    values: dict[str, str],
    force: bool,
) -> bool:
    if not isinstance(specification, dict):
        raise SecretError(f"Raw secret specification for {relative_path} is invalid")
    target = safe_target(root, relative_path)
    desired = desired_value(specification, values) or ""
    existed = target.exists()
    existing = target.read_text(encoding="utf-8") if existed else ""
    if (
        not existed
        or (not existing and desired)
        or (force and specification.get("source") != "manual" and existing != desired)
    ):
        atomic_write(target, desired)
        return True
    return False


def payload_parts(payload: dict[str, Any]) -> tuple[dict[str, Any], dict[str, str]]:
    config = validate_config(payload.get("config"))
    values = validate_state(payload.get("state"))
    return config, values


def apply_secrets(root: Path, payload: dict[str, Any], force: bool = False) -> bool:
    if not root.is_dir():
        raise SecretError(f"Services root is not a directory: {root}")
    config, values = payload_parts(payload)
    changed_paths: list[str] = []
    for relative_path, fields in config.get("env_files", {}).items():
        if apply_env_file(root, relative_path, fields, values, force):
            changed_paths.append(relative_path)
    for relative_path, specification in config.get("raw_files", {}).items():
        if apply_raw_file(root, relative_path, specification, values, force):
            changed_paths.append(relative_path)
    print(json.dumps({"changed": bool(changed_paths), "changed_paths": changed_paths}))
    return bool(changed_paths)


def verify_secrets(root: Path, payload: dict[str, Any]) -> bool:
    if not root.is_dir():
        raise SecretError(f"Services root is not a directory: {root}")
    config, values = payload_parts(payload)
    issues: list[str] = []

    for relative_path, untrusted_fields in config.get("env_files", {}).items():
        fields = validated_fields(relative_path, untrusted_fields)
        try:
            target = safe_target(root, relative_path)
        except (OSError, SecretError) as error:
            issues.append(str(error))
            continue
        if not target.is_file():
            issues.append(f"missing file: {relative_path}")
            continue
        try:
            lines, positions = parse_env(
                target.read_text(encoding="utf-8"), relative_path
            )
        except (OSError, UnicodeError, SecretError) as error:
            issues.append(str(error))
            continue
        for field in fields:
            key = field["key"]
            if key not in positions:
                issues.append(f"missing variable {key} in {relative_path}")
                continue
            match = ENV_LINE.match(lines[positions[key]])
            assert match is not None
            raw_value = match.group(2).strip()
            value = unquote_env_value(raw_value)
            source = field["source"]
            if not value:
                issues.append(f"empty variable {key} in {relative_path}")
                continue
            if source == "manual":
                continue
            expected = desired_value(field, values)
            if field.get("literal_quote") and not (
                raw_value.startswith("'") and raw_value.endswith("'")
            ):
                issues.append(f"{key} in {relative_path} must be single-quoted")
            elif raw_value != expected:
                issues.append(f"unexpected value for {key} in {relative_path}")

    for relative_path, specification in config.get("raw_files", {}).items():
        try:
            target = safe_target(root, relative_path)
        except (OSError, SecretError) as error:
            issues.append(str(error))
            continue
        if not target.is_file():
            issues.append(f"missing file: {relative_path}")
            continue
        value = target.read_text(encoding="utf-8")
        source = (
            specification.get("source") if isinstance(specification, dict) else None
        )
        if not value:
            issues.append(f"empty secret file: {relative_path}")
        elif source != "manual" and value != desired_value(specification, values):
            issues.append(f"unexpected value in {relative_path}")

    print(json.dumps({"ok": not issues, "issues": issues}))
    return not issues


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    generate = subparsers.add_parser("generate")
    generate.add_argument("--state-file", type=Path, required=True)
    generate.add_argument("--force", action="store_true")
    for command in ("apply", "verify"):
        subparser = subparsers.add_parser(command)
        subparser.add_argument("--root", type=Path, required=True)
        if command == "apply":
            subparser.add_argument("--force", action="store_true")
    return parser


def main() -> int:
    arguments = build_parser().parse_args()
    try:
        payload = load_json_stdin()
        if arguments.command == "generate":
            generate_state(
                arguments.state_file, payload.get("configs"), arguments.force
            )
        elif arguments.command == "apply":
            apply_secrets(arguments.root, payload, arguments.force)
        elif arguments.command == "verify" and not verify_secrets(arguments.root, payload):
            return 1
    except (OSError, SecretError) as error:
        print(json.dumps({"ok": False, "error": str(error)}), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
