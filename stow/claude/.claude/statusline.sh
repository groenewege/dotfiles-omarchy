#!/bin/bash
input=$(cat)

CONTEXT_WINDOW_USED_PERCENTAGE=$(echo "$input" | jq -r '.context_window.used_percentage // 0 | floor')
MODEL_DISPLAY_NAME=$(echo "$input" | jq -r '.model.display_name')
CWD=$(echo "$input" | jq -r '.cwd')
# Show git branch if in a git repo
GIT_BRANCH=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git branch --show-current 2>/dev/null)
    if [ -n "$BRANCH" ]; then
        GIT_BRANCH="$BRANCH"
    fi
fi

echo " $MODEL_DISPLAY_NAME | ${CONTEXT_WINDOW_USED_PERCENTAGE}% | $CWD | $GIT_BRANCH"
