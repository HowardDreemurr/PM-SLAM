#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

ROOT="./Poses"

# Count lines of a file (used as a proxy for "trajectory length")
line_count() {
  wc -l < "$1" | tr -d '[:space:]'
}

# Extract XX from filename (supports any number of digits)
extract_xx() {
  local base="$1"
  # Match resultXX.txt or resultXX_segYY.txt
  sed -n 's/^result\([0-9][0-9]*\)\(_seg[0-9][0-9]*\)\?\.txt$/\1/p' <<<"$base"
}

# Extract YY from filename (only for *_segYY files)
extract_yy() {
  local base="$1"
  sed -n 's/^result[0-9][0-9]*_seg\([0-9][0-9]*\)\.txt$/\1/p' <<<"$base"
}

for dir in "$ROOT"/oxf_*; do
  [[ -d "$dir" ]] || continue
  echo "==> Processing: $dir"

  # Collect all seen XX in this folder
  declare -A seen_xx=()
  for f in "$dir"/result*.txt; do
    base="$(basename "$f")"
    xx="$(extract_xx "$base" || true)"
    [[ -n "${xx:-}" ]] && seen_xx["$xx"]=1
  done

  # Skip if no result files
  if [[ ${#seen_xx[@]} -eq 0 ]]; then
    echo "    (no result*.txt found) skip."
    continue
  fi

  # Handle each XX
  for xx in "${!seen_xx[@]}"; do
    # 1) If resultXX.txt exists, move it to a new seg file with seg = (max YY + 1)
    cur_result="$dir/result${xx}.txt"
    if [[ -f "$cur_result" ]]; then
      max_seg=-1
      yy_width=0

      # Find existing seg files to determine max YY and digit width
      for segf in "$dir"/result${xx}_seg*.txt; do
        base="$(basename "$segf")"
        yy="$(extract_yy "$base" || true)"
        [[ -z "${yy:-}" ]] && continue
        # Compare numeric value (strip leading zeros)
        num=$((10#$yy))
        (( num > max_seg )) && max_seg=$num
        (( ${#yy} > yy_width )) && yy_width=${#yy}
      done

      # If no seg files exist, start from 01 with 2-digit width
      if (( yy_width == 0 )); then
        yy_width=2
      fi

      next=$((max_seg + 1))
      next_padded="$(printf "%0${yy_width}d" "$next")"
      target="$dir/result${xx}_seg${next_padded}.txt"

      # In case of unexpected name collision, keep incrementing
      while [[ -e "$target" ]]; do
        next=$((next + 1))
        next_padded="$(printf "%0${yy_width}d" "$next")"
        target="$dir/result${xx}_seg${next_padded}.txt"
      done

      echo "    Rename: $(basename "$cur_result") -> $(basename "$target")"
      mv -- "$cur_result" "$target"
    fi

    # 2) Choose the "longest" (most lines) among resultXX_segYY.txt (and any stray resultXX.txt)
    best_file=""
    best_lines=-1

    candidates=()
    candidates+=("$dir"/result${xx}_seg*.txt)
    candidates+=("$dir"/result${xx}.txt)

    # Filter out non-existent globs
    tmp_candidates=()
    for c in "${candidates[@]}"; do
      [[ -f "$c" ]] && tmp_candidates+=("$c")
    done
    candidates=("${tmp_candidates[@]}")

    if [[ ${#candidates[@]} -eq 0 ]]; then
      echo "    (no candidates for XX=$xx) skip choosing longest."
      continue
    fi

    # Pick the most lines; if tie, pick the most recently modified
    for c in "${candidates[@]}"; do
      n_lines="$(line_count "$c")"
      if (( n_lines > best_lines )); then
        best_lines=$n_lines
        best_file="$c"
      elif (( n_lines == best_lines )) && [[ -n "$best_file" ]]; then
        if [[ "$c" -nt "$best_file" ]]; then
          best_file="$c"
        fi
      fi
    done

    target_main="$dir/result${xx}.txt"
    if [[ "$best_file" != "$target_main" ]]; then
      echo "    Select longest for XX=${xx}: $(basename "$best_file") (${best_lines} lines)"
      # Rename the chosen file to resultXX.txt (will overwrite if exists)
      mv -f -- "$best_file" "$target_main"
    else
      echo "    result${xx}.txt is already the longest (${best_lines} lines)."
    fi
  done

  # Cleanup local assoc array
  unset seen_xx
done

echo "All done."
