#!/usr/bin/env bash
set -euo pipefail

BASE_REF=${1:-origin/main}
ALLOWED_REGEXES=(
  '^docs/'
  '^README.md$'
  '^README_BOOTSTRAP.md$'
  '^CHANGELOG.md$'
  '^SECURITY_REPORT.md$'
  '^TEST_PLAN.md$'
  '^DX_GUIDE.md$'
)

if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  echo "[detect_changed_paths] Unable to resolve base ref '$BASE_REF'." >&2
  exit 1
fi

mapfile -t files < <(git diff --name-only "$BASE_REF"...HEAD)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "[detect_changed_paths] No changes detected vs $BASE_REF; running jobs." >&2
  exit 1
fi

allowlisted=0
for file in "${files[@]}"; do
  matched=false
  for regex in "${ALLOWED_REGEXES[@]}"; do
    if [[ $file =~ $regex ]]; then
      matched=true
      break
    fi
  done
  if [[ $matched == false ]]; then
    echo "[detect_changed_paths] Non-doc change detected: $file" >&2
    exit 1
  fi
  ((allowlisted++))
done

echo "[detect_changed_paths] Detected $allowlisted allowlisted documentation changes only."
exit 0
