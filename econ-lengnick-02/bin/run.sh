#!/usr/bin/env bash
set -exuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

BUILD_WEB=0
PORT=8080

usage() {
    set +x
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --web         Build and serve WebAssembly target"
    echo "  --port PORT   HTTP server port for web target (default: 8080)"
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
            --port)
                PORT="$2"
                shift 2
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

run_native() {
    echo "==> Running native executable build/${PROJECT_NAME}..."
    "${BUILD_DIR}/${PROJECT_NAME}"
}

run_web() {
    echo "==> Serving build/web at http://localhost:${PORT} ..."
    python3 -m http.server "${PORT}" --directory "${BUILD_DIR}/web"
}

main() {
    parse_args "$@"

    BUILD_ARGS=()
    if [[ "${BUILD_WEB}" -eq 1 ]]; then
        BUILD_ARGS+=("--web")
    fi

    "${SCRIPT_DIR}/build.sh" "${BUILD_ARGS[@]+"${BUILD_ARGS[@]}"}"

    if [[ "${BUILD_WEB}" -eq 1 ]]; then
        run_web
    else
        run_native
    fi
}

main "$@"
