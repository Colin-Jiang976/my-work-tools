# modules/OpenMorningPages.ps1
# Opens the pages for the current shift, then shows the password book
# with only the accounts needed for those pages.

function Invoke-OpenMorningPages {
    param (
        [object]$Config,
        [string]$SecretsFolder
    )

    # Morning only
    $CurrentHour = (Get-Date).Hour

    if ($CurrentHour -ge $Config.ShiftSplitHour) {
        Write-Host "[Morning Pages] Skipped." -ForegroundColor DarkGray
        return
    }

    # Check config
    if ($null -eq $Config.MorningPages) {
        Write-Warning "MorningPages not found in config."
        return
    }

    # Open pages
    Write-Host "[Morning Pages] Opening..." -ForegroundColor Cyan

    foreach ($Page in $Config.MorningPages) {
        if ([string]::IsNullOrWhiteSpace($Page.Url)) {
            Write-Warning "Empty URL: $($Page.Name)"
            continue
        }

        try {
            Write-Host "Opening: $($Page.Name)" -ForegroundColor Green
            Start-Process $Page.Url
        }
        catch {
            Write-Warning "Failed to open: $($Page.Name)"
        }
    }

    # Show only the accounts needed for today's pages
    if (Get-Command Invoke-PasswordBook -ErrorAction SilentlyContinue) {
        Invoke-PasswordBook -Config $Config -Pages $Config.MorningPages -SecretsFolder $SecretsFolder
    }
    else {
        Write-Warning "PasswordBook module not loaded; skipping."
    }
}
