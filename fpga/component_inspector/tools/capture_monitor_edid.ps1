param(
    [Parameter(Mandatory = $true)][string]$Model,
    [Parameter(Mandatory = $true)][string]$OutputDirectory
)

# Read the active monitor declaration only. Never change display/registry settings.
# Keep the raw EDID local: it can contain monitor serial identifiers.
$ErrorActionPreference = 'Stop'
$captureDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $captureDirectory) { throw 'Refusing existing output directory' }
$matchingIds = @(Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorID | Where-Object {
    $friendlyName = -join ($_.UserFriendlyName | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ })
    $_.Active -and $friendlyName -eq $Model
})
if ($matchingIds.Count -ne 1) { throw 'Expected exactly one active monitor matching Model' }
$monitorId = $matchingIds[0]
$connections = @(Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorConnectionParams |
    Where-Object { $_.InstanceName -eq $monitorId.InstanceName })
$sourceModes = @(Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorListedSupportedSourceModes |
    Where-Object { $_.InstanceName -eq $monitorId.InstanceName })
if ($connections.Count -ne 1 -or $sourceModes.Count -ne 1) { throw 'Missing/ambiguous WMI monitor association' }
$registryInstance = $monitorId.InstanceName -replace '_\d+$', ''
$registryKey = 'HKLM:\SYSTEM\CurrentControlSet\Enum\' + $registryInstance + '\Device Parameters'
$edidBytes = [byte[]](Get-ItemProperty -LiteralPath $registryKey -Name EDID).EDID
if ($edidBytes.Length -lt 128) { throw 'Missing EDID' }
$hasher = [Security.Cryptography.SHA256]::Create()
try { $edidHash = ([BitConverter]::ToString($hasher.ComputeHash($edidBytes))).Replace('-', '').ToLowerInvariant() }
finally { $hasher.Dispose() }
$modeRows = @($sourceModes[0].MonitorSourceModes | Select-Object HorizontalActivePixels,
    VerticalActivePixels, VerticalRefreshRateNumerator, VerticalRefreshRateDenominator, PixelClockRate)
$capture = [ordered]@{
    captured_at = (Get-Date).ToString('o')
    model = $Model
    active = [bool]$monitorId.Active
    video_output_technology = [uint32]$connections[0].VideoOutputTechnology
    edid_bytes = $edidBytes.Length
    edid_sha256 = $edidHash
    source_mode_count = $modeRows.Count
    preferred_source_mode_index = [uint32]$sourceModes[0].PreferredMonitorSourceModeIndex
    source_modes = $modeRows
    capture_script_sha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
    limit = 'Registry EDID and WMI declarations, not measured link timing. Raw EDID remains local; exported JSON omits monitor serial/instance identifiers.'
}
[void][IO.Directory]::CreateDirectory($captureDirectory)
[IO.File]::WriteAllBytes((Join-Path $captureDirectory 'monitor.edid'), $edidBytes)
$jsonText = ($capture | ConvertTo-Json -Depth 6) + "`n"
[IO.File]::WriteAllText((Join-Path $captureDirectory 'capture.json'), $jsonText, [Text.UTF8Encoding]::new($false))
[pscustomobject]@{ Model = $Model; Bytes = $edidBytes.Length; SHA256 = $edidHash; SourceModes = $modeRows.Count; OutputDirectory = $captureDirectory }
