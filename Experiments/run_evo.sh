#!/usr/bin/env bash
# Batch-evaluate APE / RPE with evo and collect numeric metrics.
# Output: ./PoseErrors/APE|RPE/<name>.txt  (only if any valid metrics exist)
#
# Usage:
#   bash run_evo.sh ape <poses_dir> <groundtruth.txt> [name] [evo_args...]
#   bash run_evo.sh rpe <poses_dir> <groundtruth.txt> [name] [evo_args...]
#
set -u

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <ape|rpe> <poses_dir> <groundtruth.txt> [name] [evo_args...]" >&2
  exit 1
fi

MODE="$1"; shift
[[ "$MODE" == "ape" || "$MODE" == "rpe" ]] || { echo "ERROR: first arg must be 'ape' or 'rpe'." >&2; exit 1; }

POSES_DIR="$1"; shift
GT="$1"; shift
NAME="${1:-}"
if [[ -z "$NAME" || "$NAME" == -* ]]; then NAME="$(basename "$POSES_DIR")"; else shift; fi

USER_ARGS=("$@")
if [[ ${#USER_ARGS[@]} -eq 0 ]]; then
  if [[ "$MODE" == "ape" ]]; then USER_ARGS=(-a -s -r trans_part); else USER_ARGS=(-r trans_part -d 1 -u f); fi
fi

# Normalize '--delta_unit X' -> '-u code'
norm_args=()
i=0
while [[ $i -lt ${#USER_ARGS[@]} ]]; do
  arg="${USER_ARGS[$i]}"
  if [[ "$arg" == "--delta_unit" ]]; then
    j=$((i+1)); [[ $j -lt ${#USER_ARGS[@]} ]] || { echo "ERROR: --delta_unit requires a value." >&2; exit 2; }
    val="${USER_ARGS[$j]}"
    case "${val,,}" in
      f|frame|frames) code="f" ;;
      s|sec|secs|second|seconds|time|timesteps) code="s" ;;
      m|meter|meters|metres|metre|distance) code="m" ;;
      r|rad|radian|radians) code="r" ;;
      d) code="d" ;;
      *) echo "WARNING: unknown delta_unit '${val}', passing as-is." >&2; code="$val" ;;
    esac
    norm_args+=("-u" "$code")
    i=$((i+2)); continue
  fi
  norm_args+=("$arg"); i=$((i+1))
done

EVO_BIN="evo_${MODE}"
if ! command -v "$EVO_BIN" >/dev/null 2>&1; then
  echo "ERROR: '$EVO_BIN' not found in PATH. Activate your evo environment first." >&2
  exit 3
fi

[[ -d "$POSES_DIR" ]] || { echo "ERROR: poses_dir not found: $POSES_DIR" >&2; exit 4; }

shopt -s nullglob
mapfile -t FILES < <(ls -1 "$POSES_DIR"/result*.txt 2>/dev/null | sort -V)
shopt -u nullglob
if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "[SKIP] No result*.txt in $POSES_DIR ; no metrics file will be created."
  exit 0
fi

OUT_ROOT="./PoseErrors"
OUT_DIR="${OUT_ROOT}/$(echo "$MODE" | tr '[:lower:]' '[:upper:]')"
mkdir -p "$OUT_DIR"
OUT_FILE="${OUT_DIR}/${NAME}.txt"
TMP_OUT="${OUT_FILE}.tmp"
: > "$TMP_OUT"
any=0

echo "[INFO] mode=$MODE name=$NAME gt=$GT poses_dir=$POSES_DIR" | tee -a /dev/stderr
echo "[INFO] evo args: ${norm_args[*]}" | tee -a /dev/stderr
echo "" >> "$TMP_OUT"

for f in "${FILES[@]}"; do
  base=$(basename "$f")
  # Capture evo output and show it to user; then parse numeric block
  out="$("$EVO_BIN" tum "$GT" "$f" "${norm_args[@]}" 2>&1)"
  echo "$out" >&2
  block="$(printf "%s\n" "$out" | awk '
    BEGIN{capture=0}
    /^[[:space:]]*(max|mean|median|min|rmse|sse|std)[[:space:]]+[0-9.eE+-]+[[:space:]]*$/ {
      capture=1; print; next
    }
    capture && NF==0 { capture=0; exit }
  ')"
  if [[ -n "$block" ]]; then
    any=1
    {
      echo "========== ${base} =========="
      printf "%s\n\n" "$block"
    } >> "$TMP_OUT"
  else
    echo "[WARN] No numeric metrics parsed for ${base}; skipping." >&2
  fi
done

if [[ $any -eq 1 ]]; then
  mv -f "$TMP_OUT" "$OUT_FILE"
  echo "[DONE] Saved metrics to: $OUT_FILE"
else
  rm -f "$TMP_OUT"
  echo "[SKIP] No valid metrics produced; no ${MODE^^} file created for '$NAME'."
fi
