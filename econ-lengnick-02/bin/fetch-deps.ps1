[CmdletBinding()]
param (
    [switch]$Pin,

    [Alias("h")]
    [switch]$Help
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\config.ps1"

if ($Help) {
    Write-Host "Usage: .\bin\fetch-deps.ps1 [OPTIONS]"
    Write-Host "Options:"
    Write-Host "  -Pin, --pin         Capture current commit hashes and write to deps.lock"
    Write-Host "  -Help, --help       Display this help message"
    exit 0
}

function Resolve-Commit {
    param (
        [string]$repoUrl,
        [string]$ref
    )

    if ($ref -match '^[0-9a-fA-F]{40}$') {
        return $ref
    }

    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        $lsRemote = & git ls-remote $repoUrl $ref 2>$null
        if ($lsRemote) {
            $firstLine = ($lsRemote -split '[\r\n]+')[0]
            $sha = ($firstLine -split '\s+')[0]
            if ($sha -and $sha.Length -eq 40) { return $sha }
        }
        $lsRemoteHead = & git ls-remote $repoUrl HEAD 2>$null
        if ($lsRemoteHead) {
            $firstLine = ($lsRemoteHead -split '[\r\n]+')[0]
            $sha = ($firstLine -split '\s+')[0]
            if ($sha -and $sha.Length -eq 40) { return $sha }
        }
    }

    return $ref
}

if ($Pin) {
    Write-Host "==> Resolving repository commit hashes to write $DEPS_LOCK..."
    $SOKOL_COMMIT = Resolve-Commit "https://github.com/floooh/sokol.git" $SOKOL_COMMIT
    $SOKOL_TOOLS_COMMIT = Resolve-Commit "https://github.com/floooh/sokol-tools-bin.git" $SOKOL_TOOLS_COMMIT
    $NUKLEAR_COMMIT = Resolve-Commit "https://github.com/Immediate-Mode-UI/Nuklear.git" $NUKLEAR_COMMIT

    $lockContent = "SOKOL_COMMIT=$SOKOL_COMMIT`nSOKOL_TOOLS_COMMIT=$SOKOL_TOOLS_COMMIT`nNUKLEAR_COMMIT=$NUKLEAR_COMMIT"
    Set-Content -Path $DEPS_LOCK -Value $lockContent -Encoding UTF8
    Write-Host "==> Pinned versions written to deps.lock:"
    Get-Content $DEPS_LOCK

    $SOKOL_URL = "https://github.com/floooh/sokol/archive/${SOKOL_COMMIT}.tar.gz"
    $SOKOL_SHDC_BASE_URL = "https://raw.githubusercontent.com/floooh/sokol-tools-bin/${SOKOL_TOOLS_COMMIT}/bin"
    $NUKLEAR_URL = "https://raw.githubusercontent.com/Immediate-Mode-UI/Nuklear/${NUKLEAR_COMMIT}/nuklear.h"
}

$isLinux = if (Get-Variable -Name IsLinux -ErrorAction SilentlyContinue) { $IsLinux } else { $false }
$isMacOS = if (Get-Variable -Name IsMacOS -ErrorAction SilentlyContinue) { $IsMacOS } else { $false }

if ($isLinux) {
    $shdcOs = "linux"
    $shdcExe = "$TOOLS_DIR\sokol-shdc"
} elseif ($isMacOS) {
    $arch = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture
    if ($arch -eq [System.Runtime.InteropServices.Architecture]::Arm64) {
        $shdcOs = "osx_arm64"
    } else {
        $shdcOs = "osx"
    }
    $shdcExe = "$TOOLS_DIR\sokol-shdc"
} else {
    $shdcOs = "win32"
    $shdcExe = "$TOOLS_DIR\sokol-shdc.exe"
}

Write-Host "==> Fetching dependencies for $shdcOs..."
New-Item -ItemType Directory -Force -Path $INCLUDE_DIR, $TOOLS_DIR | Out-Null

$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

try {
    $sokolCommitShort = $SOKOL_COMMIT.Substring(0, [Math]::Min(7, $SOKOL_COMMIT.Length))
    Write-Host "==> Downloading Sokol headers ($sokolCommitShort)..."
    $sokolTar = Join-Path $tmpDir "sokol.tar.gz"
    curl.exe -sSL -o $sokolTar $SOKOL_URL
    tar.exe -xzf $sokolTar -C $tmpDir

    $extractedSokol = Get-ChildItem -Path $tmpDir -Directory -Filter "sokol-*" | Select-Object -First 1
    if ($extractedSokol) {
        Get-ChildItem -Path $extractedSokol.FullName -Filter "*.h" | Copy-Item -Destination $INCLUDE_DIR -Force
        $utilDir = Join-Path $extractedSokol.FullName "util"
        if (Test-Path $utilDir) {
            $targetUtilDir = Join-Path $INCLUDE_DIR "util"
            New-Item -ItemType Directory -Force -Path $targetUtilDir | Out-Null
            Get-ChildItem -Path $utilDir -Filter "*.h" | Copy-Item -Destination $targetUtilDir -Force
        }
    }

    $shdcCommitShort = $SOKOL_TOOLS_COMMIT.Substring(0, [Math]::Min(7, $SOKOL_TOOLS_COMMIT.Length))
    Write-Host "==> Downloading sokol-shdc compiler ($shdcOs @ $shdcCommitShort)..."
    $shdcRemoteName = if ($shdcOs -eq "win32") { "sokol-shdc.exe" } else { "sokol-shdc" }
    $shdcUrl = "${SOKOL_SHDC_BASE_URL}/${shdcOs}/${shdcRemoteName}"
    curl.exe -sSL -o $shdcExe $shdcUrl

    $nuklearCommitShort = $NUKLEAR_COMMIT.Substring(0, [Math]::Min(7, $NUKLEAR_COMMIT.Length))
    Write-Host "==> Downloading Nuklear header ($nuklearCommitShort)..."
    $nuklearFile = Join-Path $INCLUDE_DIR "nuklear.h"
    curl.exe -sSL -o $nuklearFile $NUKLEAR_URL

    Write-Host "==> Dependencies successfully fetched."
}
finally {
    if (Test-Path $tmpDir) {
        Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
    }
}
