[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Join-Path $PSScriptRoot ".."),
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$tocPath = Join-Path $repositoryRoot "EbonTransmogCheck.toc"

if (-not (Test-Path -LiteralPath $tocPath -PathType Leaf)) {
    throw "Addon manifest not found: $tocPath"
}

$tocContent = Get-Content -LiteralPath $tocPath -Raw
$versionMatches = [regex]::Matches($tocContent, "(?m)^## Version:\s*(\S+)\s*$")
if ($versionMatches.Count -ne 1) {
    throw "The addon manifest must contain exactly one ## Version: value."
}

$version = $versionMatches[0].Groups[1].Value
if ($version -notmatch '^\d+(?:\.\d+){1,2}(?:[-+][0-9A-Za-z.-]+)?$') {
    throw "Invalid addon version '$version' in EbonTransmogCheck.toc."
}

$manifestEntries = @()
foreach ($line in Get-Content -LiteralPath $tocPath) {
    $entry = $line.Trim()
    if ($entry -and -not $entry.StartsWith("#")) {
        $manifestEntries += $entry
    }
}
if ($manifestEntries.Count -eq 0) {
    throw "The addon manifest does not list any addon files."
}

$packageFiles = @($tocPath)
foreach ($entry in $manifestEntries) {
    $relativePath = $entry.Replace("/", [System.IO.Path]::DirectorySeparatorChar).Replace("\", [System.IO.Path]::DirectorySeparatorChar)
    $sourcePath = Join-Path $repositoryRoot $relativePath
    if (Test-Path -LiteralPath $sourcePath -PathType Leaf) {
        $packageFiles += (Resolve-Path -LiteralPath $sourcePath).Path
    } elseif (Test-Path -LiteralPath $sourcePath -PathType Container) {
        $packageFiles += Get-ChildItem -LiteralPath $sourcePath -File -Recurse | ForEach-Object { $_.FullName }
    } else {
        throw "Manifest entry not found: $entry"
    }
}

if ($packageFiles.Count -lt 2) {
    throw "The addon package must contain the manifest and at least one addon file."
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $repositoryRoot "dist/EbonTransmogCheck.zip"
}
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

$archive = $null
try {
    if (Test-Path -LiteralPath $OutputPath) {
        Remove-Item -LiteralPath $OutputPath -Force
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::Open(
        $OutputPath,
        [System.IO.Compression.ZipArchiveMode]::Create
    )
    foreach ($sourceFile in $packageFiles) {
        $relativePath = $sourceFile.Substring($repositoryRoot.Length).TrimStart(
            [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
        ).Replace("\", "/")
        $entryName = "EbonTransmogCheck/$relativePath"
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive,
            $sourceFile,
            $entryName,
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
    $archive.Dispose()
    $archive = [System.IO.Compression.ZipFile]::OpenRead($OutputPath)

    $requiredEntries = @()
    foreach ($sourceFile in $packageFiles) {
        $relativePath = $sourceFile.Substring($repositoryRoot.Length).TrimStart(
            [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
        ).Replace("\", "/")
        $requiredEntries += "EbonTransmogCheck/$relativePath"
    }
    foreach ($requiredEntry in $requiredEntries) {
        if (-not ($archive.Entries | Where-Object { $_.FullName -eq $requiredEntry })) {
            throw "Packaged archive is missing $requiredEntry."
        }
    }
} catch {
    if ($archive) { $archive.Dispose() }
    Remove-Item -LiteralPath $OutputPath -Force -ErrorAction SilentlyContinue
    throw
} finally {
    if ($archive) { $archive.Dispose() }
}

if ($env:GITHUB_OUTPUT) {
    Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "version=$version"
}
Write-Host "Packaged EbonTransmogCheck v$version to $OutputPath"