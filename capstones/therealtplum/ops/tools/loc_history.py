#!/usr/bin/env python3
import csv
import json
import subprocess
import tempfile
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any

REPO_ROOT = Path(__file__).resolve().parents[1]  # adjust if needed
OUTPUT_CSV = REPO_ROOT / "data" / "loc_history.csv"
OUTPUT_JSON = REPO_ROOT / "data" / "loc_history.json"
BRANCH = "main"

# Directories to exclude (same as your cloc runs)
EXCLUDE_DIRS = [
    ".next",
    "node_modules",
    "dist",
    "build",
    "out",
    "target",
    "DerivedData",
    "Pods",
]

# Languages to ignore entirely (not counted in totals or per-language)
IGNORE_LANGUAGES = {"JSON", "Markdown"}

# How aggressively to sample commits (e.g. every 10th commit)
COMMIT_STRIDE = 1  # lower = more precise, higher = faster


@dataclass
class LocSnapshot:
    sha: str
    date: str  # ISO date
    total_code: int
    by_language: Dict[str, int]


def run(cmd: List[str], cwd: Path | None = None) -> str:
    result = subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=True,
    )
    return result.stdout.strip()


def get_commits(branch: str) -> List[tuple[str, str]]:
    """
    Returns list of (sha, date) for branch, oldest -> newest,
    first-parent only (so you follow the mainline history).
    """
    log_format = "%H,%cI"
    output = run(
        ["git", "log", "--first-parent", "--reverse", f"--format={log_format}", branch],
        cwd=REPO_ROOT,
    )
    commits: List[tuple[str, str]] = []
    for line in output.splitlines():
        sha, date = line.split(",", 1)
        commits.append((sha, date))
    return commits


def cloc_for_commit(sha: str) -> LocSnapshot:
    """
    Checkout the given commit in a detached HEAD in a temporary worktree,
    run cloc with excludes, parse JSON, then remove the worktree.
    This avoids trashing your working tree.
    """
    # Create a temporary worktree
    tmpdir = tempfile.mkdtemp(prefix="loc-worktree-")
    tmp_path = Path(tmpdir)

    try:
        # Add worktree for this commit
        run(["git", "worktree", "add", "--detach", str(tmp_path), sha], cwd=REPO_ROOT)

        # Build cloc command
        exclude_arg = ",".join(EXCLUDE_DIRS)
        cloc_cmd = [
            "cloc",
            ".",
            f"--exclude-dir={exclude_arg}",
            "--json",
            "--quiet",
        ]

        cloc_output = run(cloc_cmd, cwd=tmp_path)

        data = json.loads(cloc_output)

        # Recalculate total_code EXCLUDING ignored languages
        total_code = 0
        for lang, stats in data.items():
            if lang in IGNORE_LANGUAGES:
                continue
            if lang in ("header", "SUM"):
                continue
            code = int(stats.get("code", 0))
            total_code += code

        # Extract per-language totals, also excluding ignored languages
        by_language: Dict[str, int] = {}
        for lang, stats in data.items():
            if lang in IGNORE_LANGUAGES:
                continue
            if lang in ("header", "SUM"):
                continue
            code = int(stats.get("code", 0))
            if code > 0:
                by_language[lang] = code

        # Get commit date via git
        date_str = run(["git", "show", "-s", "--format=%cI", sha], cwd=REPO_ROOT)

        return LocSnapshot(
            sha=sha,
            date=date_str,
            total_code=total_code,
            by_language=by_language,
        )
    finally:
        # Remove worktree
        run(["git", "worktree", "remove", "--force", str(tmp_path)], cwd=REPO_ROOT)


def main() -> None:
    REPO_ROOT.mkdir(parents=True, exist_ok=True)
    OUTPUT_CSV.parent.mkdir(parents=True, exist_ok=True)

    commits = get_commits(BRANCH)
    if not commits:
        raise SystemExit("No commits found on branch {BRANCH}")

    snapshots: List[LocSnapshot] = []

    # Sample commits: every COMMIT_STRIDE-th commit, plus the last
    for idx, (sha, _date) in enumerate(commits):
        if idx % COMMIT_STRIDE != 0 and idx != len(commits) - 1:
            continue
        print(f"[loc_history] Processing {idx+1}/{len(commits)}: {sha}")
        snapshot = cloc_for_commit(sha)
        snapshots.append(snapshot)

    # Sort snapshots by date just in case
    snapshots.sort(key=lambda s: s.date)

    # Write CSV
    fieldnames = ["date", "sha", "total_code", "languages"]
    with OUTPUT_CSV.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for snap in snapshots:
            writer.writerow(
                {
                    "date": snap.date,
                    "sha": snap.sha,
                    "total_code": snap.total_code,
                    "languages": ";".join(
                        f"{lang}:{loc}" for lang, loc in snap.by_language.items()
                    ),
                }
            )

    # Also write JSON for direct import into the dashboard
    json_payload: List[Dict[str, Any]] = []
    for snap in snapshots:
        json_payload.append(
            {
                "date": snap.date,
                "sha": snap.sha,
                "total_code": snap.total_code,
                "by_language": snap.by_language,
            }
        )

    with OUTPUT_JSON.open("w") as f:
        json.dump(json_payload, f, indent=2)

    print(f"[loc_history] Wrote {len(snapshots)} snapshots to:")
    print(f" - {OUTPUT_CSV}")
    print(f" - {OUTPUT_JSON}")


if __name__ == "__main__":
    main()