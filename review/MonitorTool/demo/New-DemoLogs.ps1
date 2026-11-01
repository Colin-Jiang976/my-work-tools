#Requires -Version 5.1
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot 'logs'
# A fixed Monday makes weekend handling reproducible on any actual weekday.
foreach ($folder in 'ShareFolder1','ShareFolderX') {
    $path = Join-Path $root $folder
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    foreach ($day in '2026-10-17','2026-10-18','2026-10-19') {
        foreach ($time in '085000','085100','085200','165000','165100','165200') {
            # Monday demo represents a morning run; no future afternoon files.
            if ($day -eq '2026-10-19' -and $time.StartsWith('16')) { continue }
            $file = Join-Path $path "sample_${day}_${time}.log"
            Set-Content -LiteralPath $file -Value "Synthetic log; $day $time; operator review required." -Encoding UTF8
            $stamp = [datetime]::ParseExact("$day $time", 'yyyy-MM-dd HHmmss', [cultureinfo]::InvariantCulture)
            (Get-Item -LiteralPath $file).LastWriteTime = $stamp
        }
    }
}
Write-Host "Synthetic logs ready: $root"
