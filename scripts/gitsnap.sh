#!/bin/bash

# ==============================================================================
# USAGE & VALIDATION SECTION
# ==============================================================================
# Abort if no snapshot name is provided
if [ -z "$1" ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    echo "=============================================================================="
    echo "ERROR: Snapshot name is required."
    echo "=============================================================================="
    echo "Usage: ./git-snapshot.sh <snapshot_name> [optional_commit_message]"
    echo ""
    echo "Description:"
    echo "  Captures the current state of the codebase as a tagged snapshot."
    echo "  This is useful for protecting stable states of the Fyxxer API."
    echo ""
    echo "Example:"
    echo "  ./git-snapshot.sh working-search \"Fixed Fastify validation schema\""
    echo "=============================================================================="
    exit 1
fi

SNAPSHOT_NAME=$1
COMMIT_MSG=$2

# 1. Get current branch name
CURRENT_BRANCH=$(git branch --show-current)

if [ -z "$CURRENT_BRANCH" ]; then
    echo "Error: You are in a detached HEAD state. Cannot snapshot."
    exit 1
fi

# 2. Check for uncommitted changes
if [[ -n $(git status -s) ]]; then
    echo "Changes detected in Fyxxer source. Staging and committing..."
    git add -A
    
    # Use the second argument as commit message, or default to the snapshot name
    if [ -z "$COMMIT_MSG" ]; then
        git commit -m "Snapshot: $SNAPSHOT_NAME"
    else
        git commit -m "$COMMIT_MSG"
    fi
    
    # Push the new commit to remote
    git push origin "$CURRENT_BRANCH"
else
    echo "No local changes to commit. Proceeding with tag only."
fi

# 3. Create the unique timestamped tag
TIMESTAMP=$(TZ="America/New_York" date +%Y%m%d-%H%M%S)
# Combine user input name with timestamp for uniqueness
FULL_TAG_NAME="${SNAPSHOT_NAME}-$TIMESTAMP"

echo "Creating tag: $FULL_TAG_NAME"
git tag -a "$FULL_TAG_NAME" -m "User-initiated snapshot: $SNAPSHOT_NAME at $TIMESTAMP"

# 4. Push the tag to remote
git push origin "$FULL_TAG_NAME"

echo "=============================================================================="
echo "Snapshot complete."
echo "Branch: $CURRENT_BRANCH"
echo "Tag:    $FULL_TAG_NAME (Backed up on remote)"
echo "To revert to this state later: git reset --hard $FULL_TAG_NAME"
echo "=============================================================================="