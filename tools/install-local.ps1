[CmdletBinding()]
param(
    [string]$AddOnsPath = 'E:\Games\World of Warcraft\_classic_beta_\Interface\AddOns'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$packageScript = Join-Path $PSScriptRoot 'package.ps1'
$tocPath = Join-Path $projectRoot 'ForeverRP\ForeverRP.toc'

if (-not (Test-Path -LiteralPath $AddOnsPath -PathType Container)) {
    throw "AddOns destination does not exist: $AddOnsPath"
}
if ((Split-Path -Leaf $AddOnsPath) -ne 'AddOns') {
    throw "Refusing destination that is not named AddOns: $AddOnsPath"
}

$destination = Join-Path $AddOnsPath 'ForeverRP'
if ((Split-Path -Leaf $destination) -ne 'ForeverRP' -or $destination -eq $AddOnsPath) {
    throw "Refusing unsafe addon destination: $destination"
}

& $packageScript

$versionMatch = Select-String -LiteralPath $tocPath -Pattern '^## Version:\s*(\S+)\s*$' | Select-Object -First 1
$version = $versionMatch.Matches[0].Groups[1].Value
$archivePath = Join-Path $projectRoot "dist\ForeverRP-v$version.zip"
$extractRoot = Join-Path $projectRoot 'build\install'
$extractedAddon = Join-Path $extractRoot 'ForeverRP'

try {
    if (Test-Path -LiteralPath $extractRoot) {
        Remove-Item -LiteralPath $extractRoot -Recurse -Force
    }
    Expand-Archive -LiteralPath $archivePath -DestinationPath $extractRoot -Force
    if (-not (Test-Path -LiteralPath (Join-Path $extractedAddon 'ForeverRP.toc'))) {
        throw 'Validated package did not extract to the expected ForeverRP folder.'
    }

    Write-Host "Installing ForeverRP to: $destination"
    if (Test-Path -LiteralPath $destination) {
        Remove-Item -LiteralPath $destination -Recurse -Force
    }
    Copy-Item -LiteralPath $extractedAddon -Destination $destination -Recurse -Force
    Write-Host "Local install complete: $(Join-Path $destination 'ForeverRP.toc')"
}
finally {
    if (Test-Path -LiteralPath $extractRoot) {
        Remove-Item -LiteralPath $extractRoot -Recurse -Force
    }
}
