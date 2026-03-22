param(
    [string]$DeviceId,
    [int]$Port = 3000,
    [switch]$SkipRun,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArgs
)

$ErrorActionPreference = 'Stop'

function Get-AndroidDeviceId {
    param([string]$PreferredDeviceId)

    if ($PreferredDeviceId) {
        return $PreferredDeviceId
    }

    $adbOutput = & adb devices
    if ($LASTEXITCODE -ne 0) {
        throw 'No se pudo ejecutar adb. Comprueba que Android SDK Platform-Tools esta instalado y en PATH.'
    }

    $deviceLines = $adbOutput |
        Select-Object -Skip 1 |
        Where-Object { $_ -match '\S+\s+device$' }

    if (-not $deviceLines) {
        throw 'No hay dispositivos Android conectados en estado device.'
    }

    foreach ($line in $deviceLines) {
        $candidateId = ($line -split '\s+')[0]
        if ($candidateId -notmatch '^emulator-') {
            return $candidateId
        }
    }

    return ($deviceLines[0] -split '\s+')[0]
}

$resolvedDeviceId = Get-AndroidDeviceId -PreferredDeviceId $DeviceId

Write-Host "[exom] adb reverse tcp:$Port tcp:$Port -> $resolvedDeviceId"
& adb -s $resolvedDeviceId reverse "tcp:$Port" "tcp:$Port"
if ($LASTEXITCODE -ne 0) {
    throw "No se pudo configurar adb reverse para $resolvedDeviceId."
}

if ($SkipRun) {
    Write-Host '[exom] Puerto preparado. Omitiendo flutter run.'
    exit 0
}

$runArgs = @('run', '-d', $resolvedDeviceId) + $FlutterArgs
Write-Host "[exom] flutter $($runArgs -join ' ')"
& flutter @runArgs
exit $LASTEXITCODE
