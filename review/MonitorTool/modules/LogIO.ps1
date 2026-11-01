# Selection stays in OpenTodayLogs.ps1; filesystem and opening live here.
function Resolve-ToolLogPath {
    param([object]$Config, [string]$FolderName, [string]$LogRoot)
    if (-not [string]::IsNullOrWhiteSpace($LogRoot)) {
        return Join-Path $LogRoot $FolderName
    }
    return "\\$($Config.ServerIP)\$FolderName"
}

function Get-ToolLogFiles {
    param([string]$Path)
    try {
        Get-ChildItem -LiteralPath $Path -File -Filter '*.log' -ErrorAction Stop
    }
    catch { Write-Warning "Cannot enumerate logs in '$Path': $($_.Exception.Message)" }
}

function Invoke-ToolLogItem {
    param([System.IO.FileInfo]$Log, [switch]$Preview)
    if ($Preview) {
        [pscustomobject]@{ Name=$Log.Name; LastWriteTime=$Log.LastWriteTime; FullName=$Log.FullName }
        return
    }
    try { Invoke-Item -LiteralPath $Log.FullName -ErrorAction Stop }
    catch { Write-Warning "Cannot open '$($Log.FullName)': $($_.Exception.Message)" }
}
