[CmdletBinding()]
param (
    [switch]$Web,

    [Alias("fetch-deps")]
    [switch]$FetchDeps,

    [Alias("p")]
    [int]$Port = 8080,

    [Alias("h")]
    [switch]$Help
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\config.ps1"

if ($Help) {
    Write-Host "Usage: .\bin\run.ps1 [OPTIONS]"
    Write-Host "Options:"
    Write-Host "  -Web, --web         Build and serve WebAssembly target"
    Write-Host "  -FetchDeps, --fetch-deps  Force fetch dependencies before building"
    Write-Host "  -Port, --port PORT  HTTP server port for web target (default: 8080)"
    Write-Host "  -Help, --help       Display this help message"
    exit 0
}

$isLinux = if (Get-Variable -Name IsLinux -ErrorAction SilentlyContinue) { $IsLinux } else { $false }
$isMacOS = if (Get-Variable -Name IsMacOS -ErrorAction SilentlyContinue) { $IsMacOS } else { $false }

function Run-Native {
    $exeExt = if ($isLinux -or $isMacOS) { "" } else { ".exe" }
    $exePath = "$BUILD_DIR\${PROJECT_NAME}${exeExt}"
    Write-Host "==> Running native executable build/${PROJECT_NAME}${exeExt}..."
    & $exePath
}

function Run-Web {
    Write-Host "==> Serving build/web at http://localhost:${Port} ..."
    $pythonCmd = if (Get-Command python3 -ErrorAction SilentlyContinue) { "python3" } else { "python" }
    & $pythonCmd -m http.server $Port --directory "$BUILD_DIR\web"
}

$buildParams = @{}
if ($Web) { $buildParams["Web"] = $true }
if ($FetchDeps) { $buildParams["FetchDeps"] = $true }

& "$PSScriptRoot\build.ps1" @buildParams

if ($Web) {
    Run-Web
} else {
    Run-Native
}
