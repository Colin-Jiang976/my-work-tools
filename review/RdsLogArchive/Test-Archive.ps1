#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Archive.Core.ps1')
$testParent = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'test-runs'))
$scratch = Join-Path $testParent ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($scratch) | Out-Null
$script:checks = 0
function Assert-True([bool]$Value, [string]$Message) {
    if (-not $Value) { throw $Message }
    $script:checks++
}
function Assert-Reject([scriptblock]$Operation, [string]$Message) {
    $rejected = $false
    try { $null = & $Operation } catch { $rejected = $true }
    Assert-True $rejected $Message
}
function New-Fixture([string]$Name, [string[]]$Names = @('query-a (1).log', 'query-b.log', 'query-c.log', 'query-d.log')) {
    $folder = Join-Path $scratch $Name
    $inputDirectory = Join-Path $folder 'input'
    [IO.Directory]::CreateDirectory($inputDirectory) | Out-Null
    for ($i = 0; $i -lt $Names.Count; $i++) {
        $text = @('ordinary synthetic line', 'ERROR=0 still needs human interpretation', 'ORA-00000 synthetic hint', 'ordinary synthetic line')[$i % 4]
        Set-Content -LiteralPath (Join-Path $inputDirectory $Names[$i]) -Value $text -Encoding UTF8
    }
    @{ InputDirectory = $inputDirectory; ArchiveRoot = Join-Path $folder 'archive'; Files = $Names; Date = [datetime]'2026-10-26' }
}
try {
    $f = New-Fixture 'normal'
    $other = Join-Path $f.InputDirectory 'unrelated.txt'
    Set-Content -LiteralPath $other -Value 'DO NOT SELECT OR MODIFY' -Encoding UTF8
    $before = @{}; Get-ChildItem -LiteralPath $f.InputDirectory -File | ForEach-Object { $before[$_.FullName] = (Get-FileHash -LiteralPath $_.FullName).Hash }
    $preview = Invoke-RdsLogArchive @f
    Assert-True ($preview.Status -eq 'Preview' -and -not (Test-Path -LiteralPath $f.ArchiveRoot)) 'Preview created archive output.'
    Assert-True ($preview.Files.Count -eq 4 -and $preview.Files[0].Group -eq 'Group1' -and $preview.Files[3].Group -eq 'Group2') 'Preview grouping is wrong.'
    $result = Invoke-RdsLogArchive @f -Apply
    Assert-True ($result.Status -eq 'Archived' -and $result.BackupStatus -eq 'NotRequested') 'Apply did not archive locally.'
    foreach ($row in $result.Files) {
        $source = Join-Path $f.InputDirectory $row.OriginalName
        $copy = Join-Path $result.Directory $row.RelativePath
        Assert-True ((Get-FileHash -LiteralPath $source).Hash -eq $before[$source]) 'Source was modified or removed.'
        Assert-True ((Get-FileHash -LiteralPath $copy).Hash -eq $before[$source]) 'Archive bytes changed.'
    }
    Assert-True ((Get-Content -LiteralPath $other -Raw).Trim() -eq 'DO NOT SELECT OR MODIFY') 'Unselected input was modified.'
    Assert-True (@(Get-ChildItem -LiteralPath $result.Directory -Recurse -File | Where-Object Name -eq 'unrelated.txt').Count -eq 0) 'Unselected file was archived.'
    Assert-True ($result.Files[1].MatchingLines -eq 1 -and $result.Files[2].MatchingLines -eq 1) 'Expected keyword hints were not counted.'
    $report = Get-Content -LiteralPath (Join-Path $result.Directory 'archive-report.json') -Raw | ConvertFrom-Json
    Assert-True ($report.Meaning -match 'do not establish business health' -and $report.Files.Count -eq 4) 'Report overstates keyword checking.'
    Assert-Reject { Invoke-RdsLogArchive @f -Apply } 'Existing date archive was overwritten.'
    Assert-Reject { Invoke-RdsLogArchive @f -OpenMatchedFiles } 'Preview was allowed to launch applications.'

    $collision = New-Fixture 'collision' @('same (1).log', 'same.log', 'c.log', 'd.log')
    Assert-Reject { Invoke-RdsLogArchive @collision -Apply } 'Normalized-name collision was accepted.'
    Assert-True (-not (Test-Path -LiteralPath $collision.ArchiveRoot)) 'Collision rejection wrote output.'
    $missing = New-Fixture 'missing'
    $missing.Files = @('absent.log', 'query-b.log', 'query-c.log', 'query-d.log')
    Assert-Reject { Invoke-RdsLogArchive @missing -Apply } 'Missing file was accepted.'
    Assert-True (-not (Test-Path -LiteralPath $missing.ArchiveRoot)) 'Missing file rejection wrote output.'
    $invalid = New-Fixture 'invalid'
    $invalid.Files = @('query-a (1).log')
    Assert-Reject { Invoke-RdsLogArchive @invalid } 'Wrong input count was accepted.'
    $invalid.Files = @('..\outside.log', 'query-b.log', 'query-c.log', 'query-d.log')
    Assert-Reject { Invoke-RdsLogArchive @invalid } 'Path traversal was accepted as a filename.'
    $invalid.Files = @('query-a (1).log', 'query-b.log', 'QUERY-B.LOG', 'query-d.log')
    Assert-Reject { Invoke-RdsLogArchive @invalid } 'Case-only duplicate input was accepted.'

    $literal = New-Fixture 'literal' @('db[01] (1).log', 'node_1.log', 'c.log', 'd.log')
    $literalResult = Invoke-RdsLogArchive @literal -Apply
    Assert-True (Test-Path -LiteralPath (Join-Path $literalResult.Directory 'Group1/db[01].log')) 'Literal brackets were treated as a wildcard.'
    Assert-True (Test-Path -LiteralPath (Join-Path $literalResult.Directory 'Group1/node_1.log')) 'A meaningful underscore suffix was stripped.'

    $backup = New-Fixture 'backup'
    $backupRoot = Join-Path $scratch 'backup-copy'
    $backupResult = Invoke-RdsLogArchive @backup -Apply -BackupRoot $backupRoot
    Assert-True ($backupResult.BackupStatus -eq 'CopiedAndVerified') 'Explicit local backup failed.'
    foreach ($row in $backupResult.Files) {
        Assert-True ((Get-FileHash -LiteralPath (Join-Path $backupResult.Backup $row.RelativePath)).Hash -eq $row.SHA256) 'Backup bytes changed.'
    }
    $existingBackup = New-Fixture 'existing-backup'
    Assert-Reject { Invoke-RdsLogArchive @existingBackup -Apply -BackupRoot $backupRoot } 'Existing backup was overwritten.'
    Assert-True (-not (Test-Path -LiteralPath $existingBackup.ArchiveRoot)) 'Existing backup rejection still wrote local archive.'

    $failedBackup = New-Fixture 'failed-backup'
    $blocker = Join-Path $scratch 'not-a-directory'
    Set-Content -LiteralPath $blocker -Value 'synthetic blocker'
    $backupError = ''
    try { $null = Invoke-RdsLogArchive @failedBackup -Apply -BackupRoot $blocker } catch { $backupError = $_.Exception.Message }
    Assert-True ($backupError -match 'backup FAILED') 'Backup failure was reported as success.'
    Assert-True (Test-Path -LiteralPath (Join-Path $failedBackup.ArchiveRoot '2026-10-26/archive-report.json')) 'Backup failure lost local archive.'

    $partial = New-Fixture 'partial-copy'
    $script:copyCalls = 0
    function Copy-ArchiveVerifiedFile {
        param([string]$Source, [string]$Destination, [string]$SHA256)
        $script:copyCalls++
        if ($script:copyCalls -eq 2) { throw 'controlled copy failure' }
        [IO.File]::Copy($Source, $Destination, $false)
    }
    Assert-Reject { Invoke-RdsLogArchive @partial -Apply } 'Partial copy was reported as complete.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $partial.ArchiveRoot '2026-10-26'))) 'Partial copy published a completed archive.'
    Assert-True (@(Get-ChildItem -LiteralPath $partial.InputDirectory -File).Count -eq 4) 'Partial copy removed sources.'
    . (Join-Path $PSScriptRoot 'Archive.Core.ps1')
    $badHashCopy = Join-Path $scratch 'bad-hash-copy.log'
    Assert-Reject { Copy-ArchiveVerifiedFile -Source (Join-Path $partial.InputDirectory $partial.Files[0]) -Destination $badHashCopy -SHA256 '0000' } 'Wrong SHA256 was accepted.'

    Write-Host ('PASS: ' + $script:checks + ' archive assertions on synthetic files; no real Downloads, shares, AWS or applications used.')
} finally {
    $resolved = [IO.Path]::GetFullPath($scratch)
    if (-not $resolved.StartsWith($testParent + '\', [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($resolved) -notmatch '^[a-f0-9]{32}$') { throw 'Refusing cleanup outside this test directory.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction Stop
}
