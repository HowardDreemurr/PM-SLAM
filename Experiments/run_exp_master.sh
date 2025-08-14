#!/usr/bin/env bash
# Master experiment runner:
# - Iterates over a list of experiments (name, seq_dir, yaml, gt, runs, exe_dir)
# - For each experiment:
#     1) runs run_bench.sh (produces Performance/, Logs/, PoseError/)
#     2) runs run_evo.sh ape (collect APE metrics to PoseErrors/APE/<name>.txt)
#     3) runs run_evo.sh rpe (collect RPE metrics to PoseErrors/RPE/<name>.txt)
#
# Edit the EXPS block below: one quoted line per experiment with key=value pairs.
# Required keys: name, seq, yaml, gt
# Optional keys: runs (default 20), exe (default ../Install/bin), res_prefix (default result)
#
# You can also adjust global defaults for APE/RPE args here:
APE_ARGS_DEFAULT=(-a -s -r trans_part)
RPE_ARGS_DEFAULT=(-r trans_part -d 1 -u f)
#
# Usage:
#   bash run_exp_master.sh               # uses EXPS defined below
#   bash run_exp_master.sh path/to/my_exps.list   # optional: external config file with same format
#
set -euo pipefail

# ------------- helpers -------------
expand_path() {
  # expand ~ and vars without requiring realpath
  local p="$1"
  # shellcheck disable=SC2086
  eval echo "$p"
}

have() { command -v "$1" >/dev/null 2>&1; }

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "ERROR: required file not found: $1" >&2; exit 2
  fi
}

# ------------- config -------------
read_config_lines() {
  if [[ $# -gt 0 ]]; then
    local cfg="$1"
    if [[ ! -f "$cfg" ]]; then
      echo "ERROR: config file not found: $cfg" >&2; exit 1
    fi
    mapfile -t LINES < "$cfg"
  else
    # Inline EXPS config: edit here
    LINES=(
      # Example entries (remove or replace):
       'name=fr1_xyz_orb seq=~/dataset/tum/fr1_xyz yaml=TUM1.yaml gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=1 exe=../Install/bin'
       'name=fr3_nnf_orb seq=~/dataset/tum/fr3_nnf yaml=TUM3.yaml gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=1 exe=../Install/bin'
    )
  fi
}

# ------------- main -------------
main() {
  read_config_lines "$@"

  require_file "./run_bench.sh"
  require_file "./run_evo.sh"

  # Print summary header
  echo ">>> Experiments to run: ${#LINES[@]}"
  [[ ${#LINES[@]} -eq 0 ]] && { echo "No experiments configured. Edit run_exp_master.sh 'LINES' or pass a config file."; exit 1; }

  for line in "${LINES[@]}"; do
    # skip comments/empty lines
    [[ -z "${line// }" ]] && continue
    [[ "$line" =~ ^# ]] && continue

    # reset vars
    name="" seq="" yaml="" gt="" runs="20" exe="../Install/bin" res_prefix="result"

    # parse key=value pairs
    for kv in $line; do
      k="${kv%%=*}"
      v="${kv#*=}"
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

    # sanity
    if [[ -z "$name" || -z "$seq" || -z "$yaml" || -z "$gt" ]]; then
      echo "ERROR: missing required key (need name, seq, yaml, gt) in line: $line" >&2
      exit 1
    fi

    # expand paths
    seq=$(expand_path "$seq")
    gt=$(expand_path "$gt")
    exe=$(expand_path "$exe")

    echo ""
    echo "===== RUN: ${name} ====="
    echo "[bench] seq=$seq  yaml=$yaml  runs=$runs  exe_dir=$exe"

    # 1) run bench
    bash ./run_bench.sh "$name" "$seq" "$runs" "$yaml" "$exe" "$res_prefix"

    # 2) APE
    echo "[evo-ape] $name"
    bash ./run_evo.sh ape "./Poses/${name}" "$gt" "$name" "${APE_ARGS_DEFAULT[@]}"

    # 3) RPE
    echo "[evo-rpe] $name"
    bash ./run_evo.sh rpe "./Poses/${name}" "$gt" "$name" "${RPE_ARGS_DEFAULT[@]}"
  done

  echo ""
  echo "All experiments finished."
  echo "Performance summaries under ./Performance/<name>/<name>_pref.txt"
  echo "APE/RPE metrics under ./PoseErrors/APE|RPE/<name>.txt"
  echo "Logs and trajectories under ./Logs/<name>/ and ./PoseError/<name>/"
}

main "$@"
