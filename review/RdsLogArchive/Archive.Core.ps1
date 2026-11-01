#Requires -Version 5.1
# Explicit input files, preview first, copy without overwrite. No AWS client.
Set-StrictMode -Version 2.0

function Get-ArchiveFullPath {
    param([Parameter(Mandatory)][string]$Path, [string]$BasePath = (Get-Location).Path)
    if (-not [IO.Path]::IsPathRooted($Path)) { $Path = Join-Path $BasePath $Path }
    $full = [IO.Path]::GetFullPath($Path)
    if ($full.TrimEnd('\') -eq ([IO.Path]::GetPathRoot($full)).TrimEnd('\')) { throw 'Choose a dedicated directory, not a drive/share root.' }
    $full.TrimEnd([IO.Path]::DirectorySeparatorChar)
}

function Test-ArchiveContains {
    param([string]$Parent, [string]$Child)
    $Parent = Get-ArchiveFullPath $Parent
    $Child = Get-ArchiveFullPath $Child
    $Child.Equals($Parent, [StringComparison]::OrdinalIgnoreCase) -or
        $Child.StartsWith($Parent + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}

function Assert-ArchiveLeaf {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name) -or $Name -in @('.', '..') -or
        $Name.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0 -or
        $Name -match '[. ]$' -or $Name -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)') {
        throw 'Use a plain Windows filename, not a path or reserved name.'
    }
}

function Get-ArchiveCleanName {
    param([string]$Name)
    Assert-ArchiveLeaf $Name
    # Only the common browser suffix. A legitimate _1 suffix is left intact.
    $clean = $Name -replace '(?: \([0-9]+\))+(?=\.[^.]+$)', ''
    Assert-ArchiveLeaf $clean
    $clean
}

function New-ArchivePlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$InputDirectory,
        [Parameter(Mandatory)][string]$ArchiveRoot,
        [Parameter(Mandatory)][string[]]$Files,
        [string[]]$GroupNames = @('Group1', 'Group2'),
        [datetime]$Date = (Get-Date)
    )
    if ($Files.Count -ne 4 -or @($Files | Select-Object -Unique).Count -ne 4) {
        throw 'Select exactly four distinct files, in the intended two-plus-two order.'
    }
    if ($GroupNames.Count -ne 2 -or $GroupNames[0] -eq $GroupNames[1]) {
        throw 'Use two distinct group labels.'
    }
    foreach ($group in $GroupNames) { Assert-ArchiveLeaf $group }
    $inputRoot = Get-ArchiveFullPath $InputDirectory
    $archive = Get-ArchiveFullPath $ArchiveRoot
    if ($inputRoot.StartsWith('\\') -or $archive.StartsWith('\\')) {
        throw 'Input and local archive must be local paths. Use explicit backup for a share.'
    }
    if (-not (Test-Path -LiteralPath $inputRoot -PathType Container)) { throw 'Input directory not found.' }
    if ((Test-ArchiveContains $inputRoot $archive) -or (Test-ArchiveContains $archive $inputRoot)) {
        throw 'Input and archive directories must be separate, without nesting.'
    }
    $dayFolder = Join-Path $archive $Date.ToString('yyyy-MM-dd')
    if (Test-Path -LiteralPath $dayFolder) { throw 'Date archive already exists; no files were overwritten. Choose a separate archive root for another batch.' }
    $rows = @()
    $targets = @{}
    $sources = @{}
    for ($i = 0; $i -lt 4; $i++) {
        Assert-ArchiveLeaf $Files[$i]
        $source = Join-Path $inputRoot $Files[$i]
        $item = Get-Item -LiteralPath $source -ErrorAction Stop
        if ($sources.ContainsKey($item.FullName)) { throw 'The same input file was selected more than once.' }
        $sources[$item.FullName] = $true
        if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw 'Input must be a regular file, not a directory or link.'
        }
        $group = $GroupNames[[int][Math]::Floor($i / 2)]
        $cleanName = Get-ArchiveCleanName $item.Name
        $relative = Join-Path $group $cleanName
        if ($targets.ContainsKey($relative)) { throw 'Filename cleanup would cause a collision within a group.' }
        $targets[$relative] = $true
        $rows += [pscustomobject]@{
            Source = $item.FullName; OriginalName = $item.Name; Name = $cleanName; Group = $group
            RelativePath = $relative; Destination = Join-Path $dayFolder $relative
            Bytes = $item.Length; SHA256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
        }
    }
    [pscustomobject]@{ InputDirectory = $inputRoot; ArchiveRoot = $archive; Directory = $dayFolder; Date = $Date.ToString('yyyy-MM-dd'); Files = $rows }
}

function Copy-ArchiveVerifiedFile {
    param([string]$Source, [string]$Destination, [string]$SHA256)
    [IO.File]::Copy($Source, $Destination, $false)
    if ((Get-FileHash -LiteralPath $Destination -Algorithm SHA256 -ErrorAction Stop).Hash -ne $SHA256) {
        throw 'Copied file did not match the planned SHA256. Source files were retained.'
    }
}

function Invoke-RdsLogArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$InputDirectory,
        [Parameter(Mandatory)][string]$ArchiveRoot,
        [Parameter(Mandatory)][string[]]$Files,
        [string[]]$GroupNames = @('Group1', 'Group2'),
        [datetime]$Date = (Get-Date),
        [ValidateSet('UTF8', 'Default', 'Unicode', 'BigEndianUnicode', 'ASCII', 'UTF32')][string]$Encoding = 'UTF8',
        [string[]]$Keywords = @('err', 'ORA'),
        [switch]$Apply,
        [string]$BackupRoot,
        [switch]$OpenMatchedFiles
    )
    if (-not $Keywords -or @($Keywords | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count) { throw 'Keywords must be nonempty literal strings.' }
    if ($OpenMatchedFiles -and -not $Apply) { throw 'Opening files requires an explicit apply operation.' }
    $plan = New-ArchivePlan -InputDirectory $InputDirectory -ArchiveRoot $ArchiveRoot -Files $Files -GroupNames $GroupNames -Date $Date
    $backupTarget = $null
    if ($BackupRoot) {
        $backup = Get-ArchiveFullPath $BackupRoot
        if ((Test-ArchiveContains $plan.ArchiveRoot $backup) -or (Test-ArchiveContains $backup $plan.ArchiveRoot) -or
            (Test-ArchiveContains $plan.InputDirectory $backup) -or (Test-ArchiveContains $backup $plan.InputDirectory)) {
            throw 'Backup must be separate from input and local archive.'
        }
        $backupTarget = Join-Path $backup $plan.Date
        if (Test-Path -LiteralPath $backupTarget) { throw 'Backup destination already exists; no overwrite is allowed.' }
    }
    if (-not $Apply) {
        return [pscustomobject]@{ Status = 'Preview'; Directory = $plan.Directory; Backup = $backupTarget; Files = $plan.Files }
    }

    [IO.Directory]::CreateDirectory($plan.ArchiveRoot) | Out-Null
    $stage = Join-Path $plan.ArchiveRoot ('.staging-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage -ErrorAction Stop | Out-Null
    $observations = @()
    try {
        foreach ($row in $plan.Files) {
            $destination = Join-Path $stage $row.RelativePath
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination)) | Out-Null
            Copy-ArchiveVerifiedFile -Source $row.Source -Destination $destination -SHA256 $row.SHA256
            # This count means matching lines, not confirmed incidents.
            $hits = @(Select-String -LiteralPath $destination -Pattern $Keywords -SimpleMatch -Encoding $Encoding -ErrorAction Stop)
            $observations += [pscustomobject]@{ OriginalName = $row.OriginalName; Name = $row.Name; Group = $row.Group; RelativePath = $row.RelativePath; Bytes = $row.Bytes; SHA256 = $row.SHA256; MatchingLines = $hits.Count }
        }
        $report = [ordered]@{ SchemaVersion = '1.0'; Date = $plan.Date; CreatedAt = (Get-Date).ToUniversalTime().ToString('o'); Files = $observations
            Meaning = 'Keyword matches are review hints. No matches do not establish business health. Source files were retained.' }
        $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $stage 'archive-report.json') -Encoding UTF8 -ErrorAction Stop
        [IO.Directory]::Move($stage, $plan.Directory)
    } catch {
        # Retain failed staging material for inspection rather than deleting unknown contents.
        throw ('Local archive did not commit. Source files retained. Staging: ' + $stage + '. ' + $_.Exception.Message)
    }

    $backupStatus = 'NotRequested'
    if ($backupTarget) {
        $backupStage = $null
        try {
            [IO.Directory]::CreateDirectory($backup) | Out-Null
            $backupStage = Join-Path $backup ('.staging-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $backupStage -ErrorAction Stop | Out-Null
            foreach ($row in $plan.Files) {
                $destination = Join-Path $backupStage $row.RelativePath
                [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination)) | Out-Null
                Copy-ArchiveVerifiedFile -Source (Join-Path $plan.Directory $row.RelativePath) -Destination $destination -SHA256 $row.SHA256
            }
            [IO.File]::Copy((Join-Path $plan.Directory 'archive-report.json'), (Join-Path $backupStage 'archive-report.json'), $false)
            [IO.Directory]::Move($backupStage, $backupTarget)
            $backupStatus = 'CopiedAndVerified'
        } catch {
            throw ('Local archive completed at ' + $plan.Directory + ', but backup FAILED. Sources and local archive retained. ' + $_.Exception.Message)
        }
    }
    if ($OpenMatchedFiles) {
        foreach ($row in $observations | Where-Object { $_.MatchingLines -gt 0 }) {
            Invoke-Item -LiteralPath (Join-Path $plan.Directory $row.RelativePath) -ErrorAction Stop
        }
    }
    [pscustomobject]@{ Status = 'Archived'; Directory = $plan.Directory; Backup = $backupTarget; BackupStatus = $backupStatus; Files = $observations
        Meaning = 'Keyword counts are hints only. Continue the manual business checklist.' }
}
