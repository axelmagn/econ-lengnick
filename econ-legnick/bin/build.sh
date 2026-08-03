#!/usr/bin/env bash
set -exuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

BUILD_WEB=0
FETCH_DEPS=0
CLEAN_FIRST=0

usage() {
    set +x
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --web         Build WebAssembly target using Emscripten (emcc)"
    echo "  --fetch-deps  Fetch or update Sokol and Nuklear dependencies"
    echo "  --clean       Clean build artifacts before building"
    echo "  --help        Display this help message"
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --web)
                BUILD_WEB=1
                shift
                ;;
            --fetch-deps)
                FETCH_DEPS=1
                shift
                ;;
            --clean)
                CLEAN_FIRST=1
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
}

OS_NAME="$(uname -s)"
ARCH_NAME="$(uname -m)"

case "${OS_NAME}" in
    Linux*)
        SHDC_OS="linux"
        NATIVE_LIBS=("-lGL" "-lX11" "-lXi" "-lXcursor" "-lm" "-ldl")
        ;;
    Darwin*)
        if [[ "${ARCH_NAME}" == "arm64" ]]; then
            SHDC_OS="osx_arm64"
        else
            SHDC_OS="osx"
        fi
        NATIVE_LIBS=("-framework" "Metal" "-framework" "MetalKit" "-framework" "Cocoa" "-framework" "QuartzCore" "-lm")
        ;;
    *)
        echo "Unsupported operating system: ${OS_NAME}" >&2
        exit 1
        ;;
esac

clean() {
    echo "==> Cleaning build directory..."
    rm -rf "${BUILD_DIR}"
}

fetch_deps() {
    echo "==> Fetching dependencies for ${SHDC_OS}..."
    mkdir -p "${SOKOL_DIR}" "${NUKLEAR_DIR}" "${TOOLS_DIR}"

    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "${TMP_DIR}"' EXIT

    echo "==> Downloading Sokol headers (${SOKOL_COMMIT:0:7})..."
    curl -sSL -o "${TMP_DIR}/sokol.tar.gz" "${SOKOL_URL}"
    tar -xzf "${TMP_DIR}/sokol.tar.gz" -C "${TMP_DIR}"

    EXTRACTED_SOKOL="$(find "${TMP_DIR}" -maxdepth 1 -type d -name "sokol-*" | head -n 1)"
    if [[ -n "${EXTRACTED_SOKOL}" ]]; then
        cp -r "${EXTRACTED_SOKOL}"/*.h "${SOKOL_DIR}/" 2>/dev/null || true
        if [[ -d "${EXTRACTED_SOKOL}/util" ]]; then
            mkdir -p "${SOKOL_DIR}/util"
            cp -r "${EXTRACTED_SOKOL}/util"/*.h "${SOKOL_DIR}/util/" 2>/dev/null || true
        fi
    fi

    echo "==> Downloading sokol-shdc compiler (${SHDC_OS} @ ${SOKOL_TOOLS_COMMIT:0:7})..."
    curl -sSL -o "${TOOLS_DIR}/sokol-shdc" "${SOKOL_SHDC_BASE_URL}/${SHDC_OS}/sokol-shdc"
    chmod +x "${TOOLS_DIR}/sokol-shdc"

    echo "==> Downloading Nuklear header (${NUKLEAR_COMMIT:0:7})..."
    curl -sSL -o "${NUKLEAR_DIR}/nuklear.h" "${NUKLEAR_URL}"

    trap - EXIT
    rm -rf "${TMP_DIR}"
    echo "==> Dependencies successfully fetched."
}

compile_shaders() {
    echo "==> Compiling shaders in ${SHADERS_DIR}..."
    shopt -s nullglob
    local glsl_files=("${SHADERS_DIR}"/*.glsl)
    shopt -u nullglob

    if [[ ${#glsl_files[@]} -eq 0 ]]; then
        echo "    No GLSL shaders found in ${SHADERS_DIR}."
        return
    fi

    for shader_file in "${glsl_files[@]}"; do
        local output_header="${shader_file}.h"
        echo "    Compiling ${shader_file} -> ${output_header}..."
        "${TOOLS_DIR}/sokol-shdc" \
            -i "${shader_file}" \
            -o "${output_header}" \
            -l glsl410:hlsl5:glsl300es:metal_macos
    done
}

build_native() {
    echo "==> Compiling native executable (${CC}) for ${OS_NAME}..."
    mkdir -p "${BUILD_DIR}"
    "${CC}" -std=c99 -Wall -Wextra -O2 \
        -D_CRT_SECURE_NO_WARNINGS \
        -I"${SOKOL_DIR}" \
        -I"${NUKLEAR_DIR}" \
        -I"${REPO_ROOT}" \
        "${SRC_DIR}/main.c" \
        "${NATIVE_LIBS[@]}" \
        -o "${BUILD_DIR}/${PROJECT_NAME}"
    echo "==> Native build complete: build/${PROJECT_NAME}"
}

build_web() {
    echo "==> Compiling WebAssembly target (emcc)..."
    if ! command -v emcc &>/dev/null; then
        echo "Error: Emscripten compiler (emcc) is not in PATH." >&2
        exit 1
    fi
    mkdir -p "${BUILD_DIR}/web"
    emcc -std=c99 -Wall -Wextra -O2 \
        -s USE_WEBGL2=1 \
        -s WASM=1 \
        --shell-file "${WEB_DIR}/shell.html" \
        -I"${SOKOL_DIR}" \
        -I"${NUKLEAR_DIR}" \
        -I"${REPO_ROOT}" \
        "${SRC_DIR}/main.c" \
        -o "${BUILD_DIR}/web/index.html"
    echo "==> Web build complete: build/web/index.html"
}

main() {
    parse_args "$@"

    if [[ "${CLEAN_FIRST}" -eq 1 ]]; then
        clean
    fi

    if [[ "${FETCH_DEPS}" -eq 1 ]] || [[ ! -d "${SOKOL_DIR}" ]] || [[ ! -f "${TOOLS_DIR}/sokol-shdc" ]]; then
        fetch_deps
    fi

    compile_shaders

    if [[ "${BUILD_WEB}" -eq 1 ]]; then
        build_web
    else
        build_native
    fi
}

main "$@"
