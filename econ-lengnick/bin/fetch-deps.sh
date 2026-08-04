#!/usr/bin/env bash
set -exuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

PIN_VERSIONS=0

usage() {
    set +x
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --pin       Capture current commit hashes and write to deps.lock"
    echo "  --help, -h  Display this help message"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --pin)
            PIN_VERSIONS=1
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

resolve_commit() {
    local repo_url="$1"
    local ref="$2"

    if [[ "${ref}" =~ ^[0-9a-fA-F]{40}$ ]]; then
        echo "${ref}"
        return 0
    fi

    if command -v git &>/dev/null; then
        local remote_sha
        remote_sha="$(git ls-remote "${repo_url}" "${ref}" 2>/dev/null | awk '{print $1}' | head -n 1)"
        if [[ -z "${remote_sha}" ]]; then
            remote_sha="$(git ls-remote "${repo_url}" HEAD 2>/dev/null | awk '{print $1}' | head -n 1)"
        fi
        if [[ -n "${remote_sha}" ]]; then
            echo "${remote_sha}"
            return 0
        fi
    fi

    echo "${ref}"
}

if [[ "${PIN_VERSIONS}" -eq 1 ]]; then
    echo "==> Resolving repository commit hashes to write ${DEPS_LOCK}..."
    SOKOL_COMMIT="$(resolve_commit "https://github.com/floooh/sokol.git" "${SOKOL_COMMIT}")"
    SOKOL_TOOLS_COMMIT="$(resolve_commit "https://github.com/floooh/sokol-tools-bin.git" "${SOKOL_TOOLS_COMMIT}")"
    NUKLEAR_COMMIT="$(resolve_commit "https://github.com/Immediate-Mode-UI/Nuklear.git" "${NUKLEAR_COMMIT}")"

    cat <<EOF > "${DEPS_LOCK}"
SOKOL_COMMIT=${SOKOL_COMMIT}
SOKOL_TOOLS_COMMIT=${SOKOL_TOOLS_COMMIT}
NUKLEAR_COMMIT=${NUKLEAR_COMMIT}
EOF
    echo "==> Pinned versions written to deps.lock:"
    cat "${DEPS_LOCK}"

    SOKOL_URL="https://github.com/floooh/sokol/archive/${SOKOL_COMMIT}.tar.gz"
    SOKOL_SHDC_BASE_URL="https://raw.githubusercontent.com/floooh/sokol-tools-bin/${SOKOL_TOOLS_COMMIT}/bin"
    NUKLEAR_URL="https://raw.githubusercontent.com/Immediate-Mode-UI/Nuklear/${NUKLEAR_COMMIT}/nuklear.h"
fi

OS_NAME="$(uname -s)"
ARCH_NAME="$(uname -m)"

case "${OS_NAME}" in
    Linux*)
        SHDC_OS="linux"
        ;;
    Darwin*)
        if [[ "${ARCH_NAME}" == "arm64" ]]; then
            SHDC_OS="osx_arm64"
        else
            SHDC_OS="osx"
        fi
        ;;
    *)
        echo "Unsupported operating system: ${OS_NAME}" >&2
        exit 1
        ;;
esac

echo "==> Fetching dependencies for ${SHDC_OS}..."
mkdir -p "${INCLUDE_DIR}" "${TOOLS_DIR}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "==> Downloading Sokol headers (${SOKOL_COMMIT:0:7})..."
curl -sSL -o "${TMP_DIR}/sokol.tar.gz" "${SOKOL_URL}"
tar -xzf "${TMP_DIR}/sokol.tar.gz" -C "${TMP_DIR}"

EXTRACTED_SOKOL="$(find "${TMP_DIR}" -maxdepth 1 -type d -name "sokol-*" | head -n 1)"
if [[ -n "${EXTRACTED_SOKOL}" ]]; then
    cp -r "${EXTRACTED_SOKOL}"/*.h "${INCLUDE_DIR}/" 2>/dev/null || true
    if [[ -d "${EXTRACTED_SOKOL}/util" ]]; then
        mkdir -p "${INCLUDE_DIR}/util"
        cp -r "${EXTRACTED_SOKOL}/util"/*.h "${INCLUDE_DIR}/util/" 2>/dev/null || true
    fi
fi

echo "==> Downloading sokol-shdc compiler (${SHDC_OS} @ ${SOKOL_TOOLS_COMMIT:0:7})..."
curl -sSL -o "${TOOLS_DIR}/sokol-shdc" "${SOKOL_SHDC_BASE_URL}/${SHDC_OS}/sokol-shdc"
chmod +x "${TOOLS_DIR}/sokol-shdc"

echo "==> Downloading Nuklear header (${NUKLEAR_COMMIT:0:7})..."
curl -sSL -o "${INCLUDE_DIR}/nuklear.h" "${NUKLEAR_URL}"

trap - EXIT
rm -rf "${TMP_DIR}"
echo "==> Dependencies successfully fetched."
