function Invoke-OpenTodayLogs {
    param ([object]$Config)
    
    # 1. Determine shift based on config time split
    $CurrentHour = (Get-Date).Hour
    $TargetFolders = @{}

    if ($CurrentHour -lt $Config.ShiftSplitHour) {
      Write-Host "[Morning Shift] Checking folders..." -ForegroundColor Cyan
      foreach ($p in $Config.MorningShift.psobject.Properties) { $TargetFolders[$p.Name] = $p.Value }
  } else {
      Write-Host "[Evening Shift] Checking folders..." -ForegroundColor Cyan
      foreach ($p in $Config.EveningShift.psobject.Properties) { $TargetFolders[$p.Name] = $p.Value }
  }

    $Today = (Get-Date).Date

    # 2. Process logs in each folder
    foreach ($FolderName in $TargetFolders.Keys) {
        $Count = $TargetFolders[$FolderName]
        $ResolvedPath = "//$($Config.ServerIP)/$FolderName"
        
        if (Test-Path $ResolvedPath) {
            # Standard Logic: Get latest logs of today
            $LogsToOpen = Get-ChildItem -Path $ResolvedPath -Filter "*.log" | 
                          Where-Object { $_.LastWriteTime.Date -eq $Today } | 
                          Sort-Object LastWriteTime -Descending | 
                          Select-Object -First $Count

            # Check if this folder matches any exception configured in config.json[cite: 2]
            $IsException = $false
            foreach ($ExFolder in $Config.OffseFolders) {
                if ($FolderName -like "*$ExFolder") {
                    $IsException = $true
                    break
                }
            }

            # Exceptional Logic: Evening shift specific folder offset[cite: 2]
            if ($CurrentHour -ge $Config.ShiftSplitHour -and $IsException) {
                $LogsToOpen = Get-ChildItem -Path $ResolvedPath -Filter "*.log" | 
                              Where-Object { $_.LastWriteTime.Date -eq $Today } | 
                              Sort-Object LastWriteTime -Descending | 
                              Select-Object -Skip 2 -First 1
            }

            if ($LogsToOpen) {
                foreach ($Log in $LogsToOpen) {
                    Write-Host "Opening from [$FolderName]: $($Log.Name)" -ForegroundColor Green
                    Invoke-Item $Log.FullName
                }
            } else {
                Write-Warning "No logs found today in: $FolderName"
            }
        } else {
            Write-Error "Path not accessible: $ResolvedPath"
        }
    }
}