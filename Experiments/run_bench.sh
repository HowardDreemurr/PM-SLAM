#!/usr/bin/env bash
set -u

usage() {
  cat >&2 <<'USAGE'
Usage:
  # Mode A (explicit name):
  bash run_bench.sh <name> <seq_dir> [runs=20] [yaml=TUM1.yaml] [exe_dir=../Install/bin] [res_prefix=result]

  # Mode B (infer name from seq_dir basename):
  bash run_bench.sh <seq_dir> [runs=20] [yaml=TUM1.yaml] [exe_dir=../Install/bin] [res_prefix=result]

Notes:
  - Runs ./mono_tum inside <exe_dir> (default: ../Install/bin)
  - Moves resultXX.txt to ./Poses/<name>/
  - Saves per-run logs to ./Logs/<name>/runXX.log
  - Writes ONLY the 'Performance Summary (ms)' blocks to ./Performances/<name>/<name>_pref.txt
    * If no blocks captured across all runs, NO pref file is created.
  - Run index is zero-padded to 2 digits (01..20) by default
USAGE
}

# Parse arguments
if [[ $# -lt 1 ]]; then usage; exit 1; fi

if [[ -d "$1" || "$1" == */* ]]; then
  SEQ=$1; shift || true
  NAME=$(basename "$SEQ")
else
  NAME=$1; shift || true
  if [[ $# -lt 1 ]]; then usage; echo "ERROR: <seq_dir> missing." >&2; exit 1; fi
  SEQ=$1; shift || true
fi

RUNS=${1:-20}
YAML=${2:-TUM1.yaml}
EXE_DIR=${3:-../Install/bin}
RES_PREFIX=${4:-result}

PAD=2  # two-digit zero padding by default

# Prepare dirs (summary under Performances; logs & results under Logs/ and Poses/)
NAME_BASE=$(basename "$NAME")
PERF_DIR="./Performances/${NAME_BASE}"
LOG_DIR="./Logs/${NAME_BASE}"
POSE_DIR="./Poses/${NAME_BASE}"
mkdir -p "$LOG_DIR" "$POSE_DIR"  # defer PERF file creation until we have content
PERF_DIR_ABS="$(mkdir -p "$PERF_DIR" && cd "$PERF_DIR" && pwd)"
LOG_DIR_ABS="$(cd "$LOG_DIR" && pwd)"
POSE_DIR_ABS="$(cd "$POSE_DIR" && pwd)"

SUMMARY_FILE="${PERF_DIR_ABS}/${NAME_BASE}_pref.txt"
TMP_SUMMARY="${SUMMARY_FILE}.tmp"
: > "$TMP_SUMMARY"
any_block=0

# Resolve mono_tum
EXE_DIR_ABS="$(cd "$EXE_DIR" 2>/dev/null && pwd || true)"
EXE="${EXE_DIR_ABS}/mono_tum"
if [[ -z "${EXE_DIR_ABS}" || ! -x "$EXE" ]]; then
  echo "ERROR: Executable not found or not executable: ${EXE}" >&2
  echo "       (exe_dir resolved from: '${EXE_DIR}')" >&2
  rm -f "$TMP_SUMMARY"
  exit 2
fi

echo "[INFO] name=${NAME_BASE}  seq=${SEQ}  runs=${RUNS}  yaml=${YAML}"

for ((i=1;i<=RUNS;i++)); do
  num=$(printf "%0${PAD}d" "$i")
  RESULT_FILE="${RES_PREFIX}${num}.txt"
  LOG_FILE="${LOG_DIR_ABS}/run${num}.log"

  echo "[RUN ${num}/${RUNS}] $(date '+%F %T')"

  pushd "$EXE_DIR_ABS" >/dev/null

  if command -v stdbuf >/dev/null 2>&1; then
    stdbuf -oL -eL "./mono_tum" "$YAML" "$SEQ" "$RESULT_FILE" | tee "$LOG_FILE"
  else
    "./mono_tum" "$YAML" "$SEQ" "$RESULT_FILE" | tee "$LOG_FILE"
  fi
  status=${PIPESTATUS[0]}

  # Move trajectory to Poses/<name>/
  if [[ -f "$RESULT_FILE" ]]; then
    mv -f "$RESULT_FILE" "${POSE_DIR_ABS}/"
  fi

  popd >/dev/null

  # Extract ONLY the Performance Summary block and append to TEMP summary
  if grep -q "^========== Performance Summary (ms) ==========$" "$LOG_FILE"; then
    awk -v N="$num" '
      /^=+ Performance Summary \(ms\) =+$/ { print "========== " N " Performance Summary (ms) =========="; capture=1; next }
      capture {
        # header row
        if ($0 ~ /^name[[:space:]]+mean[[:space:]]+median[[:space:]]+rmse[[:space:]]+min[[:space:]]+max[[:space:]]+count$/) { print; next }
        # data rows: label + 5 numeric columns + integer count
        if ($0 ~ /^[A-Za-z0-9 .:_-]+[[:space:]]+[-0-9.]+([[:space:]]+[-0-9.]+){4}[[:space:]]+[0-9]+$/) { print; any=1; next }
        # blank line -> end of block
        if ($0 ~ /^[[:space:]]*$/) { exit }
        # known terminators
        if ($0 ~ /^(Saving camera trajectory|Segmentation fault|System Shutdown|All done|System::StopViewer)/) { exit }
      }
      END { if (capture==1) print "" }
    ' "$LOG_FILE" >> "$TMP_SUMMARY"
    # Detect if we actually added any data rows for this block
    if grep -q "^Tracking[[:space:]]" "$TMP_SUMMARY" || grep -q "^Pipeline[[:space:]]" "$TMP_SUMMARY"; then
      any_block=1
    fi
  else
    echo "[WARN] Summary block not found in run ${num} (exit ${status})"
  fi

  sleep 0.5
done

# Finalize: only create the official summary file if we captured at least one block with data
if [[ $any_block -eq 1 ]] && [[ -s "$TMP_SUMMARY" ]]; then
  mv -f "$TMP_SUMMARY" "$SUMMARY_FILE"
  echo "[DONE] Summary: ${SUMMARY_FILE}"
else
  rm -f "$TMP_SUMMARY"
  echo "[SKIP] No performance summaries captured; no pref file created."
fi

echo "[DONE] Logs:    ${LOG_DIR_ABS}"
echo "[DONE] Results: ${POSE_DIR_ABS}"
