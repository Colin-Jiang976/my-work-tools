function Get-ToolConfig {
    param([Parameter(Mandatory)][string]$ConfigPath)
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        throw "Configuration not found: $ConfigPath"
    }
    try {
        $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 -ErrorAction Stop |
            ConvertFrom-Json -ErrorAction Stop
    }
    catch { throw "Cannot read configuration '$ConfigPath': $($_.Exception.Message)" }
    if ($null -eq $config) { throw 'Configuration must be a JSON object.' }
    if ([string]$config.ShiftSplitHour -notmatch '^\d+$' -or
        [int]$config.ShiftSplitHour -gt 23) {
        throw 'ShiftSplitHour must be an integer from 0 to 23.'
    }
    foreach ($shift in 'MorningShift','EveningShift') {
        $rules = $config.$shift
        if ($null -eq $rules -or $rules -isnot [pscustomobject]) {
            throw "$shift must be a JSON object of folder names and positive counts."
        }
        foreach ($p in $rules.psobject.Properties) {
            if ([string]::IsNullOrWhiteSpace($p.Name) -or
                [string]$p.Value -notmatch '^[1-9]\d*$' -or [double]$p.Value -gt [int]::MaxValue) {
                throw "Invalid folder/count in $shift : $($p.Name)"
            }
        }
    }
    foreach ($page in $config.MorningPages) {
        if (-not [string]::IsNullOrWhiteSpace($page.Url)) {
            $pageUri = $null
            if (-not [uri]::TryCreate([string]$page.Url, [UriKind]::Absolute, [ref]$pageUri) -or
                $pageUri.Scheme -notin @('http', 'https') -or
                -not [string]::IsNullOrEmpty($pageUri.UserInfo)) {
                throw 'MorningPages URLs must be absolute HTTP/HTTPS addresses without embedded credentials.'
            }
        }
        if (-not [string]::IsNullOrWhiteSpace($page.AccountKey) -and
            $page.AccountKey -notmatch '^[A-Za-z0-9_-]+$') {
            throw 'AccountKey must contain only letters, digits, underscores or hyphens.'
        }
    }
    return $config
}
