#!/usr/bin/env python3
"""
Analyze all GitHub issues and generate project management report.
"""

import requests
import os
import json
from collections import defaultdict

GITHUB_API_BASE = "https://api.github.com"
REPO = "therealtplum/foundry90"


def get_all_issues(token, state="open"):
    """Fetch all issues from GitHub."""
    headers = {
        'Authorization': f'token {token}',
        'Accept': 'application/vnd.github.v3+json'
    }
    
    issues = []
    page = 1
    
    while True:
        url = f"{GITHUB_API_BASE}/repos/{REPO}/issues?state={state}&per_page=100&page={page}"
        r = requests.get(url, headers=headers)
        r.raise_for_status()
        page_issues = r.json()
        
        if not page_issues:
            break
            
        issues.extend(page_issues)
        
        if len(page_issues) < 100:
            break
            
        page += 1
    
    return issues


def analyze_issues(issues):
    """Analyze issues and generate statistics."""
    stats = {
        'total': len(issues),
        'by_epic': defaultdict(list),
        'by_label': defaultdict(list),
        'no_epic': [],
        'parent_issues': [],
        'child_issues': [],
        'issues_with_parents': defaultdict(list),
    }
    
    for issue in issues:
        labels = [l['name'] for l in issue.get('labels', [])]
        
        # Find epic labels
        epic_labels = [l for l in labels if l.startswith('epic:')]
        if epic_labels:
            epic = epic_labels[0]
            stats['by_epic'][epic].append(issue)
        else:
            stats['no_epic'].append(issue)
        
        # Track all labels
        for label in labels:
            stats['by_label'][label].append(issue['number'])
        
        # Check if it's a parent (epic)
        if 'epic:' in str(labels):
            # Try to get parent info
            if 'parent_issue_url' in issue:
                parent_url = issue.get('parent_issue_url')
                if parent_url:
                    stats['issues_with_parents'][parent_url].append(issue)
    
    return stats, issues


def print_analysis(stats, issues):
    """Print formatted analysis."""
    print("=" * 80)
    print("GITHUB ISSUES ANALYSIS")
    print("=" * 80)
    print(f"\nTotal Open Issues: {stats['total']}")
    
    print("\n📊 Issues by Epic:")
    for epic, epic_issues in sorted(stats['by_epic'].items()):
        print(f"  {epic}: {len(epic_issues)} issues")
        for issue in epic_issues[:5]:
            print(f"    - #{issue['number']}: {issue['title'][:60]}")
        if len(epic_issues) > 5:
            print(f"    ... and {len(epic_issues) - 5} more")
    
    if stats['no_epic']:
        print(f"\n  No Epic: {len(stats['no_epic'])} issues")
        for issue in stats['no_epic'][:5]:
            print(f"    - #{issue['number']}: {issue['title'][:60]}")
    
    print("\n🏷️  Top Labels:")
    sorted_labels = sorted(stats['by_label'].items(), key=lambda x: len(x[1]), reverse=True)
    for label, numbers in sorted_labels[:10]:
        print(f"  {label}: {len(numbers)} issues")
    
    print("\n📋 Recent Issues (Last 10):")
    sorted_issues = sorted(issues, key=lambda x: x.get('created_at', ''), reverse=True)[:10]
    for issue in sorted_issues:
        labels_str = ', '.join([l['name'] for l in issue.get('labels', [])[:3]])
        print(f"  #{issue['number']}: {issue['title'][:50]} [{labels_str}]")
    
    return stats


if __name__ == '__main__':
    token = os.environ.get('GITHUB_TOKEN')
    if not token:
        print("Error: GITHUB_TOKEN environment variable not set")
        exit(1)
    
    print("Fetching issues...")
    issues = get_all_issues(token)
    print(f"Found {len(issues)} open issues\n")
    
    stats, issues = analyze_issues(issues)
    print_analysis(stats, issues)
    
    # Save to JSON for further processing
    with open('issues_analysis.json', 'w') as f:
        json.dump({
            'stats': {
                'total': stats['total'],
                'by_epic': {k: len(v) for k, v in stats['by_epic'].items()},
            },
            'issues': [
                {
                    'number': i['number'],
                    'title': i['title'],
                    'labels': [l['name'] for l in i.get('labels', [])],
                    'url': i['html_url'],
                    'created_at': i.get('created_at'),
                }
                for i in issues
            ]
        }, f, indent=2)
    
    print("\n✅ Analysis saved to issues_analysis.json")

