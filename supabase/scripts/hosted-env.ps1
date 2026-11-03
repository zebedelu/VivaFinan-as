[CmdletBinding()]
param(
    [switch]$RequireResetConsent
)

$ErrorActionPreference = 'Stop'

$envFile = if ($env:VIVAFINANCAS_ENV_FILE) {
    $env:VIVAFINANCAS_ENV_FILE
} else {
    Join-Path $HOME '.config\vivafinancas\hosted.env'
}

if (-not (Test-Path $envFile)) {
    throw "Arquivo de ambiente nao encontrado: $envFile. Copie hosted.env.example e preencha."
}

$values = @{}
foreach ($line in Get-Content $envFile) {
    $trimmed = $line.Trim()
    if ($trimmed.Length -eq 0 -or $trimmed.StartsWith('#')) { continue }
    $idx = $trimmed.IndexOf('=')
    if ($idx -lt 1) { continue }
    $key = $trimmed.Substring(0, $idx).Trim()
    $value = $trimmed.Substring($idx + 1).Trim()
    if ($value.Length -ge 2) {
        $first = $value.Substring(0, 1)
        $last = $value.Substring($value.Length - 1, 1)
        if (($first -eq '"' -and $last -eq '"') -or ($first -eq "'" -and $last -eq "'")) {
            $value = $value.Substring(1, $value.Length - 2)
        }
    }
    $values[$key] = $value
}

$required = @(
    'SUPABASE_ACCESS_TOKEN',
    'SUPABASE_PROJECT_REF',
    'VIVAFINANCAS_DEV_PROJECT_REF',
    'SUPABASE_DB_PASSWORD',
    'SUPABASE_DB_URL',
    'SUPABASE_URL',
    'SUPABASE_ANON_KEY',
    'SUPABASE_SERVICE_ROLE_KEY'
)

foreach ($key in $required) {
    if (-not $values.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($values[$key])) {
        throw "Variavel ausente ou vazia em ${envFile}: $key"
    }
    Set-Item -Path "Env:$key" -Value $values[$key]
}

if ($values.ContainsKey('VIVAFINANCAS_ALLOW_REMOTE_RESET')) {
    $env:VIVAFINANCAS_ALLOW_REMOTE_RESET = $values['VIVAFINANCAS_ALLOW_REMOTE_RESET']
}

$env:SUPABASE_URL = $env:SUPABASE_URL.TrimEnd('/')

if ($env:SUPABASE_PROJECT_REF -ne $env:VIVAFINANCAS_DEV_PROJECT_REF) {
    throw 'SUPABASE_PROJECT_REF e VIVAFINANCAS_DEV_PROJECT_REF precisam ter o mesmo valor.'
}

if ($RequireResetConsent -and $env:VIVAFINANCAS_ALLOW_REMOTE_RESET -ne 'yes') {
    throw 'Reset remoto nao autorizado. Defina VIVAFINANCAS_ALLOW_REMOTE_RESET=yes em hosted.env.'
}

$perlRoot = Join-Path $env:LOCALAPPDATA 'StrawberryPerl'
if (Test-Path $perlRoot) {
    foreach ($p in @(
        (Join-Path $perlRoot 'perl\site\bin'),
        (Join-Path $perlRoot 'perl\bin'),
        (Join-Path $perlRoot 'c\bin')
    )) {
        if ($env:Path -notlike "*$p*") { $env:Path = "$p;$env:Path" }
    }
}

if (-not (Get-Command pg_prove -ErrorAction SilentlyContinue)) {
    throw 'pg_prove nao encontrado. Instale com: cpanm TAP::Parser::SourceHandler::pgTAP'
}
