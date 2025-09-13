#!/usr/bin/env bash
# run_evo_master.sh
# Scan ./Poses/* and run evo via ./run_evo.sh
# - RPE (translation)  -> ./PoseErrors/RPE/<name>.txt
# - RPE (rotation)     -> ./PoseErrors/RPEr/<name>.txt
# - (Optional) APE     -> enable with --ape to also compute APE with Sim(3) alignment (-a -s -r trans_part)
#
# Alignment for RPE:
#   --rpe-align none | se3 | sim3   (default: se3)
#   se3  -> evo_* -a
#   sim3 -> evo_* -as
#
# Ground truth resolution:
#   1) Local inside ./Poses/<name>: groundtruth.txt | gt.txt | GT.txt | *.tum | groundtruth.csv | *.csv
#   2) GLOBAL MAPPING by dataset prefix:
#        Edit DATASETS[] and GT_PATHS[] below (same length).
#        If <name> starts with a key, use the mapped path.
#        - If the mapped path is a directory, search inside with the same local rules.
#        - No conversion here: CSV is passed directly to run_evo.sh (it handles CSV).
#
# ENV (optional):
#   EVO_ACTIVATE=~/.venvs/evo/bin/activate
#
set -euo pipefail

ROOT="$(pwd)"
POSES_DIR="${ROOT}/Poses"

# -------------------- USER CONFIG (GLOBAL GT MAP) --------------------
# Example:
# DATASETS=(fr1 fr2 fr3 mh v1 v2)
# GT_PATHS=(/data/tum/fr1/groundtruth.txt /data/tum/fr2/groundtruth.txt /data/tum/fr3/groundtruth.txt \
#           /data/euroc/MH_01/state_groundtruth_estimate.csv /data/euroc/V1_02/state_groundtruth_estimate.csv /data/euroc/V2_03/state_groundtruth_estimate.csv)
#DATASETS=(fr1 fr2 fr3)
#GT_PATHS=(~/datasets/tum/fr1/groundtruth.txt ~/datasets/tum/fr2/groundtruth.txt ~/datasets/tum/fr3/groundtruth.txt)
#DATASETS=(kt01 kt04 kt07)
#GT_PATHS=(${POSES_DIR}/kitti_gt/01_tum.txt ${POSES_DIR}/kitti_gt/04_tum.txt ${POSES_DIR}/kitti_gt/07_tum.txt)
#DATASETS=(mh01 mh03 mh05)
#GT_PATHS=(~/dataset/euroc/MH_01/state_groundtruth_estimate0/data.csv ~/dataset/euroc/MH_03/state_groundtruth_estimate0/data.csv ~/dataset/euroc/MH_05/state_groundtruth_estimate0/data.csv)
DATASETS=(oxf)
GT_PATHS=(${POSES_DIR}/oxf_gt_ip.txt)
DATASETS=(fr1 fr2 fr3 kt01 kt04 kt07 mh01 mh03 mh05)
GT_PATHS=(~/dataset/tum/fr1/groundtruth.txt ~/dataset/tum/fr2/groundtruth.txt ~/dataset/tum/fr3/groundtruth.txt ${POSES_DIR}/kitti_gt/01_tum.txt ${POSES_DIR}/kitti_gt/04_tum.txt ${POSES_DIR}/kitti_gt/07_tum.txt ~/dataset/euroc/MH_01/state_groundtruth_estimate0/data.csv ~/dataset/euroc/MH_03/state_groundtruth_estimate0/data.csv ~/dataset/euroc/MH_05/state_groundtruth_estimate0/data.csv)

# --------------- helpers ---------------

maybe_activate_venv() {
  local act="${EVO_ACTIVATE:-$HOME/.venvs/evo/bin/activate}"
  [[ -f "$act" ]] && source "$act" || true
}

search_gt_in_dir() {
  local dir="$1"
  shopt -s nullglob
  local cands=( "$dir/groundtruth.txt" "$dir/gt.txt" "$dir/GT.txt" "$dir"/*.tum "$dir/groundtruth.csv" "$dir"/*.csv )
  shopt -u nullglob
  for f in "${cands[@]}"; do [[ -f "$f" ]] && { echo "$f"; return; }; done
  echo ""
}

mapped_gt_for_name() {
  local name="$1"
  local -n _keys=DATASETS
  local -n _vals=GT_PATHS
  if [[ ${#_keys[@]} -ne ${#_vals[@]} ]]; then
    echo "[WARN] DATASETS and GT_PATHS length mismatch (${#_keys[@]} vs ${#_vals[@]}), ignoring mapping." >&2
    echo ""; return
  fi
  for ((i=0;i<${#_keys[@]};++i)); do
    local key="${_keys[i]}"; local val="${_vals[i]}"
    if [[ "$name" == "$key" || "$name" == "$key"* || "$name" == $key ]]; then
      if [[ -d "$val" ]]; then
        local found; found="$(search_gt_in_dir "$val")"
        [[ -n "$found" ]] && { echo "$found"; return; }
      elif [[ -f "$val" ]]; then
        echo "$val"; return
      else
        echo "[WARN] Mapped GT path not found for key '$key': $val" >&2
      fi
    fi
  done
  echo ""
}

find_gt_for_dir() {
  local d="$1"; local name; name="$(basename "$d")"
  # 1) local search
  local found; found="$(search_gt_in_dir "$d")"
  [[ -n "$found" ]] && { echo "$found"; return; }
  # 2) mapped
  local mapped; mapped="$(mapped_gt_for_name "$name")"
  [[ -n "$mapped" ]] && { echo "$mapped"; return; }
  echo ""
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [--ape] [--only NAME|glob] [--dry] [--rpe-align none|se3|sim3] [--rpet|--rper]
  --ape                Also compute APE (-a -s -r trans_part)
  --only ARG           Only run subdirs matching name or glob (e.g., 'fr1_*'); can be repeated
  --dry                Show actions without running evo
  --rpe-align <mode>   Pre-alignment for RPE: none | se3 (-a) | sim3 (-as). Default: se3
  --rpet               Only run translation RPE (skip rotation)
  --rper               Only run rotation RPE (skip translation)

GT file can be TUM (.txt/.tum), EuRoC CSV (.csv), or KITTI; the low-level run_evo.sh handles ref format & CSV conversion.
Edit DATASETS[] and GT_PATHS[] at the top to map dataset prefixes to GT paths.
Outputs:
  - ./PoseErrors/RPE/<name>.txt     (translation metrics)
  - ./PoseErrors/RPEr/<name>.txt    (rotation metrics)
  - ./PoseErrors/APE/<name>.txt     (if --ape)
EOF
}

make_rpe_align_flags() {
  local mode="$1"
  case "$mode" in
    none|"") echo "" ;;
    se3) echo "-a" ;;
    sim3) echo "-as" ;;
    *) echo "[WARN] Unknown --rpe-align '$mode', using 'se3'." >&2; echo "-a" ;;
  esac
}

main() {
  local DO_APE=0 DO_DRY=0
  local DO_RPET=1 DO_RPER=1   # default: run both; flags below will toggle
  local only_patterns=()
  local RPE_ALIGN_MODE="se3"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ape) DO_APE=1; shift ;;
      --dry) DO_DRY=1; shift ;;
      --only) only_patterns+=("$2"); shift 2 ;;
      --rpe-align) RPE_ALIGN_MODE="$2"; shift 2 ;;
      --rpet) DO_RPET=1; DO_RPER=0; shift ;;
      --rper) DO_RPER=1; DO_RPET=0; shift ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Unknown arg: $1"; usage; exit 1 ;;
    esac
  done

  [[ -d "$POSES_DIR" ]] || { echo "ERROR: ./Poses not found" >&2; exit 2; }
  [[ -f "./run_evo.sh" ]] || { echo "ERROR: missing ./run_evo.sh" >&2; exit 3; }

  maybe_activate_venv

  mapfile -t dirs < <(find "$POSES_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
  if [[ ${#dirs[@]} -eq 0 ]]; then
    echo "No subfolders in ./Poses" >&2
    exit 0
  fi

  if [[ ${#only_patterns[@]} -gt 0 ]]; then
    filtered=()
    for d in "${dirs[@]}"; do
      name="$(basename "$d")"
      for p in "${only_patterns[@]}"; do
        [[ "$name" == $p ]] && { filtered+=("$d"); break; }
      done
    done
    dirs=("${filtered[@]}")
  fi

  echo ">>> Found ${#dirs[@]} pose folders under ./Poses"
  mkdir -p "./PoseErrors/RPEr"

  local RPE_ALIGN_FLAGS; RPE_ALIGN_FLAGS="$(make_rpe_align_flags "$RPE_ALIGN_MODE")"
  echo "[INFO] RPE alignment mode: $RPE_ALIGN_MODE  (flags: '$RPE_ALIGN_FLAGS')"

  for d in "${dirs[@]}"; do
    name="$(basename "$d")"
    shopt -s nullglob; files=( "$d"/result*.txt ); shopt -u nullglob
    if [[ ${#files[@]} -eq 0 ]]; then
      echo "[SKIP] ${name}: no result*.txt"
      continue
    fi

    gt="$(find_gt_for_dir "$d")"
    if [[ -z "$gt" ]]; then
      echo "[SKIP] ${name}: no ground truth found (local or mapped)"
      continue
    fi

    echo ""; echo "===== ${name} ====="
    echo "[GT] $gt"

    # --- RPE (translation) ---
    if [[ $DO_RPET -eq 1 ]]; then
      echo "[RPE-trans] evo_rpe <ref> $gt <est> ${RPE_ALIGN_FLAGS} -a -s -r trans_part -d 1 -u f"
      if [[ $DO_DRY -eq 0 ]]; then
        bash ./run_evo.sh rpe "$d" "$gt" "$name" ${RPE_ALIGN_FLAGS} -r trans_part -d 1 -u f || true
      fi
    fi

    # --- RPE (rotation) ---
    if [[ $DO_RPER -eq 1 ]]; then
    echo "[RPE-rot] evo_rpe <ref> $gt <est> ${RPE_ALIGN_FLAGS} -a -s -r angle_deg -d 1 -u f"
      if [[ $DO_DRY -eq 0 ]]; then
      bash ./run_evo.sh rpe "$d" "$gt" "${name}__ROT" ${RPE_ALIGN_FLAGS} -r angle_deg -d 1 -u f || true
        if [[ -f "./PoseErrors/RPE/${name}__ROT.txt" ]]; then
          mv -f "./PoseErrors/RPE/${name}__ROT.txt" "./PoseErrors/RPEr/${name}.txt"
          echo "[DONE] Saved rotation metrics to: ./PoseErrors/RPEr/${name}.txt"
        else
          echo "[WARN] Rotation metrics file not found for ${name}"
        fi
      fi
    fi

    # --- (optional) APE ---
    if [[ $DO_APE -eq 1 ]]; then
      echo "[APE] evo_ape tum <gt> <est> -a -s -r trans_part"
      if [[ $DO_DRY -eq 0 ]]; then
        bash ./run_evo.sh ape "$d" "$gt" "$name" -a -s -r trans_part || true
      fi
    fi
  done

  echo ""; echo "All done."
  [[ $DO_RPET -eq 1 ]] && echo "Translation RPE -> ./PoseErrors/RPE/<name>.txt"
  [[ $DO_RPER -eq 1 ]] && echo "Rotation    RPE -> ./PoseErrors/RPEr/<name>.txt"
  [[ $DO_APE -eq 1 ]] && echo "APE            -> ./PoseErrors/APE/<name>.txt"
}

main "$@"
