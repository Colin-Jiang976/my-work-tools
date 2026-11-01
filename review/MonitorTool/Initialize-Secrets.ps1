# Initialize-Secrets.ps1
# Run this ONCE per Windows account/machine to create encrypted credential files.
#
# The resulting .cred files under /secrets can only be decrypted by this same
# Windows account on this same PC (Windows DPAPI). Re-run this script whenever
# a password changes, or after moving to a new PC / new Windows account.
#
# The account key you enter here must match the "AccountKey" value used for
# the matching page in config.json.

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/modules/SecretStore.ps1"

$SecretsFolder = "$PSScriptRoot/secrets"

Write-Host "=== Secret Initialization ===" -ForegroundColor Cyan
Write-Host "Enter an account key that matches 'AccountKey' in config.json (e.g. page1_account)." -ForegroundColor DarkGray
Write-Host "Leave the account key blank to finish." -ForegroundColor DarkGray
Write-Host ""

while ($true) {
    $key = Read-Host "Account key"
    if ([string]::IsNullOrWhiteSpace($key)) { break }

    if ($key -notmatch '^[A-Za-z0-9_-]+$') {
        Write-Warning 'Use letters, digits, underscores or hyphens for account keys.'
        continue
    }
    $username = Read-Host "Username for '$key'"
    $securePassword = Read-Host "Password for '$key'" -AsSecureString

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    try { $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }

    $payload = @{ Username = $username; Password = $password } | ConvertTo-Json -Compress

    Protect-SecretData -PlainText $payload -OutFile (Join-Path $SecretsFolder "$key.cred")

    Write-Host "Saved: $key.cred" -ForegroundColor Green
    Write-Host ""
}

Write-Host "Done. These files only work for this Windows account on this PC." -ForegroundColor Cyan
