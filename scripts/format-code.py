#!/usr/bin/env python3
"""Format maintained source files, or check them without modifying files."""

import argparse
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUFF_VERSION = "0.14.0"
DEPENDENCY_DIRECTORIES = {
    ".agents",
    ".claude",
    ".shared",
    "Pods",
    "ThirdParty",
    "Vendor",
    "node_modules",
    "vendor",
}


def run(arguments: list[str], *, capture: bool = False) -> str:
    result = subprocess.run(
        arguments,
        cwd=ROOT,
        check=True,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        timeout=180,
    )
    return result.stdout if capture else ""


def source_files(suffix: str) -> list[str]:
    # Respect Git's ignores: build products, dependencies and private diagnostics
    # must never become formatter input, even when they contain source files.
    paths = run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        capture=True,
    ).split("\0")
    return sorted(
        {
            path
            for path in paths
            if path.endswith(suffix)
            and not DEPENDENCY_DIRECTORIES.intersection(Path(path).parts)
            and (ROOT / path).is_file()
        }
    )


def format_swift(files: list[str], check: bool) -> None:
    configuration = json.loads(run(["swift-format", "dump-configuration"], capture=True))
    preferences = ROOT / ".swift-format"
    if preferences.is_file():
        configuration.update(json.loads(preferences.read_text(encoding="utf-8")))
    # Keep source transformations out of a formatting pass. Existing lint rules
    # still apply when developers invoke the linter separately.
    configuration["rules"] = {name: False for name in configuration["rules"]}
    configuration["multiElementCollectionTrailingCommas"] = True
    configuration["reflowMultilineStringLiterals"] = "never"
    command = ["swift-format", "lint" if check else "format"]
    command.append("--strict" if check else "--in-place")
    run(command + ["--configuration", json.dumps(configuration), *files])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check", action="store_true", help="Report formatting changes without writing"
    )
    arguments = parser.parse_args()

    swift = source_files(".swift")
    if swift:
        format_swift(swift, arguments.check)

    python = source_files(".py")
    if python:
        command = ["uvx", "--from", f"ruff=={RUFF_VERSION}", "ruff", "format"]
        if arguments.check:
            command.append("--check")
        run(command + [*python])


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        raise SystemExit(error.returncode) from None
