#!/bin/bash

# Blog Update Script
# Usage: ./update-blog.sh [commit-message]

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOG_DIR="$(dirname "$SCRIPT_DIR")"
CADDY_SERVICE="caddy"
LOG_FILE="$BLOG_DIR/tools/blog-update.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >> "$LOG_FILE"
    echo -e "${RED}ERROR:${NC} $1" >&2
}

success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: $1" >> "$LOG_FILE"
    echo -e "${GREEN}SUCCESS:${NC} $1"
}

warning() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: $1" >> "$LOG_FILE"
    echo -e "${YELLOW}WARNING:${NC} $1"
}

# Check if script is run from correct directory
if [ ! -d "$BLOG_DIR" ]; then
    error "Blog directory not found: $BLOG_DIR"
    exit 1
fi

cd "$BLOG_DIR"

# Get commit message from parameter or use auto-generated one
if [ -n "$1" ]; then
    COMMIT_MSG="$1"
else
    # Auto-generate commit message based on changes
    NEW_POSTS=$(find _posts -name "*.md" -newer .git/COMMIT_EDITMSG 2>/dev/null | wc -l)
    MODIFIED_FILES=$(git diff --name-only HEAD | wc -l)

    if [ "$NEW_POSTS" -gt 0 ]; then
        COMMIT_MSG="Add new blog post - $(date '+%Y-%m-%d')"
    elif [ "$MODIFIED_FILES" -gt 0 ]; then
        COMMIT_MSG="Update blog content - $(date '+%Y-%m-%d')"
    else
        COMMIT_MSG="Blog maintenance - $(date '+%Y-%m-%d %H:%M')"
    fi

    log "Auto-generated commit message: $COMMIT_MSG"
fi

log "Starting blog update process..."

# 1. Check if there are any changes
if git diff --quiet && git diff --cached --quiet; then
    warning "No changes detected in the repository."
    echo -n "Continue anyway? (y/N): "
    read continue_choice
    if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
        log "Update cancelled by user."
        exit 0
    fi
fi

# 2. Add all changes
log "Adding changes to git..."
git add .

# 3. Check if there are staged changes
if git diff --cached --quiet; then
    warning "No staged changes to commit."
else
    # 4. Commit changes
    log "Committing changes..."
    git commit -m "$COMMIT_MSG"
    success "Changes committed successfully"
fi

# 5. Push to remote (if configured)
if git remote get-url origin >/dev/null 2>&1; then
    log "Pushing to remote repository..."
    if git push origin main 2>/dev/null || git push origin master 2>/dev/null; then
        success "Pushed to remote repository"
    else
        warning "Failed to push to remote repository (continuing anyway)"
    fi
else
    warning "No remote repository configured"
fi

# 6. Build Jekyll site
log "Building Jekyll site..."
if JEKYLL_ENV=production bundle exec jekyll build; then
    success "Jekyll site built successfully"
else
    error "Jekyll build failed!"
    exit 1
fi

# 7. Reload Caddy server
log "Reloading Caddy server..."
if sudo systemctl reload "$CADDY_SERVICE"; then
    success "Caddy server reloaded successfully"
else
    warning "Failed to reload Caddy (site may still work)"
fi

# 8. Verify site is accessible
log "Verifying site accessibility..."
if curl -s -H "Host: geordannyblog.com" http://localhost/ >/dev/null; then
    success "Site is accessible"
else
    warning "Site accessibility check failed"
fi

# 9. Display summary
echo
echo "=================================="
echo "        UPDATE COMPLETE"
echo "=================================="
echo "Commit message: $COMMIT_MSG"
echo "Build time: $(date)"
echo "Log file: $LOG_FILE"
echo
echo "Your blog has been updated!"
echo "Visit: https://geordannyblog.com"

log "Blog update process completed successfully"
