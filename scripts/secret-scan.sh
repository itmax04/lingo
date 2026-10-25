#!/usr/bin/env bash
# Поиск ключей и личных данных в репозитории (AC-13, plan.md P-01). Запускать перед каждым push.
# По образцу Interview Copilot (scripts/secret-scan.sh, коммит cf0e764), шаблоны — по R-30 (Groq, Mistral, OpenRouter).
#   scripts/secret-scan.sh              — рабочее дерево (отслеживаемые и новые файлы) + индекс + вся история Git
#   scripts/secret-scan.sh --no-history — без истории (быстро)
# Вывод: строки с находками (значения маскируются) и итог «N findings». Код возврата 1, если N > 0.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

HISTORY=1
[ "${1:-}" = "--no-history" ] && HISTORY=0

# Ключи провайдеров.
KEY_PATTERNS=(
  'gsk_[A-Za-z0-9]{20,}'                         # Groq
  'sk-or-(v1-)?[A-Za-z0-9]{32,}'                 # OpenRouter
  'sk-[A-Za-z0-9_-]{32,}'                        # общие OpenAI-совместимые
  'AIza[0-9A-Za-z_-]{35}'                        # Google (Gemini не используется, но ключ не должен попасть)
  '(mistral|MISTRAL)[A-Za-z_]*[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Za-z0-9]{32}'   # Mistral: ключ без префикса — ищется рядом с именем
  'Bearer [A-Za-z0-9_-]{24,}'                    # заголовок с ключом в логах и фикстурах
)
# Личные данные: email и телефоны. Вне проверки: evals/ (синтетика) и этот скрипт.
EMAIL_PATTERN='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
PHONE_PATTERN='(\+[0-9]{1,3}[ -]?\(?[0-9]{2,4}\)?[ -]?[0-9]{3}[ -]?[0-9]{2}[ -]?[0-9]{2})|(\(?[0-9]{3}\)?[ -][0-9]{3}[ -][0-9]{2}[ -][0-9]{2})'
# Безопасные адреса (документация, примеры, атрибуция коммитов).
EMAIL_ALLOW='@(example\.(com|org|net)|users\.noreply\.github\.com|anthropic\.com)$'
PII_EXCLUDE=(':(exclude)evals/**' ':(exclude)scripts/secret-scan.sh')

findings=0
mask() { sed -E -e 's/(gsk_|sk-or-|sk-|AIza|Bearer )[A-Za-z0-9_-]{4}[A-Za-z0-9_-]*/\1****[masked]/g' \
                 -e 's/([:=][[:space:]]*["'"'"']?)[A-Za-z0-9]{24,}/\1****[masked]/g'; }

report() { # $1 — категория, stdin — строки git grep. Вызывать через `< <(…)`, не через `|`, иначе счётчик теряется.
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "[$1] $(printf '%s' "$line" | cut -c1-200 | mask)"
    findings=$((findings + 1))
  done
}

# git grep: опции до шаблона, ревизии после. $1 — режим: worktree | index | history.
# --threads=1: многопоточный вывод иногда разрывал строку (ложная находка в IC, COPILOT-06).
ggrep() {
  local mode="$1" pattern="$2"; shift 2
  case "$mode" in
    worktree) git grep -I -n --threads=1 --untracked ${GREP_EXTRA[@]+"${GREP_EXTRA[@]}"} -E "$pattern" -- "$@" ;;
    index)    git grep -I -n --threads=1 --cached ${GREP_EXTRA[@]+"${GREP_EXTRA[@]}"} -E "$pattern" -- "$@" ;;
    # Все ревизии одним вызовом: по ревизии на вызов проверка шла минутами.
    history)  git rev-list --all | xargs git grep -I -n --threads=1 ${GREP_EXTRA[@]+"${GREP_EXTRA[@]}"} -E "$pattern" -- "$@" ;;
  esac 2>/dev/null || true
}

scan_tree() { # $1 — режим
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

# Файлы, которые должны игнорироваться, но попали в индекс.
report "ignored-but-tracked" < <(git ls-files -ci --exclude-standard)
# Запрещённые каталоги и типы файлов в индексе независимо от .gitignore: private/ (оригинал PDF), модели, логи, evals/out.
report "forbidden-path" < <(git ls-files | grep -E '(^|/)(private|profile|models|logs)/|^evals/out/|\.(gguf|bin|p12|cer|key|log|pdf|mlmodelc)$|(^|/)\.env' || true)
# Оригинал PDF и всё из private/ не должно быть ни в одном коммите.
if [ "$HISTORY" = 1 ]; then
  report "forbidden-history" < <(git log --all --name-only --format= | sort -u | grep -E '^private/|\.pdf$' || true)
fi

echo "$findings findings"
[ "$findings" -eq 0 ]
