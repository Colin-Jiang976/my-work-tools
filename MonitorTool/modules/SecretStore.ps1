# modules/SecretStore.ps1
# Encrypts/decrypts credential files using Windows DPAPI.
#
# Design note: encryption is bound to the current Windows user + this specific
# machine. This means credentials can be read automatically at runtime with no
# extra password prompt (approved trade-off, since this is a one-person/one-
# account/one-PC setup), while a stolen or copied .cred file is still useless
# on any other machine or under any other Windows account.

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

    Set-Content -Path $OutFile -Value $encrypted -Encoding UTF8
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
        $encrypted = (Get-Content -Path $InFile -Raw).Trim()
        $secure = ConvertTo-SecureString -String $encrypted
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        return $plain
    }
    catch {
        Write-Warning "Failed to decrypt '$InFile'. Wrong Windows account or machine?"
        return $null
    }
}

function Get-AccountSecret {
    param(
        [Parameter(Mandatory)][string]$SecretsFolder,
        [Parameter(Mandatory)][string]$AccountKey
    )

    $path = Join-Path $SecretsFolder "$AccountKey.cred"
    $json = Unprotect-SecretData -InFile $path
    if ($null -eq $json) { return $null }

    try {
        return $json | ConvertFrom-Json
    }
    catch {
        Write-Warning "Secret file is not valid JSON: $AccountKey"
        return $null
    }
}
