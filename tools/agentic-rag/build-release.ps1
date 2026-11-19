#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[a-zA-Z0-9]+([.-][a-zA-Z0-9]+)*)?$')]
    [ValidateLength(5, 64)]
    [string]$Version,
    [switch]$Plan
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$projectBranch = & git -C $repo branch --show-current
if ($LASTEXITCODE -ne 0 -or $projectBranch -cne 'agentic-rag') {
    throw 'Build candidates from the agentic-rag branch.'
}
$commit = & git -C $repo rev-parse --verify HEAD
if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$') {
    throw 'Cannot identify the source commit.'
}

$shortCommit = $commit.Substring(0, 12)
$destination = Join-Path $repo "target/agentic-rag/$Version-$shortCommit"
$architectures = @('amd64', 'arm64')
$dependencyImage = 'infiniflow/ragflow_deps:latest'

if ($Plan) {
    Write-Host "Source: $projectBranch at $commit"
    Write-Host "Output: $destination"
    foreach ($architecture in $architectures) {
        Write-Host "linux/$architecture -> linux-$architecture/ragflow-agentic-rag.tar (ragflow-agentic-rag:$Version-$shortCommit-$architecture)"
    }
    return
}

$changes = & git -C $repo status --porcelain --untracked-files=normal
if ($LASTEXITCODE -ne 0 -or $changes) { throw 'Commit all candidate changes before building.' }
if (Test-Path -LiteralPath $destination) { throw "Candidate directory already exists: $destination" }
& (Join-Path $PSScriptRoot 'check.ps1')
$null = Get-Command docker,tar -CommandType Application

function Invoke-Docker([string[]]$Arguments) {
    & docker @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Docker command failed: $($Arguments -join ' ')" }
}

$dependencyContext = Join-Path $repo 'ragflow_deps'
$dependencyDockerfile = Join-Path $dependencyContext 'Dockerfile'
$images = @()
foreach ($architecture in $architectures) {
    $platform = "linux/$architecture"
    $image = "ragflow-agentic-rag:$Version-$shortCommit-$architecture"
    $artifact = "linux-$architecture/ragflow-agentic-rag.tar"
    $archive = Join-Path $destination $artifact

    Invoke-Docker @('buildx','build','--platform',$platform,'--file',$dependencyDockerfile,'--tag',$dependencyImage,'--load',$dependencyContext)
    $actualDependencyPlatform = Invoke-Docker @('image','inspect','--format','{{.Os}}/{{.Architecture}}',$dependencyImage)
    if ($actualDependencyPlatform -ne $platform) { throw "Dependency image platform is $actualDependencyPlatform, expected $platform." }

    Invoke-Docker @('buildx','build','--platform',$platform,'--label',"org.opencontainers.image.revision=$commit",'--label',"org.opencontainers.image.version=$Version",'--tag',$image,'--load',$repo)
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $archive)
    Invoke-Docker @('image','save','--platform',$platform,'--output',$archive,$image)

    $manifestJson = & tar -xOf $archive 'manifest.json'
    if ($LASTEXITCODE -ne 0) { throw "Docker archive manifest is unreadable: $archive" }
    $manifest = @(($manifestJson -join "`n") | ConvertFrom-Json)
    if ($manifest.Count -ne 1 -or $manifest[0].RepoTags -notcontains $image -or -not $manifest[0].Config) {
        throw "Expected one tagged application image in $archive."
    }
    $configJson = & tar -xOf $archive $manifest[0].Config
    if ($LASTEXITCODE -ne 0) { throw "Docker archive image config is unreadable: $archive" }
    $config = ($configJson -join "`n") | ConvertFrom-Json
    if ("$($config.os)/$($config.architecture)" -ne $platform -or
        $config.config.Labels.'org.opencontainers.image.revision' -ne $commit -or
        $config.config.Labels.'org.opencontainers.image.version' -ne $Version) {
        throw "Archive platform or source labels do not match in $archive."
    }

    $images += [ordered]@{
        platform = $platform
        image = $image
        file = $artifact
        sha256 = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
        size_bytes = (Get-Item -LiteralPath $archive).Length
    }
}

[ordered]@{
    version = $Version
    source_commit = $commit
    images = $images
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $destination 'release-manifest.json') -Encoding utf8NoBOM
Write-Host "Candidate ready for platform smoke tests: $destination"
