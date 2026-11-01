#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'modules/ConfigLoader.ps1')
$testParent = [IO.Path]::GetFullPath((Join-Path $root 'test-runs'))
$scratch = Join-Path $testParent ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($scratch) | Out-Null
$checks = 0
try {
    foreach ($url in @('https://monitoring.example.invalid/status', 'http://monitoring.example.invalid/status',
                       'file:///C:/sample.txt', 'C:\sample.cmd', 'powershell:example', 'https://user:secret@example.invalid/')) {
        $expected = $url -in @('https://monitoring.example.invalid/status', 'http://monitoring.example.invalid/status')
        $path = Join-Path $scratch 'config.json'
        @{ ServerIP = '<YOUR_SERVER_IP>'; ShiftSplitHour = 13; MorningShift = @{}; EveningShift = @{}; OffsetFolders = @();
           MorningPages = @(@{ Name = 'Synthetic page'; Url = $url; AccountKey = 'demo' }) } |
            ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path -Encoding UTF8
        $accepted = $true
        try { $null = Get-ToolConfig -ConfigPath $path } catch { $accepted = $false }
        if ($accepted -ne $expected) { throw ('URL validation did not match expected behavior for case ' + $checks) }
        $checks++
    }
    Write-Host ('PASS: ' + $checks + ' MonitorTool URL cases. No browser, clipboard, share or existing test suite was used.')
} finally {
    $resolved = [IO.Path]::GetFullPath($scratch)
    if (-not $resolved.StartsWith($testParent + '\', [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($resolved) -notmatch '^[a-f0-9]{32}$') { throw 'Refusing cleanup outside this test directory.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction Stop
}
