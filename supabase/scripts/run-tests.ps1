[CmdletBinding()]
param(
    [string[]]$Path
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'hosted-env.ps1')

$setup = @'
create extension if not exists pgtap with schema extensions;
grant anon, authenticated to postgres;
grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;
'@

$setupFile = Join-Path ([System.IO.Path]::GetTempPath()) 'vivafinancas-pgtap-setup.sql'
Set-Content -Path $setupFile -Value $setup -Encoding ascii

& psql $env:SUPABASE_DB_URL -v ON_ERROR_STOP=1 -q -f $setupFile
if ($LASTEXITCODE -ne 0) { throw 'Falha ao preparar o pgTAP.' }

$env:PGOPTIONS = '-c search_path=public,extensions'
$targets = if ($Path) { $Path } else { Join-Path $PSScriptRoot '..\tests' }
& pg_prove --ext .sql -r $targets --dbname $env:SUPABASE_DB_URL
exit $LASTEXITCODE
