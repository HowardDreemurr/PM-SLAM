#!/usr/bin/env bash
# Master experiment runner (always pass ../../../../Experiments/<file>.yaml to mono_tum/mono_euroc)
# Flags:
#   --withCorr  : also collect Correlation artifacts via run_bench.sh
#   --noEvo     : skip evo_ape / evo_rpe analysis
#
# Per-line config supports 'features=' (e.g., features=[ORB,AKAZE]).
# Optional dataset controls:
#   mode= tum | euroc | kitti
#   times= <path_to_times_file>
#
# If features present: create ./<name>.yaml (in Experiments), then pass "../../../../Experiments/<name>.yaml".
# If no features: ensure ./<basename>.yaml exists (copy from base yaml if needed), and pass "../../../../Experiments/<basename>.yaml".
#
# ENV (optional):
#   EVO_ACTIVATE=~/.venvs/evo/bin/activate

APE_ARGS_DEFAULT=(-a -s -r trans_part)
RPE_ARGS_DEFAULT=(-r trans_part -d 1 -u f)
set -euo pipefail

expand_path() { eval echo "$1"; }

# defaults
START=0
SKIP=1
WITH_CORR=0
NO_EVO=1

# keep leftover args here
args=()

# --- parse arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --start)
            START="$2"
            shift 2
            ;;
        --skip)
            SKIP="$2"
            shift 2
            ;;
        --withCorr)
            WITH_CORR=1
            shift
            ;;
        --noEvo)
            NO_EVO=1
            shift
            ;;
        --) # end of our options
            shift
            args+=("$@")
            break
            ;;
        *)  # everything else is forwarded
            args+=("$1")
            shift
            ;;
    esac
done

read_config_lines() {
  if [[ $# -gt 0 ]]; then
    local cfg="$1"; [[ -f "$cfg" ]] || { echo "ERROR: config file not found: $cfg" >&2; exit 1; }
    mapfile -t LINES < "$cfg"
  else
    LINES=(
#        'name=fr1_corr         seq=~/dataset/tum/fr1_xyz yaml=../Install/etc/orbslam2/Monocular/TUM1.yaml gt=~/dataset/tum/fr1_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[ORB,AKAZE,BRISK,KAZE,SIFT,SuperPoint]'
#        'name=fr2_corr         seq=~/dataset/tum/fr2_xyz yaml=../Install/etc/orbslam2/Monocular/TUM2.yaml gt=~/dataset/tum/fr2_xyz/groundtruth.txt runs=20 exe=../Install/bin features=[ORB,AKAZE,BRISK,KAZE,SIFT,SuperPoint]'
#        'name=fr3_corr         seq=~/dataset/tum/fr3_nnf yaml=../Install/etc/orbslam2/Monocular/TUM3.yaml gt=~/dataset/tum/fr3_nnf/groundtruth.txt runs=20 exe=../Install/bin features=[ORB,AKAZE,BRISK,KAZE,SIFT,SuperPoint]'

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
#
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

#         'name=mh01_corr       seq=~/dataset/euroc/MH_01/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml gt=~/dataset/euroc/MH_01/state_groundtruth_estimate0/data.csv runs=20 exe=../Install/bin mode=euroc features=[ORB,AKAZE,BRISK,KAZE,SIFT,SuperPoint] times=MH01.txt'
#
#         'name=mh01_orb        seq=~/dataset/euroc/MH_01/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml gt=~/dataset/euroc/MH_01/state_groundtruth_estimate0/data.csv runs=20 exe=../Install/bin mode=euroc features=[ORB] times=MH01.txt'
#         'name=mh01_akz        seq=~/dataset/euroc/MH_01/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml gt=~/dataset/euroc/MH_01/state_groundtruth_estimate0/data.csv runs=20 exe=../Install/bin mode=euroc features=[AKAZE] times=MH01.txt'
#         'name=mh01_bsk        seq=~/dataset/euroc/MH_01/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml gt=~/dataset/euroc/MH_01/state_groundtruth_estimate0/data.csv runs=20 exe=../Install/bin mode=euroc features=[BRISK] times=MH01.txt'
#         'name=mh01_kaz        seq=~/dataset/euroc/MH_01/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml gt=~/dataset/euroc/MH_01/state_groundtruth_estimate0/data.csv runs=20 exe=../Install/bin mode=euroc features=[KAZE] times=MH01.txt'
#         'name=mh01_sft        seq=~/dataset/euroc/MH_01/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml gt=~/dataset/euroc/MH_01/state_groundtruth_estimate0/data.csv runs=20 exe=../Install/bin mode=euroc features=[SIFT] times=MH01.txt'
#         'name=mh01_spp        seq=~/dataset/euroc/MH_01/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml gt=~/dataset/euroc/MH_01/state_groundtruth_estimate0/data.csv runs=20 exe=../Install/bin mode=euroc features=[SuperPoint] times=MH01.txt'
#
#         'name=mh01_orb_akz    seq=~/dataset/euroc/MH_01/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml gt=~/dataset/euroc/MH_01/state_groundtruth_estimate0/data.csv runs=20 exe=../Install/bin mode=euroc features=[ORB,AKAZE] times=MH01.txt'
#         'name=mh01_orb_bsk    seq=~/dataset/euroc/MH_01/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml gt=~/dataset/euroc/MH_01/state_groundtruth_estimate0/data.csv runs=20 exe=../Install/bin mode=euroc features=[ORB,BRISK] times=MH01.txt'
#         'name=mh01_orb_kaz    seq=~/dataset/euroc/MH_01/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml gt=~/dataset/euroc/MH_01/state_groundtruth_estimate0/data.csv runs=20 exe=../Install/bin mode=euroc features=[ORB,KAZE] times=MH01.txt'
#         'name=mh01_orb_sft    seq=~/dataset/euroc/MH_01/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml gt=~/dataset/euroc/MH_01/state_groundtruth_estimate0/data.csv runs=20 exe=../Install/bin mode=euroc features=[ORB,SIFT] times=MH01.txt'
#         'name=mh01_orb_spp    seq=~/dataset/euroc/MH_01/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml gt=~/dataset/euroc/MH_01/state_groundtruth_estimate0/data.csv runs=20 exe=../Install/bin mode=euroc features=[ORB,SuperPoint] times=MH01.txt'
#         'name=mh01_akz_bsk    seq=~/dataset/euroc/MH_01/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml gt=~/dataset/euroc/MH_01/state_groundtruth_estimate0/data.csv runs=20 exe=../Install/bin mode=euroc features=[AKAZE,BRISK] times=MH01.txt'
#         'name=mh01_akz_kaz    seq=~/dataset/euroc/MH_01/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml gt=~/dataset/euroc/MH_01/state_groundtruth_estimate0/data.csv runs=20 exe=../Install/bin mode=euroc features=[AKAZE,KAZE] times=MH01.txt'
#         'name=mh01_akz_sft    seq=~/dataset/euroc/MH_01/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml gt=~/dataset/euroc/MH_01/state_groundtruth_estimate0/data.csv runs=20 exe=../Install/bin mode=euroc features=[AKAZE,SIFT] times=MH01.txt'
#         'name=mh01_akz_spp    seq=~/dataset/euroc/MH_01/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml gt=~/dataset/euroc/MH_01/state_groundtruth_estimate0/data.csv runs=20 exe=../Install/bin mode=euroc features=[AKAZE,SuperPoint] times=MH01.txt'
#         'name=mh01_bsk_kaz    seq=~/dataset/euroc/MH_01/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml gt=~/dataset/euroc/MH_01/state_groundtruth_estimate0/data.csv runs=20 exe=../Install/bin mode=euroc features=[BRISK,KAZE] times=MH01.txt'
#         'name=mh01_bsk_sft    seq=~/dataset/euroc/MH_01/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml gt=~/dataset/euroc/MH_01/state_groundtruth_estimate0/data.csv runs=20 exe=../Install/bin mode=euroc features=[BRISK,SIFT] times=MH01.txt'
#         'name=mh01_bsk_spp    seq=~/dataset/euroc/MH_01/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml gt=~/dataset/euroc/MH_01/state_groundtruth_estimate0/data.csv runs=20 exe=../Install/bin mode=euroc features=[BRISK,SuperPoint] times=MH01.txt'
#         'name=mh01_kaz_sft    seq=~/dataset/euroc/MH_01/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml gt=~/dataset/euroc/MH_01/state_groundtruth_estimate0/data.csv runs=20 exe=../Install/bin mode=euroc features=[KAZE,SIFT] times=MH01.txt'
#         'name=mh01_kaz_spp    seq=~/dataset/euroc/MH_01/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml gt=~/dataset/euroc/MH_01/state_groundtruth_estimate0/data.csv runs=20 exe=../Install/bin mode=euroc features=[KAZE,SuperPoint] times=MH01.txt'
#         'name=mh01_sft_spp    seq=~/dataset/euroc/MH_01/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml gt=~/dataset/euroc/MH_01/state_groundtruth_estimate0/data.csv runs=20 exe=../Install/bin mode=euroc features=[SIFT,SuperPoint] times=MH01.txt'

#         'name=mh03_spp        seq=~/dataset/euroc/MH_03/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml runs=20 exe=../Install/bin mode=euroc features=[SuperPoint] times=MH03.txt'
#         'name=mh03_orb_spp    seq=~/dataset/euroc/MH_03/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml runs=20 exe=../Install/bin mode=euroc features=[ORB,SuperPoint] times=MH03.txt'
#         'name=mh03_akz_spp    seq=~/dataset/euroc/MH_03/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml runs=20 exe=../Install/bin mode=euroc features=[AKAZE,SuperPoint] times=MH03.txt'
#         'name=mh03_bsk_spp    seq=~/dataset/euroc/MH_03/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml runs=20 exe=../Install/bin mode=euroc features=[BRISK,SuperPoint] times=MH03.txt'
#         'name=mh03_kaz_spp    seq=~/dataset/euroc/MH_03/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml runs=20 exe=../Install/bin mode=euroc features=[KAZE,SuperPoint] times=MH03.txt'
#         'name=mh03_sft_spp    seq=~/dataset/euroc/MH_03/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml runs=20 exe=../Install/bin mode=euroc features=[SIFT,SuperPoint] times=MH03.txt'

#         'name=mh05_spp        seq=~/dataset/euroc/MH_05/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml runs=20 exe=../Install/bin mode=euroc features=[SuperPoint] times=MH05.txt'
#         'name=mh05_orb_spp    seq=~/dataset/euroc/MH_05/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml runs=20 exe=../Install/bin mode=euroc features=[ORB,SuperPoint] times=MH05.txt'
#         'name=mh05_akz_spp    seq=~/dataset/euroc/MH_05/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml runs=20 exe=../Install/bin mode=euroc features=[AKAZE,SuperPoint] times=MH05.txt'
#         'name=mh05_bsk_spp    seq=~/dataset/euroc/MH_05/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml runs=20 exe=../Install/bin mode=euroc features=[BRISK,SuperPoint] times=MH05.txt'
#         'name=mh05_kaz_spp    seq=~/dataset/euroc/MH_05/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml runs=20 exe=../Install/bin mode=euroc features=[KAZE,SuperPoint] times=MH05.txt'
#         'name=mh05_sft_spp    seq=~/dataset/euroc/MH_05/cam0/data yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml runs=20 exe=../Install/bin mode=euroc features=[SIFT,SuperPoint] times=MH05.txt'

         #'name=kt00_corr     seq=~/dataset/kitti/00 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml gt=~/dataset/kitti/gt/poses/00.txt runs=20 exe=../Install/bin mode=kitti features=[ORB,AKAZE,BRISK,KAZE,SIFT,SuperPoint]'

#         'name=kt04_orb      seq=~/dataset/kitti/04 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml gt=~/dataset/kitti/gt/poses/04.txt runs=20 exe=../Install/bin mode=kitti features=[ORB]'
#         'name=kt04_akz      seq=~/dataset/kitti/04 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml gt=~/dataset/kitti/gt/poses/04.txt runs=20 exe=../Install/bin mode=kitti features=[AKAZE]'
#         'name=kt04_bsk      seq=~/dataset/kitti/04 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml gt=~/dataset/kitti/gt/poses/04.txt runs=20 exe=../Install/bin mode=kitti features=[BRISK]'
#         'name=kt04_kaz      seq=~/dataset/kitti/04 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml gt=~/dataset/kitti/gt/poses/04.txt runs=20 exe=../Install/bin mode=kitti features=[KAZE]'
#         'name=kt04_sft      seq=~/dataset/kitti/04 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml gt=~/dataset/kitti/gt/poses/04.txt runs=20 exe=../Install/bin mode=kitti features=[SIFT]'
#         'name=kt04_spp      seq=~/dataset/kitti/04 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml gt=~/dataset/kitti/gt/poses/04.txt runs=20 exe=../Install/bin mode=kitti features=[SuperPoint]'
#
#         'name=kt04_orb_akz  seq=~/dataset/kitti/04 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml gt=~/dataset/kitti/gt/poses/04.txt runs=20 exe=../Install/bin mode=kitti features=[ORB,AKAZE]'
#         'name=kt04_orb_bsk  seq=~/dataset/kitti/04 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml gt=~/dataset/kitti/gt/poses/04.txt runs=20 exe=../Install/bin mode=kitti features=[ORB,BRISK]'
#         'name=kt04_orb_kaz  seq=~/dataset/kitti/04 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml gt=~/dataset/kitti/gt/poses/04.txt runs=20 exe=../Install/bin mode=kitti features=[ORB,KAZE]'
#         'name=kt04_orb_sft  seq=~/dataset/kitti/04 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml gt=~/dataset/kitti/gt/poses/04.txt runs=20 exe=../Install/bin mode=kitti features=[ORB,SIFT]'
#         'name=kt04_orb_spp  seq=~/dataset/kitti/04 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml gt=~/dataset/kitti/gt/poses/04.txt runs=20 exe=../Install/bin mode=kitti features=[ORB,SuperPoint]'
#         'name=kt04_akz_bsk  seq=~/dataset/kitti/04 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml gt=~/dataset/kitti/gt/poses/04.txt runs=20 exe=../Install/bin mode=kitti features=[AKAZE,BRISK]'
#         'name=kt04_akz_kaz  seq=~/dataset/kitti/04 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml gt=~/dataset/kitti/gt/poses/04.txt runs=20 exe=../Install/bin mode=kitti features=[AKAZE,KAZE]'
#         'name=kt04_akz_sft  seq=~/dataset/kitti/04 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml gt=~/dataset/kitti/gt/poses/04.txt runs=20 exe=../Install/bin mode=kitti features=[AKAZE,SIFT]'
#         'name=kt04_akz_spp  seq=~/dataset/kitti/04 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml gt=~/dataset/kitti/gt/poses/04.txt runs=20 exe=../Install/bin mode=kitti features=[AKAZE,SuperPoint]'
#         'name=kt04_bsk_kaz  seq=~/dataset/kitti/04 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml gt=~/dataset/kitti/gt/poses/04.txt runs=20 exe=../Install/bin mode=kitti features=[BRISK,KAZE]'
#         'name=kt04_bsk_sft  seq=~/dataset/kitti/04 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml gt=~/dataset/kitti/gt/poses/04.txt runs=20 exe=../Install/bin mode=kitti features=[BRISK,SIFT]'
#         'name=kt04_bsk_spp  seq=~/dataset/kitti/04 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml gt=~/dataset/kitti/gt/poses/04.txt runs=20 exe=../Install/bin mode=kitti features=[BRISK,SuperPoint]'
#         'name=kt04_kaz_sft  seq=~/dataset/kitti/04 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml gt=~/dataset/kitti/gt/poses/04.txt runs=20 exe=../Install/bin mode=kitti features=[KAZE,SIFT]'
#         'name=kt04_kaz_spp  seq=~/dataset/kitti/04 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml gt=~/dataset/kitti/gt/poses/04.txt runs=20 exe=../Install/bin mode=kitti features=[KAZE,SuperPoint]'
#         'name=kt04_sft_spp  seq=~/dataset/kitti/04 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml gt=~/dataset/kitti/gt/poses/04.txt runs=20 exe=../Install/bin mode=kitti features=[SIFT,SuperPoint]'

#         'name=kt07_orb      seq=~/dataset/kitti/07 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml runs=20 exe=../Install/bin mode=kitti features=[ORB]'
#         'name=kt07_akz      seq=~/dataset/kitti/07 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml runs=20 exe=../Install/bin mode=kitti features=[AKAZE]'
#         'name=kt07_bsk      seq=~/dataset/kitti/07 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml runs=20 exe=../Install/bin mode=kitti features=[BRISK]'
#         'name=kt07_kaz      seq=~/dataset/kitti/07 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml runs=20 exe=../Install/bin mode=kitti features=[KAZE]'
#         'name=kt07_sft      seq=~/dataset/kitti/07 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml runs=20 exe=../Install/bin mode=kitti features=[SIFT]'
#         'name=kt07_spp      seq=~/dataset/kitti/07 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml runs=20 exe=../Install/bin mode=kitti features=[SuperPoint]'
#
#         'name=kt07_orb_akz  seq=~/dataset/kitti/07 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml runs=20 exe=../Install/bin mode=kitti features=[ORB,AKAZE]'
#         'name=kt07_orb_bsk  seq=~/dataset/kitti/07 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml runs=20 exe=../Install/bin mode=kitti features=[ORB,BRISK]'
#         'name=kt07_orb_kaz  seq=~/dataset/kitti/07 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml runs=20 exe=../Install/bin mode=kitti features=[ORB,KAZE]'
#         'name=kt07_orb_sft  seq=~/dataset/kitti/07 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml runs=20 exe=../Install/bin mode=kitti features=[ORB,SIFT]'
#         'name=kt07_orb_spp  seq=~/dataset/kitti/07 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml runs=20 exe=../Install/bin mode=kitti features=[ORB,SuperPoint]'
#         'name=kt07_akz_bsk  seq=~/dataset/kitti/07 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml runs=20 exe=../Install/bin mode=kitti features=[AKAZE,BRISK]'
#         'name=kt07_akz_kaz  seq=~/dataset/kitti/07 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml runs=20 exe=../Install/bin mode=kitti features=[AKAZE,KAZE]'
#         'name=kt07_akz_sft  seq=~/dataset/kitti/07 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml runs=20 exe=../Install/bin mode=kitti features=[AKAZE,SIFT]'
#         'name=kt07_akz_spp  seq=~/dataset/kitti/07 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml runs=20 exe=../Install/bin mode=kitti features=[AKAZE,SuperPoint]'
#         'name=kt07_bsk_kaz  seq=~/dataset/kitti/07 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml runs=20 exe=../Install/bin mode=kitti features=[BRISK,KAZE]'
#         'name=kt07_bsk_sft  seq=~/dataset/kitti/07 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml runs=20 exe=../Install/bin mode=kitti features=[BRISK,SIFT]'
#         'name=kt07_bsk_spp  seq=~/dataset/kitti/07 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml runs=20 exe=../Install/bin mode=kitti features=[BRISK,SuperPoint]'
#         'name=kt07_kaz_sft  seq=~/dataset/kitti/07 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml runs=20 exe=../Install/bin mode=kitti features=[KAZE,SIFT]'
#         'name=kt07_kaz_spp  seq=~/dataset/kitti/07 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml runs=20 exe=../Install/bin mode=kitti features=[KAZE,SuperPoint]'
#         'name=kt07_sft_spp  seq=~/dataset/kitti/07 yaml=../Install/etc/orbslam2/Monocular/KITTI04-12.yaml runs=20 exe=../Install/bin mode=kitti features=[SIFT,SuperPoint]'

#         'name=kt01_orb      seq=~/dataset/kitti/01 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[ORB]'
#         'name=kt01_akz      seq=~/dataset/kitti/01 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[AKAZE]'
#         'name=kt01_bsk      seq=~/dataset/kitti/01 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[BRISK]'
#         'name=kt01_kaz      seq=~/dataset/kitti/01 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[KAZE]'
#         'name=kt01_sft      seq=~/dataset/kitti/01 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[SIFT]'
#         'name=kt01_spp      seq=~/dataset/kitti/01 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[SuperPoint]'
#
#         'name=kt01_orb_akz  seq=~/dataset/kitti/01 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[ORB,AKAZE]'
#         'name=kt01_orb_bsk  seq=~/dataset/kitti/01 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[ORB,BRISK]'
#         'name=kt01_orb_kaz  seq=~/dataset/kitti/01 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[ORB,KAZE]'
#         'name=kt01_orb_sft  seq=~/dataset/kitti/01 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[ORB,SIFT]'
#         'name=kt01_orb_spp  seq=~/dataset/kitti/01 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[ORB,SuperPoint]'
#         'name=kt01_akz_bsk  seq=~/dataset/kitti/01 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[AKAZE,BRISK]'
#         'name=kt01_akz_kaz  seq=~/dataset/kitti/01 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[AKAZE,KAZE]'
#         'name=kt01_akz_sft  seq=~/dataset/kitti/01 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[AKAZE,SIFT]'
#         'name=kt01_akz_spp  seq=~/dataset/kitti/01 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[AKAZE,SuperPoint]'
#         'name=kt01_bsk_kaz  seq=~/dataset/kitti/01 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[BRISK,KAZE]'
#         'name=kt01_bsk_sft  seq=~/dataset/kitti/01 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[BRISK,SIFT]'
#         'name=kt01_bsk_spp  seq=~/dataset/kitti/01 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[BRISK,SuperPoint]'
#         'name=kt01_kaz_sft  seq=~/dataset/kitti/01 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[KAZE,SIFT]'
#         'name=kt01_kaz_spp  seq=~/dataset/kitti/01 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[KAZE,SuperPoint]'
#         'name=kt01_sft_spp  seq=~/dataset/kitti/01 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[SIFT,SuperPoint]'

#         'name=kt00_orb      seq=~/dataset/kitti/00 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[ORB]'
#         'name=kt00_akz      seq=~/dataset/kitti/00 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[AKAZE]'
#         'name=kt00_bsk      seq=~/dataset/kitti/00 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[BRISK]'
#         'name=kt00_kaz      seq=~/dataset/kitti/00 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[KAZE]'
#         'name=kt00_sft      seq=~/dataset/kitti/00 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[SIFT]'
#         'name=kt00_spp      seq=~/dataset/kitti/00 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[SuperPoint]'
#
#         'name=kt00_orb_akz  seq=~/dataset/kitti/00 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[ORB,AKAZE]'
#         'name=kt00_orb_bsk  seq=~/dataset/kitti/00 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[ORB,BRISK]'
#         'name=kt00_orb_kaz  seq=~/dataset/kitti/00 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[ORB,KAZE]'
#         'name=kt00_orb_sft  seq=~/dataset/kitti/00 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[ORB,SIFT]'
#         'name=kt00_orb_spp  seq=~/dataset/kitti/00 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[ORB,SuperPoint]'
#         'name=kt00_akz_bsk  seq=~/dataset/kitti/00 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[AKAZE,BRISK]'
#         'name=kt00_akz_kaz  seq=~/dataset/kitti/00 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[AKAZE,KAZE]'
#         'name=kt00_akz_sft  seq=~/dataset/kitti/00 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[AKAZE,SIFT]'
#         'name=kt00_akz_spp  seq=~/dataset/kitti/00 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[AKAZE,SuperPoint]'
#         'name=kt00_bsk_kaz  seq=~/dataset/kitti/00 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[BRISK,KAZE]'
#         'name=kt00_bsk_sft  seq=~/dataset/kitti/00 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[BRISK,SIFT]'
#         'name=kt00_bsk_spp  seq=~/dataset/kitti/00 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[BRISK,SuperPoint]'
#         'name=kt00_kaz_sft  seq=~/dataset/kitti/00 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[KAZE,SIFT]'
#         'name=kt00_kaz_spp  seq=~/dataset/kitti/00 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[KAZE,SuperPoint]'
#         'name=kt00_sft_spp  seq=~/dataset/kitti/00 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml runs=20 exe=../Install/bin mode=kitti features=[SIFT,SuperPoint]'

#        'name=oxf_orb         seq=~/dataset/tum/oxf_car yaml=../Install/etc/orbslam2/Monocular/TUM_OC.yaml runs=20 exe=../Install/bin features=[ORB]'
        'name=oxf_akz         seq=~/dataset/tum/oxf_car yaml=../Install/etc/orbslam2/Monocular/TUM_OC.yaml runs=20 exe=../Install/bin features=[AKAZE]'
#        'name=oxf_bsk         seq=~/dataset/tum/oxf_car yaml=../Install/etc/orbslam2/Monocular/TUM_OC.yaml runs=20 exe=../Install/bin features=[BRISK]'
#        'name=oxf_kaz         seq=~/dataset/tum/oxf_car yaml=../Install/etc/orbslam2/Monocular/TUM_OC.yaml runs=20 exe=../Install/bin features=[KAZE]'
#        'name=oxf_sft         seq=~/dataset/tum/oxf_car yaml=../Install/etc/orbslam2/Monocular/TUM_OC.yaml runs=20 exe=../Install/bin features=[SIFT]'
#        'name=oxf_spp         seq=~/dataset/tum/oxf_car yaml=../Install/etc/orbslam2/Monocular/TUM_OC.yaml runs=20 exe=../Install/bin features=[SuperPoint]'
#        'name=oxf_orb_akz     seq=~/dataset/tum/oxf_car yaml=../Install/etc/orbslam2/Monocular/TUM_OC.yaml runs=20 exe=../Install/bin features=[ORB,AKAZE]'
        'name=oxf_orb_bsk     seq=~/dataset/tum/oxf_car yaml=../Install/etc/orbslam2/Monocular/TUM_OC.yaml runs=20 exe=../Install/bin features=[ORB,BRISK]'
        'name=oxf_orb_kaz     seq=~/dataset/tum/oxf_car yaml=../Install/etc/orbslam2/Monocular/TUM_OC.yaml runs=20 exe=../Install/bin features=[ORB,KAZE]'
        'name=oxf_orb_sft     seq=~/dataset/tum/oxf_car yaml=../Install/etc/orbslam2/Monocular/TUM_OC.yaml runs=20 exe=../Install/bin features=[ORB,SIFT]'
        'name=oxf_orb_spp     seq=~/dataset/tum/oxf_car yaml=../Install/etc/orbslam2/Monocular/TUM_OC.yaml runs=20 exe=../Install/bin features=[ORB,SuperPoint]'
        'name=oxf_akz_bsk     seq=~/dataset/tum/oxf_car yaml=../Install/etc/orbslam2/Monocular/TUM_OC.yaml runs=20 exe=../Install/bin features=[AKAZE,BRISK]'
        'name=oxf_akz_kaz     seq=~/dataset/tum/oxf_car yaml=../Install/etc/orbslam2/Monocular/TUM_OC.yaml runs=20 exe=../Install/bin features=[AKAZE,KAZE]'
        'name=oxf_akz_sft     seq=~/dataset/tum/oxf_car yaml=../Install/etc/orbslam2/Monocular/TUM_OC.yaml runs=20 exe=../Install/bin features=[AKAZE,SIFT]'
        'name=oxf_akz_spp     seq=~/dataset/tum/oxf_car yaml=../Install/etc/orbslam2/Monocular/TUM_OC.yaml runs=20 exe=../Install/bin features=[AKAZE,SuperPoint]'
        'name=oxf_bsk_kaz     seq=~/dataset/tum/oxf_car yaml=../Install/etc/orbslam2/Monocular/TUM_OC.yaml runs=20 exe=../Install/bin features=[BRISK,KAZE]'
        'name=oxf_bsk_sft     seq=~/dataset/tum/oxf_car yaml=../Install/etc/orbslam2/Monocular/TUM_OC.yaml runs=20 exe=../Install/bin features=[BRISK,SIFT]'
        'name=oxf_bsk_spp     seq=~/dataset/tum/oxf_car yaml=../Install/etc/orbslam2/Monocular/TUM_OC.yaml runs=20 exe=../Install/bin features=[BRISK,SuperPoint]'
        'name=oxf_kaz_sft     seq=~/dataset/tum/oxf_car yaml=../Install/etc/orbslam2/Monocular/TUM_OC.yaml runs=20 exe=../Install/bin features=[KAZE,SIFT]'
        'name=oxf_kaz_spp     seq=~/dataset/tum/oxf_car yaml=../Install/etc/orbslam2/Monocular/TUM_OC.yaml runs=20 exe=../Install/bin features=[KAZE,SuperPoint]'
        'name=oxf_sft_spp     seq=~/dataset/tum/oxf_car yaml=../Install/etc/orbslam2/Monocular/TUM_OC.yaml runs=20 exe=../Install/bin features=[SIFT,SuperPoint]'




# Example (KITTI):
# 'name=kitti_00 seq=~/dataset/kitti/sequences/00 yaml=../Install/etc/orbslam2/Monocular/KITTI00-02.yaml gt=~/dataset/kitti/poses/00.txt runs=5 exe=../Install/bin features=[ORB,AKAZE] mode=kitti'
#
# Example (EuRoC):
# 'name=MH_01 seq=${SEQ_MH01} yaml=../Install/etc/orbslam2/Monocular/EuRoC.yaml  runs=20 exe=../Install/bin mode=euroc features=[ORB,SuperPoint] times=MH01.txt'
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


  numLines=${#LINES[@]}
  echo numLines=${numLines}
  
  echo ">>> Experiments to run: ${numLines} (withCorr=${WITH_CORR}, noEvo=${NO_EVO}, start=${START},skip=${SKIP})"
  [[ $numLines -eq 0 ]] && { echo "No experiments configured."; exit 1; }

  lineNo=$START

  while (( lineNo < $numLines )); do
      line="${LINES[$lineNo]}"
      echo line=${line}
    [[ -z "${line// }" || "$line" =~ ^# ]] && continue

    local name="" seq="" yaml="" gt="" runs="20" exe="../Install/bin" res_prefix="result" features="" mode="" times=""
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
        mode) mode="$v" ;;
        times) times="$v" ;;
      esac
    done

    seq=$(expand_path "$seq"); gt=$(expand_path "$gt"); exe=$(expand_path "$exe"); yaml=$(expand_path "$yaml")
    [[ -n "$times" ]] && times=$(expand_path "$times")

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
    echo "[bench] seq=$seq  yaml=${yaml_rel}  runs=$runs  exe_dir=$exe  mode=${mode:-tum} times=${times}"
    bash ./run_bench.sh ${WITH_CORR:+--withCorr} "$name" "$seq" "$runs" "$yaml_rel" "$exe" "$res_prefix" "${mode:-}" "${times:-}"

    if [[ -n "$temp_created" && -f "$temp_created" && "${KEEP_TMP_YAML:-0}" -eq 0 ]]; then
      rm -f "$temp_created"
    fi

    if [[ $NO_EVO -eq 1 ]]; then
      echo "[SKIP] --noEvo set; skip APE/RPE for '${name}'."
      lineNo=$((lineNo + SKIP))
      continue
    fi

    local poses_dir="./Poses/${name}"
    if [[ ! -d "$poses_dir" ]] || ! ls "$poses_dir"/result*.txt >/dev/null 2>&1; then
      echo "[SKIP] No poses found for '${name}' -> skip APE/RPE."
      lineNo=$((lineNo + SKIP))
      continue
    fi

    echo "[evo-ape] $name"
    bash ./run_evo.sh ape "$poses_dir" "$gt" "$name" "${APE_ARGS_DEFAULT[@]}" || true

    echo "[evo-rpe] $name"
    bash ./run_evo.sh rpe "$poses_dir" "$gt" "$name" "${RPE_ARGS_DEFAULT[@]}" || true

    lineNo=$((lineNo + SKIP))
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
