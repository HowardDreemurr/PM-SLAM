#!/usr/bin/env bash
# Batch-evaluate APE / RPE with evo and collect numeric metrics.
# Output: ./PoseErrors/APE|RPE/<name>.txt
#
# Usage:
#   bash run_evo.sh ape <poses_dir> <groundtruth.txt> [name] [evo_args...]
#   bash run_evo.sh rpe <poses_dir> <groundtruth.txt> [name] [evo_args...]
#
# Notes:
# - Default APE args:  -a -s -r trans_part      (align origin? no; '-a' is align, '-s' is scale)
# - Default RPE args:  -r trans_part -d 1 -u f  (delta=1 frame, unit=frames)
# - If you pass '--delta_unit frames|seconds|meters|radians' (or f/s/m/r), we normalize to '-u f|s|m|r' for evo.
set -u

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <ape|rpe> <poses_dir> <groundtruth.txt> [name] [evo_args...]" >&2
  exit 1
fi

MODE="$1"; shift
if [[ "$MODE" != "ape" && "$MODE" != "rpe" ]]; then
  echo "ERROR: first arg must be 'ape' or 'rpe'." >&2
  exit 1
fi

POSES_DIR="$1"; shift
GT="$1"; shift
NAME="${1:-}"
if [[ -z "$NAME" || "$NAME" == -* ]]; then
  NAME="$(basename "$POSES_DIR")"
else
  shift
fi

# Remaining args as array
USER_ARGS=("$@")

# Defaults if no user args
if [[ ${#USER_ARGS[@]} -eq 0 ]]; then
  if [[ "$MODE" == "ape" ]]; then
    USER_ARGS=(-a -s -r trans_part)
  else
    USER_ARGS=(-r trans_part -d 1 -u f)
  fi
fi

# Normalize '--delta_unit X' to '-u code'
norm_args=()
i=0
while [[ $i -lt ${#USER_ARGS[@]} ]]; do
  arg="${USER_ARGS[$i]}"
  if [[ "$arg" == "--delta_unit" ]]; then
    j=$((i+1))
    if [[ $j -ge ${#USER_ARGS[@]} ]]; then
      echo "ERROR: --delta_unit requires a value." >&2
      exit 2
    fi
    val="${USER_ARGS[$j]}"
    # map common words to evo codes
    case "${val,,}" in
      f|frame|frames) code="f" ;;
      s|sec|secs|second|seconds|time|timesteps) code="s" ;;
      m|meter|meters|metres|metre|distance) code="m" ;;
      r|rad|radian|radians) code="r" ;;
      d) code="d" ;;  # some evo versions display 'd' in help; pass through if user insists
      *) echo "WARNING: unknown delta_unit '${val}', passing as-is." >&2; code="$val" ;;
    esac
    norm_args+=("-u" "$code")
    i=$((i+2))
    continue
  fi
  # pass everything else through
  norm_args+=("$arg")
  i=$((i+1))
done

EVO_BIN="evo_${MODE}"
if ! command -v "$EVO_BIN" >/dev/null 2>&1; then
  echo "ERROR: '$EVO_BIN' not found in PATH. Activate your evo environment first." >&2
  exit 3
fi

OUT_ROOT="./PoseErrors"
OUT_DIR="${OUT_ROOT}/$(echo "$MODE" | tr '[:lower:]' '[:upper:]')"
mkdir -p "$OUT_DIR"
OUT_FILE="${OUT_DIR}/${NAME}.txt"
: > "$OUT_FILE"

if [[ ! -d "$POSES_DIR" ]]; then
  echo "ERROR: poses_dir not found: $POSES_DIR" >&2
  exit 4
fi

shopt -s nullglob
mapfile -t FILES < <(ls -1 "$POSES_DIR"/result*.txt 2>/dev/null | sort -V)
shopt -u nullglob

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "ERROR: no result*.txt in $POSES_DIR" >&2
  exit 5
fi

echo "[INFO] mode=$MODE name=$NAME gt=$GT poses_dir=$POSES_DIR" | tee -a "$OUT_FILE"
echo "[INFO] evo args: ${norm_args[*]}" | tee -a "$OUT_FILE"
echo "" >> "$OUT_FILE"

for f in "${FILES[@]}"; do
  base=$(basename "$f")
  echo "========== ${base} ==========" >> "$OUT_FILE"
  "$EVO_BIN" tum "$GT" "$f" "${norm_args[@]}" 2>&1 | tee /dev/stderr | awk '
    BEGIN{capture=0}
    /^[[:space:]]*(max|mean|median|min|rmse|sse|std)[[:space:]]+[0-9.eE+-]+[[:space:]]*$/ {
      capture=1; print; next
    }
    capture && NF==0 { capture=0; exit }
  ' >> "$OUT_FILE"
  echo "" >> "$OUT_FILE"
done

echo "[DONE] Saved metrics to: $OUT_FILE"
