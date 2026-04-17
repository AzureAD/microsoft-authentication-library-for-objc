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
  "\.(png|jpg|jpeg|svg|pdf|icns|gif|tiff)$"
  "\.md$"
  "\.mdx$"
)

# ── Merge common + repo-specific exclusions ───────────────────
ALL_EXCLUDES=("${COMMON_EXCLUDES[@]}" "${EXTRA_EXCLUDES[@]}")

# ── Build grep pattern ────────────────────────────────────────
GREP_PATTERN=$(printf "|%s" "${ALL_EXCLUDES[@]}")
GREP_PATTERN="${GREP_PATTERN:1}"

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

# ── Get list of changed files (excluding patterns) ───────────
mapfile -t CHANGED_FILES < <(git diff --name-only "$BASE_BRANCH"...HEAD 2>/dev/null | grep -vE "$GREP_PATTERN")

if [ "${#CHANGED_FILES[@]}" -eq 0 ]; then
  exit 0
fi

# ── Count lines changed ───────────────────────────────────────
TOTAL_LINES=$(git diff "$BASE_BRANCH"...HEAD -- "${CHANGED_FILES[@]}" 2>/dev/null \
  | grep -E "^\+|^-" \
  | grep -vE "^\+\+\+|^---" \
  | wc -l \
  | tr -d ' ')

# ── Warn if over limit ────────────────────────────────────────
if [ "$TOTAL_LINES" -gt "$MAX_LINES" ]; then
  echo ""
  echo "⚠️  WARNING: Your push contains ~${TOTAL_LINES} line changes (limit: ${MAX_LINES})."
  echo "   Consider splitting this into smaller PRs."
  echo ""
  echo "   To push anyway:  git push --no-verify"
  echo "   To cancel:       Ctrl+C"
  echo ""
  read -r -p "   Push anyway? [y/N]: " response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Push cancelled."
    exit 1
  fi
fi

exit 0
