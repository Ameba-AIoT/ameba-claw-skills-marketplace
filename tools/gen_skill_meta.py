#!/usr/bin/env python3
"""
gen_skill_meta.py — generate _metadata.json per skill and skills-index.json.

Usage:
  python tools/gen_skill_meta.py [--skills-dir DIR] [--skill NAME]

  --skills-dir DIR   marketplace repo root (default: cwd)
  --skill NAME       regenerate only this skill's _metadata.json;
                     skills-index.json is always fully rebuilt
"""
import argparse
import json
import os
import re
import subprocess
import time
from pathlib import Path


def parse_frontmatter(skill_md: Path) -> dict:
    """Extract JSON frontmatter from SKILL.md (between first pair of ---).

    Supports both YAML-style keys and raw JSON blocks.
    Returns empty dict if not found or invalid.
    """
    text = skill_md.read_text(encoding="utf-8")
    m = re.match(r"^---\s*\n(.*?)\n---", text, re.DOTALL)
    if not m:
        return {}
    block = m.group(1).strip()
    # Try raw JSON first
    try:
        return json.loads(block)
    except json.JSONDecodeError:
        pass
    # Try YAML-style "key: value" (simple single-level only)
    data = {}
    for line in block.splitlines():
        kv = line.split(":", 1)
        if len(kv) == 2:
            data[kv[0].strip()] = kv[1].strip().strip('"')
    return data


def scan_extra_files(skill_dir: Path) -> dict:
    result = {"references": [], "scripts": [], "assets": []}
    for group in ("scripts", "references", "assets"):
        gdir = skill_dir / group
        if gdir.is_dir():
            result[group] = sorted(f.name for f in gdir.iterdir() if f.is_file())
    return result


def get_last_modified(skill_dir: Path, skills_dir: Path) -> int:
    """Unix millisecond timestamp from git log; fallback to mtime."""
    rel = skill_dir.relative_to(skills_dir)
    try:
        out = subprocess.check_output(
            ["git", "log", "-1", "--format=%cI", "--", str(rel)],
            cwd=str(skills_dir),
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
        if out:
            import datetime
            dt = datetime.datetime.fromisoformat(out)
            return int(dt.timestamp() * 1000)
    except Exception:
        pass
    # fallback: newest mtime in skill_dir
    mtimes = [f.stat().st_mtime for f in skill_dir.rglob("*") if f.is_file()]
    return int((max(mtimes) if mtimes else time.time()) * 1000)


def build_metadata(skill_dir: Path, skills_dir: Path) -> dict:
    skill_md = skill_dir / "SKILL.md"
    fm = parse_frontmatter(skill_md)
    extra_files = scan_extra_files(skill_dir)
    last_modified = get_last_modified(skill_dir, skills_dir)
    metadata_block = fm.get("metadata", {})
    return {
        "name": fm.get("name", skill_dir.name),
        "description": fm.get("description", ""),
        "author": fm.get("author", ""),
        "last_modified": last_modified,
        "metadata": {
            "cap_groups": metadata_block.get("cap_groups", []),
            "manage_mode": metadata_block.get("manage_mode", "web"),
            "category": metadata_block.get("category", []),
            "tags": metadata_block.get("tags", []),
            "peripherals": metadata_block.get("peripherals", []),
        },
        "extra_files": extra_files,
    }


def build_index_entry(meta: dict) -> dict:
    return {
        "id": meta["name"],
        "name": meta["name"],
        "description": meta["description"],
        "author": meta["author"],
        "last_modified": meta["last_modified"],
        "metadata": {
            "category": meta["metadata"]["category"],
            "tags": meta["metadata"]["tags"],
            "peripherals": meta["metadata"]["peripherals"],
        },
        "extra_files": meta["extra_files"],
    }


def main():
    parser = argparse.ArgumentParser(description="Generate skill metadata files.")
    parser.add_argument("--skills-dir", default=".", metavar="DIR",
                        help="marketplace repo root (default: .)")
    parser.add_argument("--skill", default=None, metavar="NAME",
                        help="regenerate only this skill's _metadata.json")
    args = parser.parse_args()

    skills_dir = Path(args.skills_dir).resolve()
    skill_dirs = sorted(
        d for d in skills_dir.iterdir()
        if d.is_dir() and (d / "SKILL.md").exists() and not d.name.startswith(".")
    )

    if not skill_dirs:
        print("No skills found (no subdirectory with SKILL.md).")
        return

    index = []
    for skill_dir in skill_dirs:
        meta = build_metadata(skill_dir, skills_dir)
        index.append(build_index_entry(meta))

        if args.skill is None or args.skill == skill_dir.name:
            meta_path = skill_dir / "_metadata.json"
            meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
            print(f"  wrote {meta_path.relative_to(skills_dir)}")

    index_path = skills_dir / "skills-index.json"
    index_path.write_text(json.dumps(index, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"  wrote skills-index.json  ({len(index)} skill(s))")


if __name__ == "__main__":
    main()
