#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <threshold_percent> <coveralls_json_path>" >&2
  exit 2
}

[[ $# -eq 2 ]] || usage
threshold=$1
report=$2

if ! command -v jq >/dev/null 2>&1; then
  echo "[coverage_gate] jq is required. Install via 'brew install jq' or 'sudo apt-get install jq'." >&2
  exit 3
fi

if [[ ! -f "$report" ]]; then
  echo "[coverage_gate] Coverage report '$report' not found" >&2
  exit 4
fi

covered=$(jq -r '.metrics.covered_percent // .coverage' "$report")

if [[ -z "$covered" || "$covered" == "null" ]]; then
  echo "[coverage_gate] Unable to read covered_percent from $report" >&2
  exit 5
fi

python3 - "$threshold" "$covered" <<'PY'
import sys
thr = float(sys.argv[1])
cov = float(sys.argv[2])
if cov + 1e-6 < thr:
    print(f"Coverage {cov:.2f}% is below threshold {thr:.2f}%", file=sys.stderr)
    sys.exit(1)
print(f"Coverage {cov:.2f}% meets threshold {thr:.2f}%")
PY
