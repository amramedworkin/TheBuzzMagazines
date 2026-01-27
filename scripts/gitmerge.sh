#!/bin/bash

# ==============================================================================
# USAGE & VALIDATION SECTION
# ==============================================================================
if [ -z "$1" ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    echo "=============================================================================="
    echo "Usage: ./gitmerge.sh <new_branch_name> [optional_commit_message]"
    echo "=============================================================================="
    exit 1
fi

NEW_BRANCH=$1
COMMIT_MSG=$2
TIMESTAMP=$(TZ="America/New_York" date +%Y%m%d-%H%M%S)

# 1. Get current branch name
ORIGINAL_BRANCH=$(git branch --show-current)

if [ -z "$ORIGINAL_BRANCH" ]; then
    echo "Error: Could not detect current branch."
    exit 1
fi

# 2. Stage, Commit, and Push current work
echo "Step 1: Saving current work on '$ORIGINAL_BRANCH'..."
git add -A
if [ -z "$COMMIT_MSG" ]; then
    git commit -m "Auto-commit before merge: $TIMESTAMP"
else
    git commit -m "$COMMIT_MSG"
fi
git push origin "$ORIGINAL_BRANCH"

# 3. Merge into main
echo "Step 2: Merging '$ORIGINAL_BRANCH' into 'main'..."
git checkout main
git pull origin main # Ensure main is up to date before merging
git merge "$ORIGINAL_BRANCH" --no-edit

# 4. Push main to remote
echo "Step 3: Updating remote main..."
git push origin main

# 5. Create and switch to the new branch
echo "Step 4: Creating and switching to new branch '$NEW_BRANCH'..."
git checkout -b "$NEW_BRANCH"

# 6. Push the new branch to remote
echo "Step 5: Setting up remote for '$NEW_BRANCH'..."
git push -u origin "$NEW_BRANCH"

echo "=============================================================================="
echo "Workflow Complete."
echo "Merged: $ORIGINAL_BRANCH -> main"
echo "Current Branch: $NEW_BRANCH (Empty/Clean on remote)"
echo "Time (ET): $TIMESTAMP"
echo "=============================================================================="