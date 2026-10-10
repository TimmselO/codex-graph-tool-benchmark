#!/usr/bin/env bash
set -Eeuo pipefail
BENCH="${BENCH_ROOT:?Set BENCH_ROOT to your disposable benchmark directory}"
[[ -f "$BENCH/.disposable-benchmark" ]] || {
  echo "ERROR: Missing disposable benchmark marker" >&2
  exit 1
}
for pair in baseline:graft baseline:codegraph graft:codegraph codegraph:graft; do
  variant="${pair%%:*}"
  tool="${pair##*:}"
  mkdir -p "$BENCH/guards/$variant"
  cat > "$BENCH/guards/$variant/$tool" <<'GUARD'
#!/bin/sh
echo "Tool disabled in this benchmark variant" >&2
exit 127
GUARD
  chmod +x "$BENCH/guards/$variant/$tool"
done
