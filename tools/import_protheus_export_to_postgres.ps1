param(
  [Parameter(Mandatory = $true)]
  [string]$ExportDir,

  [string]$PsqlPath = 'C:\Program Files\PostgreSQL\18\bin\psql.exe',
  [string]$HostName = 'localhost',
  [int]$Port = 5432,
  [string]$User = 'postgres',
  [string]$Database = 'vettiflow'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ExportDir)) {
  throw "Pasta de export nao encontrada: $ExportDir"
}

if (-not (Test-Path -LiteralPath $PsqlPath)) {
  throw "psql nao encontrado: $PsqlPath"
}

$mappings = @(
  @{ File = 'sb1010.json'; Table = 'protheus_raw.sb1_products'; Source = 'SB1010' },
  @{ File = 'sc2010.json'; Table = 'protheus_raw.sc2_orders'; Source = 'SC2010' },
  @{ File = 'sg1010.json'; Table = 'protheus_raw.sg1_structures'; Source = 'SG1010' },
  @{ File = 'sb2010.json'; Table = 'protheus_raw.sb2_balances'; Source = 'SB2010' }
)

$csvMappings = @(
  @{ File = 'sd4010.csv'; Table = 'protheus_raw.sd4_commitments'; Source = 'SD4010' },
  @{ File = 'sd3010.csv'; Table = 'protheus_raw.sd3_movements'; Source = 'SD3010' }
)

$tmpDir = Join-Path $ExportDir '.postgres-import'
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

function Invoke-PsqlFile {
  param([Parameter(Mandatory = $true)][string]$SqlFile)

  & $PsqlPath `
    -h $HostName `
    -p $Port `
    -U $User `
    -d $Database `
    -v ON_ERROR_STOP=1 `
    -f $SqlFile

  if ($LASTEXITCODE -ne 0) {
    throw "Falha ao executar SQL: $SqlFile"
  }
}

function ConvertTo-SqlIdentifier {
  param([Parameter(Mandatory = $true)][string]$Name)

  return '"' + ($Name -replace '"', '""') + '"'
}

function Get-CsvHeaderColumns {
  param([Parameter(Mandatory = $true)][string]$CsvPath)

  $header = Get-Content -LiteralPath $CsvPath -TotalCount 1
  if ([string]::IsNullOrWhiteSpace($header)) {
    throw "CSV sem cabecalho: $CsvPath"
  }

  return $header.Split(',') | ForEach-Object { $_.Trim().Trim('"') }
}

Invoke-PsqlFile 'db\migrations\005_create_protheus_raw_tables.sql'
Invoke-PsqlFile 'db\migrations\010_create_sd3_sd4_raw_tables.sql'

foreach ($mapping in $mappings) {
  $inputPath = Join-Path $ExportDir $mapping.File
  if (-not (Test-Path -LiteralPath $inputPath)) {
    Write-Warning "Arquivo nao encontrado, pulando: $inputPath"
    continue
  }

  $jsonlPath = Join-Path $tmpDir ($mapping.File -replace '\.json$', '.jsonl')
  if (Test-Path -LiteralPath $jsonlPath) {
    Remove-Item -LiteralPath $jsonlPath
  }

  Write-Host "Convertendo $($mapping.File) para JSONL..."
  $count = (& node 'tools/json_array_to_jsonl.mjs' $inputPath $jsonlPath | Select-Object -Last 1).Trim()
  if ($LASTEXITCODE -ne 0) {
    throw "Falha ao converter $inputPath para JSONL."
  }

  Write-Host "Importando $count registros em $($mapping.Table)..."
  $copyPath = $jsonlPath.Replace('\', '/')
  $importSql = Join-Path $tmpDir (($mapping.File -replace '\.json$', '.import.sql'))
  @"
TRUNCATE $($mapping.Table);
CREATE TEMP TABLE import_json_lines(line text);
\copy import_json_lines(line) FROM '$copyPath' WITH (FORMAT csv, DELIMITER E'\x02', QUOTE E'\x01', ESCAPE E'\x01')
INSERT INTO $($mapping.Table)(payload)
SELECT line::jsonb
FROM import_json_lines;
DROP TABLE import_json_lines;
"@ | Set-Content -LiteralPath $importSql -Encoding UTF8

  & $PsqlPath `
    -h $HostName `
    -p $Port `
    -U $User `
    -d $Database `
    -v ON_ERROR_STOP=1 `
    -f $importSql

  if ($LASTEXITCODE -ne 0) {
    throw "Falha ao importar $($mapping.File) em $($mapping.Table)."
  }
}

foreach ($mapping in $csvMappings) {
  $inputPath = Join-Path $ExportDir $mapping.File
  if (-not (Test-Path -LiteralPath $inputPath)) {
    Write-Warning "Arquivo nao encontrado, pulando: $inputPath"
    continue
  }

  $columns = Get-CsvHeaderColumns $inputPath
  $tempColumns = ($columns | ForEach-Object { "$(ConvertTo-SqlIdentifier $_) text" }) -join ",`n  "
  $copyColumns = ($columns | ForEach-Object { ConvertTo-SqlIdentifier $_ }) -join ', '
  $copyPath = $inputPath.Replace('\', '/')
  $importSql = Join-Path $tmpDir (($mapping.File -replace '\.csv$', '.import.sql'))

  Write-Host "Importando CSV $($mapping.File) em $($mapping.Table)..."
  @"
TRUNCATE $($mapping.Table);
CREATE TEMP TABLE import_csv (
  $tempColumns
);
\copy import_csv($copyColumns) FROM '$copyPath' WITH (FORMAT csv, HEADER true)
INSERT INTO $($mapping.Table)(payload)
SELECT to_jsonb(import_csv)
FROM import_csv;
DROP TABLE import_csv;
"@ | Set-Content -LiteralPath $importSql -Encoding UTF8

  Invoke-PsqlFile $importSql
}

Invoke-PsqlFile 'db\migrations\007_create_protheus_business_views.sql'
Invoke-PsqlFile 'db\migrations\011_create_sd3_sd4_business_views.sql'
Invoke-PsqlFile 'db\migrations\009_add_component_branch_warehouse.sql'
Invoke-PsqlFile 'db\migrations\012_add_component_requirement_source.sql'
Invoke-PsqlFile 'db\migrations\013_use_sb2_current_stock_for_op_availability.sql'
Invoke-PsqlFile 'db\migrations\014_add_smd_stage.sql'
Invoke-PsqlFile 'db\migrations\015_create_warehouse_requests.sql'
Invoke-PsqlFile 'db\migrations\016_index_vettiflow_stage_transfer.sql'
Invoke-PsqlFile 'db\migrations\017_add_production_order_planned_stages.sql'
Invoke-PsqlFile 'db\postgres\view_imported_protheus_summary.sql'
