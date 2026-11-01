#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'config.json'),
    [datetime]$Date = (Get-Date),
    [switch]$Apply,
    [switch]$Backup,
    [switch]$OpenMatchedFiles
)
$ErrorActionPreference = 'Stop'
try {
    . (Join-Path $PSScriptRoot 'Archive.Core.ps1')
    $configFile = Get-Item -LiteralPath $ConfigPath -ErrorAction Stop
    $config = Get-Content -LiteralPath $configFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    foreach ($key in 'InputDirectory', 'ArchiveRoot', 'Files', 'GroupNames', 'Encoding', 'Keywords') {
        if ($null -eq $config.PSObject.Properties[$key]) { throw "Missing configuration field: $key" }
    }
    $options = @{
        InputDirectory = Get-ArchiveFullPath $config.InputDirectory $configFile.DirectoryName
        ArchiveRoot = Get-ArchiveFullPath $config.ArchiveRoot $configFile.DirectoryName
        Files = @($config.Files); GroupNames = @($config.GroupNames); Encoding = $config.Encoding
        Keywords = @($config.Keywords); Date = $Date; Apply = $Apply; OpenMatchedFiles = $OpenMatchedFiles
    }
    if ($Backup) {
        if ($null -eq $config.PSObject.Properties['BackupRoot'] -or [string]::IsNullOrWhiteSpace($config.BackupRoot)) { throw 'Set BackupRoot explicitly before requesting backup.' }
        $options.BackupRoot = Get-ArchiveFullPath $config.BackupRoot $configFile.DirectoryName
    }
    $result = Invoke-RdsLogArchive @options
    $result.Files | Select-Object Group, OriginalName, Name, Bytes | Format-Table -AutoSize | Out-Host
    Write-Host ('Status: ' + $result.Status)
    Write-Host ('Local destination: ' + $result.Directory)
    if ($result.Status -eq 'Archived') {
        $result.Files | Select-Object Group, Name, MatchingLines | Format-Table -AutoSize | Out-Host
        Write-Host $result.Meaning
        Write-Host ('Backup status: ' + $result.BackupStatus)
    } else {
        Write-Host 'Preview only. No archive was created. Use -Apply after checking file order and destinations.'
    }
    exit 0
} catch { Write-Error $_ -ErrorAction Continue; exit 1 }
