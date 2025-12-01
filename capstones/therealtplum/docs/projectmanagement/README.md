# GitHub Issues Management

Python scripts for managing GitHub issues programmatically - close issues, create new ones, update statuses, and more.

---

## 🚀 Quick Start

### Setup (3 steps)

1. **Install dependency:**
   ```bash
   pip install requests
   ```

2. **Get GitHub token:**
   - Go to https://github.com/settings/tokens
   - Generate new token (classic)
   - Select `repo` scope
   - Copy the token

3. **Set environment variable:**
   ```bash
   export GITHUB_TOKEN="your_token_here"
   ```

### Common Commands

| Action | Command |
|--------|---------|
| Close issue | `python manage_github_issues.py --close 126 --comment "Done"` |
| Create issue | `python manage_github_issues.py --open --title "Title" --body "Description"` |
| Update status | `python manage_github_issues.py --update-status 124 --status in-progress` |
| Add label | `python manage_github_issues.py --add-label 123 --label "backend"` |
| Preview changes | `python manage_github_issues.py --close 126 --dry-run` |

### Quick Examples

**Close an issue:**
```bash
python manage_github_issues.py \
  --close 126 \
  --comment "This feature is already fully implemented. Closing as completed."
```

**Mark issue as in-progress:**
```bash
python manage_github_issues.py \
  --update-status 124 \
  --status in-progress \
  --comment "Starting implementation of typed config struct."
```

**Create a new issue:**
```bash
python manage_github_issues.py \
  --open \
  --title "API Hardening: Add request tracing" \
  --body "## Description\n\nAdd request tracing..." \
  --labels "backend,epic:api-hardening"
```

---

## 📖 Full Documentation

### Scripts

- **`manage_github_issues.py`** - Main script for managing issues
- **`analyze_issues.py`** - Analyze all open issues and generate reports

### Setup Details

#### 1. Install Dependencies

```bash
pip install requests
```

Or use a virtual environment:
```bash
python3 -m venv venv
source venv/bin/activate
pip install requests
```

#### 2. Get GitHub Token

1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Give it a name (e.g., "foundry90-issue-manager")
4. Select scope: **`repo`** (Full control of private repositories)
5. Generate and copy the token

#### 3. Set Environment Variable

```bash
export GITHUB_TOKEN="your_token_here"
```

Or add to your shell profile (`~/.zshrc` or `~/.bashrc`):
```bash
echo 'export GITHUB_TOKEN="your_token_here"' >> ~/.zshrc
source ~/.zshrc
```

---

## Usage

### Close a Completed Issue

```bash
# Close issue #126 with a comment
python manage_github_issues.py --close 126 --comment "Already implemented"

# Or use config file (create JSON config first)
python manage_github_issues.py --config my_config.json
```

### Create a New Issue

```bash
python manage_github_issues.py \
  --open \
  --title "New Feature Request" \
  --body "Description of the feature" \
  --labels "enhancement,backend" \
  --assignees "therealtplum"
```

### Update Issue Status

```bash
# Mark issue as in-progress
python manage_github_issues.py \
  --update-status 124 \
  --status in-progress \
  --comment "Starting work on this issue"
```

### Add Labels

```bash
python manage_github_issues.py \
  --add-label 123 \
  --label "backend"
```

### Update Issue Details

```bash
python manage_github_issues.py \
  --update 124 \
  --title "Updated Title" \
  --body "Updated description" \
  --state open \
  --labels "backend,epic:api-hardening"
```

### Dry Run (Preview Changes)

```bash
# See what would happen without making changes
python manage_github_issues.py --close 126 --comment "Test" --dry-run
```

---

## Configuration Files

You can use JSON configuration files for batch operations. Create a JSON file with the following structure:

### Close Issues

```json
{
  "close": [
    {
      "issue": 126,
      "comment": "Closing comment explaining why"
    }
  ]
}
```

### Update Statuses

```json
{
  "status": [
    {
      "issue": 124,
      "status": "in-progress",
      "comment": "Starting work on this"
    }
  ]
}
```

### Create Issues

```json
{
  "create": [
    {
      "title": "New Issue",
      "body": "Description",
      "labels": ["enhancement"],
      "assignees": ["therealtplum"]
    }
  ]
}
```

### Full Config Example

```json
{
  "close": [
    {
      "issue": 126,
      "comment": "Already implemented"
    }
  ],
  "create": [
    {
      "title": "New Issue",
      "body": "Description",
      "labels": ["enhancement"],
      "assignees": ["therealtplum"]
    }
  ],
  "update": [
    {
      "issue": 124,
      "title": "Updated Title",
      "labels": ["backend"]
    }
  ],
  "status": [
    {
      "issue": 124,
      "status": "in-progress",
      "comment": "Starting work"
    }
  ]
}
```

Then run:
```bash
python manage_github_issues.py --config my_config.json
```

---

## Status Labels

The script supports these status labels:
- `in-progress` - Issue is being actively worked on
- `blocked` - Issue is blocked by something
- `ready-for-review` - Issue is ready for code review
- `needs-triage` - Issue needs to be triaged
- `todo` - Remove status labels (default state)

---

## Examples

### Close Issue #126 (Already Implemented)

```bash
python manage_github_issues.py \
  --close 126 \
  --comment "This feature is already fully implemented. See FocusTickerStrip.tsx lines 207-222. Closing as completed."
```

### Mark Issue #124 as In-Progress

```bash
python manage_github_issues.py \
  --update-status 124 \
  --status in-progress \
  --comment "Starting implementation of typed config struct as foundation for API hardening epic."
```

---

## Troubleshooting

### "GitHub token required"
- Make sure `GITHUB_TOKEN` environment variable is set
- Or use `--token` flag: `--token your_token_here`

### "404 Not Found"
- Check that the repository name is correct (default: `therealtplum/foundry90`)
- Use `--repo` flag to override if needed

### "403 Forbidden"
- Your token may not have the required permissions
- Make sure the token has `repo` scope
- Token may have expired - generate a new one

### "Invalid JSON"
- Check your config file syntax
- Use a JSON validator online

### "Error: 'requests' library is required"
- Install with: `pip install requests`
- Or use virtual environment (see Setup section)

---

## Safety Features

- **Dry run mode** (`--dry-run`) to preview changes before executing
- **Comments added** before closing issues (audit trail)
- **Error handling** with clear messages
- **Validation** of required parameters

---

## Script Location

The scripts are located in:
```
capstones/therealtplum/docs/projectmanagement/
```

Make scripts executable:
```bash
chmod +x manage_github_issues.py
chmod +x analyze_issues.py
```

Then run directly:
```bash
./manage_github_issues.py --close 126 --comment "Done"
```

---

## Help

Get full help:
```bash
python manage_github_issues.py --help
```

---

## Related Files

- `ISSUES_IN_PROGRESS_AND_TODO.md` - Prioritized work items
- `PROJECT_MANAGEMENT_PLAN.md` - Comprehensive project plan


