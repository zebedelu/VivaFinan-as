[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'hosted-env.ps1')

function Write-Step($name, $ok, $detail = '') {
    $status = if ($ok) { 'PASS' } else { 'FAIL' }
    $suffix = if ($detail) { " - $detail" } else { '' }
    Write-Output ("[{0}] {1}{2}" -f $status, $name, $suffix)
}

Write-Output '== Ferramentas =='
$supabaseVersion = (& supabase --version 2>&1 | Out-String).Trim()
Write-Step 'supabase 3.0.0' ($supabaseVersion -match '^3\.0\.0') $supabaseVersion
$psqlVersion = (& psql --version 2>&1 | Out-String).Trim()
Write-Step 'psql' ($LASTEXITCODE -eq 0) $psqlVersion
$pgProveVersion = (& pg_prove --version 2>&1 | Out-String).Trim()
Write-Step 'pg_prove' ($LASTEXITCODE -eq 0) $pgProveVersion

Write-Output '== Projeto =='
$projectsRaw = (& supabase projects list --output-format json 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) { throw "supabase projects list falhou: $projectsRaw" }
$projects = $projectsRaw | ConvertFrom-Json
$list = if ($projects.projects) { $projects.projects } else { $projects }
$project = $list | Where-Object { $_.id -eq $env:SUPABASE_PROJECT_REF } | Select-Object -First 1
Write-Step 'projeto encontrado' ($null -ne $project) $env:SUPABASE_PROJECT_REF
if ($null -eq $project) { throw 'Projeto nao encontrado na conta do access token.' }

$linkOut = (& supabase link --project-ref $env:SUPABASE_PROJECT_REF --yes 2>&1 | Out-String)
Write-Step 'supabase link' ($LASTEXITCODE -eq 0) ($linkOut.Trim())
if ($LASTEXITCODE -ne 0) { throw "supabase link falhou: $linkOut" }

Write-Output '== Banco =='
$psqlCheck = (& psql $env:SUPABASE_DB_URL -v ON_ERROR_STOP=1 -Atc "select current_user || '|' || current_database();" 2>&1 | Out-String).Trim()
Write-Step 'psql conecta' ($LASTEXITCODE -eq 0) $psqlCheck
if ($LASTEXITCODE -ne 0) { throw "psql falhou: $psqlCheck" }

$authRead = (& psql $env:SUPABASE_DB_URL -v ON_ERROR_STOP=1 -Atc "select count(*) from auth.users;" 2>&1 | Out-String).Trim()
Write-Step 'le auth.users' ($LASTEXITCODE -eq 0) "count=$authRead"
if ($LASTEXITCODE -ne 0) { throw "Leitura de auth.users falhou: $authRead" }

$roleGrant = (& psql $env:SUPABASE_DB_URL -v ON_ERROR_STOP=1 -c "grant anon, authenticated to postgres;" 2>&1 | Out-String).Trim()
Write-Step 'grant anon/authenticated to postgres' ($LASTEXITCODE -eq 0) $roleGrant
if ($LASTEXITCODE -ne 0) { throw "Nao foi possivel conceder authenticated/anon ao postgres: $roleGrant" }

$roleSwitch = (& psql $env:SUPABASE_DB_URL -v ON_ERROR_STOP=1 -Atc "begin; set local role authenticated; select current_user; rollback;" 2>&1 | Out-String).Trim()
Write-Step 'set role authenticated' ($LASTEXITCODE -eq 0) $roleSwitch
if ($LASTEXITCODE -ne 0) { throw "set role authenticated falhou: $roleSwitch" }

$pgtap = (& psql $env:SUPABASE_DB_URL -v ON_ERROR_STOP=1 -Atc "create extension if not exists pgtap with schema extensions; select extversion from pg_extension where extname='pgtap';" 2>&1 | Out-String).Trim()
Write-Step 'pgtap' ($LASTEXITCODE -eq 0) $pgtap
if ($LASTEXITCODE -ne 0) { throw "pgtap indisponivel: $pgtap" }

$tapGrant = (& psql $env:SUPABASE_DB_URL -v ON_ERROR_STOP=1 -c "grant usage on schema extensions to authenticated; grant execute on all functions in schema extensions to authenticated;" 2>&1 | Out-String).Trim()
Write-Step 'grants pgTAP' ($LASTEXITCODE -eq 0) $tapGrant
if ($LASTEXITCODE -ne 0) { throw "Nao foi possivel conceder pgTAP ao authenticated: $tapGrant" }

$plpgsql = (& psql $env:SUPABASE_DB_URL -v ON_ERROR_STOP=1 -Atc "create extension if not exists plpgsql_check; select extversion from pg_extension where extname='plpgsql_check';" 2>&1 | Out-String).Trim()
Write-Step 'plpgsql_check' ($LASTEXITCODE -eq 0) $plpgsql
if ($LASTEXITCODE -ne 0) { Write-Output '[WARN] plpgsql_check indisponivel; db lint tera fallback.' }

Write-Output '== Admin API =='
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$headers = @{
    apikey = $env:SUPABASE_SERVICE_ROLE_KEY
    Authorization = "Bearer $env:SUPABASE_SERVICE_ROLE_KEY"
}
$probeId = '00000000-0000-4000-8000-0000000000ff'
try {
    Invoke-RestMethod -Method Delete -Uri "$env:SUPABASE_URL/auth/v1/admin/users/$probeId" -Headers $headers -ErrorAction SilentlyContinue | Out-Null
} catch { }

$body = @{
    id = $probeId
    email = 'probe@vivafinancas.test'
    password = 'Probe@2026!'
    email_confirm = $true
} | ConvertTo-Json
$probe = Invoke-RestMethod -Method Post -Uri "$env:SUPABASE_URL/auth/v1/admin/users" -Headers $headers -ContentType 'application/json' -Body $body
Write-Step 'admin API cria usuario com id fixo' ($probe.id -eq $probeId) "id=$($probe.id)"
if ($probe.id -ne $probeId) { throw 'A Admin API nao honrou o id fixo; adaptar o provisionamento.' }
try {
    Invoke-RestMethod -Method Delete -Uri "$env:SUPABASE_URL/auth/v1/admin/users/$probeId" -Headers $headers | Out-Null
} catch { }

Write-Output '== Preflight concluido =='
