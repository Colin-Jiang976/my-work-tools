function Invoke-OpenTodayLogs {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][object]$Config,
        [datetime]$Now = (Get-Date),
        [string]$LogRoot,
        [switch]$Preview
    )
    
    # 1. Determine shift based on config time split
    $CurrentHour = $Now.Hour
    $TargetFolders = @{}

    if ($CurrentHour -lt $Config.ShiftSplitHour) {
      Write-Host "[Morning Shift] Checking folders..." -ForegroundColor Cyan
      foreach ($p in $Config.MorningShift.psobject.Properties) { $TargetFolders[$p.Name] = $p.Value }
  } else {
      Write-Host "[Evening Shift] Checking folders..." -ForegroundColor Cyan
      foreach ($p in $Config.EveningShift.psobject.Properties) { $TargetFolders[$p.Name] = $p.Value }
  }

    $Today = $Now.Date

    # 2. Process logs in each folder
    foreach ($FolderName in $TargetFolders.Keys) {
        $Count = $TargetFolders[$FolderName]
        $ResolvedPath = (Resolve-ToolLogPath -Config $Config -FolderName $FolderName -LogRoot $LogRoot)
        
        if (Test-Path $ResolvedPath) {
            # Standard Logic: Get latest logs of today
            $LogsToOpen = Get-ToolLogFiles -Path $ResolvedPath | 
                          Where-Object { $_.LastWriteTime.Date -eq $Today } | 
                          Sort-Object LastWriteTime -Descending | 
                          Select-Object -First $Count

            # Check if this folder matches any exception configured in config.json
            $IsException = $false
            foreach ($ExFolder in $Config.OffsetFolders) {
                if ($FolderName -like "*$ExFolder") {
                    $IsException = $true
                    break
                }
            }

            # Exceptional Logic: Evening shift specific folder offset
            if ($CurrentHour -ge $Config.ShiftSplitHour -and $IsException) {
                $LogsToOpen = Get-ToolLogFiles -Path $ResolvedPath | 
                              Where-Object { $_.LastWriteTime.Date -eq $Today } | 
                              Sort-Object LastWriteTime -Descending | 
                              Select-Object -Skip 2 -First 1
            }

            if ($LogsToOpen) {
                foreach ($Log in $LogsToOpen) {
                    Write-Host "Opening from [$FolderName]: $($Log.Name)" -ForegroundColor Green
                    Invoke-ToolLogItem -Log $Log -Preview:$Preview
                }
            } else {
                Write-Warning "No logs found today in: $FolderName"
            }
        } else {
            Write-Warning "Path not accessible: $ResolvedPath"
        }
    }

    # 3. Existing Monday exception (not a holiday calendar) - also open Saturday & Sunday logs (morning + evening)
    if ($CurrentHour -lt $Config.ShiftSplitHour -and $Today.DayOfWeek -eq [System.DayOfWeek]::Monday) {
        Write-Host "[Monday Catch-up] Checking Saturday & Sunday folders..." -ForegroundColor Yellow

        foreach ($DaysAgo in 1,2) {
            $CheckDate = $Today.AddDays(-$DaysAgo)

            # -- Morning-shift folders for that day --
            foreach ($p in $Config.MorningShift.psobject.Properties) {
                $FolderName = $p.Name
                $Count = $p.Value
                $ResolvedPath = (Resolve-ToolLogPath -Config $Config -FolderName $FolderName -LogRoot $LogRoot)

                if (Test-Path $ResolvedPath) {
                    $LogsToOpen = Get-ToolLogFiles -Path $ResolvedPath | 
                                  Where-Object { $_.LastWriteTime.Date -eq $CheckDate } | 
                                  Sort-Object LastWriteTime -Descending | 
                                  Select-Object -First $Count

                    if ($LogsToOpen) {
                        foreach ($Log in $LogsToOpen) {
                            Write-Host "Opening from [$FolderName] ($($CheckDate.ToString('yyyy-MM-dd'))): $($Log.Name)" -ForegroundColor Green
                            Invoke-ToolLogItem -Log $Log -Preview:$Preview
                        }
                    } else {
                        Write-Warning "No logs found in [$FolderName] for $($CheckDate.ToString('yyyy-MM-dd'))"
                    }
                } else {
                    Write-Warning "Path not accessible: $ResolvedPath"
                }
            }

            # -- Evening-shift folders for that day (same offset exception as usual evening logic) --
            foreach ($p in $Config.EveningShift.psobject.Properties) {
                $FolderName = $p.Name
                $Count = $p.Value
                $ResolvedPath = (Resolve-ToolLogPath -Config $Config -FolderName $FolderName -LogRoot $LogRoot)

                if (Test-Path $ResolvedPath) {
                    $LogsToOpen = Get-ToolLogFiles -Path $ResolvedPath | 
                                  Where-Object { $_.LastWriteTime.Date -eq $CheckDate } | 
                                  Sort-Object LastWriteTime -Descending | 
                                  Select-Object -First $Count

                    $IsException = $false
                    foreach ($ExFolder in $Config.OffsetFolders) {
                        if ($FolderName -like "*$ExFolder") {
                            $IsException = $true
                            break
                        }
                    }

                    if ($IsException) {
                        $LogsToOpen = Get-ToolLogFiles -Path $ResolvedPath | 
                                      Where-Object { $_.LastWriteTime.Date -eq $CheckDate } | 
                                      Sort-Object LastWriteTime -Descending | 
                                      Select-Object -Skip 2 -First 1
                    }

                    if ($LogsToOpen) {
                        foreach ($Log in $LogsToOpen) {
                            Write-Host "Opening from [$FolderName] ($($CheckDate.ToString('yyyy-MM-dd'))): $($Log.Name)" -ForegroundColor Green
                            Invoke-ToolLogItem -Log $Log -Preview:$Preview
                        }
                    } else {
                        Write-Warning "No logs found in [$FolderName] for $($CheckDate.ToString('yyyy-MM-dd'))"
                    }
                } else {
                    Write-Warning "Path not accessible: $ResolvedPath"
                }
            }
        }
    }
}
