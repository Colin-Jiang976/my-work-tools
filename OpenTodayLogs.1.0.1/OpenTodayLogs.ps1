# ======================================================
# PROJECT: Automated Server Log Monitor
# DESCRIPTION: Automatically opens the latest server logs for daily inspection.
#              Supports separate morning/evening shift configurations.
# ======================================================

# ================= CONFIGURATION AREA =================
# Define target shared folders and log counts via Hash Tables
if ((Get-Date).Hour -lt 13) {
    Write-Host "[Morning Shift] Checking folders..." -ForegroundColor Cyan
    
    $TargetFolders = @{
        "\\<YOUR_SERVER_IP>\ShareFolder1" = 2
        "\\<YOUR_SERVER_IP>\ShareFolder2" = 3
        "\\<YOUR_SERVER_IP>\ShareFolder3" = 3
        "\\<YOUR_SERVER_IP>\ShareFolder4" = 3
        "\\<YOUR_SERVER_IP>\ShareFolder5" = 2
    }
} else {
    Write-Host "[Evening Shift] Checking folders..." -ForegroundColor Cyan
    
    $TargetFolders = @{
        "\\<YOUR_SERVER_IP>\ShareFolder1" = 3
        "\\<YOUR_SERVER_IP>\ShareFolder2" = 3
        "\\<YOUR_SERVER_IP>\ShareFolder3" = 2
    }
}
# ======================================================

# Fetch today's date timestamp (ignoring specific hours/minutes)
$Today = (Get-Date).Date

# Process each folder in the configuration queue
foreach ($Folder in $TargetFolders.Keys) {
    $Count = $TargetFolders[$Folder]
    
    # Verify network connectivity and folder access permissions
    if (Test-Path $Folder) {
        
        # Standard Logic: Fetch today's logs sorted from newest to oldest
        $LogsToOpen = Get-ChildItem -Path $Folder -Filter "*.log" | 
                      Where-Object { $_.LastWriteTime.Date -eq $Today } | 
                      Sort-Object LastWriteTime -Descending | 
                      Select-Object -First $Count

        # Exceptional Logic: Only trigger in the evening (>= 13) for specific folders
        $Hour = (Get-Date).Hour
        if ($Hour -ge 13 -and ($Folder -like "*ShareFolderX" -or $Folder -like "*ShareFolderY")){
		$LogsToOpen = Get-ChildItem -Path $Folder -Filter "*.log" | 
                          Where-Object { $_.LastWriteTime.Date -eq $Today } | 
                          Sort-Object LastWriteTime -Descending | 
                          Select-Object -Skip 2 -First 1
        }

        # Trigger file execution using the default system text editor
        if ($LogsToOpen) {
            foreach ($Log in $LogsToOpen) {
                Write-Host "Opening from [$Folder]: $($Log.Name)" -ForegroundColor Green
                Invoke-Item $Log.FullName
            }
        } else {
            Write-Warning "No logs found today in: $Folder"
        }
    } else {
        Write-Error "Path not accessible: $Folder"
    }
}

# Keep the console open for 3 seconds to review logs before exit
Start-Sleep -Seconds 3