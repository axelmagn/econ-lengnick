# Centralized project configuration for PowerShell

$PROJECT_NAME = "triangle"
$CC = if ($env:CC) { $env:CC } else { "clang" }

$SCRIPT_DIR = $PSScriptRoot
$REPO_ROOT = (Resolve-Path "$SCRIPT_DIR\..").Path
$BUILD_DIR = "$REPO_ROOT\build"
$DEPS_DIR = "$REPO_ROOT\deps"
$INCLUDE_DIR = "$DEPS_DIR\include"
$TOOLS_DIR = "$DEPS_DIR\tools"
$SHADERS_DIR = "$REPO_ROOT\shaders"
$SRC_DIR = "$REPO_ROOT\src"
$WEB_DIR = "$REPO_ROOT\web"
$DEPS_LOCK = "$REPO_ROOT\deps.lock"

# Default commit hashes
$SOKOL_COMMIT = "master"
$SOKOL_TOOLS_COMMIT = "master"
$NUKLEAR_COMMIT = "master"

# Load pinned commit hashes from deps.lock if present
if (Test-Path $DEPS_LOCK) {
    Get-Content $DEPS_LOCK | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#")) {
            $parts = $line.Split("=", 2)
            if ($parts.Count -eq 2) {
                $varName = $parts[0].Trim()
                $varValue = $parts[1].Trim().Trim('"').Trim("'")
                Set-Variable -Name $varName -Value $varValue -Scope Script -ErrorAction SilentlyContinue
            }
        }
    }
}

# Dependency download URLs
$SOKOL_URL = "https://github.com/floooh/sokol/archive/${SOKOL_COMMIT}.tar.gz"
$SOKOL_SHDC_BASE_URL = "https://raw.githubusercontent.com/floooh/sokol-tools-bin/${SOKOL_TOOLS_COMMIT}/bin"
$NUKLEAR_URL = "https://raw.githubusercontent.com/Immediate-Mode-UI/Nuklear/${NUKLEAR_COMMIT}/nuklear.h"
