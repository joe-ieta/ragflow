#Requires -Version 7.4
[CmdletBinding()]
param([switch]$SkipCompose)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path

& git -C $repo diff --check HEAD --
if ($LASTEXITCODE -ne 0) { throw 'Git diff check failed.' }

foreach ($script in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -File) {
    $tokens = $null
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        $script.FullName, [ref]$tokens, [ref]$parseErrors
    )
    if ($parseErrors) { throw "Invalid PowerShell in $($script.Name): $parseErrors" }
}

$contracts = Join-Path $repo 'agentic_rag/contracts'
$schema = Join-Path $contracts 'payment-readiness.schema.json'
$example = Get-Content -LiteralPath (Join-Path $contracts 'payment-readiness.example.json') -Raw -Encoding UTF8
if (-not (Test-Json -Json $example -SchemaFile $schema)) {
    throw 'Payment readiness example failed schema validation.'
}
$invalid = $example | ConvertFrom-Json -AsHashtable
$invalid.decision = 'eligible_for_review'
$invalidJson = $invalid | ConvertTo-Json -Depth 8
if (Test-Json -Json $invalidJson -SchemaFile $schema -ErrorAction SilentlyContinue) {
    throw 'A result with missing evidence was accepted as eligible.'
}
$eligible = $example | ConvertFrom-Json -AsHashtable
$eligible.decision = 'eligible_for_review'
$eligible.checks[1].status = 'satisfied'
$eligible.checks[1].source_refs = @('archive:D-451/signed-v2')
if (-not (Test-Json -Json ($eligible | ConvertTo-Json -Depth 8) -SchemaFile $schema)) {
    throw 'The positive eligibility example failed validation.'
}

if (-not $SkipCompose) {
    $dockerDirectory = Join-Path $repo 'docker'
    & docker compose --project-name agentic-rag-check --env-file (Join-Path $dockerDirectory '.env') -f (Join-Path $dockerDirectory 'docker-compose.yml') config --quiet
    if ($LASTEXITCODE -ne 0) { throw 'RAGFlow Compose configuration check failed.' }
}
Write-Host 'Agentic RAG scaffold checks passed.'
