#!/usr/bin/env bash
set -u

usage() {
  cat >&2 <<'USAGE'
Usage:
  # Mode A (explicit name):
  bash run_bench.sh [--withCorr] <name> <seq_dir> [runs=20] [yaml=TUM1.yaml] [exe_dir=../Install/bin] [res_prefix=result]

  # Mode B (infer name from seq_dir basename):
  bash run_bench.sh [--withCorr] <seq_dir> [runs=20] [yaml=TUM1.yaml] [exe_dir=../Install/bin] [res_prefix=result]

Notes:
  - Runs ./mono_tum inside <exe_dir> (default: ../Install/bin)
  - Moves resultXX.txt to ./Poses/<name>/
  - Saves per-run logs to ./Logs/<name>/runXX.log
  - Writes ONLY the 'Performance Summary (ms)' blocks to ./Performances/<name>/<name>_pref.txt
    * If no blocks captured across all runs, NO pref file is created.
  - If --withCorr is set:
    * Copies correlation file (default: CorrelationStatus.txt) from exe dir to ./Correlations/<name>/XX.txt
    * Appends 'Per-Channel Summary' (with run index header) to ./Correlations/corr_exp_<name>.txt
    * Env override for filename: CORR_SRC_NAME=<filename>
  - Run index is zero-padded to 2 digits (01..20) by default
USAGE
}

# ---------- Parse optional flags ----------
WITH_CORR=0
args=()
for a in "$@"; do
  case "$a" in
    --withCorr) WITH_CORR=1 ;;
    *) args+=("$a") ;;
  esac
done
set -- "${args[@]}"

# ---------- Parse positional arguments ----------
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
CORR_SRC_NAME="${CORR_SRC_NAME:-CorrelationStatus.txt}"

# ---------- Prepare dirs ----------
NAME_BASE=$(basename "$NAME")
PERF_DIR="./Performances"
LOG_DIR="./Logs/${NAME_BASE}"
POSE_DIR="./Poses/${NAME_BASE}"
mkdir -p "$LOG_DIR" "$POSE_DIR"
LOG_DIR_ABS="$(cd "$LOG_DIR" && pwd)"
POSE_DIR_ABS="$(cd "$POSE_DIR" && pwd)"

# Performance summary (defer finalization)
mkdir -p "$PERF_DIR"
PERF_DIR_ABS="$(cd "$PERF_DIR" && pwd)"
SUMMARY_FILE="${PERF_DIR_ABS}/${NAME_BASE}_pref.txt"
TMP_SUMMARY="${SUMMARY_FILE}.tmp"
: > "$TMP_SUMMARY"
any_block=0

# Correlation (only if requested)
if [[ $WITH_CORR -eq 1 ]]; then
  CORR_DIR="./Correlations/${NAME_BASE}"
  CORR_ROOT="./Correlations"
  mkdir -p "$CORR_DIR" "$CORR_ROOT"
  CORR_DIR_ABS="$(cd "$CORR_DIR" && pwd)"
  CORR_ROOT_ABS="$(cd "$CORR_ROOT" && pwd)"
  AGG_FILE="${CORR_ROOT_ABS}/corr_exp_${NAME_BASE}.txt"
  TMP_AGG="${AGG_FILE}.tmp"
  : > "$TMP_AGG"
  any_corr=0
fi

# ---------- Resolve mono_tum ----------
EXE_DIR_ABS="$(cd "$EXE_DIR" 2>/dev/null && pwd || true)"
EXE="${EXE_DIR_ABS}/mono_tum"
if [[ -z "${EXE_DIR_ABS}" || ! -x "$EXE" ]]; then
  echo "ERROR: Executable not found or not executable: ${EXE}" >&2
  echo "       (exe_dir resolved from: '${EXE_DIR}')" >&2
  rm -f "$TMP_SUMMARY"
  [[ $WITH_CORR -eq 1 ]] && rm -f "$TMP_AGG"
  exit 2
fi

echo "[INFO] name=${NAME_BASE}  seq=${SEQ}  runs=${RUNS}  yaml=${YAML}  withCorr=${WITH_CORR}"

# ---------- Run loop ----------
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

  # Correlation per-run artifacts
  if [[ $WITH_CORR -eq 1 ]]; then
    # Copy correlation source file from exe dir to Correlations/<name>/XX.txt
    if [[ -f "$CORR_SRC_NAME" ]]; then
      cp -f "$CORR_SRC_NAME" "${CORR_DIR_ABS}/${num}.txt"
    else
      echo "[WARN] correlation source '$CORR_SRC_NAME' not found in exe dir for run ${num}"
    fi
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

  # Correlation aggregate (from log)
  if [[ $WITH_CORR -eq 1 ]]; then
    if grep -q "Per-Channel Summary" "$LOG_FILE"; then
      {
        echo "# ---------- ${num} Per-Channel Summary ----------"
        awk '
          BEGIN{cap=0}
          /Per-Channel Summary/ {cap=1; next}
          cap==1 {
            # termination conditions
            if ($0 ~ /^[[:space:]]*$/) { exit }
            if ($0 ~ /^=+ Performance Summary/ || $0 ~ /^System Shutdown/ || $0 ~ /^All done/ || $0 ~ /^System::StopViewer/) { exit }

            # already formatted
            if ($0 ~ /chA:[[:space:]]*[0-9]+.*\|.*avgC:/) { print; next }

            # skip textual header row
            if ($1 ~ /^chA$/ || $0 ~ /avgCorr/ ) { next }

            # parse numeric table: expect >= 8 columns
            n = split($0, a)
            if (n >= 8 && a[1] ~ /^[0-9]+$/ && a[2] ~ /^[0-9]+$/) {
              chA=a[1]; chB=a[2]; c=a[3]; A=a[4]; B=a[5]; mnr=a[6]; gnr=a[7];
              dice=a[8]; if (n>8) { for (i=9;i<=n;i++) dice=dice""a[i]; }
              printf "chA: %d chB: %d | avgC: %s avgA: %s avgB: %s MNR: %s GNR: %s DICE: %s\n", chA, chB, c, A, B, mnr, gnr, dice;
              next
            }
          }
        ' "$LOG_FILE"
        echo
      } >> "$TMP_AGG"
      any_corr=1
    else
      echo "[WARN] Per-Channel Summary not found in run ${num} (exit ${status})"
    fi
  fi

  sleep 0.5
done

# ---------- Finalize ----------
# Performance
if [[ $any_block -eq 1 ]] && [[ -s "$TMP_SUMMARY" ]]; then
  mv -f "$TMP_SUMMARY" "$SUMMARY_FILE"
  echo "[DONE] Summary: ${SUMMARY_FILE}"
else
  rm -f "$TMP_SUMMARY"
  echo "[SKIP] No performance summaries captured; no pref file created."
fi

# Correlations
if [[ $WITH_CORR -eq 1 ]]; then
  if [[ $any_corr -eq 1 ]] && [[ -s "$TMP_AGG" ]]; then
    mv -f "$TMP_AGG" "$AGG_FILE"
    echo "[DONE] Correlations aggregate: ${AGG_FILE}"
    echo "[DONE] Correlations per-run:   ${CORR_DIR_ABS}/XX.txt"
  else
    rm -f "$TMP_AGG"
    echo "[SKIP] No Per-Channel summaries captured; no correlation files created."
  fi
fi

echo "[DONE] Logs:    ${LOG_DIR_ABS}"
echo "[DONE] Results: ${POSE_DIR_ABS}"
