#Requires -Version 5.1
# No Pester dependency. Run from Windows PowerShell; throws on any failure.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$parseFailures = @()
Get-ChildItem -LiteralPath $root -Filter '*.ps1' -Recurse -File | ForEach-Object {
    $tokens = $null; $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$errors)
    if ($errors) { $parseFailures += @($errors) }
}
if ($parseFailures.Count -gt 0) { throw ($parseFailures | Out-String) }
foreach ($module in 'ConfigLoader','LogIO','OpenTodayLogs','SecretStore') {
    . (Join-Path $root "modules/$module.ps1")
}
function Assert-True([bool]$Value,[string]$Message) { if (-not $Value) { throw $Message } }
$scratch = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
try {
    New-Item -ItemType Directory -Path (Join-Path $scratch 'ShareFolderX') -Force | Out-Null
    $folder = Join-Path $scratch 'ShareFolderX'
    foreach ($day in '2026-10-17','2026-10-18','2026-10-19') {
        foreach ($hour in 8,12,16) {
            $f = Join-Path $folder "$day-$hour.log"
            Set-Content -LiteralPath $f -Value 'synthetic'
            (Get-Item -LiteralPath $f).LastWriteTime = ([datetime]$day).AddHours($hour)
        }
    }
    $cfg = [pscustomobject]@{
        ServerIP='<YOUR_SERVER_IP>'; ShiftSplitHour=13; OffsetFolders=@('ShareFolderX')
        MorningShift=[pscustomobject]@{ShareFolderX=2}
        EveningShift=[pscustomobject]@{ShareFolderX=3}
    }
    # Preview must not open any file. Shadow the external operation to catch regressions.
    function Invoke-Item { throw 'Preview attempted to open a file.' }
    $r = @(Invoke-OpenTodayLogs -Config $cfg -LogRoot $scratch -Now ([datetime]'2026-10-19T09:00:00') -Preview)
    Assert-True ($r.Count -eq 8) 'Monday: expected today 2 + weekend (2 morning + 1 offset) x 2.'
    Assert-True (@($r | Where-Object {$_.LastWriteTime.Date -eq [datetime]'2026-10-18'}).Count -eq 3) 'Sunday selections missing.'
    $r = @(Invoke-OpenTodayLogs -Config $cfg -LogRoot $scratch -Now ([datetime]'2026-10-19T17:00:00') -Preview)
    Assert-True ($r.Count -eq 1 -and $r[0].LastWriteTime.Hour -eq 8) 'Evening offset should select the third latest.'
    $r = @(Invoke-OpenTodayLogs -Config $cfg -LogRoot $scratch -Now ([datetime]'2026-10-20T09:00:00') -Preview -WarningAction SilentlyContinue)
    Assert-True ($r.Count -eq 0) 'Empty date must not select yesterday logs.'
    $cfg | Add-Member -NotePropertyName MorningPages -NotePropertyValue @()
    $cfg.ShiftSplitHour = 24
    $bad = Join-Path $scratch 'bad.json'; $cfg | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $bad
    $rejected = $false
    try { $null = Get-ToolConfig -ConfigPath $bad } catch { $rejected = $true }
    Assert-True $rejected 'Invalid hour must be rejected.'
    # Windows-only DPAPI round trip and corrupt-file preservation.
    $secret = Join-Path $scratch 'demo.cred'
    Protect-SecretData -PlainText '{"Username":"demo","Password":"fake-only"}' -OutFile $secret
    $cred = Get-AccountSecret -SecretsFolder $scratch -AccountKey 'demo'
    Assert-True ($cred.Password -eq 'fake-only') 'DPAPI round trip failed.'
    Set-Content -LiteralPath $secret -Value 'invalid encrypted payload'
    $rejected = $false
    try { $null = Get-AccountSecret -SecretsFolder $scratch -AccountKey 'demo' } catch { $rejected = $true }
    Assert-True $rejected 'Corrupt credential must fail instead of requesting replacement.'
    Assert-True ((Get-Content -LiteralPath $secret -Raw).Trim() -eq 'invalid encrypted payload') 'Corrupt file was overwritten.'
    Write-Host 'PASS: parser, selection, preview, config and DPAPI checks.' -ForegroundColor Green
}
finally { Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue }
