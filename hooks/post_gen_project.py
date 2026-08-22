#!/usr/bin/env python
"""Cookiecutter post-generation hook to initialize Git and install prek hooks.

This script executes automatically after Cookiecutter generates the project.
It ensures that a Git repository is initialized, synchronization of dependencies
via uv takes place, and prek pre-commit hooks are wired up properly.
"""

from pathlib import Path
import subprocess
import sys
from typing import List, Optional


def run_cmd(args: List[str], cwd: Optional[Path] = None) -> bool:
    """
    Run a subprocess command safely and capture its execution status.

    Parameters
    ----------
    args : list of str
        The command and its accompanying arguments to be executed.
    cwd : Path, optional
        The working directory path where the command should run.
        Defaults to None, which uses the current working directory.

    Returns
    -------
    bool
        True if the process completed successfully with a return code of 0.
        False if the command failed, raised an error, or was not found.
    """
    try:
        subprocess.run(args, cwd=cwd, check=True, capture_output=True, text=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        print(f"Command '{' '.join(args)}' failed: {e}", file=sys.stderr)
        return False


def main() -> None:
    """Execute the primary post-generation pipeline steps.

    This function coordinates checking for uv availability, initializing a Git
    repository, provisioning the local project virtual environment via uv sync,
    and applying the prek Git hooks.

    Returns
    -------
    None
    """
    project_dir: Path = Path.cwd()
    print(f"Running post-generation hooks in {project_dir}...")

    # 1. Check if uv is installed
    if not run_cmd(["uv", "--version"]):
        print(
            "Error: 'uv' is not installed or not found in PATH.",
            file=sys.stderr,
        )
        print("Please install uv via https://astral.sh", file=sys.stderr)
        sys.exit(1)

    # 2. Initialize a git repo first (prek needs the .git directory)
    if not (project_dir / ".git").exists():
        print("Initializing Git repository...")
        if not run_cmd(["git", "init"], cwd=project_dir):
            print("Warning: Failed to initialize git repository.")

    # 3. Create the virtual environment and install the project's dev
    #    dependencies
    print("Syncing uv environment and installing dependencies...")
    if not run_cmd(["uv", "sync"], cwd=project_dir):
        print(
            "Warning: 'uv sync' failed. Skipping prek hook installation.",
            file=sys.stderr,
        )
        sys.exit(0)  # Exit safely so Cookiecutter doesn't delete the project

    # 4. Install the prek hooks using the local environment
    print("Setting up prek git hooks...")
    if not run_cmd(["uv", "run", "prek", "install"], cwd=project_dir):
        print("Warning: Failed to run 'prek install'.", file=sys.stderr)

    print("Project generation and local hook installation complete!")


if __name__ == "__main__":
    main()
