#Requires -Version 5.1
param([switch]$Apply)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Archive.Core.ps1')
$run = Join-Path $PSScriptRoot ('demo-runs/' + [guid]::NewGuid().ToString('N'))
$inputDir = Join-Path $run 'input'
[IO.Directory]::CreateDirectory($inputDir) | Out-Null
$files = @('query-a.log', 'query-b.log', 'query-a (1).log', 'query-b (1).log')
$texts = @('Synthetic database log: routine sample.', 'Synthetic sample: ERROR=0; still needs operator interpretation.', 'Synthetic sample: ORA-00000 placeholder, not a real incident.', 'Synthetic database log: no business conclusion.')
for ($i = 0; $i -lt 4; $i++) { Set-Content -LiteralPath (Join-Path $inputDir $files[$i]) -Value $texts[$i] -Encoding UTF8 }
$config = @{ InputDirectory = './input'; ArchiveRoot = './archive'; Files = $files; GroupNames = @('Group1', 'Group2'); Encoding = 'UTF8'; Keywords = @('err', 'ORA'); BackupRoot = $null }
$configPath = Join-Path $run 'config.demo.json'
$config | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $configPath -Encoding UTF8
Write-Host 'Synthetic local demo. No Downloads scan, AWS access, shared folder or application launch.'
& (Join-Path $PSScriptRoot 'Start-Archive.ps1') -ConfigPath $configPath -Date ([datetime]'2026-10-26') -Apply:$Apply
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
