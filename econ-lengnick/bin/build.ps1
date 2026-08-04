[CmdletBinding()]
param (
    [switch]$Web,

    [switch]$Clean,

    [Alias("h")]
    [switch]$Help
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\config.ps1"

if ($Help) {
    Write-Host "Usage: .\bin\build.ps1 [OPTIONS]"
    Write-Host "Options:"
    Write-Host "  -Web, --web         Build WebAssembly target using Emscripten (emcc)"
    Write-Host "  -Clean, --clean     Clean build artifacts before building"
    Write-Host "  -Help, --help       Display this help message"
    exit 0
}

$isLinux = if (Get-Variable -Name IsLinux -ErrorAction SilentlyContinue) { $IsLinux } else { $false }
$isMacOS = if (Get-Variable -Name IsMacOS -ErrorAction SilentlyContinue) { $IsMacOS } else { $false }

if ($isLinux) {
    $shdcOs = "linux"
    $shdcExe = "$TOOLS_DIR\sokol-shdc"
    $nativeLibs = @("-lGL", "-lX11", "-lXi", "-lXcursor", "-lm", "-ldl")
} elseif ($isMacOS) {
    $arch = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture
    if ($arch -eq [System.Runtime.InteropServices.Architecture]::Arm64) {
        $shdcOs = "osx_arm64"
    } else {
        $shdcOs = "osx"
    }
    $shdcExe = "$TOOLS_DIR\sokol-shdc"
    $nativeLibs = @("-framework", "Metal", "-framework", "MetalKit", "-framework", "Cocoa", "-framework", "QuartzCore", "-lm")
} else {
    $shdcOs = "win32"
    $shdcExe = "$TOOLS_DIR\sokol-shdc.exe"
    $nativeLibs = @("-lkernel32", "-luser32", "-lgdi32", "-ld3d11", "-ldxgi", "-lole32")
}

function Clean-BuildDir {
    Write-Host "==> Cleaning build directory..."
    if (Test-Path $BUILD_DIR) {
        Remove-Item -Recurse -Force $BUILD_DIR
    }
}

function Compile-Shaders {
    Write-Host "==> Compiling shaders in $SHADERS_DIR..."
    $glslFiles = Get-ChildItem -Path $SHADERS_DIR -Filter "*.glsl" -File -ErrorAction SilentlyContinue
    if ((-not $glslFiles) -or ($glslFiles.Count -eq 0)) {
        Write-Host "    No GLSL shaders found in $SHADERS_DIR."
        return
    }

    foreach ($shaderFile in $glslFiles) {
        $outputHeader = "$($shaderFile.FullName).h"
        Write-Host "    Compiling $($shaderFile.FullName) -> $outputHeader..."
        & $shdcExe -i $shaderFile.FullName -o $outputHeader -l glsl410:hlsl5:glsl300es:metal_macos
        if ($LASTEXITCODE -ne 0) {
            throw "Shader compilation failed for $($shaderFile.FullName)"
        }
    }
}

function Build-Native {
    Write-Host "==> Compiling native executable ($CC)..."
    New-Item -ItemType Directory -Force -Path $BUILD_DIR | Out-Null

    $exeExt = if ($shdcOs -eq "win32") { ".exe" } else { "" }
    $outFile = "$BUILD_DIR\${PROJECT_NAME}${exeExt}"
    $srcFile = "$SRC_DIR\main.c"

    $argsList = @(
        "-std=c99", "-Wall", "-Wextra", "-O2",
        "-D_CRT_SECURE_NO_WARNINGS",
        "-I$INCLUDE_DIR",
        "-I$REPO_ROOT",
        $srcFile
    ) + $nativeLibs + @("-o", $outFile)

    & $CC @argsList
    if ($LASTEXITCODE -ne 0) {
        throw "Native compilation failed with exit code $LASTEXITCODE"
    }

    Write-Host "==> Native build complete: build/${PROJECT_NAME}${exeExt}"
}

function Build-Web {
    Write-Host "==> Compiling WebAssembly target (emcc)..."
    $emccCmd = Get-Command emcc -ErrorAction SilentlyContinue
    if (-not $emccCmd) {
        Write-Error "Error: Emscripten compiler (emcc) is not in PATH."
        exit 1
    }

    $webBuildDir = "$BUILD_DIR\web"
    New-Item -ItemType Directory -Force -Path $webBuildDir | Out-Null

    $argsList = @(
        "-std=c99", "-Wall", "-Wextra", "-O2",
        "-s", "USE_WEBGL2=1",
        "-s", "WASM=1",
        "--shell-file", "$WEB_DIR\shell.html",
        "-I$INCLUDE_DIR",
        "-I$REPO_ROOT",
        "$SRC_DIR\main.c",
        "-o", "$webBuildDir\index.html"
    )

    & emcc @argsList
    if ($LASTEXITCODE -ne 0) {
        throw "Web build failed with exit code $LASTEXITCODE"
    }

    Write-Host "==> Web build complete: build/web/index.html"
}

if ($Clean) {
    Clean-BuildDir
}

Compile-Shaders

if ($Web) {
    Build-Web
} else {
    Build-Native
}
