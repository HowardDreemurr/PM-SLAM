#!/usr/bin/env bash
# Master experiment runner with safeguards:
# - Runs run_bench.sh, then only runs APE/RPE if poses exist.
# - Optionally auto-activate evo venv via EVO_ACTIVATE env var.
#
# Defaults for evo:
APE_ARGS_DEFAULT=(-a -s -r trans_part)
RPE_ARGS_DEFAULT=(-r trans_part -d 1 -u f)
set -euo pipefail

expand_path() { eval echo "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }
require_file() { [[ -f "$1" ]] || { echo "ERROR: missing file: $1" >&2; exit 2; }; }

read_config_lines() {
  if [[ $# -gt 0 ]]; then
    local cfg="$1"; [[ -f "$cfg" ]] || { echo "ERROR: config file not found: $cfg" >&2; exit 1; }
    mapfile -t LINES < "$cfg"
  else
    LINES=(
       'name=fr1_xyz_orb seq=~/dataset/tum/fr1_xyz yaml=TUM1.yaml gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=1 exe=../Install/bin'
       'name=fr3_nnf_orb seq=~/dataset/tum/fr3_nnf yaml=TUM3.yaml gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=1 exe=../Install/bin'
    )
  fi
}

maybe_activate_venv() {
  local act="${EVO_ACTIVATE:-}"
  if [[ -n "$act" ]]; then
    act=$(expand_path "$act")
    if [[ -f "$act" ]]; then
      # shellcheck disable=SC1090
      source "$act"
      echo "[INFO] activated evo venv: $act"
    else
      echo "[WARN] EVO_ACTIVATE set but file not found: $act"
    fi
  fi
}

main() {
  read_config_lines "$@"
  require_file "./run_bench.sh"; require_file "./run_evo.sh"
  maybe_activate_venv

  echo ">>> Experiments to run: ${#LINES[@]}"
  [[ ${#LINES[@]} -eq 0 ]] && { echo "No experiments configured."; exit 1; }

  for line in "${LINES[@]}"; do
    [[ -z "${line// }" || "$line" =~ ^# ]] && continue

    name="" seq="" yaml="" gt="" runs="20" exe="../Install/bin" res_prefix="result"
    for kv in $line; do
      k="${kv%%=*}"; v="${kv#*=}"
      case "$k" in
        name) name="$v" ;;
        seq)  seq="$v" ;;
        yaml) yaml="$v" ;;
        gt)   gt="$v" ;;
        runs) runs="$v" ;;
        exe)  exe="$v" ;;
        res_prefix) res_prefix="$v" ;;
        *) echo "WARNING: unknown key '$k' ignored." ;;
      esac
    done
    [[ -n "$name" && -n "$seq" && -n "$yaml" && -n "$gt" ]] || { echo "ERROR: missing key(s) in: $line"; exit 1; }

    seq=$(expand_path "$seq"); gt=$(expand_path "$gt"); exe=$(expand_path "$exe")

    echo ""; echo "===== RUN: ${name} ====="
    echo "[bench] seq=$seq  yaml=$yaml  runs=$runs  exe_dir=$exe"
    bash ./run_bench.sh "$name" "$seq" "$runs" "$yaml" "$exe" "$res_prefix"

    poses_dir="./Poses/${name}"
    if [[ ! -d "$poses_dir" ]] || ! ls "$poses_dir"/result*.txt >/dev/null 2>&1; then
      echo "[SKIP] No poses found for '${name}' -> skip APE/RPE."
      continue
    fi

    echo "[evo-ape] $name"
    if ! have evo_ape; then echo "ERROR: 'evo_ape' not found in PATH."; exit 4; fi
    bash ./run_evo.sh ape "$poses_dir" "$gt" "$name" "${APE_ARGS_DEFAULT[@]}" || true

    echo "[evo-rpe] $name"
    if ! have evo_rpe; then echo "ERROR: 'evo_rpe' not found in PATH."; exit 5; fi
    bash ./run_evo.sh rpe "$poses_dir" "$gt" "$name" "${RPE_ARGS_DEFAULT[@]}" || true
  done

  echo ""; echo "All experiments finished."
  echo "Performance -> ./Performances/<name>/<name>_pref.txt"
  echo "APE/RPE     -> ./PoseErrors/APE|RPE/<name>.txt"
  echo "Logs/Poses  -> ./Logs/<name>/, ./Poses/<name>/"
}

main "$@"
