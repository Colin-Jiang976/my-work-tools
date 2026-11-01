# modules/SecretStore.ps1
# Encrypts/decrypts credential files using Windows DPAPI.
#
# Design note: encryption is bound to the current Windows user + this specific
# machine. This means credentials can be read automatically at runtime with no
# extra password prompt for this one-user / one-PC workflow.
# This does not protect against a compromised Windows session.

function Protect-SecretData {
    param(
        [Parameter(Mandatory)][string]$PlainText,
        [Parameter(Mandatory)][string]$OutFile
    )

    $secure = ConvertTo-SecureString -String $PlainText -AsPlainText -Force
    $encrypted = ConvertFrom-SecureString -SecureString $secure

    $dir = Split-Path -Parent $OutFile
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    Set-Content -LiteralPath $OutFile -Value $encrypted -Encoding UTF8 -ErrorAction Stop
}

function Unprotect-SecretData {
    param(
        [Parameter(Mandatory)][string]$InFile
    )

    if (-not (Test-Path $InFile)) {
        Write-Warning "Secret file not found: $InFile"
        return $null
    }

    try {
        $encrypted = (Get-Content -LiteralPath $InFile -Raw -ErrorAction Stop).Trim()
        $secure = ConvertTo-SecureString -String $encrypted -ErrorAction Stop
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        try { $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
        finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
        return $plain
    }
    catch {
        throw "Cannot decrypt '$InFile'. Existing credentials were not overwritten. Check the Windows account/machine or restore the file."
    }
}

function Get-AccountSecret {
    param(
        [Parameter(Mandatory)][string]$SecretsFolder,
        [Parameter(Mandatory)][string]$AccountKey
    )

    if ($AccountKey -notmatch '^[A-Za-z0-9_-]+$') { throw 'Invalid account key.' }
    $path = Join-Path $SecretsFolder "$AccountKey.cred"
    $json = Unprotect-SecretData -InFile $path
    if ($null -eq $json) { return $null }

    try {
        $cred = $json | ConvertFrom-Json -ErrorAction Stop
        if ($null -eq $cred -or $null -eq $cred.Username -or $null -eq $cred.Password) {
            throw 'Required credential fields missing.'
        }
        return $cred
    }
    catch {
        throw "Invalid stored credential: $AccountKey. Existing file was not overwritten."
    }
}
