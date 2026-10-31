#!/usr/bin/env bash
# Repository language policy check (AGENTS.md §7): text files must be English unless allow-listed
# in scripts/english-allowlist.txt (language data, fixtures, pending translations).
# Usage: scripts/check-english.sh            — tracked files + untracked, non-ignored files
# Exit code 1 if a file outside the allow-list contains Cyrillic.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
patterns=()
while IFS= read -r line; do
  case "$line" in ''|'#'*) continue ;; esac
  patterns+=("$line")
done < scripts/english-allowlist.txt
allowed() {
  local f="$1" p
  for p in "${patterns[@]}"; do
    # shellcheck disable=SC2053
    [[ "$f" == $p ]] && return 0
  done
  return 1
}
has_cyrillic() { perl -CSD -ne 'if (/\p{Script=Cyrillic}/) { $f = 1; last } END { exit($f ? 0 : 1) }' "$1"; }
show_cyrillic() { perl -CSD -ne 'if (/\p{Script=Cyrillic}/ && $n++ < 3) { chomp; print "    $.: ", substr($_, 0, 150), "\n" }' "$1"; }
bad=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  LC_ALL=C grep -Iq . "$f" 2>/dev/null || continue          # skip binary files
  has_cyrillic "$f" || continue
  if ! allowed "$f"; then
    echo "check-english: Cyrillic text in $f"
    show_cyrillic "$f"
    bad=$((bad + 1))
  fi
done < <({ git ls-files; git ls-files --others --exclude-standard; } | sort -u)
if [ "$bad" -gt 0 ]; then
  echo "check-english: FAIL ($bad file(s)). Translate, or add a justified pattern to scripts/english-allowlist.txt."
  exit 1
fi
echo "check-english: PASS"
