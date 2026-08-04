param(
  [Parameter(Mandatory = $true)]
  [string]$BakPath,

  [Parameter(Mandatory = $true)]
  [string]$WorkDir,

  [Parameter(Mandatory = $true)]
  [string]$SaPassword,

  [string]$ContainerName = 'vettiflow-sqlserver',
  [int]$SqlPort = 11433,
  [string]$DatabaseName = 'VettiP12',
  [switch]$SkipImport
)

$ErrorActionPreference = 'Stop'

function Resolve-RequiredCommand {
  param([string]$Name)

  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $cmd) {
    throw "Comando '$Name' nao encontrado. Instale antes de continuar."
  }
  return $cmd.Source
}

function Invoke-SqlcmdQuery {
  param(
    [string]$Query,
    [string]$Database = 'master'
  )

  & sqlcmd `
    -S "localhost,$SqlPort" `
    -U sa `
    -P $SaPassword `
    -C `
    -d $Database `
    -l 30 `
    -W `
    -h -1 `
    -Q $Query
}

if (-not (Test-Path -LiteralPath $BakPath)) {
  throw "Backup nao encontrado: $BakPath"
}

Resolve-RequiredCommand 'docker' | Out-Null
Resolve-RequiredCommand 'sqlcmd' | Out-Null
Resolve-RequiredCommand 'bcp' | Out-Null

$postgresPsql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
if (-not $SkipImport -and -not (Test-Path -LiteralPath $postgresPsql)) {
  throw "psql nao encontrado em $postgresPsql. Use -SkipImport para exportar sem importar."
}

$bakItem = Get-Item -LiteralPath $BakPath
$bakDir = $bakItem.DirectoryName
$bakFileName = $bakItem.Name

$dataDir = Join-Path $WorkDir 'mssql-data'
$exportDir = Join-Path $WorkDir 'export'
New-Item -ItemType Directory -Force -Path $dataDir, $exportDir | Out-Null

$exportFile = Join-Path $exportDir 'sb1_products.jsonl'
if (Test-Path -LiteralPath $exportFile) {
  Remove-Item -LiteralPath $exportFile
}

$existing = docker ps -a --filter "name=^/$ContainerName$" --format '{{.Names}}'
if ($existing -eq $ContainerName) {
  docker rm -f $ContainerName | Out-Null
}

Write-Host "Subindo SQL Server Developer em Docker na porta $SqlPort..."
docker run `
  --name $ContainerName `
  -e 'ACCEPT_EULA=Y' `
  -e "MSSQL_SA_PASSWORD=$SaPassword" `
  -e 'MSSQL_PID=Developer' `
  -p "${SqlPort}:1433" `
  -v "${dataDir}:/var/opt/mssql" `
  -v "${bakDir}:/backup:ro" `
  -d mcr.microsoft.com/mssql/server:2022-latest | Out-Null

Write-Host "Aguardando SQL Server aceitar conexao..."
$ready = $false
for ($i = 1; $i -le 60; $i++) {
  try {
    Invoke-SqlcmdQuery "SELECT 1" | Out-Null
    $ready = $true
    break
  } catch {
    Start-Sleep -Seconds 5
  }
}

if (-not $ready) {
  throw "SQL Server no container nao ficou pronto dentro do tempo esperado."
}

$backupPathInContainer = "/backup/$bakFileName"

Write-Host "Restaurando $DatabaseName a partir de $backupPathInContainer..."
$restoreSql = @"
IF DB_ID(N'$DatabaseName') IS NOT NULL
BEGIN
  ALTER DATABASE [$DatabaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
  DROP DATABASE [$DatabaseName];
END;

RESTORE DATABASE [$DatabaseName]
FROM DISK = N'$backupPathInContainer'
WITH
  MOVE N'VettiP12' TO N'/var/opt/mssql/data/VettiP12.mdf',
  MOVE N'VettiP12_log' TO N'/var/opt/mssql/data/VettiP12_log.ldf',
  REPLACE,
  RECOVERY,
  STATS = 5;

ALTER DATABASE [$DatabaseName] SET RECOVERY SIMPLE;
DBCC SHRINKFILE (N'VettiP12_log', 1024);
"@

& sqlcmd `
  -S "localhost,$SqlPort" `
  -U sa `
  -P $SaPassword `
  -C `
  -l 30 `
  -b `
  -Q $restoreSql

Write-Host "Localizando tabelas SB1%..."
$tables = Invoke-SqlcmdQuery -Database $DatabaseName -Query @"
SET NOCOUNT ON;
SELECT QUOTENAME(s.name) + N'.' + QUOTENAME(t.name)
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE t.is_ms_shipped = 0
  AND t.name LIKE 'SB1%'
  AND EXISTS (SELECT 1 FROM sys.columns AS c WHERE c.object_id = t.object_id AND c.name = 'B1_COD')
  AND EXISTS (SELECT 1 FROM sys.columns AS c WHERE c.object_id = t.object_id AND c.name = 'B1_DESC')
ORDER BY s.name, t.name;
"@ | Where-Object { $_.Trim() -ne '' }

if (-not $tables) {
  throw "Nenhuma tabela SB1% com B1_COD/B1_DESC foi encontrada no banco restaurado."
}

foreach ($table in $tables) {
  $table = $table.Trim()
  Write-Host "Exportando $table para JSONL..."

  $plainTable = $table.Replace('[', '').Replace(']', '')
  $hasDeleteColumn = (Invoke-SqlcmdQuery -Database $DatabaseName -Query "SET NOCOUNT ON; SELECT CASE WHEN COL_LENGTH(N'$plainTable', N'D_E_L_E_T_') IS NULL THEN 0 ELSE 1 END;").Trim()
  $whereClause = ''
  if ($hasDeleteColumn -eq '1') {
    $whereClause = "WHERE ISNULL(src.D_E_L_E_T_, '') <> '*'"
  }

  $query = @"
SELECT (
  SELECT
    N'$table' AS [_source_table],
    src.*
  FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
)
FROM [$DatabaseName].$table AS src
$whereClause
"@

  $tempFile = Join-Path $exportDir ("sb1_" + ($table -replace '[\[\]\.]', '_') + ".jsonl")
  & bcp `
    $query `
    queryout $tempFile `
    -S "localhost,$SqlPort" `
    -U sa `
    -P $SaPassword `
    -C 65001 `
    -c

  Get-Content -LiteralPath $tempFile -Encoding UTF8 | Add-Content -LiteralPath $exportFile -Encoding UTF8
}

Write-Host "Export pronto: $exportFile"

if (-not $SkipImport) {
  Write-Host "Importando JSONL para Postgres local..."
  & $postgresPsql `
    -h localhost `
    -p 5432 `
    -U postgres `
    -d vettiflow `
    -v ON_ERROR_STOP=1 `
    -c "TRUNCATE protheus_raw.sb1_products;" `
    -c "\copy protheus_raw.sb1_products(payload) FROM '$($exportFile.Replace('\', '/'))' WITH (FORMAT text, ENCODING 'UTF8')"

  & $postgresPsql `
    -h localhost `
    -p 5432 `
    -U postgres `
    -d vettiflow `
    -c "SELECT count(*) AS produtos_importados FROM protheus_raw.sb1_products;"
}

Write-Host "Concluido."
