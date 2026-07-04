param(
    [string]$IdaExe = $env:IDAEXE,
    [string]$IdaSdk = $env:IDASDK,
    [string]$ExpectedIdaVersion = "",
    [int]$ExpectedSdkVersion = 0,
    [string]$ExpectedSdkBranch = "",
    [string]$ExpectedSdkCommit = "",
    [switch]$RequireOfficialSdk,
    [switch]$AllowPublicSdkMacroLag,
    [switch]$RequireBuildReady,
    [switch]$Json
)

function Resolve-IdaSdkDir {
    param([string]$Path)

    if (-not $Path -or -not (Test-Path $Path)) {
        return $null
    }

    $resolved = (Resolve-Path $Path).Path
    if (Test-Path (Join-Path $resolved 'include\pro.h')) {
        return $resolved
    }

    $srcPath = Join-Path $resolved 'src'
    if (Test-Path (Join-Path $srcPath 'include\pro.h')) {
        return $srcPath
    }

    return $resolved
}

function Get-IdaSdkVersion {
    param([string]$SdkDir)

    $proPath = Join-Path $SdkDir 'include\pro.h'
    if (-not (Test-Path $proPath)) {
        return $null
    }

    $match = Select-String -LiteralPath $proPath -Pattern '^\s*#define\s+IDA_SDK_VERSION\s+(\d+)' | Select-Object -First 1
    if ($match -and $match.Matches.Count -gt 0) {
        return [int]$match.Matches[0].Groups[1].Value
    }

    return $null
}

function Get-IdaInstallVersion {
    param([string]$InstallDir)

    if (-not $InstallDir) {
        return $null
    }

    $releaseNotes = Join-Path $InstallDir 'release-notes.md'
    if (Test-Path $releaseNotes) {
        $heading = Select-String -LiteralPath $releaseNotes -Pattern '^#\s+IDA\s+([0-9]+(?:\.[0-9]+)+)' | Select-Object -First 1
        if ($heading -and $heading.Matches.Count -gt 0) {
            return $heading.Matches[0].Groups[1].Value
        }
    }

    $folderMatch = [regex]::Match($InstallDir, 'IDA(?:\s+Professional)?\s+([0-9]+(?:\.[0-9]+)+)', 'IgnoreCase')
    if ($folderMatch.Success) {
        return $folderMatch.Groups[1].Value
    }

    return $null
}

function Invoke-Git {
    param(
        [string]$WorkingDir,
        [string[]]$Arguments
    )

    if (-not $WorkingDir -or -not (Test-Path $WorkingDir)) {
        return $null
    }

    $output = & git -C $WorkingDir @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    return ($output -join "`n").Trim()
}

function Get-GitInfo {
    param([string]$Path)

    $root = Invoke-Git $Path @('rev-parse', '--show-toplevel')
    if (-not $root) {
        return $null
    }

    $branch = Invoke-Git $root @('rev-parse', '--abbrev-ref', 'HEAD')
    $head = Invoke-Git $root @('rev-parse', 'HEAD')
    $upstream = Invoke-Git $root @('rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}')
    $remoteName = $null
    $remoteUrl = $null
    if ($upstream -and $upstream -match '^([^/]+)/') {
        $remoteName = $Matches[1]
        $remoteUrl = Invoke-Git $root @('remote', 'get-url', $remoteName)
    }

    return [ordered]@{
        Root = $root
        Branch = $branch
        Head = $head
        Upstream = $upstream
        RemoteName = $remoteName
        RemoteUrl = $remoteUrl
    }
}

$idaInstallDir = $null
if ($IdaExe -and (Test-Path $IdaExe)) {
    $idaInstallDir = Split-Path -Parent $IdaExe
}
$idaVersion = Get-IdaInstallVersion $idaInstallDir

$resolvedSdk = Resolve-IdaSdkDir $IdaSdk
$sdkVersion = $null
if ($resolvedSdk) {
    $sdkVersion = Get-IdaSdkVersion $resolvedSdk
}
$sdkGitInfo = $null
if ($resolvedSdk) {
    $sdkGitInfo = Get-GitInfo $resolvedSdk
}

$idaLibCandidates = @()
if ($resolvedSdk) {
    $idaLibCandidates = @(
        (Join-Path $resolvedSdk 'lib\x64_win_vc_64\ida.lib'),
        (Join-Path $resolvedSdk 'lib\x64_win_64\ida.lib')
    )
}
$idaLibPath = $idaLibCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
$versionMatches = $true
if ($ExpectedSdkVersion -gt 0) {
    $versionMatches = ($sdkVersion -eq $ExpectedSdkVersion)
}
$idaVersionMatches = $true
if ($ExpectedIdaVersion) {
    $idaVersionMatches = ($idaVersion -like "$ExpectedIdaVersion*")
}
$sdkBranchMatches = $true
if ($ExpectedSdkBranch) {
    $sdkBranchMatches = $sdkGitInfo -and (
        $sdkGitInfo.Branch -eq $ExpectedSdkBranch -or
        $sdkGitInfo.Upstream -eq "origin/$ExpectedSdkBranch" -or
        $sdkGitInfo.Upstream -like "*/$ExpectedSdkBranch"
    )
}
$sdkCommitMatches = $true
if ($ExpectedSdkCommit) {
    $sdkCommitMatches = $sdkGitInfo -and $sdkGitInfo.Head -and $sdkGitInfo.Head.StartsWith($ExpectedSdkCommit, [StringComparison]::OrdinalIgnoreCase)
}
$officialSdk = $false
if ($sdkGitInfo -and $sdkGitInfo.RemoteUrl) {
    $officialSdk = $sdkGitInfo.RemoteUrl -match 'github\.com[:/]+HexRaysSA/ida-sdk(\.git)?$'
}
$officialSdkMatches = (-not $RequireOfficialSdk) -or $officialSdk
$isOfficialPublic94Sdk = $officialSdk -and $sdkGitInfo -and (
    $sdkGitInfo.Branch -eq 'releases/9.4.0' -or
    $sdkGitInfo.Upstream -like '*/releases/9.4.0' -or
    $ExpectedSdkBranch -eq 'releases/9.4.0' -or
    $sdkGitInfo.Branch -like 'v9.4*' -or
    $sdkGitInfo.Upstream -like '*/v9.4*'
)
$sdkMacroLagAccepted = $false
if ($ExpectedSdkVersion -eq 940 -and $sdkVersion -eq 930 -and $AllowPublicSdkMacroLag -and $isOfficialPublic94Sdk) {
    $sdkMacroLagAccepted = $true
}
$sdkVersionGatePasses = $versionMatches -or $sdkMacroLagAccepted
$sdkGateClassification = 'no-sdk-version-required'
if ($ExpectedSdkVersion -gt 0) {
    if ($versionMatches) {
        $sdkGateClassification = 'exact-sdk-version-match'
    } elseif ($sdkMacroLagAccepted) {
        $sdkGateClassification = 'official-public-9.4-sdk-macro-lags'
    } else {
        $sdkGateClassification = 'sdk-version-mismatch'
    }
}

$status = [ordered]@{
    IdaExe = $IdaExe
    IdaInstallDir = $idaInstallDir
    IdaVersion = $idaVersion
    ExpectedIdaVersion = $(if ($ExpectedIdaVersion) { $ExpectedIdaVersion } else { $null })
    IdaVersionMatchesExpected = $idaVersionMatches
    IdaSdk = $IdaSdk
    ResolvedIdaSdk = $resolvedSdk
    SdkVersion = $sdkVersion
    ExpectedSdkVersion = $(if ($ExpectedSdkVersion -gt 0) { $ExpectedSdkVersion } else { $null })
    SdkVersionMatchesExpected = $versionMatches
    AllowPublicSdkMacroLag = [bool]$AllowPublicSdkMacroLag
    IsOfficialPublic94Sdk = $isOfficialPublic94Sdk
    SdkMacroLagAccepted = $sdkMacroLagAccepted
    SdkVersionGatePasses = $sdkVersionGatePasses
    SdkGateClassification = $sdkGateClassification
    SdkGitRoot = $(if ($sdkGitInfo) { $sdkGitInfo.Root } else { $null })
    SdkGitBranch = $(if ($sdkGitInfo) { $sdkGitInfo.Branch } else { $null })
    ExpectedSdkBranch = $(if ($ExpectedSdkBranch) { $ExpectedSdkBranch } else { $null })
    SdkBranchMatchesExpected = $sdkBranchMatches
    SdkGitHead = $(if ($sdkGitInfo) { $sdkGitInfo.Head } else { $null })
    ExpectedSdkCommit = $(if ($ExpectedSdkCommit) { $ExpectedSdkCommit } else { $null })
    SdkCommitMatchesExpected = $sdkCommitMatches
    SdkGitUpstream = $(if ($sdkGitInfo) { $sdkGitInfo.Upstream } else { $null })
    SdkGitRemoteUrl = $(if ($sdkGitInfo) { $sdkGitInfo.RemoteUrl } else { $null })
    RequireOfficialSdk = [bool]$RequireOfficialSdk
    IsOfficialHexRaysSdk = $officialSdk
    OfficialSdkMatchesExpected = $officialSdkMatches
    HasIdaExe = [bool]($IdaExe -and (Test-Path $IdaExe))
    HasInstalledLoader = [bool]($idaInstallDir -and (Test-Path (Join-Path $idaInstallDir 'loaders\idaxex.dll')))
    HasSdkRoot = [bool]($IdaSdk -and (Test-Path $IdaSdk))
    HasSdkHeaders = $false
    HasPeHeader = $false
    HasIdaLib = $false
    IdaLibPath = $idaLibPath
    HasCMakeBootstrap = $false
    HasCMakePackage = $false
    HasIdaCMake = $false
    CanBuildIdaxex = $false
    CanConfigureCMake = $false
}

if ($resolvedSdk) {
    $status.HasSdkHeaders = Test-Path (Join-Path $resolvedSdk 'include\pro.h')
    $status.HasPeHeader = Test-Path (Join-Path $resolvedSdk 'ldr\pe\pe.h')
    $status.HasIdaLib = [bool]$idaLibPath
    $status.HasCMakeBootstrap = (Test-Path (Join-Path $resolvedSdk 'cmake\bootstrap.cmake')) -or (Test-Path (Join-Path $resolvedSdk 'ida-cmake\bootstrap.cmake'))
    $status.HasCMakePackage = Test-Path (Join-Path $resolvedSdk 'cmake\idasdkConfig.cmake')
    $status.HasIdaCMake = $status.HasCMakeBootstrap -or $status.HasCMakePackage -or (Test-Path (Join-Path $resolvedSdk 'ida-cmake\common.cmake'))
    $status.CanBuildIdaxex = $status.HasSdkHeaders -and $status.HasPeHeader -and $status.HasIdaLib -and $sdkVersionGatePasses -and $idaVersionMatches -and $sdkBranchMatches -and $sdkCommitMatches -and $officialSdkMatches
    $status.CanConfigureCMake = $status.CanBuildIdaxex -and $status.HasIdaCMake
}

if ($Json) {
    $status | ConvertTo-Json -Depth 3
} else {
    $status.GetEnumerator() | ForEach-Object {
        "{0}: {1}" -f $_.Key, $_.Value
    }

    if (-not $status.HasSdkRoot) {
        Write-Host ""
        Write-Host "Set IDASDK to the IDA SDK checkout root or src directory before building." -ForegroundColor Yellow
    } elseif (-not $status.CanBuildIdaxex) {
        Write-Host ""
        Write-Host "IDASDK is set, but the SDK tree is incomplete or not the expected version for loader builds." -ForegroundColor Yellow
    } elseif ($status.SdkMacroLagAccepted) {
        Write-Host ""
        Write-Host "Official public IDA 9.4 SDK branch still reports IDA_SDK_VERSION 930; accepted because -AllowPublicSdkMacroLag was specified." -ForegroundColor Yellow
    }
}

if ($RequireBuildReady -and -not $status.CanBuildIdaxex) {
    exit 1
}
