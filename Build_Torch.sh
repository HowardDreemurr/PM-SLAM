#!/usr/bin/env bash
# Build_Torch.sh — minimal installer for LibTorch (CPU or CUDA 12.6/12.8/12.9) + env setup.
# No nvidia-smi detection. You choose one of: cu126 | cu128 | cu129 | cpu
#
# Usage:
#   sudo ./Build_Torch.sh cu129
#   sudo ./Build_Torch.sh cu128
#   sudo ./Build_Torch.sh cu126
#   sudo ./Build_Torch.sh cpu
#
# Optional second arg = LibTorch version (default: 2.8.0)
#   sudo ./Build_Torch.sh cu129 2.8.0

set -Eeuo pipefail

need_root() { [[ ${EUID:-$(id -u)} -eq 0 ]] || { echo "[ERR ] Please run as root: sudo $0 $*"; exit 1; }; }
need_bin()  { command -v "$1" >/dev/null 2>&1 || { echo "[ERR ] Missing command: $1"; exit 1; }; }
log() { echo -e "\e[1m[INFO]\e[0m $*"; }
warn(){ echo -e "\e[1m[WARN]\e[0m $*" >&2; }
die() { echo -e "\e[1m[ERR ]\e[0m $*" >&2; exit 1; }

need_root
need_bin curl
need_bin unzip
need_bin awk
need_bin grep

VARIANT="${1:-}"
TORCH_VER="${2:-2.8.0}"
PREFIX="/opt"

case "$VARIANT" in
  cu126|cu128|cu129|cpu) ;;
  12.6) VARIANT="cu126" ;;
  12.8) VARIANT="cu128" ;;
  12.9) VARIANT="cu129" ;;
  *)
    cat <<USAGE
Usage: sudo $0 <cu126|cu128|cu129|cpu> [LibTorchVersion]
Examples:
  sudo $0 cu129
  sudo $0 cu128 2.8.0
  sudo $0 cpu
USAGE
    exit 1;;
esac

# Build URLs (prefer the specific version, fallback to latest for that flavor)
if [[ "$VARIANT" == "cpu" ]]; then
  FOLDER="cpu"
  FILE="libtorch-shared-with-deps-${TORCH_VER}%2Bcpu.zip"
else
  FOLDER="$VARIANT"
  FILE="libtorch-shared-with-deps-${TORCH_VER}%2B${VARIANT}.zip"
fi
URL_VER="https://download.pytorch.org/libtorch/${FOLDER}/${FILE}"
URL_LATEST="https://download.pytorch.org/libtorch/${FOLDER}/libtorch-shared-with-deps-latest.zip"

log "Variant: $VARIANT   Version: $TORCH_VER"
if curl -fsIL --retry 2 "$URL_VER" >/dev/null 2>&1; then
  URL="$URL_VER"
else
  warn "Versioned archive not found: $URL_VER; falling back to latest for this flavor."
  if curl -fsIL --retry 2 "$URL_LATEST" >/dev/null 2>&1; then
    URL="$URL_LATEST"
  else
    die "Cannot reach LibTorch download (variant=${VARIANT}). Check your network/proxy."
  fi
fi
log "Download URL: $URL"

TMP="/tmp/libtorch-${VARIANT}.zip"
DEST="${PREFIX}/libtorch"
log "Downloading to: $TMP"
curl -# -fSL --retry 5 --retry-delay 2 "$URL" -o "$TMP"

log "Unzipping to: $DEST"
mkdir -p "$DEST"
unzip -q -o "$TMP" -d "$DEST"

# Normalize structure if the archive contains a top-level 'libtorch/' directory
if [[ -d "${DEST}/libtorch" ]]; then
  shopt -s dotglob
  mv -f "${DEST}/libtorch/"* "${DEST}/" || true
  rmdir "${DEST}/libtorch" || true
  shopt -u dotglob
fi

# /opt/libtorch -> chosen install
ln -sfn "$DEST" "${PREFIX}/libtorch"
log "Symlink updated: ${PREFIX}/libtorch → ${DEST}"

# Environment
echo 'export Torch_DIR=/opt/libtorch/share/cmake/Torch' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/opt/libtorch/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc

# CUDA Toolkit install for CUDA variants
install_cuda() {
  local vtag="$1"   # 12-6 / 12-8 / 12-9
  local ver="${vtag/-/.}"
  local pkg="cuda-toolkit-${vtag}"

  log "Installing CUDA Toolkit: ${pkg}"
  . /etc/os-release
  local deb="https://developer.download.nvidia.com/compute/cuda/repos/${ID}${VERSION_ID//./}/x86_64/cuda-keyring_1.1-1_all.deb"
  curl -fsSL "$deb" -o /tmp/cuda-keyring.deb
  dpkg -i /tmp/cuda-keyring.deb
  apt-get update -y

  DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" || {
    die "Failed to install ${pkg}. Please check if it's available for your Ubuntu version."
  }
  log "Installed ${pkg}"

  echo "export PATH=/usr/local/cuda-${ver}/bin:\$PATH" >> ~/.bashrc
  echo "export LD_LIBRARY_PATH=/usr/local/cuda-${ver}/lib64:\$LD_LIBRARY_PATH" >> ~/.bashrc
  echo "export CUDA_HOME=/usr/local/cuda-${ver}" >> ~/.bashrc
  source ~/.bashrc
}

case "$VARIANT" in
  cu126) install_cuda "12-6" ;;
  cu128) install_cuda "12-8" ;;
  cu129) install_cuda "12-9" ;;
  cpu)   log "CPU variant: skipping CUDA Toolkit installation." ;;
esac

echo
log "Done."
echo "• Open a new shell to pick up /etc/profile.d/libtorch.sh"
echo "• Or, for this shell only, run:"
echo "    export Torch_DIR='${PREFIX}/libtorch/share/cmake/Torch'"
echo "    export LD_LIBRARY_PATH='${PREFIX}/libtorch/lib:\$LD_LIBRARY_PATH'"
