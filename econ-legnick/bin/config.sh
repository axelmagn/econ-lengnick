#!/usr/bin/env bash
# Centralized project configuration

PROJECT_NAME="triangle"
CC="${CC:-clang}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"
DEPS_DIR="${REPO_ROOT}/deps"
SOKOL_DIR="${DEPS_DIR}/sokol"
NUKLEAR_DIR="${DEPS_DIR}/nuklear"
TOOLS_DIR="${DEPS_DIR}/tools"
SHADERS_DIR="${REPO_ROOT}/shaders"
SRC_DIR="${REPO_ROOT}/src"
WEB_DIR="${REPO_ROOT}/web"

# Pinned dependency commit hashes
SOKOL_COMMIT="master"
SOKOL_TOOLS_COMMIT="master"
NUKLEAR_COMMIT="master"

# Dependency download URLs
SOKOL_URL="https://github.com/floooh/sokol/archive/${SOKOL_COMMIT}.tar.gz"
SOKOL_SHDC_BASE_URL="https://raw.githubusercontent.com/floooh/sokol-tools-bin/${SOKOL_TOOLS_COMMIT}/bin"
NUKLEAR_URL="https://raw.githubusercontent.com/Immediate-Mode-UI/Nuklear/${NUKLEAR_COMMIT}/nuklear.h"

