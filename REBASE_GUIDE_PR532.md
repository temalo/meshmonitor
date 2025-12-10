# Rebase Guide for PR 532

## Understanding the Problem

Your PR 532 in the upstream repository (Yeraze/meshmonitor) is failing integration tests, likely because your feature branch has fallen behind the main branch. When a branch is behind the target branch, integration tests may fail due to:

1. **Merge conflicts** - Changes in main that conflict with your changes
2. **Missing dependencies** - Updates to dependencies that your code relies on
3. **Breaking changes** - API or interface changes in main that affect your code
4. **New test requirements** - Updates to the test suite that your changes need to accommodate

## What is Rebasing?

Rebasing is the process of moving your branch's commits to sit on top of the latest main branch. This:
- Ensures your changes work with the latest code
- Creates a clean, linear commit history
- Fixes integration test failures caused by being out of date
- Makes it easier for maintainers to review and merge your PR

## Before You Begin

### Important Limitations

**⚠️ This Copilot agent cannot perform the actual rebase for you** because:
- Rebase operations require force pushing
- Force push is not available in this sandboxed environment
- Your branch lives in your local repository and upstream

**✅ What this guide provides:**
- Step-by-step instructions for rebasing
- Automated scripts to simplify the process
- Troubleshooting guidance for common issues
- Commands you can run locally on your machine

### Prerequisites

Before rebasing, ensure you have:
1. **Git installed** on your local machine
2. **Write access** to your fork (temalo/meshmonitor)
3. **No uncommitted changes** in your working directory
4. **Backup your branch** (just in case): `git branch backup-pr532`

## Rebase Process Overview

Here's what you'll do:

```
Step 1: Identify which branch needs rebasing
Step 2: Fetch latest changes from upstream (Yeraze/meshmonitor)
Step 3: Perform the rebase operation
Step 4: Resolve any merge conflicts (if they occur)
Step 5: Test your changes locally
Step 6: Force push the rebased branch
Step 7: Verify the PR shows updated status
```

## Detailed Rebase Instructions

### Step 1: Identify Your Branch

First, figure out which local branch corresponds to PR 532. You can find this by:
1. Going to your PR: https://github.com/Yeraze/meshmonitor/pull/532
2. Looking at the branch name shown in the PR header
3. It will say something like "temalo:feature-branch-name wants to merge into Yeraze:main"

For this example, let's assume your branch is called `feature/my-feature`.

### Step 2: Set Up Your Local Environment

Open a terminal on your local machine and navigate to your meshmonitor repository:

```bash
# Navigate to your repository
cd /path/to/your/meshmonitor

# Make sure you're on your feature branch
git checkout feature/my-feature

# Verify you have the upstream remote configured
git remote -v

# If you don't see 'upstream' pointing to Yeraze/meshmonitor, add it:
git remote add upstream https://github.com/Yeraze/meshmonitor.git

# Fetch the latest changes from upstream
git fetch upstream

# Fetch your fork's latest changes
git fetch origin
```

### Step 3: Perform the Rebase

Now rebase your branch onto the latest upstream main:

```bash
# Make sure you're on your feature branch
git checkout feature/my-feature

# Start the rebase
git rebase upstream/main
```

### Step 4: Handle Merge Conflicts (If Any)

If git reports conflicts, don't panic! Here's how to resolve them:

```bash
# Git will pause and tell you which files have conflicts
# Open each conflicted file in your editor

# Look for conflict markers like this:
<<<<<<< HEAD
code from upstream/main
=======
your code
>>>>>>> your-commit-message

# Edit the file to resolve the conflict (keep what you need)
# Remove the conflict markers

# After resolving each file:
git add path/to/resolved/file

# Continue the rebase:
git rebase --continue

# Repeat this process for each commit that has conflicts
```

**If you need to abort the rebase:**
```bash
git rebase --abort
```

This returns your branch to the state before you started rebasing.

### Step 5: Test Your Changes

After the rebase completes successfully:

```bash
# Install dependencies (in case they changed)
npm install

# Run the test suite
npm test

# If there are specific integration tests, run them:
npm run test:integration

# Build the project to ensure no build errors:
npm run build
```

### Step 6: Force Push Your Rebased Branch

Once you've verified everything works:

```bash
# Force push your rebased branch
# --force-with-lease is safer than --force
git push --force-with-lease origin feature/my-feature
```

**⚠️ Warning:** Force pushing rewrites history. Only do this on your feature branches, never on main or shared branches!

### Step 7: Verify the PR

1. Go to your PR: https://github.com/Yeraze/meshmonitor/pull/532
2. Refresh the page
3. You should see:
   - Updated commit history
   - "This branch is up to date with Yeraze:main"
   - Integration tests starting to run again

## Automated Rebase Script

For convenience, here's a script that automates the rebase process. Save this as `rebase-pr532.sh`:

See `rebase-pr532.sh` in this repository.

## Common Issues and Solutions

### Issue 1: "Your branch and origin/feature-branch have diverged"

**Solution:** This is expected after a rebase. Use `git push --force-with-lease` to update the remote branch.

### Issue 2: "Cannot rebase: You have unstaged changes"

**Solution:**
```bash
# Save your changes temporarily
git stash

# Do the rebase
git rebase upstream/main

# Restore your changes
git stash pop
```

### Issue 3: Multiple Conflicts

**Solution:** If you have many conflicts, consider:
1. Taking a break and resolving them one at a time
2. Consulting with the maintainer about significant conflicts
3. Using a visual merge tool: `git mergetool`

### Issue 4: Tests Still Failing After Rebase

**Solution:**
1. Check if your code needs updates for new APIs
2. Look at recent commits in main for breaking changes
3. Read the CI logs carefully for specific error messages
4. Consider asking for help in the PR comments

## Alternative: Merge Instead of Rebase

If rebasing proves too difficult, you can alternatively merge main into your branch:

```bash
git checkout feature/my-feature
git merge upstream/main
# Resolve any conflicts
git push origin feature/my-feature
```

This is simpler but creates a merge commit instead of a linear history.

## Getting Help

If you encounter issues:

1. **Check the PR comments** - Maintainers may have left guidance
2. **Look at CI logs** - They often show exactly what's failing
3. **Ask in the PR** - Maintainers are usually happy to help
4. **Check recent commits** - See what changed in main recently

## Quick Reference Commands

```bash
# Backup your branch
git branch backup-pr532

# Add upstream remote (first time only)
git remote add upstream https://github.com/Yeraze/meshmonitor.git

# Fetch latest changes
git fetch upstream
git fetch origin

# Rebase your branch
git checkout feature/my-feature
git rebase upstream/main

# If conflicts occur
git status                    # See which files have conflicts
# ... edit files to resolve conflicts ...
git add <resolved-files>
git rebase --continue

# If you want to abort
git rebase --abort

# After successful rebase
npm install
npm test
npm run build

# Push rebased branch
git push --force-with-lease origin feature/my-feature
```

## Summary

Rebasing keeps your PR up to date with the main branch and ensures integration tests pass. The key steps are:

1. **Fetch** latest changes from upstream
2. **Rebase** your branch onto upstream/main
3. **Resolve** any conflicts
4. **Test** your changes
5. **Force push** the rebased branch

Remember: This guide is for **you to execute on your local machine**. The Copilot agent cannot perform these operations due to environment restrictions.

Good luck with your rebase! 🚀
