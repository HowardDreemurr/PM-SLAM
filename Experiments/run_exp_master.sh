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
#       'name=fr1_xyz_akz        seq=~/dataset/tum/fr1_xyz yaml=../../../../Experiments/YAMLs/TUM1_AKZ.yaml        gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin'
#       'name=fr1_xyz_akz_kaz    seq=~/dataset/tum/fr1_xyz yaml=../../../../Experiments/YAMLs/TUM1_AKZ_KAZ.yaml    gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin'
#       'name=fr1_xyz_bsk        seq=~/dataset/tum/fr1_xyz yaml=../../../../Experiments/YAMLs/TUM1_BSK.yaml        gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin'
#       'name=fr1_xyz_kaz        seq=~/dataset/tum/fr1_xyz yaml=../../../../Experiments/YAMLs/TUM1_KAZ.yaml        gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin'
#       'name=fr1_xyz_orb        seq=~/dataset/tum/fr1_xyz yaml=../../../../Experiments/YAMLs/TUM1_ORB.yaml        gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin'
#       'name=fr1_xyz_orb_akz    seq=~/dataset/tum/fr1_xyz yaml=../../../../Experiments/YAMLs/TUM1_ORB_AKZ.yaml    gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin'
#       'name=fr1_xyz_orb_bsk    seq=~/dataset/tum/fr1_xyz yaml=../../../../Experiments/YAMLs/TUM1_ORB_BSK.yaml    gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin'
#       'name=fr1_xyz_orb_sft    seq=~/dataset/tum/fr1_xyz yaml=../../../../Experiments/YAMLs/TUM1_ORB_SFT.yaml    gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin'
#       'name=fr1_xyz_sft        seq=~/dataset/tum/fr1_xyz yaml=../../../../Experiments/YAMLs/TUM1_SFT.yaml        gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin'
#
#       'name=fr2_xyz_akz        seq=~/dataset/tum/fr2_xyz yaml=../../../../Experiments/YAMLs/TUM2_AKZ.yaml        gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin'
#       'name=fr2_xyz_akz_kaz    seq=~/dataset/tum/fr2_xyz yaml=../../../../Experiments/YAMLs/TUM2_AKZ_KAZ.yaml    gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin'
#       'name=fr2_xyz_bsk        seq=~/dataset/tum/fr2_xyz yaml=../../../../Experiments/YAMLs/TUM2_BSK.yaml        gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin'
#       'name=fr2_xyz_kaz        seq=~/dataset/tum/fr2_xyz yaml=../../../../Experiments/YAMLs/TUM2_KAZ.yaml        gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin'
#       'name=fr2_xyz_orb        seq=~/dataset/tum/fr2_xyz yaml=../../../../Experiments/YAMLs/TUM2_ORB.yaml        gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin'
#       'name=fr2_xyz_orb_akz    seq=~/dataset/tum/fr2_xyz yaml=../../../../Experiments/YAMLs/TUM2_ORB_AKZ.yaml    gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin'
#       'name=fr2_xyz_orb_bsk    seq=~/dataset/tum/fr2_xyz yaml=../../../../Experiments/YAMLs/TUM2_ORB_BSK.yaml    gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin'
#       'name=fr2_xyz_orb_sft    seq=~/dataset/tum/fr2_xyz yaml=../../../../Experiments/YAMLs/TUM2_ORB_SFT.yaml    gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin'
#       'name=fr2_xyz_sft        seq=~/dataset/tum/fr2_xyz yaml=../../../../Experiments/YAMLs/TUM2_SFT.yaml        gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin'
#
#       'name=fr3_nnf_akz        seq=~/dataset/tum/fr3_nnf yaml=../../../../Experiments/YAMLs/TUM3_AKZ.yaml        gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin'
#       'name=fr3_nnf_akz_kaz    seq=~/dataset/tum/fr3_nnf yaml=../../../../Experiments/YAMLs/TUM3_AKZ_KAZ.yaml    gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin'
#       'name=fr3_nnf_bsk        seq=~/dataset/tum/fr3_nnf yaml=../../../../Experiments/YAMLs/TUM3_BSK.yaml        gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin'
#       'name=fr3_nnf_kaz        seq=~/dataset/tum/fr3_nnf yaml=../../../../Experiments/YAMLs/TUM3_KAZ.yaml        gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin'
#       'name=fr3_nnf_orb        seq=~/dataset/tum/fr3_nnf yaml=../../../../Experiments/YAMLs/TUM3_ORB.yaml        gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin'
#       'name=fr3_nnf_orb_akz    seq=~/dataset/tum/fr3_nnf yaml=../../../../Experiments/YAMLs/TUM3_ORB_AKZ.yaml    gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin'
#       'name=fr3_nnf_orb_bsk    seq=~/dataset/tum/fr3_nnf yaml=../../../../Experiments/YAMLs/TUM3_ORB_BSK.yaml    gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin'
#       'name=fr3_nnf_orb_sft    seq=~/dataset/tum/fr3_nnf yaml=../../../../Experiments/YAMLs/TUM3_ORB_SFT.yaml    gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin'
#       'name=fr3_nnf_sft        seq=~/dataset/tum/fr3_nnf yaml=../../../../Experiments/YAMLs/TUM3_SFT.yaml        gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin'

        'name=fr1_xyz_orb_kaz    seq=~/dataset/tum/fr1_xyz yaml=../../../../Experiments/YAMLs/TUM1_ORB_KAZ.yaml    gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin'
        'name=fr1_xyz_akz_bsk    seq=~/dataset/tum/fr1_xyz yaml=../../../../Experiments/YAMLs/TUM1_AKZ_BSK.yaml    gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin'
        'name=fr1_xyz_akz_sft    seq=~/dataset/tum/fr1_xyz yaml=../../../../Experiments/YAMLs/TUM1_AKZ_SFT.yaml    gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin'
        'name=fr1_xyz_bsk_kaz    seq=~/dataset/tum/fr1_xyz yaml=../../../../Experiments/YAMLs/TUM1_BSK_KAZ.yaml    gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin'
        'name=fr1_xyz_bsk_sft    seq=~/dataset/tum/fr1_xyz yaml=../../../../Experiments/YAMLs/TUM1_BSK_SFT.yaml    gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin'
        'name=fr1_xyz_kaz_sft    seq=~/dataset/tum/fr1_xyz yaml=../../../../Experiments/YAMLs/TUM1_KAZ_SFT.yaml    gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin'

        'name=fr2_xyz_orb_kaz    seq=~/dataset/tum/fr2_xyz yaml=../../../../Experiments/YAMLs/TUM2_ORB_KAZ.yaml    gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin'
        'name=fr2_xyz_akz_bsk    seq=~/dataset/tum/fr2_xyz yaml=../../../../Experiments/YAMLs/TUM2_AKZ_BSK.yaml    gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin'
        'name=fr2_xyz_akz_sft    seq=~/dataset/tum/fr2_xyz yaml=../../../../Experiments/YAMLs/TUM2_AKZ_SFT.yaml    gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin'
        'name=fr2_xyz_bsk_kaz    seq=~/dataset/tum/fr2_xyz yaml=../../../../Experiments/YAMLs/TUM2_BSK_KAZ.yaml    gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin'
        'name=fr2_xyz_bsk_sft    seq=~/dataset/tum/fr2_xyz yaml=../../../../Experiments/YAMLs/TUM2_BSK_SFT.yaml    gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin'
        'name=fr2_xyz_kaz_sft    seq=~/dataset/tum/fr2_xyz yaml=../../../../Experiments/YAMLs/TUM2_KAZ_SFT.yaml    gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin'

        'name=fr3_nnf_orb_kaz    seq=~/dataset/tum/fr3_nnf yaml=../../../../Experiments/YAMLs/TUM3_ORB_KAZ.yaml    gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin'
        'name=fr3_nnf_akz_bsk    seq=~/dataset/tum/fr3_nnf yaml=../../../../Experiments/YAMLs/TUM3_AKZ_BSK.yaml    gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin'
        'name=fr3_nnf_akz_sft    seq=~/dataset/tum/fr3_nnf yaml=../../../../Experiments/YAMLs/TUM3_AKZ_SFT.yaml    gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin'
        'name=fr3_nnf_bsk_kaz    seq=~/dataset/tum/fr3_nnf yaml=../../../../Experiments/YAMLs/TUM3_BSK_KAZ.yaml    gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin'
        'name=fr3_nnf_bsk_sft    seq=~/dataset/tum/fr3_nnf yaml=../../../../Experiments/YAMLs/TUM3_BSK_SFT.yaml    gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin'
        'name=fr3_nnf_kaz_sft    seq=~/dataset/tum/fr3_nnf yaml=../../../../Experiments/YAMLs/TUM3_KAZ_SFT.yaml    gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin'
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
  SECONDS=0
  START_STR=$(date '+%F %T')

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

  total_h=$(( SECONDS/3600 ))
  total_m=$(( (SECONDS%3600)/60 ))
  total_s=$(( SECONDS%60 ))
  echo ""
  echo "Total wall time: ${total_h}h ${total_m}m ${total_s}s  (since ${START_STR})"

  echo ""; echo "All experiments finished."
  echo "Performance -> ./Performances/<name>/<name>_pref.txt"
  echo "APE/RPE     -> ./PoseErrors/APE|RPE/<name>.txt"
  echo "Logs/Poses  -> ./Logs/<name>/, ./Poses/<name>/"
}

main "$@"
