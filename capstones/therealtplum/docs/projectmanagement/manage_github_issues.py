#!/usr/bin/env python3
"""
GitHub Issues Management Script

This script helps manage GitHub issues by:
- Closing completed issues with comments
- Opening new issues
- Updating issue status (adding labels, comments, etc.)

Usage:
    python manage_github_issues.py --config issues_to_close.json
    python manage_github_issues.py --close 126 --comment "Fixed in PR #123"
    python manage_github_issues.py --open --title "New Issue" --body "Description"
    python manage_github_issues.py --update 124 --label "in-progress"

Configuration:
    Set GITHUB_TOKEN environment variable or use --token flag
    Repository: therealtplum/foundry90 (default)
"""

import argparse
import json
import os
import sys
from typing import Dict, List, Optional
from datetime import datetime

try:
    import requests
except ImportError:
    print("Error: 'requests' library is required. Install with: pip install requests")
    sys.exit(1)


# GitHub API configuration
GITHUB_API_BASE = "https://api.github.com"
DEFAULT_REPO = "therealtplum/foundry90"


class GitHubIssueManager:
    """Manages GitHub issues via the GitHub API."""

    def __init__(self, token: str, repo: str = DEFAULT_REPO):
        """
        Initialize the GitHub issue manager.

        Args:
            token: GitHub personal access token
            repo: Repository in format 'owner/repo'
        """
        self.token = token
        self.repo = repo
        self.headers = {
            "Authorization": f"token {token}",
            "Accept": "application/vnd.github.v3+json",
            "X-GitHub-Api-Version": "2022-11-28",
        }
        self.session = requests.Session()
        self.session.headers.update(self.headers)

    def _make_request(
        self, method: str, endpoint: str, data: Optional[Dict] = None
    ) -> Dict:
        """
        Make a request to the GitHub API.

        Args:
            method: HTTP method (GET, POST, PATCH, etc.)
            endpoint: API endpoint (relative to base)
            data: Request payload

        Returns:
            Response JSON as dict

        Raises:
            SystemExit: If request fails
        """
        url = f"{GITHUB_API_BASE}/repos/{self.repo}/{endpoint}"
        
        try:
            if method == "GET":
                response = self.session.get(url, json=data)
            elif method == "POST":
                response = self.session.post(url, json=data)
            elif method == "PATCH":
                response = self.session.patch(url, json=data)
            else:
                raise ValueError(f"Unsupported method: {method}")

            response.raise_for_status()
            return response.json()
        except requests.exceptions.HTTPError as e:
            print(f"❌ GitHub API Error: {e}")
            if hasattr(e.response, 'text'):
                print(f"Response: {e.response.text}")
            sys.exit(1)
        except requests.exceptions.RequestException as e:
            print(f"❌ Request failed: {e}")
            sys.exit(1)

    def get_issue(self, issue_number: int) -> Dict:
        """
        Get issue details.

        Args:
            issue_number: Issue number

        Returns:
            Issue data as dict
        """
        return self._make_request("GET", f"issues/{issue_number}")

    def close_issue(self, issue_number: int, comment: Optional[str] = None) -> Dict:
        """
        Close an issue and optionally add a comment.

        Args:
            issue_number: Issue number to close
            comment: Optional comment to add before closing

        Returns:
            Updated issue data
        """
        # Add comment if provided
        if comment:
            self.add_comment(issue_number, comment)

        # Close the issue
        data = {"state": "closed", "state_reason": "completed"}
        result = self._make_request("PATCH", f"issues/{issue_number}", data)
        print(f"✅ Closed issue #{issue_number}: {result.get('title', '')}")
        return result

    def add_comment(self, issue_number: int, body: str) -> Dict:
        """
        Add a comment to an issue.

        Args:
            issue_number: Issue number
            body: Comment body

        Returns:
            Comment data
        """
        data = {"body": body}
        result = self._make_request("POST", f"issues/{issue_number}/comments", data)
        print(f"💬 Added comment to issue #{issue_number}")
        return result

    def create_issue(
        self,
        title: str,
        body: str,
        labels: Optional[List[str]] = None,
        assignees: Optional[List[str]] = None,
        milestone: Optional[int] = None,
    ) -> Dict:
        """
        Create a new issue.

        Args:
            title: Issue title
            body: Issue body/description
            labels: List of label names
            assignees: List of usernames to assign
            milestone: Milestone number

        Returns:
            Created issue data
        """
        data = {
            "title": title,
            "body": body,
        }
        
        if labels:
            data["labels"] = labels
        if assignees:
            data["assignees"] = assignees
        if milestone:
            data["milestone"] = milestone

        result = self._make_request("POST", "issues", data)
        print(f"✅ Created issue #{result['number']}: {title}")
        return result

    def update_issue(
        self,
        issue_number: int,
        title: Optional[str] = None,
        body: Optional[str] = None,
        state: Optional[str] = None,
        labels: Optional[List[str]] = None,
        assignees: Optional[List[str]] = None,
        milestone: Optional[int] = None,
    ) -> Dict:
        """
        Update an issue.

        Args:
            issue_number: Issue number
            title: New title (optional)
            body: New body (optional)
            state: New state ('open' or 'closed') (optional)
            labels: New labels (optional)
            assignees: New assignees (optional)
            milestone: Milestone number (optional)

        Returns:
            Updated issue data
        """
        data = {}
        
        if title:
            data["title"] = title
        if body:
            data["body"] = body
        if state:
            data["state"] = state
        if labels is not None:
            data["labels"] = labels
        if assignees is not None:
            data["assignees"] = assignees
        if milestone:
            data["milestone"] = milestone

        if not data:
            print("⚠️  No updates specified")
            return self.get_issue(issue_number)

        result = self._make_request("PATCH", f"issues/{issue_number}", data)
        print(f"✅ Updated issue #{issue_number}: {result.get('title', '')}")
        return result

    def add_label(self, issue_number: int, label: str) -> Dict:
        """
        Add a label to an issue.

        Args:
            issue_number: Issue number
            label: Label name

        Returns:
            Label data
        """
        # Get current labels
        issue = self.get_issue(issue_number)
        current_labels = [l["name"] for l in issue.get("labels", [])]
        
        if label in current_labels:
            print(f"ℹ️  Issue #{issue_number} already has label '{label}'")
            return {"name": label}

        # Add the label
        new_labels = current_labels + [label]
        return self.update_issue(issue_number, labels=new_labels)

    def remove_label(self, issue_number: int, label: str) -> Dict:
        """
        Remove a label from an issue.

        Args:
            issue_number: Issue number
            label: Label name to remove

        Returns:
            Updated issue data
        """
        # Get current labels
        issue = self.get_issue(issue_number)
        current_labels = [l["name"] for l in issue.get("labels", [])]
        
        if label not in current_labels:
            print(f"ℹ️  Issue #{issue_number} doesn't have label '{label}'")
            return issue

        # Remove the label
        new_labels = [l for l in current_labels if l != label]
        return self.update_issue(issue_number, labels=new_labels)

    def set_status(
        self,
        issue_number: int,
        status: str,
        comment: Optional[str] = None,
    ) -> Dict:
        """
        Set issue status using labels (e.g., 'in-progress', 'blocked').

        Args:
            issue_number: Issue number
            status: Status label (e.g., 'in-progress', 'blocked', 'ready-for-review')
            comment: Optional comment explaining status change

        Returns:
            Updated issue data
        """
        # Common status labels
        status_labels = {
            "in-progress": ["in-progress"],
            "blocked": ["blocked"],
            "ready-for-review": ["ready-for-review"],
            "needs-triage": ["needs-triage"],
            "todo": [],  # Remove status labels to mark as todo
        }

        # Get current labels
        issue = self.get_issue(issue_number)
        current_labels = [l["name"] for l in issue.get("labels", [])]
        
        # Remove existing status labels
        status_label_names = [
            "in-progress",
            "blocked",
            "ready-for-review",
            "needs-triage",
        ]
        filtered_labels = [l for l in current_labels if l not in status_label_names]
        
        # Add new status label
        if status in status_labels:
            new_labels = filtered_labels + status_labels[status]
        else:
            # Custom status - just add it
            new_labels = filtered_labels + [status]

        # Update issue
        result = self.update_issue(issue_number, labels=new_labels)
        
        # Add comment if provided
        if comment:
            comment_body = f"**Status changed to: {status}**\n\n{comment}"
            self.add_comment(issue_number, comment_body)

        print(f"📊 Set issue #{issue_number} status to: {status}")
        return result


def load_config(config_file: str) -> Dict:
    """Load configuration from JSON file."""
    try:
        with open(config_file, "r") as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"❌ Config file not found: {config_file}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"❌ Invalid JSON in config file: {e}")
        sys.exit(1)


def process_config(manager: GitHubIssueManager, config: Dict):
    """Process a configuration file with batch operations."""
    
    # Close issues
    if "close" in config:
        for item in config["close"]:
            issue_num = item.get("issue")
            comment = item.get("comment", "")
            manager.close_issue(issue_num, comment)

    # Create issues
    if "create" in config:
        for item in config["create"]:
            manager.create_issue(
                title=item["title"],
                body=item.get("body", ""),
                labels=item.get("labels", []),
                assignees=item.get("assignees", []),
                milestone=item.get("milestone"),
            )

    # Update issues
    if "update" in config:
        for item in config["update"]:
            manager.update_issue(
                issue_number=item["issue"],
                title=item.get("title"),
                body=item.get("body"),
                state=item.get("state"),
                labels=item.get("labels"),
                assignees=item.get("assignees"),
                milestone=item.get("milestone"),
            )

    # Set status
    if "status" in config:
        for item in config["status"]:
            manager.set_status(
                issue_number=item["issue"],
                status=item["status"],
                comment=item.get("comment"),
            )


def main():
    parser = argparse.ArgumentParser(
        description="Manage GitHub issues for foundry90 repository",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Close issue #126 with a comment
  python manage_github_issues.py --close 126 --comment "Already implemented"

  # Create a new issue
  python manage_github_issues.py --open --title "New Feature" --body "Description"

  # Update issue status to in-progress
  python manage_github_issues.py --update-status 124 --status in-progress

  # Add label to issue
  python manage_github_issues.py --add-label 123 --label "backend"

  # Process batch operations from config file
  python manage_github_issues.py --config issues_config.json
        """,
    )

    # Authentication
    parser.add_argument(
        "--token",
        help="GitHub personal access token (or set GITHUB_TOKEN env var)",
        default=os.getenv("GITHUB_TOKEN"),
    )
    parser.add_argument(
        "--repo",
        help=f"Repository (default: {DEFAULT_REPO})",
        default=DEFAULT_REPO,
    )

    # Operations
    parser.add_argument("--config", help="Process batch operations from JSON config file")
    
    parser.add_argument("--close", type=int, help="Close an issue by number")
    parser.add_argument("--comment", help="Comment to add (use with --close or --update)")
    
    parser.add_argument("--open", action="store_true", help="Create a new issue")
    parser.add_argument("--title", help="Issue title (use with --open)")
    parser.add_argument("--body", help="Issue body/description (use with --open or --update)")
    parser.add_argument(
        "--labels",
        help="Comma-separated list of labels (use with --open or --update)",
    )
    parser.add_argument(
        "--assignees",
        help="Comma-separated list of assignees (use with --open or --update)",
    )
    
    parser.add_argument("--update", type=int, help="Update an issue by number")
    parser.add_argument("--state", choices=["open", "closed"], help="Set issue state")
    
    parser.add_argument(
        "--update-status",
        type=int,
        help="Set issue status label (in-progress, blocked, etc.)",
    )
    parser.add_argument(
        "--status",
        choices=["in-progress", "blocked", "ready-for-review", "needs-triage", "todo"],
        help="Status to set (use with --update-status)",
    )
    
    parser.add_argument("--add-label", type=int, help="Add label to issue")
    parser.add_argument("--label", help="Label name (use with --add-label)")
    
    parser.add_argument("--dry-run", action="store_true", help="Show what would be done without making changes")

    args = parser.parse_args()

    # Validate token
    if not args.token:
        print("❌ Error: GitHub token required")
        print("Set GITHUB_TOKEN environment variable or use --token flag")
        print("\nCreate a token at: https://github.com/settings/tokens")
        print("Required scopes: repo (full control of private repositories)")
        sys.exit(1)

    # Initialize manager
    manager = GitHubIssueManager(args.token, args.repo)

    # Process config file
    if args.config:
        if args.dry_run:
            print("🔍 DRY RUN: Would process config file:", args.config)
            config = load_config(args.config)
            print(json.dumps(config, indent=2))
            return
        config = load_config(args.config)
        process_config(manager, config)
        return

    # Dry run mode
    if args.dry_run:
        print("🔍 DRY RUN: Would perform the following operations:")
        if args.close:
            print(f"  - Close issue #{args.close}")
        if args.open:
            print(f"  - Create issue: {args.title}")
        if args.update:
            print(f"  - Update issue #{args.update}")
        if args.update_status:
            print(f"  - Set issue #{args.update_status} status to: {args.status}")
        return

    # Close issue
    if args.close:
        manager.close_issue(args.close, args.comment)
        return

    # Create issue
    if args.open:
        if not args.title:
            print("❌ Error: --title required when creating issue")
            sys.exit(1)
        
        labels = args.labels.split(",") if args.labels else []
        assignees = args.assignees.split(",") if args.assignees else []
        
        manager.create_issue(
            title=args.title,
            body=args.body or "",
            labels=labels,
            assignees=assignees,
        )
        return

    # Update issue
    if args.update:
        labels = args.labels.split(",") if args.labels else None
        assignees = args.assignees.split(",") if args.assignees else None
        
        manager.update_issue(
            issue_number=args.update,
            title=args.title,
            body=args.body,
            state=args.state,
            labels=labels,
            assignees=assignees,
        )
        if args.comment:
            manager.add_comment(args.update, args.comment)
        return

    # Update status
    if args.update_status:
        if not args.status:
            print("❌ Error: --status required when updating status")
            sys.exit(1)
        manager.set_status(args.update_status, args.status, args.comment)
        return

    # Add label
    if args.add_label:
        if not args.label:
            print("❌ Error: --label required when adding label")
            sys.exit(1)
        manager.add_label(args.add_label, args.label)
        return

    # No operation specified
    parser.print_help()


if __name__ == "__main__":
    main()

