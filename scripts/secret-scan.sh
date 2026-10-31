#!/usr/bin/env bash
# Searches the repository for keys and personal data (AC-13, plan.md P-01). Run before every push.
# Modelled on Interview Copilot (scripts/secret-scan.sh, commit cf0e764); patterns per R-30 (Groq, Mistral, OpenRouter).
#   scripts/secret-scan.sh              — working tree (tracked and new files) + index + the whole Git history
#   scripts/secret-scan.sh --no-history — without history (fast)
# Output: lines with findings (values masked) and a total "N findings". Exit code 1 if N > 0.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

HISTORY=1
[ "${1:-}" = "--no-history" ] && HISTORY=0

# Provider keys.
KEY_PATTERNS=(
  'gsk_[A-Za-z0-9]{20,}'                         # Groq
  'sk-or-(v1-)?[A-Za-z0-9]{32,}'                 # OpenRouter
  'sk-[A-Za-z0-9_-]{32,}'                        # generic OpenAI-compatible
  'AIza[0-9A-Za-z_-]{35}'                        # Google (Gemini is not used, but such a key must never get in)
  '(mistral|MISTRAL)[A-Za-z_]*[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Za-z0-9]{32}'   # Mistral: a key without a prefix — searched next to the name
  'Bearer [A-Za-z0-9_-]{24,}'                    # a header with a key in logs and fixtures
)
# Personal data: emails and phone numbers. Excluded: packages/contracts/evals/ (synthetic) and this script.
EMAIL_PATTERN='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
PHONE_PATTERN='(\+[0-9]{1,3}[ -]?\(?[0-9]{2,4}\)?[ -]?[0-9]{3}[ -]?[0-9]{2}[ -]?[0-9]{2})|(\(?[0-9]{3}\)?[ -][0-9]{3}[ -][0-9]{2}[ -][0-9]{2})'
# Safe addresses (documentation, examples, commit attribution).
EMAIL_ALLOW='@(example\.(com|org|net)|users\.noreply\.github\.com|anthropic\.com)$'
PII_EXCLUDE=(':(exclude)packages/contracts/evals/**' ':(exclude)scripts/secret-scan.sh')

findings=0
mask() { sed -E -e 's/(gsk_|sk-or-|sk-|AIza|Bearer )[A-Za-z0-9_-]{4}[A-Za-z0-9_-]*/\1****[masked]/g' \
                 -e 's/([:=][[:space:]]*["'"'"']?)[A-Za-z0-9]{24,}/\1****[masked]/g'; }

report() { # $1 — category, stdin — git grep lines. Call via `< <(…)`, not via `|`, otherwise the counter is lost.
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "[$1] $(printf '%s' "$line" | cut -c1-200 | mask)"
    findings=$((findings + 1))
  done
}

# git grep: options before the pattern, revisions after. $1 — mode: worktree | index | history.
# --threads=1: multithreaded output sometimes split a line (a false finding in IC, COPILOT-06).
ggrep() {
  local mode="$1" pattern="$2"; shift 2
  case "$mode" in
    worktree) git grep -I -n --threads=1 --untracked ${GREP_EXTRA[@]+"${GREP_EXTRA[@]}"} -E "$pattern" -- "$@" ;;
    index)    git grep -I -n --threads=1 --cached ${GREP_EXTRA[@]+"${GREP_EXTRA[@]}"} -E "$pattern" -- "$@" ;;
    # All revisions in one call: one call per revision took minutes.
    history)  git rev-list --all | xargs git grep -I -n --threads=1 ${GREP_EXTRA[@]+"${GREP_EXTRA[@]}"} -E "$pattern" -- "$@" ;;
  esac 2>/dev/null || true
}

scan_tree() { # $1 — mode
  local mode="$1"
  GREP_EXTRA=()
  for p in "${KEY_PATTERNS[@]}"; do
    report "key:$mode" < <(ggrep "$mode" "$p" . ':(exclude)scripts/secret-scan.sh')
  done
  GREP_EXTRA=(-o)
  report "email:$mode" < <(ggrep "$mode" "$EMAIL_PATTERN" . "${PII_EXCLUDE[@]}" | grep -v -E "$EMAIL_ALLOW" || true)
  report "phone:$mode" < <(ggrep "$mode" "$PHONE_PATTERN" . "${PII_EXCLUDE[@]}")
  GREP_EXTRA=()
}

scan_tree worktree
scan_tree index
[ "$HISTORY" = 1 ] && scan_tree history

# Files that should be ignored but got into the index.
report "ignored-but-tracked" < <(git ls-files -ci --exclude-standard)
# Forbidden directories and file types in the index regardless of .gitignore: private/ (the original PDF), models, logs, packages/contracts/evals/out.
report "forbidden-path" < <(git ls-files | grep -E '(^|/)(private|profile|models|logs)/|^packages/contracts/evals/out/|\.(gguf|bin|p12|cer|key|log|pdf|mlmodelc)$|(^|/)\.env' || true)
# The original PDF and everything from private/ must not be in any commit.
if [ "$HISTORY" = 1 ]; then
  report "forbidden-history" < <(git log --all --name-only --format= | sort -u | grep -E '^private/|\.pdf$' || true)
fi

echo "$findings findings"
[ "$findings" -eq 0 ]
