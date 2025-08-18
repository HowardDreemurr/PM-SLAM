#!/usr/bin/env bash
# Master experiment runner (always pass ../../../../Experiments/<file>.yaml to mono_tum)
# Flags:
#   --withCorr  : also collect Correlation artifacts via run_bench.sh
#   --noEvo     : skip evo_ape / evo_rpe analysis
#
# Per-line config supports 'features=' (e.g., features=[ORB,AKAZE]).
# If features present: create ./<name>.yaml (in Experiments), then pass "../../../../Experiments/<name>.yaml".
# If no features: ensure ./<basename>.yaml exists (copy from base yaml if needed), and pass "../../../../Experiments/<basename>.yaml".
#
# ENV (optional):
#   EVO_ACTIVATE=~/.venvs/evo/bin/activate

APE_ARGS_DEFAULT=(-a -s -r trans_part)
RPE_ARGS_DEFAULT=(-r trans_part -d 1 -u f)
set -euo pipefail

expand_path() { eval echo "$1"; }

WITH_CORR=0
NO_EVO=0
args=()
for a in "$@"; do
  case "$a" in
    --withCorr) WITH_CORR=1 ;;
    --noEvo)    NO_EVO=1 ;;
    *) args+=("$a") ;;
  esac
done
set -- "${args[@]}"

read_config_lines() {
  if [[ $# -gt 0 ]]; then
    local cfg="$1"; [[ -f "$cfg" ]] || { echo "ERROR: config file not found: $cfg" >&2; exit 1; }
    mapfile -t LINES < "$cfg"
  else
    LINES=(
        'name=fr1_corr         seq=~/dataset/tum/fr1_xyz yaml=../Install/etc/orbslam2/Monocular/TUM1.yaml gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[ORB,AKAZE,BRISK,KAZE,SIFT,SuperPoint]'
        'name=fr2_corr         seq=~/dataset/tum/fr2_xyz yaml=../Install/etc/orbslam2/Monocular/TUM2.yaml gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[ORB,AKAZE,BRISK,KAZE,SIFT,SuperPoint]'
        'name=fr3_corr         seq=~/dataset/tum/fr3_nnf yaml=../Install/etc/orbslam2/Monocular/TUM3.yaml gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin features=[ORB,AKAZE,BRISK,KAZE,SIFT,SuperPoint]'

#        'name=fr1_orb         seq=~/dataset/tum/fr1_xyz yaml=../Install/etc/orbslam2/Monocular/TUM1.yaml gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[ORB]'
#        'name=fr1_akz         seq=~/dataset/tum/fr1_xyz yaml=../Install/etc/orbslam2/Monocular/TUM1.yaml gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[AKAZE]'
#        'name=fr1_bsk         seq=~/dataset/tum/fr1_xyz yaml=../Install/etc/orbslam2/Monocular/TUM1.yaml gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[BRISK]'
#        'name=fr1_kaz         seq=~/dataset/tum/fr1_xyz yaml=../Install/etc/orbslam2/Monocular/TUM1.yaml gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[KAZE]'
#        'name=fr1_sft         seq=~/dataset/tum/fr1_xyz yaml=../Install/etc/orbslam2/Monocular/TUM1.yaml gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[SIFT]'
#        'name=fr1_spp         seq=~/dataset/tum/fr1_xyz yaml=../Install/etc/orbslam2/Monocular/TUM1.yaml gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[SuperPoint]'
#        'name=fr1_orb_akz     seq=~/dataset/tum/fr1_xyz yaml=../Install/etc/orbslam2/Monocular/TUM1.yaml gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[ORB,AKAZE]'
#        'name=fr1_orb_bsk     seq=~/dataset/tum/fr1_xyz yaml=../Install/etc/orbslam2/Monocular/TUM1.yaml gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[ORB,BRISK]'
#        'name=fr1_orb_kaz     seq=~/dataset/tum/fr1_xyz yaml=../Install/etc/orbslam2/Monocular/TUM1.yaml gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[ORB,KAZE]'
#        'name=fr1_orb_sft     seq=~/dataset/tum/fr1_xyz yaml=../Install/etc/orbslam2/Monocular/TUM1.yaml gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[ORB,SIFT]'
#        'name=fr1_orb_spp     seq=~/dataset/tum/fr1_xyz yaml=../Install/etc/orbslam2/Monocular/TUM1.yaml gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[ORB,SuperPoint]'
#        'name=fr1_akz_bsk     seq=~/dataset/tum/fr1_xyz yaml=../Install/etc/orbslam2/Monocular/TUM1.yaml gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[AKAZE,BRISK]'
#        'name=fr1_akz_kaz     seq=~/dataset/tum/fr1_xyz yaml=../Install/etc/orbslam2/Monocular/TUM1.yaml gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[AKAZE,KAZE]'
#        'name=fr1_akz_sft     seq=~/dataset/tum/fr1_xyz yaml=../Install/etc/orbslam2/Monocular/TUM1.yaml gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[AKAZE,SIFT]'
#        'name=fr1_akz_spp     seq=~/dataset/tum/fr1_xyz yaml=../Install/etc/orbslam2/Monocular/TUM1.yaml gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[AKAZE,SuperPoint]'
#        'name=fr1_bsk_kaz     seq=~/dataset/tum/fr1_xyz yaml=../Install/etc/orbslam2/Monocular/TUM1.yaml gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[BRISK,KAZE]'
#        'name=fr1_bsk_sft     seq=~/dataset/tum/fr1_xyz yaml=../Install/etc/orbslam2/Monocular/TUM1.yaml gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[BRISK,SIFT]'
#        'name=fr1_bsk_spp     seq=~/dataset/tum/fr1_xyz yaml=../Install/etc/orbslam2/Monocular/TUM1.yaml gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[BRISK,SuperPoint]'
#        'name=fr1_kaz_sft     seq=~/dataset/tum/fr1_xyz yaml=../Install/etc/orbslam2/Monocular/TUM1.yaml gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[KAZE,SIFT]'
#        'name=fr1_kaz_spp     seq=~/dataset/tum/fr1_xyz yaml=../Install/etc/orbslam2/Monocular/TUM1.yaml gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[KAZE,SuperPoint]'
#        'name=fr1_sft_spp     seq=~/dataset/tum/fr1_xyz yaml=../Install/etc/orbslam2/Monocular/TUM1.yaml gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[SIFT,SuperPoint]'

#        'name=fr2_orb       seq=~/dataset/tum/fr2_xyz yaml=../Install/etc/orbslam2/Monocular/TUM2.yaml gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[ORB]'
#        'name=fr2_akz       seq=~/dataset/tum/fr2_xyz yaml=../Install/etc/orbslam2/Monocular/TUM2.yaml gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[AKAZE]'
#        'name=fr2_bsk       seq=~/dataset/tum/fr2_xyz yaml=../Install/etc/orbslam2/Monocular/TUM2.yaml gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[BRISK]'
#        'name=fr2_kaz       seq=~/dataset/tum/fr2_xyz yaml=../Install/etc/orbslam2/Monocular/TUM2.yaml gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[KAZE]'
#        'name=fr2_sft       seq=~/dataset/tum/fr2_xyz yaml=../Install/etc/orbslam2/Monocular/TUM2.yaml gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[SIFT]'
#        'name=fr2_spp       seq=~/dataset/tum/fr2_xyz yaml=../Install/etc/orbslam2/Monocular/TUM2.yaml gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[SuperPoint]'
#        'name=fr2_orb_akz   seq=~/dataset/tum/fr2_xyz yaml=../Install/etc/orbslam2/Monocular/TUM2.yaml gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[ORB,AKAZE]'
#        'name=fr2_orb_bsk   seq=~/dataset/tum/fr2_xyz yaml=../Install/etc/orbslam2/Monocular/TUM2.yaml gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[ORB,BRISK]'
#        'name=fr2_orb_kaz   seq=~/dataset/tum/fr2_xyz yaml=../Install/etc/orbslam2/Monocular/TUM2.yaml gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[ORB,KAZE]'
#        'name=fr2_orb_sft   seq=~/dataset/tum/fr2_xyz yaml=../Install/etc/orbslam2/Monocular/TUM2.yaml gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[ORB,SIFT]'
#        'name=fr2_orb_spp   seq=~/dataset/tum/fr2_xyz yaml=../Install/etc/orbslam2/Monocular/TUM2.yaml gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[ORB,SuperPoint]'
#        'name=fr2_akz_bsk   seq=~/dataset/tum/fr2_xyz yaml=../Install/etc/orbslam2/Monocular/TUM2.yaml gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[AKAZE,BRISK]'
#        'name=fr2_akz_kaz   seq=~/dataset/tum/fr2_xyz yaml=../Install/etc/orbslam2/Monocular/TUM2.yaml gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[AKAZE,KAZE]'
#        'name=fr2_akz_sft   seq=~/dataset/tum/fr2_xyz yaml=../Install/etc/orbslam2/Monocular/TUM2.yaml gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[AKAZE,SIFT]'
#        'name=fr2_akz_spp   seq=~/dataset/tum/fr2_xyz yaml=../Install/etc/orbslam2/Monocular/TUM2.yaml gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[AKAZE,SuperPoint]'
#        'name=fr2_bsk_kaz   seq=~/dataset/tum/fr2_xyz yaml=../Install/etc/orbslam2/Monocular/TUM2.yaml gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[BRISK,KAZE]'
#        'name=fr2_bsk_sft   seq=~/dataset/tum/fr2_xyz yaml=../Install/etc/orbslam2/Monocular/TUM2.yaml gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[BRISK,SIFT]'
#        'name=fr2_bsk_spp   seq=~/dataset/tum/fr2_xyz yaml=../Install/etc/orbslam2/Monocular/TUM2.yaml gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[BRISK,SuperPoint]'
#        'name=fr2_kaz_sft   seq=~/dataset/tum/fr2_xyz yaml=../Install/etc/orbslam2/Monocular/TUM2.yaml gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[KAZE,SIFT]'
#        'name=fr2_kaz_spp   seq=~/dataset/tum/fr2_xyz yaml=../Install/etc/orbslam2/Monocular/TUM2.yaml gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[KAZE,SuperPoint]'
#        'name=fr2_sft_spp   seq=~/dataset/tum/fr2_xyz yaml=../Install/etc/orbslam2/Monocular/TUM2.yaml gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[SIFT,SuperPoint]'

#        'name=fr3_orb       seq=~/dataset/tum/fr3_nnf yaml=../Install/etc/orbslam2/Monocular/TUM3.yaml gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin features=[ORB]'
#        'name=fr3_akz       seq=~/dataset/tum/fr3_nnf yaml=../Install/etc/orbslam2/Monocular/TUM3.yaml gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin features=[AKAZE]'
#        'name=fr3_bsk       seq=~/dataset/tum/fr3_nnf yaml=../Install/etc/orbslam2/Monocular/TUM3.yaml gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin features=[BRISK]'
#        'name=fr3_kaz       seq=~/dataset/tum/fr3_nnf yaml=../Install/etc/orbslam2/Monocular/TUM3.yaml gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin features=[KAZE]'
#        'name=fr3_sft       seq=~/dataset/tum/fr3_nnf yaml=../Install/etc/orbslam2/Monocular/TUM3.yaml gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin features=[SIFT]'
#        'name=fr3_spp       seq=~/dataset/tum/fr3_nnf yaml=../Install/etc/orbslam2/Monocular/TUM3.yaml gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin features=[SuperPoint]'
#        'name=fr3_orb_akz   seq=~/dataset/tum/fr3_nnf yaml=../Install/etc/orbslam2/Monocular/TUM3.yaml gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin features=[ORB,AKAZE]'
#        'name=fr3_orb_bsk   seq=~/dataset/tum/fr3_nnf yaml=../Install/etc/orbslam2/Monocular/TUM3.yaml gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin features=[ORB,BRISK]'
#        'name=fr3_orb_kaz   seq=~/dataset/tum/fr3_nnf yaml=../Install/etc/orbslam2/Monocular/TUM3.yaml gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin features=[ORB,KAZE]'
#        'name=fr3_orb_sft   seq=~/dataset/tum/fr3_nnf yaml=../Install/etc/orbslam2/Monocular/TUM3.yaml gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin features=[ORB,SIFT]'
#        'name=fr3_orb_spp   seq=~/dataset/tum/fr3_nnf yaml=../Install/etc/orbslam2/Monocular/TUM3.yaml gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin features=[ORB,SuperPoint]'
#        'name=fr3_akz_bsk   seq=~/dataset/tum/fr3_nnf yaml=../Install/etc/orbslam2/Monocular/TUM3.yaml gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin features=[AKAZE,BRISK]'
#        'name=fr3_akz_kaz   seq=~/dataset/tum/fr3_nnf yaml=../Install/etc/orbslam2/Monocular/TUM3.yaml gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin features=[AKAZE,KAZE]'
#        'name=fr3_akz_sft   seq=~/dataset/tum/fr3_nnf yaml=../Install/etc/orbslam2/Monocular/TUM3.yaml gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin features=[AKAZE,SIFT]'
#        'name=fr3_akz_spp   seq=~/dataset/tum/fr3_nnf yaml=../Install/etc/orbslam2/Monocular/TUM3.yaml gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin features=[AKAZE,SuperPoint]'
#        'name=fr3_bsk_kaz   seq=~/dataset/tum/fr3_nnf yaml=../Install/etc/orbslam2/Monocular/TUM3.yaml gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin features=[BRISK,KAZE]'
#        'name=fr3_bsk_sft   seq=~/dataset/tum/fr3_nnf yaml=../Install/etc/orbslam2/Monocular/TUM3.yaml gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin features=[BRISK,SIFT]'
#        'name=fr3_bsk_spp   seq=~/dataset/tum/fr3_nnf yaml=../Install/etc/orbslam2/Monocular/TUM3.yaml gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin features=[BRISK,SuperPoint]'
#        'name=fr3_kaz_sft   seq=~/dataset/tum/fr3_nnf yaml=../Install/etc/orbslam2/Monocular/TUM3.yaml gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin features=[KAZE,SIFT]'
#        'name=fr3_kaz_spp   seq=~/dataset/tum/fr3_nnf yaml=../Install/etc/orbslam2/Monocular/TUM3.yaml gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin features=[KAZE,SuperPoint]'
#        'name=fr3_sft_spp   seq=~/dataset/tum/fr3_nnf yaml=../Install/etc/orbslam2/Monocular/TUM3.yaml gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin features=[SIFT,SuperPoint]'
    )
  fi
}

maybe_activate_venv() {
  local act="${EVO_ACTIVATE:-$HOME/.venvs/evo/bin/activate}"
  act=$(expand_path "$act")
  [[ -f "$act" ]] && source "$act" || true
}

make_temp_yaml_in_experiments() {
  local base_yaml="$1"
  local name="$2"
  local features_csv="$3"

  local base_abs="$base_yaml"
  [[ "$base_abs" != /* ]] && base_abs="$(cd "$(dirname "$base_abs")" && pwd)/$(basename "$base_abs")"
  local out="./${name}.yaml"
  cp -f "$base_abs" "$out"

  local raw="${features_csv//[\[\],]/ }"
  raw="$(echo "$raw" | awk '{$1=$1; print}')"
  local list="${raw// /, }"

  sed -i -E '/^[[:space:]]*Extractors?:/d' "$out"

  if grep -q '^[[:space:]]*Vocabularies:' "$out"; then
    sed -i -E "0,/^[[:space:]]*Vocabularies:/{s//Extractors: [ ${list} ]\nVocabularies:/}" "$out"
  else
    printf '\nExtractors: [ %s ]\n' "$list" >> "$out"
  fi

  echo "../../../../Experiments/${name}.yaml"
}


main() {
  SECONDS=0
  read_config_lines "$@"
  [[ -f "./run_bench.sh" ]] || { echo "ERROR: missing run_bench.sh" >&2; exit 2; }
  [[ -f "./run_evo.sh"   ]] || { echo "ERROR: missing run_evo.sh"   >&2; exit 2; }
  maybe_activate_venv

  echo ">>> Experiments to run: ${#LINES[@]} (withCorr=${WITH_CORR}, noEvo=${NO_EVO})"
  [[ ${#LINES[@]} -eq 0 ]] && { echo "No experiments configured."; exit 1; }

  for line in "${LINES[@]}"; do
    [[ -z "${line// }" || "$line" =~ ^# ]] && continue

    local name="" seq="" yaml="" gt="" runs="20" exe="../Install/bin" res_prefix="result" features=""
    for kv in $line; do
      local k="${kv%%=*}"; local v="${kv#*=}"
      case "$k" in
        name) name="$v" ;;
        seq)  seq="$v"  ;;
        yaml) yaml="$v" ;;
        gt)   gt="$v"   ;;
        runs) runs="$v" ;;
        exe)  exe="$v"  ;;
        res_prefix) res_prefix="$v" ;;
        features) features="$v" ;;
      esac
    done

    seq=$(expand_path "$seq"); gt=$(expand_path "$gt"); exe=$(expand_path "$exe"); yaml=$(expand_path "$yaml")

    local yaml_name yaml_rel temp_created=""
    yaml_name="$(basename "$yaml")"
    yaml_rel="../../../../Experiments/${yaml_name}"

    if [[ -n "$features" ]]; then
      local feat_norm
      feat_norm="$(echo "$features" | tr -d '[]' | tr ',' ' ' | awk '{$1=$1; print}')"
      yaml_rel="$(make_temp_yaml_in_experiments "$yaml" "$name" "$feat_norm")"
      temp_created="./${name}.yaml"
      echo "[INFO] YAML for ${name}: $(basename "$yaml") -> $(basename "$temp_created")  [${feat_norm}]"
    else
      if [[ ! -f "./${yaml_name}" ]]; then
        local src="$yaml"; [[ "$src" != /* ]] && src="$(cd "$(dirname "$src")" && pwd)/$(basename "$src")"
        cp -f "$src" "./${yaml_name}"
      fi
      echo "[INFO] YAML for ${name}: ./${yaml_name}"
    fi

    echo ""; echo "===== RUN: ${name} ====="
    echo "[bench] seq=$seq  yaml=${yaml_rel}  runs=$runs  exe_dir=$exe"
    if [[ $WITH_CORR -eq 1 ]]; then
      bash ./run_bench.sh --withCorr "$name" "$seq" "$runs" "$yaml_rel" "$exe" "$res_prefix"
    else
      bash ./run_bench.sh "$name" "$seq" "$runs" "$yaml_rel" "$exe" "$res_prefix"
    fi

    if [[ -n "$temp_created" && -f "$temp_created" && "${KEEP_TMP_YAML:-0}" -eq 0 ]]; then
      rm -f "$temp_created"
    fi

    if [[ $NO_EVO -eq 1 ]]; then
      echo "[SKIP] --noEvo set; skip APE/RPE for '${name}'."
      continue
    fi

    local poses_dir="./Poses/${name}"
    if [[ ! -d "$poses_dir" ]] || ! ls "$poses_dir"/result*.txt >/dev/null 2>&1; then
      echo "[SKIP] No poses found for '${name}' -> skip APE/RPE."
      continue
    fi

    echo "[evo-ape] $name"
    bash ./run_evo.sh ape "$poses_dir" "$gt" "$name" "${APE_ARGS_DEFAULT[@]}" || true

    echo "[evo-rpe] $name"
    bash ./run_evo.sh rpe "$poses_dir" "$gt" "$name" "${RPE_ARGS_DEFAULT[@]}" || true
  done

  local h=$(( SECONDS/3600 )); local m=$(( (SECONDS%3600)/60 )); local s=$(( SECONDS%60 ))
  echo ""; echo "Total wall time: ${h}h ${m}m ${s}s"
  echo "All experiments finished."
  echo "Performance -> ./Performances/<name>/<name>_pref.txt"
  echo "APE/RPE     -> ./PoseErrors/APE|RPE/<name>.txt"
  echo "Logs/Poses  -> ./Logs/<name>/, ./Poses/<name>/"
  echo "Correlations-> ./Correlations/<name>/ and ./Correlations/corr_exp_<name>.txt (if --withCorr)"
}

main "$@"
