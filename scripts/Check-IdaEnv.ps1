param(
    [string]$IdaExe = "C:\Program Files\IDA Professional 9.1\ida.exe",
    [string]$IdaSdk = $env:IDASDK,
    [switch]$RequireBuildReady,
    [switch]$Json
)

$idaInstallDir = $null
if ($IdaExe -and (Test-Path $IdaExe)) {
    $idaInstallDir = Split-Path -Parent $IdaExe
}

$status = [ordered]@{
    IdaExe = $IdaExe
    IdaInstallDir = $idaInstallDir
    IdaSdk = $IdaSdk
    HasIdaExe = [bool]($IdaExe -and (Test-Path $IdaExe))
    HasInstalledLoader = [bool]($idaInstallDir -and (Test-Path (Join-Path $idaInstallDir 'loaders\idaxex.dll')))
    HasSdkRoot = [bool]($IdaSdk -and (Test-Path $IdaSdk))
    HasSdkHeaders = $false
    HasPeHeader = $false
    HasIdaLib = $false
    HasIdaCMake = $false
    CanBuildIdaxex = $false
}

if ($status.HasSdkRoot) {
    $status.HasSdkHeaders = Test-Path (Join-Path $IdaSdk 'include\pro.h')
    $status.HasPeHeader = Test-Path (Join-Path $IdaSdk 'ldr\pe\pe.h')
    $status.HasIdaLib = Test-Path (Join-Path $IdaSdk 'lib\x64_win_vc_64\ida.lib')
    $status.HasIdaCMake = Test-Path (Join-Path $IdaSdk 'ida-cmake\common.cmake')
    $status.CanBuildIdaxex = $status.HasSdkHeaders -and $status.HasPeHeader -and $status.HasIdaLib
}

if ($Json) {
    $status | ConvertTo-Json -Depth 3
} else {
    $status.GetEnumerator() | ForEach-Object {
        "{0}: {1}" -f $_.Key, $_.Value
    }

    if (-not $status.HasSdkRoot) {
        Write-Host ""
        Write-Host "Set IDASDK to the root of the full IDA C++ SDK before building." -ForegroundColor Yellow
    } elseif (-not $status.CanBuildIdaxex) {
        Write-Host ""
        Write-Host "IDASDK is set, but the SDK tree is incomplete for loader builds." -ForegroundColor Yellow
    }
}

if ($RequireBuildReady -and -not $status.CanBuildIdaxex) {
    exit 1
}
