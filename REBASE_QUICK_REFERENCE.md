# Quick Reference: Rebasing PR 532

## TL;DR - Fast Track

```bash
# Method 1: Use the automated script (recommended)
bash rebase-pr532.sh

# Method 2: Manual commands
git checkout <your-branch>
git fetch upstream
git rebase upstream/main
# ... resolve conflicts if any ...
git push --force-with-lease origin <your-branch>
```

## What's the Problem?

Your PR 532 is failing integration tests because your branch is behind the main branch.

## What's the Solution?

Rebase your branch onto the latest main branch to bring it up to date.

## Why Can't Copilot Do This?

Rebasing requires force pushing, which isn't available in the sandboxed environment. You need to do this on your local machine.

## Quick Steps

### 1️⃣ On Your Local Machine

```bash
cd /path/to/your/meshmonitor
```

### 2️⃣ Run the Automated Script

```bash
bash rebase-pr532.sh
```

The script will:
- ✅ Create a backup of your branch
- ✅ Fetch latest changes from upstream
- ✅ Rebase your branch
- ✅ Guide you through conflict resolution
- ✅ Provide next steps

### 3️⃣ Test Your Changes

```bash
npm install
npm test
npm run build
```

### 4️⃣ Push the Rebased Branch

```bash
git push --force-with-lease origin <your-branch>
```

### 5️⃣ Check Your PR

Visit: https://github.com/Yeraze/meshmonitor/pull/532

## Manual Rebase (If Script Fails)

### Setup (First Time Only)
```bash
git remote add upstream https://github.com/Yeraze/meshmonitor.git
```

### Every Time
```bash
# 1. Backup your branch
git branch backup-$(date +%Y%m%d)

# 2. Checkout your PR branch
git checkout <your-branch-name>

# 3. Fetch latest changes
git fetch upstream
git fetch origin

# 4. Rebase
git rebase upstream/main

# 5. If conflicts occur
git status                    # See conflicted files
# Edit files to resolve conflicts
git add <resolved-files>
git rebase --continue
# Repeat until done

# 6. Test
npm install && npm test && npm run build

# 7. Push
git push --force-with-lease origin <your-branch-name>
```

## Conflict Resolution

If you see conflicts:

```
<<<<<<< HEAD
Code from main branch
=======
Your code
>>>>>>> Your commit message
```

**Steps:**
1. Edit the file - keep what you need, remove markers
2. `git add <file>`
3. `git rebase --continue`
4. Repeat for each conflict

**To abort:** `git rebase --abort`

## Common Errors

### "Cannot rebase: You have unstaged changes"
```bash
git stash
git rebase upstream/main
git stash pop
```

### "Your branch and origin/branch have diverged"
This is normal after rebasing. Use:
```bash
git push --force-with-lease origin <branch>
```

### "Failed to fetch from upstream"
Check your network and remote:
```bash
git remote -v
git remote set-url upstream https://github.com/Yeraze/meshmonitor.git
```

## Alternative: Merge Instead

If rebasing is too complex:
```bash
git checkout <your-branch>
git merge upstream/main
git push origin <your-branch>
```

This is easier but creates a merge commit.

## Files in This Repository

- **REBASE_GUIDE_PR532.md** - Comprehensive guide with detailed explanations
- **rebase-pr532.sh** - Automated script to perform the rebase
- **REBASE_QUICK_REFERENCE.md** - This file

## Need Help?

1. Read the full guide: `REBASE_GUIDE_PR532.md`
2. Check PR comments for maintainer guidance
3. Look at CI logs for specific errors
4. Ask in the PR if you're stuck

## Success Checklist

- [ ] Backed up my branch
- [ ] Fetched from upstream
- [ ] Rebased onto upstream/main
- [ ] Resolved any conflicts
- [ ] Ran tests successfully
- [ ] Force pushed rebased branch
- [ ] Verified PR shows as up-to-date
- [ ] Integration tests are passing

## Remember

⚠️ **Force pushing rewrites history** - Only do this on your feature branches, never on main!

✅ **Backup before rebasing** - You can always restore if something goes wrong

🧪 **Test before pushing** - Make sure everything works after rebasing

🚀 **Good luck with your rebase!**
