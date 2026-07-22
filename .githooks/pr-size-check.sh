#!/usr/bin/env bash
# ============================================================
# PR Size Check — Reusable Hook Logic
#
# Do NOT call this directly. It is sourced by the pre-push hook
# with repo-specific config already set:
#
#   MAX_LINES          — line change limit (default: 500)
#   EXTRA_EXCLUDES     — bash array of additional regex patterns
# ============================================================

MAX_LINES="${MAX_LINES:-500}"

# ── Common exclusions (all repos) ────────────────────────────
# Kept in sync with .github/workflows/pr-size-check-reusable.yml
COMMON_EXCLUDES=(
  "\.pbxproj$"
  "\.xcscheme$"
  "\.xcsettings$"
  "\.xcconfig$"
  "\.xctestplan$"
  "\.xcworkspace/"
  "\.xcodeproj/"
  "\.plist$"
  "\.entitlements$"
  "\.storyboard$"
  "\.xib$"
  "\.xcassets/"
  "\.modulemap$"
  "\.xcprivacy$"
  "\.strings$"
  "\.stringsdict$"
  "\.xcstrings$"
  "\.ya?ml$"
  "\.lock$"
  "\.(png|jpe?g|gif|bmp|svg|webp|heic|heif|tiff?|ico|pdf|icns)$"
  "\.(mp4|mov|m4v|avi|mpe?g|webm|mp3|wav|aiff?|m4a)$"
  "\.md$"
  "\.mdx$"
)

# ── Merge common + repo-specific exclusions ───────────────────
ALL_EXCLUDES=("${COMMON_EXCLUDES[@]}" "${EXTRA_EXCLUDES[@]}")

# ── Resolve base branch — tries origin/dev, origin/main, origin/master ──────
BASE_BRANCH=""
for candidate in origin/dev origin/main origin/master; do
  if git show-ref --verify --quiet "refs/remotes/${candidate}"; then
    BASE_BRANCH="$candidate"
    break
  fi
done

if [ -z "$BASE_BRANCH" ]; then
  echo "ℹ️  PR size check skipped: no remote base branch found."
  exit 0
fi

MERGE_BASE=$(git merge-base HEAD "$BASE_BRANCH" 2>/dev/null)
if [ -z "$MERGE_BASE" ]; then
  echo "ℹ️  PR size check skipped: no common ancestor with ${BASE_BRANCH}."
  exit 0
fi

# ── Count lines changed (excluding patterns & binaries) ──────
TOTAL_LINES=0
while IFS=$'\t' read -r added deleted filepath; do
  [ -z "$filepath" ] && continue

  # Check exclusion first
  excluded=false
  for pattern in "${ALL_EXCLUDES[@]}"; do
    if [[ "$filepath" =~ $pattern ]]; then
      excluded=true
      break
    fi
  done
  [ "$excluded" = true ] && continue

  # Binary/submodule: git diff --numstat reports "-" for these
  if [ "$added" = "-" ] || [ "$deleted" = "-" ]; then
    echo "⚠️  Binary or submodule change in non-excluded file: $filepath"
    continue
  fi

  TOTAL_LINES=$((TOTAL_LINES + added + deleted))
done < <(git diff --numstat "$MERGE_BASE"...HEAD 2>/dev/null)

# ── Warn if over limit ────────────────────────────────────────
if [ "$TOTAL_LINES" -gt "$MAX_LINES" ]; then
  echo ""
  echo "⚠️  WARNING: Your push contains ~${TOTAL_LINES} line changes (limit: ${MAX_LINES})."
  echo "   Excluded paths match the PR Size Check workflow."
  echo "   Consider splitting this into smaller PRs."
  echo ""
  echo "   To push anyway:  git push --no-verify"
  echo "   To cancel:       Ctrl+C"
  echo ""
  if [ -t 1 ] && [ -r /dev/tty ]; then
    read -r -p "   Push anyway? [y/N]: " response < /dev/tty
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
      echo "Push cancelled."
      exit 1
    fi
  else
    echo "   Non-interactive shell detected; allowing push."
  fi
fi

exit 0
