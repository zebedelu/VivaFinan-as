[CmdletBinding()]
param(
    [switch]$SkipSeed
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'hosted-env.ps1') -RequireResetConsent

$supabaseDir = Split-Path $PSScriptRoot -Parent
$linkedRefFile = Join-Path $supabaseDir '.temp\project-ref'
$linkedRef = if (Test-Path $linkedRefFile) { (Get-Content $linkedRefFile -Raw).Trim() } else { '' }

if ($linkedRef -ne $env:SUPABASE_PROJECT_REF) {
    & supabase link --project-ref $env:SUPABASE_PROJECT_REF --yes
    if ($LASTEXITCODE -ne 0) { throw 'supabase link falhou.' }
}

$resetArgs = @('db', 'reset', '--remote', '--yes')
if ($SkipSeed) { $resetArgs += '--no-seed' }

& supabase @resetArgs
exit $LASTEXITCODE
