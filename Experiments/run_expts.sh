#!/usr/bin/env bash
# launch_workers.sh
set -euo pipefail

RUNNER="./run_exp_master.sh"          # your strided runner (supports --start/--skip)
WORKERS="${1:-6}"          # number of workers == max parallel jobs

# Pass-through extra args to each worker after "--"
shift || true
EXTRA=()
if [[ ${1:-} == "--" ]]; then shift; EXTRA=("$@"); fi

LOGDIR="${LOGDIR:-worker_logs}"
mkdir -p "$LOGDIR"

echo "Launching $WORKERS workers (parallel=$WORKERS)..."
pids=()

# Forward Ctrl-C / TERM to all children
cleanup() {
  echo; echo "Stopping workers..."
  trap - INT TERM
  # Send SIGINT first (graceful), then SIGTERM as fallback
  kill -INT "${pids[@]}" 2>/dev/null || true
  sleep 0.3
  kill -TERM "${pids[@]}" 2>/dev/null || true
}
trap cleanup INT TERM

# Launch exactly WORKERS workers, each with its shard
for (( start=0; start<WORKERS; start++ )); do
  log="$LOGDIR/worker_${start}.log"
  echo "[launch] worker $start → $RUNNER --start $start --skip $WORKERS ${EXTRA[*]}"
  "$RUNNER" --start "$start" --skip "$WORKERS" "${EXTRA[@]}" >"$log" 2>&1 &
  pids+=("$!")
done

# Wait for all; fail if any fails
fail=0
for pid in "${pids[@]}"; do
  if ! wait "$pid"; then
    fail=1
  fi
done

echo
if (( fail )); then
  echo "Some workers failed. Check $LOGDIR/"
  exit 1
else
  echo "All workers completed successfully. Logs in $LOGDIR/"
fi
