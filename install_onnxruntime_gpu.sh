#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# ONNX Runtime GPU installer for Ubuntu Linux x86_64
#
# Default package:
#   onnxruntime-linux-x64-gpu_cuda13-1.28.0.tgz
#
# Installation paths:
#   Headers:   /usr/local/include/onnxruntime
#   Libraries: /usr/local/lib
#
# Usage:
#   chmod +x install_onnxruntime_gpu.sh
#   ./install_onnxruntime_gpu.sh
#
# Optional:
#   ORT_VERSION=1.28.0 ./install_onnxruntime_gpu.sh
# ============================================================

ORT_VERSION="${ORT_VERSION:-1.28.0}"
ORT_PACKAGE_NAME="onnxruntime-linux-x64-gpu_cuda13-${ORT_VERSION}"
ORT_ARCHIVE_NAME="${ORT_PACKAGE_NAME}.tgz"
ORT_DOWNLOAD_URL="https://github.com/microsoft/onnxruntime/releases/download/v${ORT_VERSION}/${ORT_ARCHIVE_NAME}"

INSTALL_INCLUDE_DIR="/usr/local/include/onnxruntime"
INSTALL_LIB_DIR="/usr/local/lib"

WORK_DIR="$(mktemp -d)"
ARCHIVE_PATH="${WORK_DIR}/${ORT_ARCHIVE_NAME}"
EXTRACTED_DIR="${WORK_DIR}/${ORT_PACKAGE_NAME}"

if [[ "${EUID}" -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

cleanup() {
    rm -rf "${WORK_DIR}"
}

on_error() {
    local exit_code=$?
    local line_number="${1:-unknown}"

    echo
    echo "Installation failed at line ${line_number}, exit code ${exit_code}." >&2
    exit "${exit_code}"
}

trap cleanup EXIT
trap 'on_error $LINENO' ERR

log() {
    echo
    echo "==> $*"
}

warn() {
    echo
    echo "WARNING: $*" >&2
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ------------------------------------------------------------
# 1. Validate operating system and architecture
# ------------------------------------------------------------

log "Checking operating system and architecture"

if [[ "$(uname -s)" != "Linux" ]]; then
    echo "This installer only supports Linux." >&2
    exit 1
fi

MACHINE_ARCH="$(uname -m)"

case "${MACHINE_ARCH}" in
    x86_64 | amd64)
        ;;
    *)
        echo "Unsupported architecture: ${MACHINE_ARCH}" >&2
        echo "The requested ONNX Runtime package only supports x86_64." >&2
        exit 1
        ;;
esac

if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release

    echo "Distribution: ${PRETTY_NAME:-unknown}"

    if [[ "${ID:-}" != "ubuntu" ]]; then
        warn "This script was designed for Ubuntu, but detected ${ID:-unknown}."
    fi
fi

echo "Architecture: ${MACHINE_ARCH}"
echo "ONNX Runtime version: ${ORT_VERSION}"

# ------------------------------------------------------------
# 2. Install system dependencies
# ------------------------------------------------------------

log "Installing required system packages"

if ! command_exists apt-get; then
    echo "apt-get was not found. This installer requires Ubuntu or Debian." >&2
    exit 1
fi

${SUDO} apt-get update

${SUDO} apt-get install -y \
    build-essential \
    ca-certificates \
    curl \
    tar \
    gzip \
    pkg-config \
    zlib1g \
    zlib1g-dev

# ------------------------------------------------------------
# 3. Check NVIDIA driver and CUDA environment
# ------------------------------------------------------------

log "Checking NVIDIA driver and CUDA environment"

if command_exists nvidia-smi; then
    nvidia-smi
else
    warn "nvidia-smi was not found. Verify that the NVIDIA driver is installed."
fi

if command_exists nvcc; then
    nvcc --version
else
    warn "nvcc was not found. This may be acceptable for runtime-only installations."
fi

if [[ -d /usr/local/cuda ]]; then
    echo "CUDA directory: /usr/local/cuda"

    if [[ -L /usr/local/cuda ]]; then
        echo "CUDA symlink target: $(readlink -f /usr/local/cuda)"
    fi
else
    warn "/usr/local/cuda does not exist."
fi

# ------------------------------------------------------------
# 4. Download ONNX Runtime
# ------------------------------------------------------------

log "Downloading ONNX Runtime GPU package"

echo "URL:"
echo "${ORT_DOWNLOAD_URL}"
echo
echo "Destination:"
echo "${ARCHIVE_PATH}"

curl \
    --fail \
    --location \
    --show-error \
    --silent \
    --retry 3 \
    --retry-delay 2 \
    --connect-timeout 20 \
    --output "${ARCHIVE_PATH}" \
    "${ORT_DOWNLOAD_URL}"

if [[ ! -s "${ARCHIVE_PATH}" ]]; then
    echo "Downloaded archive is empty." >&2
    exit 1
fi

echo "Downloaded size: $(du -h "${ARCHIVE_PATH}" | cut -f1)"

# ------------------------------------------------------------
# 5. Validate and extract archive
# ------------------------------------------------------------

log "Validating downloaded archive"

if ! tar -tzf "${ARCHIVE_PATH}" >/dev/null; then
    echo "The downloaded file is not a valid gzip-compressed tar archive." >&2
    exit 1
fi

log "Extracting ONNX Runtime package"

tar -xzf "${ARCHIVE_PATH}" -C "${WORK_DIR}"

if [[ ! -d "${EXTRACTED_DIR}" ]]; then
    echo "Expected extracted directory was not found:" >&2
    echo "${EXTRACTED_DIR}" >&2

    echo
    echo "Extracted contents:" >&2
    find "${WORK_DIR}" -maxdepth 2 -mindepth 1 -print >&2

    exit 1
fi

# ------------------------------------------------------------
# 6. Validate package contents
# ------------------------------------------------------------

log "Validating ONNX Runtime package contents"

REQUIRED_FILES=(
    "${EXTRACTED_DIR}/include/onnxruntime_c_api.h"
    "${EXTRACTED_DIR}/lib/libonnxruntime.so"
)

for required_file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -e "${required_file}" ]]; then
        echo "Required file is missing:" >&2
        echo "${required_file}" >&2
        exit 1
    fi
done

if [[ ! -e "${EXTRACTED_DIR}/lib/libonnxruntime_providers_cuda.so" ]]; then
    echo "CUDA Execution Provider library was not found:" >&2
    echo "${EXTRACTED_DIR}/lib/libonnxruntime_providers_cuda.so" >&2
    exit 1
fi

echo "Package contents validated successfully."

# ------------------------------------------------------------
# 7. Remove old ONNX Runtime installation
# ------------------------------------------------------------

log "Preparing installation directories"

${SUDO} mkdir -p "${INSTALL_INCLUDE_DIR}"
${SUDO} mkdir -p "${INSTALL_LIB_DIR}"

# Remove old ONNX Runtime headers to avoid mixing versions.
${SUDO} rm -rf "${INSTALL_INCLUDE_DIR:?}/"*

# Remove only ONNX Runtime libraries, not unrelated libraries.
${SUDO} find "${INSTALL_LIB_DIR}" \
    -maxdepth 1 \
    \( \
        -name 'libonnxruntime.so*' \
        -o -name 'libonnxruntime_providers_*.so*' \
    \) \
    -delete

# ------------------------------------------------------------
# 8. Install headers and shared libraries
# ------------------------------------------------------------

log "Installing ONNX Runtime headers"

${SUDO} cp -a \
    "${EXTRACTED_DIR}/include/." \
    "${INSTALL_INCLUDE_DIR}/"

log "Installing ONNX Runtime shared libraries"

${SUDO} cp -a \
    "${EXTRACTED_DIR}/lib/." \
    "${INSTALL_LIB_DIR}/"

# ------------------------------------------------------------
# 9. Configure Linux dynamic linker
# ------------------------------------------------------------

log "Configuring Linux dynamic linker"

echo "${INSTALL_LIB_DIR}" \
    | ${SUDO} tee /etc/ld.so.conf.d/onnxruntime.conf >/dev/null

if [[ -d /usr/local/cuda/lib64 ]]; then
    echo "/usr/local/cuda/lib64" \
        | ${SUDO} tee /etc/ld.so.conf.d/cuda.conf >/dev/null
elif [[ -d /usr/local/cuda/lib ]]; then
    echo "/usr/local/cuda/lib" \
        | ${SUDO} tee /etc/ld.so.conf.d/cuda.conf >/dev/null
else
    warn "CUDA library directory was not found under /usr/local/cuda."
fi

${SUDO} ldconfig

# ------------------------------------------------------------
# 10. Verify installed files
# ------------------------------------------------------------

log "Verifying installed ONNX Runtime files"

if [[ ! -f "${INSTALL_INCLUDE_DIR}/onnxruntime_c_api.h" ]]; then
    echo "ONNX Runtime C API header installation failed." >&2
    exit 1
fi

if [[ ! -e "${INSTALL_LIB_DIR}/libonnxruntime.so" ]]; then
    echo "ONNX Runtime shared library installation failed." >&2
    exit 1
fi

if [[ ! -e "${INSTALL_LIB_DIR}/libonnxruntime_providers_cuda.so" ]]; then
    echo "ONNX Runtime CUDA provider installation failed." >&2
    exit 1
fi

echo
echo "Installed headers:"
ls -l "${INSTALL_INCLUDE_DIR}/onnxruntime_c_api.h"

echo
echo "Installed ONNX Runtime libraries:"
find "${INSTALL_LIB_DIR}" \
    -maxdepth 1 \
    -name 'libonnxruntime*.so*' \
    -printf '%f -> %l\n' \
    | sort

# ------------------------------------------------------------
# 11. Verify dynamic linker registration
# ------------------------------------------------------------

log "Checking dynamic linker cache"

if ldconfig -p | grep -q 'libonnxruntime\.so'; then
    ldconfig -p | grep 'libonnxruntime\.so'
else
    echo "libonnxruntime.so was not found in the dynamic linker cache." >&2
    exit 1
fi

# ------------------------------------------------------------
# 12. Check base ONNX Runtime dependencies
# ------------------------------------------------------------

log "Checking base ONNX Runtime dependencies"

BASE_MISSING_DEPENDENCIES="$(
    ldd "${INSTALL_LIB_DIR}/libonnxruntime.so" \
        | grep 'not found' \
        || true
)"

if [[ -n "${BASE_MISSING_DEPENDENCIES}" ]]; then
    echo "Missing dependencies for libonnxruntime.so:" >&2
    echo "${BASE_MISSING_DEPENDENCIES}" >&2
    exit 1
fi

echo "Base ONNX Runtime dependencies are available."

# ------------------------------------------------------------
# 13. Check CUDA provider dependencies
# ------------------------------------------------------------

log "Checking CUDA Execution Provider dependencies"

CUDA_PROVIDER="${INSTALL_LIB_DIR}/libonnxruntime_providers_cuda.so"

CUDA_MISSING_DEPENDENCIES="$(
    ldd "${CUDA_PROVIDER}" \
        | grep 'not found' \
        || true
)"

if [[ -n "${CUDA_MISSING_DEPENDENCIES}" ]]; then
    echo
    echo "ONNX Runtime was installed, but CUDA Provider dependencies are missing:"
    echo
    echo "${CUDA_MISSING_DEPENDENCIES}"
    echo
    echo "Install the matching CUDA 13 and cuDNN runtime libraries,"
    echo "then run:"
    echo
    echo "  sudo ldconfig"
    echo "  ldd ${CUDA_PROVIDER} | grep 'not found'"
    echo
    exit 2
fi

echo "All CUDA Execution Provider dependencies are available."

echo
echo "Resolved CUDA-related dependencies:"

ldd "${CUDA_PROVIDER}" \
    | grep -E \
        'libcuda|libcudart|libcublas|libcufft|libcurand|libcudnn|libnvrtc|libnvJitLink' \
    || warn "No CUDA-related libraries were displayed by ldd."

# ------------------------------------------------------------
# 14. Print final result
# ------------------------------------------------------------

log "Installation completed successfully"

cat <<EOF

ONNX Runtime version:
  ${ORT_VERSION}

Package:
  ${ORT_PACKAGE_NAME}

Headers:
  ${INSTALL_INCLUDE_DIR}

Libraries:
  ${INSTALL_LIB_DIR}

Your CGO configuration can use:

  #cgo linux CFLAGS: -I${INSTALL_INCLUDE_DIR}
  #cgo linux LDFLAGS: -L${INSTALL_LIB_DIR} -Wl,-rpath,${INSTALL_LIB_DIR} -lonnxruntime

Recommended verification commands:

  ldconfig -p | grep onnxruntime

  ldd ${INSTALL_LIB_DIR}/libonnxruntime.so \\
      | grep 'not found'

  ldd ${INSTALL_LIB_DIR}/libonnxruntime_providers_cuda.so \\
      | grep 'not found'

  CGO_ENABLED=1 go build ./...

Notes:

  1. An empty result from "grep not found" means no dependency is missing.
  2. CPU inference remains available with the GPU build.
  3. CUDA inference must be explicitly enabled when creating the ONNX Runtime session.
  4. Do not install a different ONNX Runtime version into /usr/include/onnxruntime,
     because that could mix headers and libraries from different versions.

EOF