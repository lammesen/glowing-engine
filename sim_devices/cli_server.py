#!/usr/bin/env python3
"""Minimal Cisco-like CLI served over SSH login shell."""

from __future__ import annotations

import os
import sys
from pathlib import Path
from typing import Dict, List

PLACEHOLDER_KEYS = ("hostname", "site", "mgmt_ip")

try:
    import yaml  # type: ignore
except ImportError as exc:  # pragma: no cover
    print(f"Failed to import yaml: {exc}", file=sys.stderr)
    sys.exit(1)

BASE_COMMAND_FILE = Path("/opt/cisco-sim/commands/base.yml")
DEVICE_DATA_PATH = Path(os.environ.get("DEVICE_DATA_PATH", "/data"))
DEVICE_FILE = DEVICE_DATA_PATH / "device.yml"
INVALID_MSG = "% Invalid input detected at '^' marker."


def load_yaml(path: Path) -> dict:
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}


def build_context(device_data: dict) -> Dict[str, str]:
    return {
        "hostname": device_data.get("hostname", "sim-router"),
        "site": device_data.get("site", "LAB"),
        "mgmt_ip": device_data.get("mgmt_ip", "10.0.0.1"),
    }


def merge_commands(base: dict, overrides: dict) -> Dict[str, List[str]]:
    merged: Dict[str, List[str]] = {}
    for source in (base or {}, overrides or {}):
        for command, output in (source or {}).items():
            if isinstance(output, str):
                merged[command] = [output]
            else:
                merged[command] = [str(line) for line in output]
    return merged


def render_template(value: str, context: Dict[str, str]) -> str:
    rendered = value
    for key in PLACEHOLDER_KEYS:
        rendered = rendered.replace(f"{{{key}}}", context.get(key, ""))
    return rendered


def format_output(lines: List[str], context: Dict[str, str]) -> str:
    return "\n".join(render_template(line, context) for line in lines)


def main() -> None:
    base_data = load_yaml(BASE_COMMAND_FILE).get("commands", {})
    device_data = load_yaml(DEVICE_FILE)
    overrides = (device_data or {}).get("commands", {})
    context = build_context(device_data or {})
    commands = merge_commands(base_data, overrides)

    mode = "exec"  # exec -> priv -> config
    prompt_map = {
        "exec": "{hostname}>",
        "priv": "{hostname}#",
        "config": "{hostname}(config)#",
    }

    while True:
        prompt = render_template(prompt_map.get(mode, "{hostname}>"), context)
        try:
            line = input(prompt + " ")
        except EOFError:
            break

        command = line.strip()
        if not command:
            continue

        if command in ("exit", "quit"):
            if mode == "config":
                mode = "priv"
                continue
            if mode == "priv":
                mode = "exec"
                continue
            print("logout")
            break

        if command == "enable" and mode == "exec":
            mode = "priv"
            continue
        if command == "disable" and mode in {"priv", "config"}:
            mode = "exec"
            continue
        if command in {"configure", "configure terminal"} and mode == "priv":
            mode = "config"
            continue
        if command == "end" and mode == "config":
            mode = "priv"
            continue

        output = commands.get(command)
        if output:
            print(format_output(output, context))
        else:
            print(INVALID_MSG)


if __name__ == "__main__":  # pragma: no cover
    main()
