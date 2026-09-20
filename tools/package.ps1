[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $projectRoot 'ForeverRP'
$tocPath = Join-Path $sourceRoot 'ForeverRP.toc'
$distRoot = Join-Path $projectRoot 'dist'
$stagingRoot = Join-Path $projectRoot 'build\package'
$stagedAddon = Join-Path $stagingRoot 'ForeverRP'

function Assert-Exists([string]$Path, [string]$Description) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing required $Description`: $Path"
    }
}

Assert-Exists $sourceRoot 'addon folder'
Assert-Exists $tocPath 'primary TOC'
Assert-Exists (Join-Path $projectRoot 'README.md') 'README'
Assert-Exists (Join-Path $projectRoot 'LICENSE') 'license file'

$versionMatch = Select-String -LiteralPath $tocPath -Pattern '^## Version:\s*(\S+)\s*$' | Select-Object -First 1
if (-not $versionMatch) {
    throw 'ForeverRP.toc does not contain a valid ## Version field.'
}
$version = $versionMatch.Matches[0].Groups[1].Value
if ($version -notmatch '^\d+\.\d+\.\d+(?:-(?:alpha|beta)(?:\.\d+)?)?$') {
    throw "Unsupported version '$version'. Use 0.1.0-alpha, 0.1.0-beta, or 0.1.0 style versioning."
}

$tocEntries = Get-Content -LiteralPath $tocPath | Where-Object {
    $_ -and $_ -notmatch '^\s*#' -and $_ -notmatch '^\s*##' -and $_ -notmatch '^\s*$'
}
foreach ($entry in $tocEntries) {
    Assert-Exists (Join-Path $sourceRoot ($entry -replace '/', '\')) "TOC runtime file '$entry'"
}

$forbiddenNames = @('.git', '.github', '.vscode', '.idea', 'tests', 'tools', 'build', 'dist', 'docs', 'screenshots', 'SavedVariables', 'WTF', 'Cache')
$forbiddenExtensions = @('.ps1', '.bat', '.py', '.log', '.tmp', '.zip')
foreach ($item in Get-ChildItem -LiteralPath $sourceRoot -Recurse -Force) {
    if ($forbiddenNames -contains $item.Name) {
        throw "Forbidden development or local-data item found in addon source: $($item.FullName)"
    }
    if (-not $item.PSIsContainer -and $forbiddenExtensions -contains $item.Extension) {
        throw "Forbidden file type found in addon source: $($item.FullName)"
    }
}

$archivePath = Join-Path $distRoot "ForeverRP-v$version.zip"
try {
    if (Test-Path -LiteralPath $stagingRoot) {
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Path $stagedAddon -Force | Out-Null
    New-Item -ItemType Directory -Path $distRoot -Force | Out-Null

    Copy-Item -Path (Join-Path $sourceRoot '*') -Destination $stagedAddon -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $projectRoot 'README.md') -Destination $stagedAddon -Force
    Copy-Item -LiteralPath (Join-Path $projectRoot 'LICENSE') -Destination $stagedAddon -Force

    if (Test-Path -LiteralPath $archivePath) {
        Remove-Item -LiteralPath $archivePath -Force
    }
    Compress-Archive -LiteralPath $stagedAddon -DestinationPath $archivePath -CompressionLevel Optimal

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        $entryNames = @($archive.Entries | ForEach-Object { $_.FullName -replace '\\', '/' })
        if ($entryNames -notcontains 'ForeverRP/ForeverRP.toc') {
            throw 'Archive validation failed: ForeverRP/ForeverRP.toc is missing.'
        }
        $looseFiles = @($entryNames | Where-Object { $_ -and $_ -notmatch '^ForeverRP/' })
        if ($looseFiles.Count -gt 0) {
            throw "Archive validation failed: loose root entries found: $($looseFiles -join ', ')"
        }
        $forbiddenEntries = @($entryNames | Where-Object { $_ -match '(^|/)(\.git|WTF|Cache|SavedVariables)(/|$)' })
        if ($forbiddenEntries.Count -gt 0) {
            throw "Archive validation failed: forbidden entries found: $($forbiddenEntries -join ', ')"
        }
    }
    finally {
        $archive.Dispose()
    }

    Write-Host "Created validated package: $archivePath"
}
finally {
    if (Test-Path -LiteralPath $stagingRoot) {
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force
    }
}
