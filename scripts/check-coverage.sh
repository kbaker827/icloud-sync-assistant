#!/usr/bin/env bash
# Fails if SyncCore line coverage is below the threshold. Run after `swift test --enable-code-coverage`.
# Usage: scripts/check-coverage.sh [threshold-percent]
set -euo pipefail

cd "$(dirname "$0")/.."
THRESHOLD="${1:-80}"
JSON="$(swift test --show-codecov-path)"

read -r COVERED TOTAL < <(jq -r '
  [.data[0].files[] | select(.filename | test("/Sources/SyncCore/")) | .summary.lines]
  | "\(map(.covered) | add // 0) \(map(.count) | add // 0)"' "$JSON")

if [ "$TOTAL" -eq 0 ]; then
  echo "::error::No SyncCore coverage data found in $JSON"
  exit 1
fi

PERCENT="$(awk -v c="$COVERED" -v t="$TOTAL" 'BEGIN { printf "%.1f", c * 100 / t }')"
echo "SyncCore line coverage: $PERCENT% ($COVERED of $TOTAL lines)"

if awk -v c="$COVERED" -v t="$TOTAL" -v min="$THRESHOLD" 'BEGIN { exit !(c * 100 / t < min) }'; then
  echo "::error::SyncCore coverage $PERCENT% is below $THRESHOLD%"
  exit 1
fi
