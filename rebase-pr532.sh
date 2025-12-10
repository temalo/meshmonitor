#!/bin/bash

# Automated Rebase Script for PR 532
# This script helps you rebase your branch onto the latest upstream main

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
UPSTREAM_REPO="https://github.com/Yeraze/meshmonitor.git"
UPSTREAM_BRANCH="main"
REMOTE_NAME="upstream"

echo -e "${BLUE}=================================${NC}"
echo -e "${BLUE}PR 532 Rebase Helper Script${NC}"
echo -e "${BLUE}=================================${NC}"
echo ""

# Function to print colored messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Step 0: Verify we're in a git repository
if [ ! -d ".git" ]; then
    print_error "Not in a git repository. Please navigate to your meshmonitor directory."
    exit 1
fi
print_success "In git repository"

# Step 1: Detect or ask for the feature branch name
print_info "Step 1: Identifying your feature branch..."

# Try to detect the current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
print_info "Currently on branch: $CURRENT_BRANCH"

echo ""
read -p "Is '$CURRENT_BRANCH' the branch for PR 532? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    read -p "Enter the name of your PR 532 branch: " FEATURE_BRANCH
    print_info "Switching to branch: $FEATURE_BRANCH"
    git checkout "$FEATURE_BRANCH" || {
        print_error "Failed to checkout branch '$FEATURE_BRANCH'"
        exit 1
    }
else
    FEATURE_BRANCH="$CURRENT_BRANCH"
fi

print_success "Working with branch: $FEATURE_BRANCH"
echo ""

# Step 2: Check for uncommitted changes
print_info "Step 2: Checking for uncommitted changes..."
if [ -n "$(git status --porcelain)" ]; then
    print_warning "You have uncommitted changes!"
    echo ""
    git status --short
    echo ""
    read -p "Do you want to stash these changes? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git stash push -m "Auto-stash before rebase PR 532 - $(date '+%Y-%m-%d %H:%M:%S')"
        print_success "Changes stashed"
        STASHED=true
    else
        print_error "Please commit or stash your changes before rebasing"
        exit 1
    fi
else
    print_success "No uncommitted changes"
    STASHED=false
fi
echo ""

# Step 3: Create backup branch
print_info "Step 3: Creating backup branch..."
BACKUP_BRANCH="${FEATURE_BRANCH}-rebase-backup-$(date +%Y%m%d-%H%M%S)"
git branch "$BACKUP_BRANCH"
print_success "Backup created: $BACKUP_BRANCH"
echo ""

# Step 4: Setup upstream remote
print_info "Step 4: Setting up upstream remote..."
if git remote get-url "$REMOTE_NAME" &>/dev/null; then
    EXISTING_UPSTREAM=$(git remote get-url "$REMOTE_NAME")
    if [ "$EXISTING_UPSTREAM" != "$UPSTREAM_REPO" ]; then
        print_warning "Upstream remote exists but points to different repo"
        print_info "Existing: $EXISTING_UPSTREAM"
        print_info "Expected: $UPSTREAM_REPO"
        read -p "Update upstream remote? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git remote set-url "$REMOTE_NAME" "$UPSTREAM_REPO"
            print_success "Updated upstream remote"
        else
            print_error "Cannot proceed without correct upstream remote"
            exit 1
        fi
    else
        print_success "Upstream remote already configured"
    fi
else
    print_info "Adding upstream remote..."
    git remote add "$REMOTE_NAME" "$UPSTREAM_REPO"
    print_success "Added upstream remote"
fi
echo ""

# Step 5: Fetch latest changes
print_info "Step 5: Fetching latest changes from upstream..."
git fetch "$REMOTE_NAME" || {
    print_error "Failed to fetch from upstream"
    exit 1
}
print_success "Fetched from upstream"

print_info "Fetching from origin..."
git fetch origin || {
    print_warning "Failed to fetch from origin (continuing anyway)"
}
echo ""

# Step 6: Show what will be rebased
print_info "Step 6: Analyzing commits to rebase..."
COMMITS_BEHIND=$(git rev-list --count HEAD..${REMOTE_NAME}/${UPSTREAM_BRANCH})
COMMITS_AHEAD=$(git rev-list --count ${REMOTE_NAME}/${UPSTREAM_BRANCH}..HEAD)

print_info "Your branch is:"
print_info "  - $COMMITS_AHEAD commit(s) ahead of upstream/$UPSTREAM_BRANCH"
print_info "  - $COMMITS_BEHIND commit(s) behind upstream/$UPSTREAM_BRANCH"
echo ""

if [ "$COMMITS_BEHIND" -eq 0 ]; then
    print_success "Your branch is already up to date!"
    echo ""
    read -p "Do you still want to proceed with rebase? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Rebase cancelled"
        exit 0
    fi
fi

# Step 7: Confirm rebase
echo ""
print_warning "This will rebase your $COMMITS_AHEAD commit(s) onto upstream/$UPSTREAM_BRANCH"
print_info "You can restore from backup branch '$BACKUP_BRANCH' if needed"
echo ""
read -p "Proceed with rebase? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Rebase cancelled"
    exit 0
fi
echo ""

# Step 8: Perform rebase
print_info "Step 8: Rebasing onto ${REMOTE_NAME}/${UPSTREAM_BRANCH}..."
print_info "If conflicts occur, the script will guide you through resolving them"
echo ""

if git rebase "${REMOTE_NAME}/${UPSTREAM_BRANCH}"; then
    print_success "Rebase completed successfully!"
else
    print_error "Rebase encountered conflicts"
    print_info "To resolve conflicts:"
    print_info "  1. Edit the conflicted files (marked in 'git status')"
    print_info "  2. Stage resolved files: git add <file>"
    print_info "  3. Continue rebase: git rebase --continue"
    print_info "  4. Repeat until rebase completes"
    print_info ""
    print_info "Or to abort: git rebase --abort"
    print_info "Then restore from backup: git reset --hard $BACKUP_BRANCH"
    exit 1
fi
echo ""

# Step 9: Restore stashed changes if any
if [ "$STASHED" = true ]; then
    print_info "Step 9: Restoring stashed changes..."
    if git stash pop; then
        print_success "Stashed changes restored"
    else
        print_warning "Could not restore stashed changes (conflicts?)"
        print_info "Your changes are still in the stash: git stash list"
    fi
    echo ""
fi

# Step 10: Success message and next steps
print_success "Rebase completed successfully!"
echo ""
echo -e "${GREEN}=================================${NC}"
echo -e "${GREEN}Next Steps:${NC}"
echo -e "${GREEN}=================================${NC}"
echo ""
print_info "1. Test your changes:"
echo "   npm install"
echo "   npm test"
echo "   npm run build"
echo ""
print_info "2. If tests pass, force push your rebased branch:"
echo "   git push --force-with-lease origin $FEATURE_BRANCH"
echo ""
print_info "3. Verify PR 532 on GitHub:"
echo "   https://github.com/Yeraze/meshmonitor/pull/532"
echo ""
print_info "4. If something went wrong, restore from backup:"
echo "   git reset --hard $BACKUP_BRANCH"
echo ""
print_success "Good luck! 🚀"
