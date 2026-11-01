# modules/PasswordBook.ps1
# Console menu listing only the accounts needed for today's pages.
#
# - If an account has never been used on this PC before, this asks for it
#   once (self-healing setup) and remembers it for next time.
# - Credentials are decrypted in memory only; nothing is written back to disk
#   in plain text.
# - Type a number to copy that account's password, or "u" + number to copy
#   the username instead. The clipboard is cleared once you finish (Enter).

function Invoke-PasswordBook {
    param(
        [Parameter(Mandatory)][object]$Config,
        [Parameter(Mandatory)][array]$Pages,
        [Parameter(Mandatory)][string]$SecretsFolder
    )

    $accounts = @()

    foreach ($page in $Pages) {
        if ([string]::IsNullOrWhiteSpace($page.AccountKey)) { continue }

        $cred = Get-AccountSecret -SecretsFolder $SecretsFolder -AccountKey $page.AccountKey

        if ($null -eq $cred) {
            # First time this account is used on this PC: ask once, then remember it.
            Write-Host ""
            Write-Host "No saved account for '$($page.Name)'. Enter it once (only asked here)."
            $username = Read-Host "  Username"
            $securePassword = Read-Host "  Password" -AsSecureString

            $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
            try { $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
            finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }

            $payload = @{ Username = $username; Password = $password } | ConvertTo-Json -Compress
            Protect-SecretData -PlainText $payload -OutFile (Join-Path $SecretsFolder "$($page.AccountKey).cred")

            $cred = [pscustomobject]@{ Username = $username; Password = $password }
        }

        $accounts += [pscustomobject]@{
            Name     = $page.Name
            Username = $cred.Username
            Password = $cred.Password
        }
    }

    if ($accounts.Count -eq 0) { return }

    Write-Host ""
    Write-Host "=== Password Book ===" -ForegroundColor Cyan
    for ($i = 0; $i -lt $accounts.Count; $i++) {
        Write-Host "  [$($i + 1)] $($accounts[$i].Name)  ($($accounts[$i].Username))"
    }
    Write-Host "  Number = copy password. 'u' + number (e.g. u1) = copy username."
    Write-Host ""

    $copied = $false
    try {
        while ($true) {
            $choice = Read-Host "Copy what? (number / u<number> / Enter to finish)"
            if ([string]::IsNullOrWhiteSpace($choice)) { break }

            $copyUsername = $false
            $numberPart = $choice

            if ($choice.ToLower().StartsWith("u")) {
                $copyUsername = $true
                $numberPart = $choice.Substring(1)
            }

            $index = 0
            if (-not [int]::TryParse($numberPart, [ref]$index)) {
                Write-Host "Invalid choice." -ForegroundColor Yellow
                continue
            }
            $index = $index - 1

            if ($index -lt 0 -or $index -ge $accounts.Count) {
                Write-Host "Invalid choice." -ForegroundColor Yellow
                continue
            }

            if ($copyUsername) {
                Set-Clipboard -Value $accounts[$index].Username -ErrorAction Stop
                $copied = $true
                Write-Host "Username copied." -ForegroundColor Green
            }
            else {
                Set-Clipboard -Value $accounts[$index].Password -ErrorAction Stop
                $copied = $true
                Write-Host "Password copied." -ForegroundColor Green
            }
        }

    }
    finally {
        if ($copied) { Set-Clipboard -Value '' -ErrorAction SilentlyContinue }
        $accounts = @()
    }
}
