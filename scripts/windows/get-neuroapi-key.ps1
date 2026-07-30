[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SecretPath
)

$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSEdition -eq 'Desktop') {
    $env:PSModulePath = [System.IO.Path]::Combine($PSHOME, 'Modules')
}

if (-not (Test-Path -LiteralPath $SecretPath -PathType Leaf)) {
    throw 'The NeuroAPI credential is not installed. Run setup-windows.bat again.'
}

$ciphertext = Get-Content -LiteralPath $SecretPath -Raw
$secureKey = ConvertTo-SecureString -String $ciphertext
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
try {
    $plainKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    [Console]::Out.WriteLine($plainKey)
}
finally {
    $plainKey = $null
    if ($bstr -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
    $secureKey.Clear()
}
