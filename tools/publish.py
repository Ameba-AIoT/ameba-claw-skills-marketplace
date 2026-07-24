#!/usr/bin/env python3
"""
publish.py — regenerate skill metadata then commit and push to GitHub.

Usage (run from marketplace repo root):
  python tools/publish.py [--skill NAME]

  --skill NAME   only regenerate _metadata.json for NAME;
                 skills-index.json is still fully rebuilt
"""
import argparse
import subprocess
import sys
from pathlib import Path

TOOLS_DIR = Path(__file__).parent
REPO_ROOT = TOOLS_DIR.parent


def run(cmd, **kw):
    result = subprocess.run(cmd, cwd=str(REPO_ROOT), text=True,
                            capture_output=True, **kw)
    if result.returncode != 0:
        print(result.stdout, end="")
        print(result.stderr, end="", file=sys.stderr)
        sys.exit(result.returncode)
    return result.stdout.strip()


def main():
    parser = argparse.ArgumentParser(description="Publish skill metadata to GitHub.")
    parser.add_argument("--skill", default=None, metavar="NAME",
                        help="only regen _metadata.json for this skill")
    args = parser.parse_args()

    # 1. Generate metadata
    gen_cmd = [sys.executable, str(TOOLS_DIR / "gen_skill_meta.py"),
               "--skills-dir", str(REPO_ROOT)]
    if args.skill:
        gen_cmd += ["--skill", args.skill]
    subprocess.run(gen_cmd, check=True)

    # 2. Stage changed files
    run(["git", "add",
         "skills-index.json",
         "*/SKILL.md",
         "*/_metadata.json"])

    # 3. Check for staged changes
    status = run(["git", "status", "--porcelain"])
    if not status:
        print("Nothing changed — skipping commit.")
        return

    print(status)

    # 4. Commit
    run(["git", "commit", "-m", "chore: update skill metadata"])
    print("Committed.")

    # 5. Push
    run(["git", "push", "origin", "main"])
    print("Pushed to origin/main.")


if __name__ == "__main__":
    main()
